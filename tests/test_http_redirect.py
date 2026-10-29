import http.client
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]
CADDY = os.environ.get('CADDY_TEST_BIN')


def generate(directory, http_port=80, https_port=443, proxy=True):
    source = (ROOT / 'deploy.sh').read_text()
    functions = '\n'.join(re.search(
        r'^' + name + r'\(\) \{\n.*?^\}', source, re.M | re.S).group()
        for name in ('caddy_escape', 'write_caddyfile'))
    # Exercise the actual generator without root or service/filesystem ownership changes.
    script = '''set -Eeuo pipefail
run_as_root() {
  case "$1" in chown|chmod) return 0 ;; esac
  "$@"
}
INSTALL_DIR="$1/config"
DATA_DIR="$1/data"
HTTP_PORT="$2"
HTTPS_PORT="$3"
DOMAIN=proxy.example.com
DECOY_DOMAIN=www.example.org
USERNAME=test-user
PASSWORD=test-password
SERVICE_USER=test
SERVICE_GROUP=test
EMAIL=''
''' + functions + '\nwrite_caddyfile "$4"\n'
    subprocess.run(['bash', '-c', script, 'test', str(directory), str(http_port),
                    str(https_port), 'true' if proxy else 'false'], check=True)
    return (Path(directory) / 'config/Caddyfile').read_text()


class HttpRedirectTests(unittest.TestCase):
    def test_generated_redirect_with_and_without_forward_proxy(self):
        for proxy in (True, False):
            for http_port, https_port, authority in (
                    (80, 443, 'proxy.example.com'),
                    (8080, 8443, 'proxy.example.com:8443')):
                with self.subTest(proxy=proxy, https_port=https_port):
                    with tempfile.TemporaryDirectory() as temp:
                        config = generate(temp, http_port, https_port, proxy)
                    self.assertIn('auto_https disable_redirects', config)
                    self.assertIn('http://:%s {' % http_port, config)
                    self.assertIn('redir https://%s{uri} 308' % authority, config)
                    self.assertNotIn('{host}', config)
                    self.assertNotIn('auto_https off', config)
                    self.assertIn('reverse_proxy https://www.example.org', config)
                    self.assertEqual('basic_auth "test-user"' in config, proxy)

    @unittest.skipUnless(CADDY, 'set CADDY_TEST_BIN for live Caddy redirect checks')
    def test_live_redirect_preserves_uri_and_method_for_any_host(self):
        for https_port in (443, 8443):
            with self.subTest(https_port=https_port), tempfile.TemporaryDirectory() as temp:
                with socket.socket() as sock:
                    sock.bind(('127.0.0.1', 0))
                    port = sock.getsockname()[1]
                config = generate(temp, port, https_port, proxy=False)
                # Stock Caddy lacks the forward_proxy plugin; this test uses the
                # certificate/decoy-only generator mode and omits its order hint.
                config = config.replace('\torder forward_proxy before reverse_proxy\n', '')
                path = Path(temp) / 'Caddyfile'
                path.write_text(config)
                adapted = subprocess.run([CADDY, 'adapt', '--config', str(path),
                                          '--adapter', 'caddyfile'], check=True,
                                         capture_output=True, text=True)
                data = json.loads(adapted.stdout)
                servers = data['apps']['http']['servers']
                tls_servers = [v for v in servers.values() if ':' + str(https_port) in v['listen']]
                self.assertEqual(len(tls_servers), 1)
                self.assertEqual(tls_servers[0]['read_idle_timeout'], 24 * 60 * 60 * 10**9)
                http_servers = {k: v for k, v in servers.items() if ':' + str(port) in v['listen']}
                self.assertEqual(len(http_servers), 1)
                # Run the adapted HTTP server only: no ACME or external network.
                live = {'admin': {'disabled': True}, 'apps': {'http': {'servers': http_servers}}}
                runtime = Path(temp) / 'runtime.json'
                runtime.write_text(json.dumps(live))
                with (Path(temp) / 'caddy.log').open('w+') as log:
                    proc = subprocess.Popen([CADDY, 'run', '--config', str(runtime)],
                                            stdout=log, stderr=log)
                    try:
                        for _ in range(100):
                            if proc.poll() is not None:
                                log.seek(0)
                                self.fail(log.read())
                            try:
                                with socket.create_connection(('127.0.0.1', port), timeout=.1):
                                    break
                            except OSError:
                                time.sleep(.02)
                        authority = 'proxy.example.com' + (':8443' if https_port == 8443 else '')
                        for host in ('213.145.72.78', 'proxy.example.com', 'untrusted.example', '[::1]'):
                            for method in ('GET', 'HEAD', 'POST'):
                                conn = http.client.HTTPConnection('127.0.0.1', port, timeout=2)
                                try:
                                    conn.request(method, '/a%20b?x=1&y=%2F', headers={'Host': host})
                                    response = conn.getresponse()
                                    self.assertEqual(response.status, 308)
                                    self.assertEqual(response.getheader('Location'),
                                                     'https://' + authority + '/a%20b?x=1&y=%2F')
                                    response.read()
                                finally:
                                    conn.close()
                    finally:
                        proc.terminate()
                        proc.wait(timeout=5)


if __name__ == '__main__':
    unittest.main()
