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

# --- Local-account challenges (need sys-user/remote-ops; assert inside) ---
sh "$repo/challenges/logic-gate/setup.sh"
sh "$repo/challenges/r2-activation/setup.sh"

# --- Local horizontals (need svc-web-prod/sys-user/remote-ops; assert inside) ---
sh "$repo/challenges/horizontal/setup.sh"

# --- Hypervisor-independent guest DHCP (NAT + host-only, any hypervisor) ---
# A wildcard networkd profile manages every physical NIC; ifupdown keeps
# loopback only so the two stacks never fight over the same lease.
install -o root -g root -m 0644 "$repo/network/10-dhcp.network" \
    /etc/systemd/network/10-dhcp.network
if grep -Eq '^\s*(auto|allow-hotplug|iface)\s+(enp|ens|eth)' \
    /etc/network/interfaces 2>/dev/null; then
    cp -a /etc/network/interfaces /root/interfaces.setup-backup
    printf '%s\n' \
        '# This file describes the network interfaces available on your system' \
        '# and how to activate them. For more information, see interfaces(5).' \
        '' \
        'source /etc/network/interfaces.d/*' \
        '' \
        '# The loopback network interface' \
        'auto lo' \
        'iface lo inet loopback' \
        > /etc/network/interfaces
    echo "Trimmed /etc/network/interfaces to loopback (backup at /root/interfaces.setup-backup)"
fi
systemctl enable --now systemd-networkd

# --- Docker network lab (lives at /opt/network, managed by hand) ---
# The compose tree is synced there separately; here we only install the
# boot unit so the lab comes up with the VM.
if [ -d /opt/network ]; then
    install -o root -g root -m 0644 "$repo/network/ctf-network.service" \
        /etc/systemd/system/ctf-network.service
    # Passive-FTP address auto-detection (host-only IP at boot, any hypervisor).
    install -o root -g root -m 0755 "$repo/network/ctf-pasv-detect.sh" \
        /usr/local/sbin/ctf-pasv-detect.sh
    install -o root -g root -m 0644 "$repo/network/ctf-pasv-detect.service" \
        /etc/systemd/system/ctf-pasv-detect.service
    mkdir -p /etc/systemd/system/ctf-network.service.d
    # Dash-prefixed EnvironmentFile: if detection ever fails, the lab still
    # starts (degraded FTP PASV) instead of failing the whole unit.
    printf '%s\n' '[Unit]' 'Wants=ctf-pasv-detect.service' \
        'After=ctf-pasv-detect.service' '' '[Service]' \
        'EnvironmentFile=-/run/ctf-pasv.env' \
        > /etc/systemd/system/ctf-network.service.d/pasv.conf
else
    echo "WARNING: /opt/network missing, skipping ctf-network.service" >&2
fi

# --- Boot persistence + start order (bots require flaskapp) ---
systemctl daemon-reload
systemctl enable flaskapp.service helix-w3-bot.service helix-oracle-worker.service \
    helix-auth.service helix-vault.service
if [ -f /etc/systemd/system/ctf-pasv-detect.service ]; then
    systemctl enable ctf-pasv-detect.service
fi
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
