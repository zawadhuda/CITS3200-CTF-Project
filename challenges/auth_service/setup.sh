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

# remote-ops is a hand-made VM account (your local-escalation chain owns it).
# The SUID below is executable by that group ONLY — assert, never create.
if ! getent group remote-ops >/dev/null 2>&1; then
    echo "ERROR: remote-ops group missing. Create the VM accounts first." >&2
    exit 1
fi

if ! command -v gcc >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y gcc
fi

install -d -o root -g root -m 0755 "$bin_dir"
gcc -O1 -fno-stack-protector -o "$bin_dir/auth_service" "$svc_dir/auth_service.c"
gcc -O1 -Wno-unused-result -o "$bin_dir/helix-diag" "$svc_dir/helix-diag.c"
chown root:root "$bin_dir/auth_service"
chown root:remote-ops "$bin_dir/helix-diag"
chmod 0755 "$bin_dir/auth_service"
# SUID, group-gated: visible to everyone via find, executable by remote-ops
# only. This is what stops svc-web-prod/authsvc shells from skipping
# straight to root — the local-escalation chain must earn remote-ops first.
chmod 4750 "$bin_dir/helix-diag"

# Root flag: root-readable only. The player reads it after the PATH-hijack
# privesc drops them into a root shell (see privesc.sh, authors only).
printf '%s\n' 'helix{ok_fine_youre_hired}' > /root/root.flag
chmod 0600 /root/root.flag

# Closing beat of the intern-vs-server story: the server concedes.
# Flavor only — solvers keep reading /root/root.flag, never this file.
cat > /root/offer.txt <<'EOF'
[FINAL AUDIT DISPATCH]
Subject matched no known intern profile. Similarity Score: 100% - hired.

You did what the intern couldn't: cache box, portal, restore desk,
auth service, and my diagnostics helper. The footage is still going
to Legal. The job offer is going to you.

Position: Junior Penetration Tester, Helix Dynamics.
Start Monday. Don't touch Redis. Don't store creds in pcaps.
And stop staring at the glass.

- MGMT (the server keeps the last word, obviously)
EOF
chmod 0600 /root/offer.txt

install -o root -g root -m 0644 "$svc_dir/helix-auth.service" \
    /etc/systemd/system/helix-auth.service

systemctl daemon-reload
systemctl enable helix-auth.service
systemctl restart helix-auth.service

echo "Auth service (:8888) + SUID diag installed"
