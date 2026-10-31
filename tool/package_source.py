"""Package only version-control eligible source, excluding ignored local files."""
from pathlib import Path
import hashlib
import subprocess
import zipfile

root = Path(__file__).resolve().parents[1]
files = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=root).decode('utf-8').split('\0')
destination = root / 'dist'
destination.mkdir(exist_ok=True)
archive = destination / 'Shakespeare-source.zip'
count = 0
with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
    for name in sorted(set(filter(None, files))):
        path = (root / name).resolve()
        path.relative_to(root)  # Ensure all packaged paths stay in the repository.
        if not path.is_file():
            continue
        info = zipfile.ZipInfo.from_file(path, f'Shakespeare/{name.replace(chr(92), "/")}')
        if name == 'android/gradlew':
            info.external_attr = 0o100755 << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        bundle.writestr(info, path.read_bytes())
        count += 1
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
(destination / 'Shakespeare-source.sha256').write_text(f'{digest}  Shakespeare-source.zip\n')
print(f'Packaged {count} source files: {archive.name} ({archive.stat().st_size:,} bytes)')
