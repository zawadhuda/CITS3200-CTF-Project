#!/bin/sh
# Build + install the R2 license-key challenge into remote-ops's home:
# compile the checker ON the VM (pyc matches the VM Python), seal the memo
# into the locked archive, install both. Run as root (or via
# scripts/setup_vm.sh). Idempotent.
set -eu

svc_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
home=/home/remote-ops

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this setup script as root" >&2
    exit 1
fi

if ! id remote-ops >/dev/null 2>&1; then
    echo "ERROR: remote-ops missing. Create the VM accounts first." >&2
    exit 1
fi

if ! command -v zip >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y zip
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM
cp "$svc_dir/activate.py" "$svc_dir/build_archive.py" "$svc_dir/memo.txt" "$work/"
cd "$work"
python3 -m py_compile activate.py
cp __pycache__/activate.cpython-*.pyc activate.pyc
python3 build_archive.py --memo memo.txt --inner-name secret.txt --out archive.zip
# Players get the .pyc + the locked zip ONLY. No source, no build scripts.
install -o remote-ops -g remote-ops -m 0644 activate.pyc archive.zip "$home"/
# Solvers only: nobody else enters this home.
chown remote-ops:remote-ops "$home"
chmod 750 "$home"

echo "R2 activation challenge installed for remote-ops"
