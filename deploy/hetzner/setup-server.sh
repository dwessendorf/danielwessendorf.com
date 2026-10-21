#!/usr/bin/env bash
# Root-free setup approved by the founder on 2026-10-21.
set -euo pipefail
[[ $(id -un) == deploy && $(hostname) == dwessendorf-cx33-1 ]] || exit 1
[[ $# == 1 && -f $1 ]] || { echo 'Usage: setup-server.sh PUBLIC_KEY_FILE' >&2; exit 1; }
command -v rrsync >/dev/null
ssh-keygen -lf "$1"
site=/srv/static-sites/danielwessendorf.com
for path in "$site" "$site/public" "$HOME/.ssh" "$HOME/.ssh/authorized_keys"; do
  [[ ! -L $path ]] || { echo "Refusing symlink: $path" >&2; exit 1; }
  if [[ -e $path ]]; then
    [[ $(stat -c %u "$path") == "$(id -u)" ]] || { echo "Wrong owner: $path" >&2; exit 1; }
  fi
done
install -d -m 755 "$site" "$site/public"
install -d -m 700 "$HOME/.ssh"
python3 - "$1" <<'PY'
from datetime import datetime, timezone
import fcntl
import hashlib
import os
from pathlib import Path
import stat
import sys

key = Path(sys.argv[1]).read_text().strip()
parts = key.split()
if len(parts) < 2 or parts[0] != 'ssh-ed25519' or '\n' in key:
    raise SystemExit('Expected one Ed25519 public key.')
directory = Path.home() / '.ssh'
path = directory / 'authorized_keys'
line = 'restrict,command="/usr/bin/rrsync -wo -munge /srv/static-sites/danielwessendorf.com/public" ' + key
with (directory / '.dw-authorize.lock').open('a') as lock:
    os.chmod(lock.fileno(), 0o600)
    fcntl.flock(lock, fcntl.LOCK_EX)
    if path.exists():
        info = path.lstat()
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o022:
            raise SystemExit('Unexpected authorized_keys ownership/type/permissions.')
    before = path.read_bytes() if path.exists() else b''
    existing = before.decode().splitlines()
    matches = [entry for entry in existing if parts[1] in entry.split()]
    if matches:
        if matches != [line]:
            raise SystemExit('This key already exists with a different or duplicate restriction.')
        print('The exact restricted key is already installed; no change.')
        raise SystemExit(0)
    backup = path.with_name('authorized_keys.before-dw-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ'))
    backup_fd = os.open(backup, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(backup_fd, 'wb') as stream:
        stream.write(before)
    addition = (b'\n' if before and not before.endswith(b'\n') else b'') + line.encode() + b'\n'
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_APPEND | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, 'ab') as stream:
        stream.write(addition)
        stream.flush()
        os.fsync(stream.fileno())
    after = path.read_bytes()
    if not after.startswith(before) or after != before + addition:
        raise SystemExit('Concurrent authorized_keys change; inspect before proceeding.')
    print('Existing authorized_keys preserved:', hashlib.sha256(before).hexdigest())
    print('Restricted website key appended; backup:', backup.name)
PY
echo 'Prepared static root and restricted website-only key. Proxy and DNS were not changed.'
