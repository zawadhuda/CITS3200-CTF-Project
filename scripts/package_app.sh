#!/bin/sh
# Build a clean deploy directory for the CTF VM.
#
# Only the files the Flask service needs are copied: app.py plus the
# templates/ and static/ trees. Everything else in src/helix-dynamics/
# (workers/, deployment/ with keys and flag strings, READMEs, bytecode
# caches, local DB files) must NEVER reach /home/svc-web-prod/ — the
# service user is the attacker's post-RCE identity.
#
# Usage:  sh scripts/package_app.sh [/tmp/app]
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
src="$repo_root/src/helix-dynamics"
dest="${1:-/tmp/app}"

rm -rf "$dest"
mkdir -p "$dest"
cp "$src/app.py" "$dest/"
cp -r "$src/templates" "$src/static" "$dest/"
find "$dest" \( -name '__pycache__' -o -name '*.pyc' \) -exec rm -rf {} + 2>/dev/null || true

# Self-check: the shipped files must contain no solutions or author notes.
# Fails the build if any banned string is present (see docs/SOLUTIONS.md).
if grep -riE '\[CTF\]|crackable|PCAP|FTP|payload|prompt injection|deliberately|deserialisation|deserialization|helix-hpf-' \
        "$dest" 2>/dev/null; then
    echo "ERROR: solution strings found in packaged app dir (see above)" >&2
    exit 1
fi

echo "Packaged clean app dir at $dest:"
find "$dest" -mindepth 1 -maxdepth 2 | sort
