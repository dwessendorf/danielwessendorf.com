#!/usr/bin/env bash
# One-time root step. No Docker/container, proxy or other application changes.
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Run as root on the FLL host.' >&2; exit 1; }
[[ $# == 1 && -f $1 ]] || { echo 'Usage: setup-server.sh PUBLIC_KEY_FILE' >&2; exit 1; }
command -v rrsync >/dev/null
[[ $(hostname) == dwessendorf-cx33-1 ]] || { echo 'Unexpected host.' >&2; exit 1; }
public_key=$(cat "$1")
[[ $public_key == ssh-ed25519\ * && $public_key != *$'\n'* ]] || exit 1
ssh-keygen -lf "$1"

site=/srv/static-sites/danielwessendorf.com
alias_path=/srv/www/danielwessendorf.com
home_dir=/var/lib/deploy-dw
if [[ -e $alias_path || -L $alias_path ]]; then
  [[ -L $alias_path && $(readlink "$alias_path") == "$site" ]] || {
    echo 'Existing /srv/www site differs; refusing to replace it.' >&2; exit 1;
  }
fi
if id deploy-dw >/dev/null 2>&1; then
  [[ $(getent passwd deploy-dw | cut -d: -f6,7) == "$home_dir:/bin/sh" ]] || exit 1
else
  useradd --system --user-group --home-dir "$home_dir" --shell /bin/sh --no-create-home deploy-dw
fi
[[ ! -L $site && ! -L $site/public && ! -L $home_dir && ! -L $home_dir/.ssh && ! -L $home_dir/.ssh/authorized_keys ]] || exit 1
install -d -o root -g root -m 755 /srv/www "$site" "$home_dir" "$home_dir/.ssh"
install -d -o deploy-dw -g deploy-dw -m 755 "$site/public"
expected="restrict,command=\"/usr/bin/rrsync -wo -munge /srv/www/danielwessendorf.com/public\" $public_key"
if [[ -e $home_dir/.ssh/authorized_keys ]]; then
  [[ $(cat "$home_dir/.ssh/authorized_keys") == "$expected" ]] || {
    echo 'A different deploy key exists; refusing to overwrite it.' >&2; exit 1;
  }
else
  printf '%s\n' "$expected" > "$home_dir/.ssh/authorized_keys"
fi
chown root:root "$home_dir/.ssh/authorized_keys"
chmod 644 "$home_dir/.ssh/authorized_keys"
if [[ ! -L $alias_path ]]; then ln -s "$site" "$alias_path"; fi
echo 'Ready: CI can write only /srv/www/danielwessendorf.com/public via restricted rsync.'
