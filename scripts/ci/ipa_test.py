"""Prove simulator binaries cannot be mislabeled as device IPA downloads."""
from pathlib import Path
import plistlib
import struct
import tempfile
import unittest
import zipfile

from package_unsigned_ipa import package


class IpaTests(unittest.TestCase):
    def fixture(self, root, platform=2, sdk='iphoneos'):
        app = root / 'Runner.app'
        app.mkdir()
        (app / 'Info.plist').write_bytes(plistlib.dumps({
            'DTPlatformName': sdk, 'CFBundleSupportedPlatforms': ['iPhoneOS'], 'CFBundleExecutable': 'Runner'}))
        header = struct.pack('<IIIIIIII', 0xfeedfacf, 0x0100000c, 0, 2, 1, 24, 0, 0)
        (app / 'Runner').write_bytes(header + struct.pack('<IIIIII', 0x32, 24, platform, 0, 0, 0))
        (app / 'Runner').chmod(0o755)
        return app

    def test_device_archive_has_payload_and_checksum(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            output = root / 'device.ipa'
            package(self.fixture(root), output)
            with zipfile.ZipFile(output) as archive:
                self.assertIn('Payload/Runner.app/Runner', archive.namelist())
                self.assertIsNone(archive.testzip())
            self.assertEqual(len(output.with_suffix('.sha256').read_text().split()[0]), 64)

    def test_arm64_simulator_binary_rejected_even_with_device_plist(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaisesRegex(ValueError, 'not built for iOS devices'):
                package(self.fixture(root, platform=7), root / 'bad.ipa')

    def test_simulator_sdk_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with self.assertRaisesRegex(ValueError, 'simulator apps are rejected'):
                package(self.fixture(root, sdk='iphonesimulator'), root / 'bad.ipa')


if __name__ == '__main__':
    unittest.main()
