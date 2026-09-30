#!/bin/sh
# Provision the no-sudo local horizontals:
#   hop 1: svc-web-prod -> sys-user  (readable backup SSH key, passphrase "dragon")
#   hop 2: sys-user -> remote-ops    (SUID ops-report command injection,
#                                     group-gated like helix-diag)
# Run as root on the CTF VM (or via scripts/setup_vm.sh). Idempotent.
set -eu

hz_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this setup script as root" >&2
    exit 1
fi

for u in svc-web-prod sys-user remote-ops; do
    if ! id "$u" >/dev/null 2>&1; then
        echo "ERROR: $u missing. Create the VM accounts first." >&2
        exit 1
    fi
done
if ! getent group sys-user >/dev/null 2>&1; then
    echo "ERROR: sys-user group missing (binary scoping needs it)." >&2
    exit 1
fi

if ! command -v gcc >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y gcc
fi

# --- Hop 1: sloppy backup, world-readable (the sin). Key has passphrase. ---
install -d -o root -g root -m 0755 /srv/backups/sys-user
install -o root -g root -m 0644 "$hz_dir/sys-user_backup_key" \
    /srv/backups/sys-user/sys-user_backup_key
install -o root -g root -m 0644 "$hz_dir/sys-user_backup_key.pub" \
    /srv/backups/sys-user/sys-user_backup_key.pub

# Public half into sys-user's authorized_keys (append once, never clobber).
install -d -o sys-user -g sys-user -m 0700 /home/sys-user/.ssh
touch /home/sys-user/.ssh/authorized_keys
chown sys-user:sys-user /home/sys-user/.ssh/authorized_keys
chmod 0600 /home/sys-user/.ssh/authorized_keys
pub=$(cat "$hz_dir/sys-user_backup_key.pub")
grep -qxF "$pub" /home/sys-user/.ssh/authorized_keys 2>/dev/null \
    || echo "$pub" >> /home/sys-user/.ssh/authorized_keys

# --- Retired: tmux hop (tmux 3.5a enforces same-UID-or-root in code, so a
# shared socket can never work). Remove every trace if a previous run
# installed it; the SUID below replaces the hop.
if [ -f /etc/systemd/system/remote-ops-tmux.service ]; then
    systemctl disable --now remote-ops-tmux.service 2>/dev/null || true
    rm -f /etc/systemd/system/remote-ops-tmux.service
    systemctl daemon-reload
fi
rm -rf /srv/tmux-shared

# --- Hop 2: remote-ops-owned SUID with a command-injection bug. ---
# 4750 remote-ops:sys-user like helix-diag's gate: sys-user (primary group)
# executes, svc-web-prod and everyone else get Permission denied — no
# skipping the hop. Deliberately a different bug class (interpolation,
# not PATH hijack).
install -d -o root -g root -m 0755 /opt/helix
gcc -O2 -o /tmp/ops-report-build "$hz_dir/ops-report.c"
install -d -o remote-ops -g remote-ops -m 0755 /srv/ops-reports
touch /srv/ops-reports/inbox.log
chown remote-ops:remote-ops /srv/ops-reports/inbox.log
chmod 0644 /srv/ops-reports/inbox.log
install -o remote-ops -g sys-user -m 4750 /tmp/ops-report-build /opt/helix/ops-report
rm -f /tmp/ops-report-build
[ "$(stat -c %a /opt/helix/ops-report)" = 4750 ] || {
    echo "ERROR: ops-report perms wrong" >&2; exit 1; }
echo "horizontals installed (key backup + gated SUID)"
