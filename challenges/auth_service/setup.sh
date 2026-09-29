#!/bin/sh
# Provision Chain C: auth-service RE foothold (:8888) + SUID helix-diag
# privesc. Run as root on the CTF VM. Builds from source — the committed
# binaries are not used. Idempotent: safe to re-run.
set -eu

svc_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
bin_dir=/opt/helix

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this setup script as root" >&2
    exit 1
fi

if ! id authsvc >/dev/null 2>&1; then
    useradd --system --home-dir /nonexistent --shell /usr/sbin/nologin authsvc
fi

if ! command -v gcc >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y gcc
fi

install -d -o root -g root -m 0755 "$bin_dir"
gcc -O1 -fno-stack-protector -o "$bin_dir/auth_service" "$svc_dir/auth_service.c"
gcc -O1 -Wno-unused-result -o "$bin_dir/helix-diag" "$svc_dir/helix-diag.c"
chown root:root "$bin_dir/auth_service" "$bin_dir/helix-diag"
chmod 0755 "$bin_dir/auth_service"
chmod 4755 "$bin_dir/helix-diag"

# Root flag: root-readable only. The player reads it after the PATH-hijack
# privesc drops them into a root shell (see privesc.sh, authors only).
printf '%s\n' 'helix{vert_suid-binary-authsvc}' > /root/root.flag
chmod 0600 /root/root.flag

install -o root -g root -m 0644 "$svc_dir/helix-auth.service" \
    /etc/systemd/system/helix-auth.service

systemctl daemon-reload
systemctl enable helix-auth.service
systemctl restart helix-auth.service

echo "Auth service (:8888) + SUID diag installed"
