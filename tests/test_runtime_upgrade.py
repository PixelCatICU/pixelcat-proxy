from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'deploy.sh').read_text()


def function(name):
    return re.search(r'^' + name + r'\(\) \{\n.*?^\}', SOURCE, re.M | re.S).group()


class RuntimeUpgradeTests(unittest.TestCase):
    def test_existing_caddy_upgrade_and_forced_source_build(self):
        for version, force, expected in (
                ('v2.11.4', 'false', 'download\nselect-go\nxcaddy\nbuild\nservice\n'),
                ('v2.11.7', 'false', 'service\n'),
                ('v2.11.7', 'true', 'select-go\nxcaddy\nbuild\nservice\n')):
            with self.subTest(version=version, force=force), tempfile.TemporaryDirectory() as temp:
                binary = Path(temp) / 'caddy'
                binary.write_text('#!/bin/sh\necho "' + version + ' h1:test"\n')
                binary.chmod(0o755)
                script = '''set -Eeuo pipefail
CADDY_BIN="$1"
CADDY_VERSION=v2.11.7
BUILD_FROM_SOURCE="$2"
install_base_packages() { :; }
ensure_service_user() { :; }
caddy_service_exists() { return 0; }
caddy_bin_has_forwardproxy() { return 0; }
info() { :; }
download_prebuilt_caddy() {
  if [ "$BUILD_FROM_SOURCE" != true ]; then echo download; fi
  return 1
}
select_or_install_go() { echo select-go; }
install_xcaddy() { echo xcaddy; }
build_caddy() { echo build; }
write_service() { echo service; }
''' + function('caddy_bin_matches_version') + '\n' + function('ensure_caddy_runtime') + '\nensure_caddy_runtime\n'
                result = subprocess.run(['bash', '-c', script, 'test', str(binary), force],
                                        check=True, capture_output=True, text=True)
                self.assertEqual(result.stdout, expected)

    def test_xcaddy_replaces_old_builder_only(self):
        for version in ('v0.4.5', 'v0.4.7'):
            with self.subTest(version=version), tempfile.TemporaryDirectory() as temp:
                binary = Path(temp) / 'xcaddy'
                binary.write_text('#!/bin/sh\necho "' + version + ' h1:test"\n')
                binary.chmod(0o755)
                script = '''set -Eeuo pipefail
XCADDY_BIN="$1"
XCADDY_VERSION=v0.4.7
GO_BIN=go
info() { :; }
run_as_root() { printf '%s\\n' "$*"; }
''' + function('install_xcaddy') + '\ninstall_xcaddy\n'
                result = subprocess.run(['bash', '-c', script, 'test', str(binary)],
                                        check=True, capture_output=True, text=True)
                if version == 'v0.4.7':
                    self.assertEqual(result.stdout, '')
                else:
                    self.assertIn('xcaddy/cmd/xcaddy@v0.4.7', result.stdout)

    def test_rejects_go_older_than_caddy_requirement(self):
        for version, expected in (('go1.25.9', 1), ('go1.26.0', 0), ('go1.27.3', 0)):
            with self.subTest(version=version), tempfile.TemporaryDirectory() as temp:
                binary = Path(temp) / 'go'
                binary.write_text('#!/bin/sh\necho "go version ' + version + ' linux/amd64"\n')
                binary.chmod(0o755)
                result = subprocess.run(['bash', '-c', function('go_version_ok') + '\ngo_version_ok "$1"',
                                         'test', str(binary)])
                self.assertEqual(result.returncode, expected)


if __name__ == '__main__':
    unittest.main()
