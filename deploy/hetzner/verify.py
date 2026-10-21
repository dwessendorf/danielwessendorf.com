#!/usr/bin/env python3
"""Verify revision and content at a specific origin or through public DNS."""
import argparse
import hashlib
import json
import re
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--revision', required=True)
parser.add_argument('--origin', help='Origin IPv4; bypass public DNS with curl --resolve')
parser.add_argument('--http', action='store_true', help='Pre-cutover HTTP origin check only')
args = parser.parse_args()
if args.http and not args.origin:
    parser.error('--http requires --origin')
scheme, port = ('http', 80) if args.http else ('https', 443)


def fetch(path, host='danielwessendorf.com', expected=200, location=None):
    with tempfile.TemporaryDirectory() as folder:
        output = Path(folder) / 'response'
        headers = Path(folder) / 'headers'
        command = ['curl', '--silent', '--show-error', '--connect-timeout', '10',
                   '--max-time', '30', '--retry', '3', '--retry-delay', '3',
                   '--output', str(output), '--dump-header', str(headers),
                   '--write-out', '%{http_code}']
        if args.origin:
            command += ['--noproxy', '*', '--resolve', f'{host}:{port}:{args.origin}']
        command += [f'{scheme}://{host}{path}']
        status = subprocess.check_output(command, text=True)
        if status != str(expected):
            raise RuntimeError(f'{host}{path}: expected {expected}, got {status}')
        if location and f'location: {location}' not in headers.read_text().lower():
            raise RuntimeError(f'Unexpected redirect for {host}{path}')
        return output.read_bytes()


marker = json.loads(fetch('/.well-known/deployment.json'))
if marker['revision'] != args.revision:
    raise RuntimeError(f'Wrong deployment: {marker["revision"]}')
index = fetch('/')
if hashlib.sha256(index).hexdigest() != marker['index_sha256']:
    raise RuntimeError('Homepage hash differs from the deployed build.')
for path in ('/about/', '/blog/', '/workshops/', '/talks/'):
    if not fetch(path):
        raise RuntimeError(f'Empty page: {path}')
assets = set(re.findall(r'(?:href|src)=[\"\x27]?(/[^\"\x27\s>]+)', index.decode()))
assets = sorted(path for path in assets if path.endswith(('.css', '.js', '.woff2')))
if not assets:
    raise RuntimeError('No local CSS, JS or font assets in homepage.')
for path in assets + ['/documents/Lebenslauf_Daniel_Wessendorf.pdf']:
    body = fetch(path)
    if not body:
        raise RuntimeError(f'Empty asset: {path}')
    local = Path('public') / path.lstrip('/')
    if local.is_file() and hashlib.sha256(body).digest() != hashlib.sha256(local.read_bytes()).digest():
        raise RuntimeError(f'Asset differs from build: {path}')
fetch('/__dw_nonexistent_page__/', expected=404)
if not args.http:
    fetch('/about/?from=www', host='www.danielwessendorf.com', expected=301,
          location='https://danielwessendorf.com/about/?from=www')
print(f'Verified {args.revision}: homepage hash, sections, assets, PDF, 404' +
      (', TLS and www redirect.' if not args.http else ' over direct origin HTTP.'))
