#!/bin/sh
# Build + install the logic-gate RE challenge into sys-user's home.
# Run as root on the CTF VM (or via scripts/setup_vm.sh). Idempotent.
set -eu

svc_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this setup script as root" >&2
    exit 1
fi

if ! id sys-user >/dev/null 2>&1; then
    echo "ERROR: sys-user missing. Create the VM accounts first." >&2
    exit 1
fi

if ! command -v g++ >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y g++
fi

# -O0 and no strip keep it Ghidra-readable for players. Never ship the .cpp.
g++ -O0 -o /tmp/logic_gate_build "$svc_dir/logic_gate.cpp"
install -o sys-user -g sys-user -m 0755 /tmp/logic_gate_build /home/sys-user/logic_gate
rm -f /tmp/logic_gate_build
# Solvers only: svc-web-prod (and everyone else) stays out of this home.
chown sys-user:sys-user /home/sys-user
chmod 750 /home/sys-user

echo "logic-gate installed for sys-user"
