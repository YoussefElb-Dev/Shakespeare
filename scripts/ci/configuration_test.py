"""Exercise credential gates without contacting any account or signing service."""
import base64
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parent
SECRETS = ['ANDROID_KEYSTORE_BASE64', 'ANDROID_KEYSTORE_PASSWORD', 'ANDROID_KEY_ALIAS', 'ANDROID_KEY_PASSWORD',
           'IOS_CERTIFICATE_BASE64', 'IOS_CERTIFICATE_PASSWORD', 'IOS_PROVISION_PROFILE_BASE64', 'APPLE_TEAM_ID',
           'QUOTE_API_URL', 'SIGNED', 'GITHUB_REF_TYPE', 'GITHUB_REF_NAME']


class ConfigurationTests(unittest.TestCase):
    def execute(self, script, extra=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'android').mkdir()
            env = {key: value for key, value in os.environ.items() if key not in SECRETS}
            env.update(RUNNER_TEMP=directory, GITHUB_OUTPUT=str(root / 'output'), GITHUB_STEP_SUMMARY=str(root / 'summary'))
            env.update(extra or {})
            process = subprocess.run([sys.executable, str(SCRIPTS / script)], cwd=root, env=env, capture_output=True, text=True)
            files = {p.relative_to(root).as_posix(): p.read_bytes() for p in root.rglob('*') if p.is_file()}
            return process, files

    def test_unsigned_build_defaults_to_labelled_preview(self):
        process, files = self.execute('configure_build.py')
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertIn(b'preview=true', files['output'])

    def test_signed_build_requires_gateway(self):
        process, _ = self.execute('configure_build.py', {'SIGNED': 'true'})
        self.assertNotEqual(process.returncode, 0)
        self.assertIn('QUOTE_API_URL', process.stderr)

    def test_endpoint_and_release_tag_validation(self):
        for endpoint in ['http://unsafe.example', 'https://user:password@example.com']:
            process, _ = self.execute('configure_build.py', {'QUOTE_API_URL': endpoint})
            self.assertNotEqual(process.returncode, 0)
        process, files = self.execute('configure_build.py', {'QUOTE_API_URL': 'https://studio.example/v1/quotes',
            'GITHUB_REF_TYPE': 'tag', 'GITHUB_REF_NAME': 'v1.2.3'})
        self.assertEqual(process.returncode, 0)
        self.assertIn(b'version=1.2.3', files['output'])
        self.assertIn(b'preview=false', files['output'])

    def test_android_no_credentials_and_partial_credentials(self):
        process, files = self.execute('android_sign.py')
        self.assertEqual(process.returncode, 0)
        self.assertIn(b'signed=false', files['output'])
        process, _ = self.execute('android_sign.py', {'ANDROID_KEY_ALIAS': 'example-only'})
        self.assertNotEqual(process.returncode, 0)

    def test_android_signing_material_stays_in_files_not_logs(self):
        password = 'example-only \\=:密碼\nvalue'
        process, files = self.execute('android_sign.py', {
            'ANDROID_KEYSTORE_BASE64': base64.b64encode(b'test-fixture-not-a-real-keystore').decode(),
            'ANDROID_KEYSTORE_PASSWORD': password, 'ANDROID_KEY_ALIAS': 'test-key', 'ANDROID_KEY_PASSWORD': password})
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertEqual(files['shakespeare-release.jks'], b'test-fixture-not-a-real-keystore')
        self.assertNotIn(password, process.stdout + process.stderr)
        self.assertIn(b'signed=true', files['output'])
        self.assertTrue(files['android/key.properties'].isascii())

    def test_ios_no_credentials_and_partial_credentials(self):
        process, files = self.execute('ios_sign.py')
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertIn(b'signed=false', files['output'])
        self.assertIn(b'unsigned ARM64 device IPA', files['summary'])
        process, _ = self.execute('ios_sign.py', {'APPLE_TEAM_ID': 'TESTTEAM'})
        self.assertNotEqual(process.returncode, 0)


if __name__ == '__main__':
    unittest.main()
