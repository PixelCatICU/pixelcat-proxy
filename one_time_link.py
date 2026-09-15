#!/usr/bin/env python3
"""Short-lived, at-most-once sing-box configuration delivery (stdlib only)."""
import argparse
import hashlib
import hmac
import json
import os
from pathlib import Path
import secrets
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PREFIX = '/pixelcat-once/'
ROUTE = '\t\thandle /pixelcat-once/* {\n\t\t\treverse_proxy 127.0.0.1:18765\n\t\t}\n'


class Claim:
    def __init__(self, digest, payload, expires):
        self.digest, self.payload, self.expires = digest, payload, expires
        self.lock = threading.Lock()

    def take(self, token):
        with self.lock:
            if time.time() >= self.expires:
                self.payload = None
            if not hmac.compare_digest(hashlib.sha256(token.encode()).hexdigest(), self.digest):
                return None
            result, self.payload = self.payload, None
            return result


def handler_for(claim):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass  # Never log bearer tokens or request paths.

        def do_GET(self):
            token = self.path[len(PREFIX):] if self.path.startswith(PREFIX) else ''
            payload = claim.take(token) if len(token) == 64 else None
            self.send_response(200 if payload is not None else 404)
            self.send_header('Cache-Control', 'no-store, private, max-age=0')
            self.send_header('Referrer-Policy', 'no-referrer')
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Content-Length', str(len(payload or b'')))
            self.end_headers()
            if payload is not None:
                try:
                    self.wfile.write(payload)
                except (BrokenPipeError, ConnectionResetError):
                    pass  # Consumption is irreversible, even on interrupted delivery.

        def do_HEAD(self):
            self.send_response(405)
            self.send_header('Allow', 'GET')
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Content-Length', '0')
            self.end_headers()
    return Handler


def prepare(text, ttl, state):
    # Input is the script's existing human-readable configuration export.
    configs = []
    decoder = json.JSONDecoder()
    while '\n{\n' in text:
        start = text.index('\n{\n') + 1
        config, length = decoder.raw_decode(text[start:])
        configs.append(config)
        text = text[start + length:]
    if not configs:
        raise ValueError('No installed node configuration found')
    config = configs[0]
    nodes = [o for c in configs for o in c['outbounds'] if o['type'] != 'direct']
    config['outbounds'] = nodes + [{'type': 'direct', 'tag': 'direct'}]
    # Preserve the already-supported mixed profile; do not silently promise VPN/TUN.
    config['route']['final'] = nodes[0]['tag']
    token = secrets.token_hex(32)
    payload = json.dumps(config, ensure_ascii=False).encode()
    data = {'digest': hashlib.sha256(token.encode()).hexdigest(),
            'payload': payload.decode(), 'expires': time.time() + ttl}
    fd = os.open(str(state), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'w') as f:
        json.dump(data, f)
    return token


def patch_caddy(text):
    if ROUTE in text:
        return text
    # Only the script-owned layout is supported; fail closed for custom files.
    if text.count('\troute {\n') != 1 or '\t\treverse_proxy https://' not in text:
        raise ValueError('Unsupported Caddyfile layout; no changes made')
    if 'log' in text or PREFIX in text:
        raise ValueError('Custom logging/route detected; review token logging before enabling')
    return text.replace('\troute {\n', '\troute {\n' + ROUTE, 1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['prepare', 'serve', 'patch'])
    parser.add_argument('path', type=Path)
    parser.add_argument('--ttl', type=int, default=600)
    args = parser.parse_args()
    if args.action == 'prepare':
        import sys
        if not 30 <= args.ttl <= 3600:
            parser.error('TTL must be between 30 and 3600 seconds')
        print(prepare(sys.stdin.read(), args.ttl, args.path))
    elif args.action == 'patch':
        print(patch_caddy(args.path.read_text()), end='')
    else:
        data = json.loads(args.path.read_text())
        args.path.unlink()  # Credentials only remain in process memory.
        claim = Claim(data['digest'], data['payload'].encode(), data['expires'])
        server = ThreadingHTTPServer(('127.0.0.1', 18765), handler_for(claim))
        server.timeout = 0.5
        try:
            while time.time() < claim.expires:
                server.handle_request()
        finally:
            server.server_close()
            claim.payload = None


if __name__ == '__main__':
    main()
