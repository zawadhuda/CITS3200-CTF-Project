#!/bin/sh
# One-command provisioning of the full CTF VM: web app, challenge workers,
# auth service, vault, flags, keys, and systemd units. All services are
# enabled, so every challenge is reachable after boot.
#
# Run as root ON THE VM with the repo tree staged (see docs/VM.md):
#     sh /tmp/helix-src/scripts/setup_vm.sh [/tmp/helix-src]
#
# Idempotent: safe to re-run. Env overrides:
#     APP_SRC=/tmp/app APP_DST=/home/svc-web-prod/app CLEANUP=0
set -eu

repo="${1:-/tmp/helix-src}"
APP_SRC="${APP_SRC:-/tmp/app}"
APP_DST="${APP_DST:-/home/svc-web-prod/app}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this setup script as root" >&2
    exit 1
fi

# --- Preconditions: svc-web-prod is created once by hand on the VM and ---
# --- must already exist (user, group, home). Fail fast, not halfway.   ---
if ! getent passwd svc-web-prod >/dev/null 2>&1 \
    || ! getent group svc-web-prod >/dev/null 2>&1 \
    || [ ! -d /home/svc-web-prod ]; then
    echo "ERROR: svc-web-prod user/group/home missing." >&2
    echo "Create it first: /usr/sbin/useradd -m -r -s /usr/sbin/nologin svc-web-prod" >&2
    exit 1
fi

# --- Web app dir (packaged by scripts/package_app.sh: app.py + templates/ + static/ only) ---
if [ -d "$APP_SRC" ]; then
    rm -rf "$APP_DST"
    mv "$APP_SRC" "$APP_DST"
    chown -R svc-web-prod:svc-web-prod "$APP_DST"
    echo "Web app installed at $APP_DST"
else
    echo "WARNING: $APP_SRC missing, keeping existing $APP_DST" >&2
fi

# --- Challenge services (order irrelevant; each script reloads systemd) ---
sh "$repo/src/helix-dynamics/deployment/w2_setup.sh"
sh "$repo/src/helix-dynamics/deployment/setup_w3_a1.sh"
sh "$repo/challenges/auth_service/setup.sh"
sh "$repo/challenges/vault/setup.sh"

# --- Docker network lab (lives at /opt/network, managed by hand) ---
# The compose tree is synced there separately; here we only install the
# boot unit so the lab comes up with the VM.
if [ -d /opt/network ]; then
    install -o root -g root -m 0644 "$repo/network/ctf-network.service" \
        /etc/systemd/system/ctf-network.service
else
    echo "WARNING: /opt/network missing, skipping ctf-network.service" >&2
fi

# --- Boot persistence + start order (bots require flaskapp) ---
systemctl daemon-reload
systemctl enable flaskapp.service helix-w3-bot.service helix-oracle-worker.service \
    helix-auth.service helix-vault.service
if [ -f /etc/systemd/system/ctf-network.service ]; then
    systemctl enable ctf-network.service
fi
systemctl restart flaskapp.service helix-auth.service helix-vault.service
systemctl restart helix-w3-bot.service helix-oracle-worker.service
sleep 2
systemctl is-active flaskapp.service helix-w3-bot.service helix-oracle-worker.service \
    helix-auth.service helix-vault.service
if [ -f /etc/systemd/system/ctf-network.service ]; then
    systemctl restart ctf-network.service
    systemctl is-active ctf-network.service
fi

# --- Destroy staging (repo copy holds keys, flags, solvers) ---
if [ "${CLEANUP:-1}" = 1 ]; then
    case "$repo" in
        /tmp/*) rm -rf "$repo" && echo "Staging $repo removed" ;;
        *) echo "WARNING: repo at $repo left in place (not under /tmp)" >&2 ;;
    esac
fi

echo "VM provisioning complete"
