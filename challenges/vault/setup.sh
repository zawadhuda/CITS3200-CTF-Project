#!/bin/sh
# Provision the Secure Vault padding-oracle service (:9000).
# Run as root on the CTF VM. Idempotent: safe to re-run.
set -eu

svc_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
bin_dir=/opt/helix

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this setup script as root" >&2
    exit 1
fi

if ! id vaultsvc >/dev/null 2>&1; then
    useradd --system --home-dir /nonexistent --shell /usr/sbin/nologin vaultsvc
fi

# Install the crypto dependency via apt (not pip) so the later pip-removal
# hardening step cannot break this service.
if ! python3 -c 'import cryptography' >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y python3-cryptography
fi

install -d -o root -g root -m 0755 "$bin_dir"
# Server embeds _SECRET: readable by the service account only. No other
# player-reachable user (notably svc-web-prod) may read this file.
install -o root -g vaultsvc -m 0750 "$svc_dir/vault_server.py" \
    "$bin_dir/vault_server.py"

install -o root -g root -m 0644 "$svc_dir/helix-vault.service" \
    /etc/systemd/system/helix-vault.service

systemctl daemon-reload
systemctl enable helix-vault.service
systemctl restart helix-vault.service

echo "Vault (:9000) installed"
