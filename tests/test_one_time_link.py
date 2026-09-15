import concurrent.futures
import hashlib
import http.client
import importlib.util
import json
from pathlib import Path
import tempfile
import threading
import time
import unittest

spec = importlib.util.spec_from_file_location('one_time_link', Path(__file__).resolve().parents[1] / 'one_time_link.py')
link = importlib.util.module_from_spec(spec)
spec.loader.exec_module(link)


class OneTimeTests(unittest.TestCase):
    def test_http_head_get_retry_and_no_cache(self):
        server = link.ThreadingHTTPServer(('127.0.0.1', 0), link.handler_for(self.claim()))
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        try:
            for method, path, expected in [('HEAD', link.PREFIX + 'a' * 64, 405),
                                            ('GET', link.PREFIX + 'b' * 64, 404),
                                            ('GET', link.PREFIX + 'a' * 64, 200),
                                            ('GET', link.PREFIX + 'a' * 64, 404)]:
                conn = http.client.HTTPConnection(*server.server_address, timeout=2)
                conn.request(method, path)
                response = conn.getresponse()
                self.assertEqual(response.status, expected)
                self.assertIn('no-store', response.getheader('Cache-Control'))
                self.assertEqual(response.read(), b'secret' if expected == 200 else b'')
                conn.close()
        finally:
            server.shutdown()
            server.server_close()
            worker.join()

    def claim(self, expires=None):
        return link.Claim(hashlib.sha256(b'a' * 64).hexdigest(), b'secret', expires or time.time() + 10)

    def test_concurrent_claim_is_at_most_once(self):
        claim = self.claim()
        with concurrent.futures.ThreadPoolExecutor(max_workers=20) as pool:
            results = list(pool.map(lambda _: claim.take('a' * 64), range(100)))
        self.assertEqual(results.count(b'secret'), 1)

    def test_bad_token_does_not_consume(self):
        claim = self.claim()
        self.assertIsNone(claim.take('b' * 64))
        self.assertEqual(claim.take('a' * 64), b'secret')
        self.assertIsNone(claim.take('a' * 64))

    def test_expired_claim_clears_credentials(self):
        claim = self.claim(time.time() - 1)
        self.assertIsNone(claim.take('a' * 64))
        self.assertIsNone(claim.payload)

    def test_prepare_combines_nodes_and_protects_file(self):
        configs = [{'outbounds': [{'type': t, 'tag': t}, {'type': 'direct', 'tag': 'direct'}],
                    'route': {'final': t}, 'inbounds': [{'type': 'mixed'}]}
                   for t in ('naive', 'hysteria2')]
        text = ''.join('\n' + json.dumps(c, indent=2) + '\nnotice\n' for c in configs)
        with tempfile.TemporaryDirectory() as temp:
            state = Path(temp) / 'claim.json'
            token = link.prepare(text, 600, state)
            self.assertEqual(len(token), 64)
            self.assertEqual(state.stat().st_mode & 0o777, 0o600)
            raw = state.read_text()
            self.assertNotIn(token, raw)
            data = json.loads(raw)
            payload = json.loads(data['payload'])
            self.assertEqual([o['type'] for o in payload['outbounds']], ['naive', 'hysteria2', 'direct'])
            self.assertEqual(payload['route']['final'], 'naive')
            with self.assertRaises(FileExistsError):
                link.prepare(text, 600, state)

    def test_caddy_patch_idempotent_and_preserves_proxy(self):
        original = 'example.com {\n\troute {\n\t\tforward_proxy {}\n\t\treverse_proxy https://example.org\n\t}\n}\n'
        patched = link.patch_caddy(original)
        self.assertEqual(link.patch_caddy(patched), patched)
        self.assertIn('forward_proxy {}', patched)
        self.assertLess(patched.index(link.PREFIX), patched.index('forward_proxy'))
        with self.assertRaises(ValueError):
            link.patch_caddy('custom site {}')
        with self.assertRaises(ValueError):
            link.patch_caddy(original + 'log { output file access.log }')


if __name__ == '__main__':
    unittest.main()
