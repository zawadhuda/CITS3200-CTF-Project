#!/bin/sh
set -eu

flag_dir=/opt/helix/flags
flag_file="$flag_dir/w2.txt"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this setup script as root" >&2
    exit 1
fi

if ! getent group svc-web-prod >/dev/null 2>&1; then
    echo "svc-web-prod group does not exist" >&2
    exit 1
fi

install -d -o root -g root -m 0755 "$flag_dir"
printf '%s\n' 'helix{unpickled_and_unbothered}' > "$flag_file"
chown root:svc-web-prod "$flag_file"
chmod 0640 "$flag_file"

echo "W2 flag installed at $flag_file"
