"""Install Apple signing assets, validate the profile, and configure Runner only."""
import base64
import datetime as dt
import fnmatch
import json
import os
from pathlib import Path
import plistlib
import secrets
import subprocess
import sys


def run(label, args):
    result = subprocess.run(args, capture_output=True)
    if result.returncode:
        sys.exit(f'{label} failed. Check the signing certificate, password, and profile. Command output is suppressed to protect secrets.')
    return result.stdout


names = ['IOS_CERTIFICATE_BASE64', 'IOS_CERTIFICATE_PASSWORD', 'IOS_PROVISION_PROFILE_BASE64', 'APPLE_TEAM_ID']
values = {key: os.environ.get(key, '') for key in names}
present = [bool(value) for value in values.values()]
if any(present) and not all(present):
    sys.exit('iOS signing is incomplete. Configure all four iOS signing secrets or remove them all.')
signed = all(present)
if signed:
    temp = Path(os.environ['RUNNER_TEMP'])
    keychain = temp / 'shakespeare-signing.keychain-db'
    cert = temp / 'distribution.p12'
    profile_file = temp / 'profile.mobileprovision'
    try:
        cert.write_bytes(base64.b64decode(values[names[0]], validate=True))
        profile_file.write_bytes(base64.b64decode(values[names[2]], validate=True))
    except ValueError:
        sys.exit('Certificate and provisioning profile secrets must be valid base64.')
    cert.chmod(0o600)
    profile_file.chmod(0o600)
    profile = plistlib.loads(run('Provisioning profile decoding', ['security', 'cms', '-D', '-i', str(profile_file)]))
    team = values['APPLE_TEAM_ID']
    bundle = os.environ.get('IOS_BUNDLE_ID', 'app.shakespeare.shakespeare')
    application_id = profile.get('Entitlements', {}).get('application-identifier', '')
    prefix = profile.get('ApplicationIdentifierPrefix', [team])[0]
    if team not in profile.get('TeamIdentifier', []) or not fnmatch.fnmatchcase(f'{prefix}.{bundle}', application_id):
        sys.exit('Provisioning profile team or bundle ID does not match APPLE_TEAM_ID / IOS_BUNDLE_ID.')
    if profile['ExpirationDate'].replace(tzinfo=dt.timezone.utc) <= dt.datetime.now(dt.timezone.utc):
        sys.exit('The provisioning profile has expired.')
    method = os.environ.get('IOS_EXPORT_METHOD', 'release-testing')
    if method not in ('release-testing', 'app-store-connect'):
        sys.exit('IOS_EXPORT_METHOD must be release-testing or app-store-connect.')
    if profile.get('Entitlements', {}).get('get-task-allow'):
        sys.exit('Use an Apple Distribution certificate and distribution profile, not a development profile.')
    if method == 'release-testing' and not profile.get('ProvisionedDevices'):
        sys.exit('release-testing requires an Ad Hoc distribution profile with registered device UDIDs.')
    if method == 'app-store-connect' and (profile.get('ProvisionedDevices') or profile.get('ProvisionsAllDevices')):
        sys.exit('app-store-connect requires an App Store distribution profile.')

    password = secrets.token_urlsafe(32)
    old_keychains = run('Read keychain search list', ['security', 'list-keychains', '-d', 'user']).decode()
    (temp / 'old-keychains.json').write_text(json.dumps([line.strip().strip('"') for line in old_keychains.splitlines() if line.strip()]))
    run('Create keychain', ['security', 'create-keychain', '-p', password, str(keychain)])
    run('Unlock keychain', ['security', 'unlock-keychain', '-p', password, str(keychain)])
    run('Configure keychain', ['security', 'set-keychain-settings', '-lut', '21600', str(keychain)])
    run('Import certificate', ['security', 'import', str(cert), '-k', str(keychain), '-P', values[names[1]], '-T', '/usr/bin/codesign', '-T', '/usr/bin/security'])
    run('Allow signing tools', ['security', 'set-key-partition-list', '-S', 'apple-tool:,apple:,codesign:', '-s', '-k', password, str(keychain)])
    old = json.loads((temp / 'old-keychains.json').read_text())
    run('Set keychain search list', ['security', 'list-keychains', '-d', 'user', '-s', str(keychain), *old])
    dest = Path.home() / 'Library/MobileDevice/Provisioning Profiles' / f'{profile["UUID"]}.mobileprovision'
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(profile_file.read_bytes())
    (temp / 'installed-profile-path.txt').write_text(str(dest))
    export = {'method': method, 'teamID': team, 'signingStyle': 'manual', 'signingCertificate': 'Apple Distribution',
              'provisioningProfiles': {bundle: profile['UUID']}, 'manageAppVersionAndBuildNumber': False, 'stripSwiftSymbols': True}
    (temp / 'ExportOptions.plist').write_bytes(plistlib.dumps(export))
    # CocoaPods supplies xcodeproj. Target-level configuration avoids signing Pods with an app profile.
    ruby = """require 'xcodeproj'
p = Xcodeproj::Project.open('ios/Runner.xcodeproj')
t = p.targets.find { |target| target.name == 'Runner' }
t.build_configurations.each do |c|
  c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = ENV.fetch('IOS_BUNDLE_ID')
  c.build_settings['DEVELOPMENT_TEAM'] = ENV.fetch('APPLE_TEAM_ID')
  c.build_settings['CODE_SIGN_STYLE'] = 'Manual'
  c.build_settings['CODE_SIGN_IDENTITY'] = 'Apple Distribution'
  c.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = ENV.fetch('PROFILE_UUID')
end
p.save
"""
    os.environ['IOS_BUNDLE_ID'] = bundle
    os.environ['PROFILE_UUID'] = profile['UUID']
    run('Configure Xcode signing', ['ruby', '-e', ruby])
    cert.unlink(missing_ok=True)
    profile_file.unlink(missing_ok=True)

with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as handle:
    handle.write(f'signed={str(signed).lower()}\n')
with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as handle:
    handle.write('### iOS signing\n' + ('Apple distribution signing configured.\n' if signed else 'No Apple distribution credentials: building an unsigned ARM64 device IPA for re-signing by your sideloader, plus separate simulator validation. The IPA must be re-signed before installation.\n'))
