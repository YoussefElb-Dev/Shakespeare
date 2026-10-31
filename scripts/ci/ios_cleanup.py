import json
import os
from pathlib import Path
import subprocess

temp = Path(os.environ['RUNNER_TEMP'])
old = temp / 'old-keychains.json'
if old.exists():
    subprocess.run(['security', 'list-keychains', '-d', 'user', '-s', *json.loads(old.read_text())], check=True)
keychain = temp / 'shakespeare-signing.keychain-db'
if keychain.exists():
    subprocess.run(['security', 'delete-keychain', str(keychain)], check=True)
profile_path = temp / 'installed-profile-path.txt'
if profile_path.exists():
    profile = Path(profile_path.read_text())
    if profile.parent == Path.home() / 'Library/MobileDevice/Provisioning Profiles':
        profile.unlink(missing_ok=True)
for name in ('distribution.p12', 'profile.mobileprovision', 'ExportOptions.plist', 'old-keychains.json', 'installed-profile-path.txt'):
    (temp / name).unlink(missing_ok=True)
