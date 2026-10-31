"""Resolve preview/release configuration without writing credentials to logs."""
import os
import re
import sys
from urllib.parse import urlparse


def output(key, value):
    with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as handle:
        handle.write(f'{key}={value}\n')


endpoint = os.environ.get('QUOTE_API_URL', '').strip()
parsed = urlparse(endpoint)
if endpoint and (parsed.scheme != 'https' or not parsed.hostname or parsed.username or '\n' in endpoint):
    sys.exit('QUOTE_API_URL must be an HTTPS URL without user credentials.')
preview = not endpoint
if os.environ.get('SIGNED') == 'true' and preview:
    sys.exit('Signed production builds require QUOTE_API_URL. Deploy the backend first.')
output('preview', str(preview).lower())
version = ''
if os.environ.get('GITHUB_REF_TYPE') == 'tag':
    tag = os.environ['GITHUB_REF_NAME']
    if not re.fullmatch(r'v\d+\.\d+\.\d+', tag):
        sys.exit('Release tags must have the form v1.0.0.')
    version = tag[1:]
output('version', version)
with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as handle:
    handle.write('### App configuration\n' + ('Offline sample preview. No AI service configured.\n' if preview else 'AI gateway configured.\n'))
