"""Package an actual unsigned iPhone device app for re-signing by a sideloader."""
from pathlib import Path
import hashlib
import os
import plistlib
import stat
import struct
import sys
import zipfile


def package(app, output):
    app, output = Path(app).resolve(), Path(output).resolve()
    with (app / 'Info.plist').open('rb') as stream:
        info = plistlib.load(stream)
    if info.get('DTPlatformName') != 'iphoneos' or info.get('CFBundleSupportedPlatforms') != ['iPhoneOS']:
        raise ValueError('Only an iPhoneOS device app can become a sideload IPA; simulator apps are rejected.')
    executable = app / info['CFBundleExecutable']
    with executable.open('rb') as stream:
        header = stream.read(32)
        if len(header) != 32 or struct.unpack('<II', header[:8]) != (0xfeedfacf, 0x0100000c):
            raise ValueError('Expected a 64-bit ARM device executable.')
        commands = struct.unpack('<I', header[16:20])[0]
        device = False
        for _ in range(commands):
            command, size = struct.unpack('<II', stream.read(8))
            if size < 8 or size > 1024 * 1024:
                raise ValueError('Invalid Mach-O load command.')
            data = stream.read(size - 8)
            if len(data) != size - 8:
                raise ValueError('Truncated Mach-O load command.')
            if command == 0x32:
                platform = struct.unpack('<I', data[:4])[0]
                if platform != 2:
                    raise ValueError('Mach-O binary is not built for iOS devices.')
                device = True
        if not device:
            raise ValueError('No iOS device build version found in Mach-O binary.')
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for root, directories, files in os.walk(app, followlinks=False):
            for name in directories + files:
                path = Path(root) / name
                relative = 'Payload/Runner.app/' + path.relative_to(app).as_posix()
                if path.is_symlink():
                    # Framework links must remain within the built app bundle.
                    path.resolve().relative_to(app)
                    entry = zipfile.ZipInfo(relative)
                    entry.create_system = 3
                    entry.external_attr = (stat.S_IFLNK | 0o777) << 16
                    archive.writestr(entry, os.readlink(path))
                elif path.is_file():
                    archive.write(path, relative)
    with zipfile.ZipFile(output) as archive:
        if archive.testzip() is not None:
            raise ValueError('IPA integrity check failed.')
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix('.sha256').write_text(f'{digest}  {output.name}\n')
    print(f'Packaged unsigned ARM64 device IPA: {output.name}; re-sign with your sideloading tool.')


if __name__ == '__main__':
    package(sys.argv[1], sys.argv[2])
