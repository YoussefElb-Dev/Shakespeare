"""Only invoked on trusted events. All-or-none release credentials."""
import base64
import os
from pathlib import Path
import sys

names = ['ANDROID_KEYSTORE_BASE64', 'ANDROID_KEYSTORE_PASSWORD', 'ANDROID_KEY_ALIAS', 'ANDROID_KEY_PASSWORD']
values = {name: os.environ.get(name, '') for name in names}
present = [bool(v) for v in values.values()]
if any(present) and not all(present):
    sys.exit('Android signing is incomplete. Set all four ANDROID_* secrets or remove them all.')
signed = all(present)
if signed:
    target = Path(os.environ['RUNNER_TEMP']) / 'shakespeare-release.jks'
    try:
        target.write_bytes(base64.b64decode(values[names[0]], validate=True))
    except ValueError:
        sys.exit('ANDROID_KEYSTORE_BASE64 must contain a valid base64-encoded keystore.')
    target.chmod(0o600)

    def escape(value):
        # Java Properties treats leading whitespace, slashes and separators specially.
        encoded = value.encode('utf-16-be')
        return ''.join('\\u%04x' % int.from_bytes(encoded[i:i + 2], 'big') for i in range(0, len(encoded), 2))

    lines = {'storeFile': str(target), 'storePassword': values[names[1]], 'keyAlias': values[names[2]], 'keyPassword': values[names[3]]}
    Path('android/key.properties').write_text(''.join(f'{key}={escape(value)}\n' for key, value in lines.items()), encoding='ascii')
    Path('android/key.properties').chmod(0o600)
with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as handle:
    handle.write(f'signed={str(signed).lower()}\n')
with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as handle:
    handle.write('### Android signing\n' + ('Release keystore configured.\n' if signed else 'No release keystore: APK uses a disposable debug key for installation/testing. No Play Store AAB or production GitHub Release will be published.\n'))
