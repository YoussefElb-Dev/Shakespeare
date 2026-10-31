"""Both platforms may publish concurrently to the same version tag."""
import os
from pathlib import Path
import re
import subprocess
import sys

tag = os.environ['GITHUB_REF_NAME']
if not re.fullmatch(r'v\d+\.\d+\.\d+', tag):
    sys.exit('Expected a version tag.')
files = [str(p) for p in Path('release-artifacts').rglob('*') if p.suffix in ('.apk', '.aab', '.ipa', '.sha256')]
if not files:
    sys.exit('No successful build artifacts were found for release.')
if subprocess.run(['gh', 'release', 'view', tag], capture_output=True).returncode:
    result = subprocess.run(['gh', 'release', 'create', tag, '--verify-tag', '--title', f'Shakespeare {tag}',
                             '--notes', 'Shakespeare mobile release. Android APK and iOS IPA are attached as each signed platform build completes. See the Actions run summaries for signing and installation details.'], capture_output=True)
    if result.returncode and subprocess.run(['gh', 'release', 'view', tag], capture_output=True).returncode:
        sys.exit('Could not create or find the GitHub Release.')
subprocess.run(['gh', 'release', 'upload', tag, *files, '--clobber'], check=True)
