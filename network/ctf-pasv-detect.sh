#!/bin/sh
# Detect the player-visible IPv4 for passive FTP and export it for
# ctf-network.service. Heuristic: first global IPv4 on an interface that is
# neither the default-route device (NAT) nor docker/bridge/veth.
# Runs at boot into /run (tmpfs), so a fresh DHCP lease on any hypervisor is
# picked up with zero guest changes. Fallback: first non-docker global IPv4.
set -eu
out=/run/ctf-pasv.env
rm -f "$out"
defdev=$(ip -4 -o route show default 2>/dev/null | awk "{print \$5}" | head -n1)
pick() {
    excl="$1"
    ip -4 -o addr show scope global 2>/dev/null | awk "{print \$2, \$4}" | while read dev addr; do
        ip=${addr%%/*}
        case "$dev" in docker*|br-*|veth*|lo) continue;; esac
        if [ -n "$excl" ] && [ "$dev" = "$excl" ]; then continue; fi
        echo "PASV_ADDRESS=$ip" > "$out"
        exit 0
    done
    [ -s "$out" ]
}
pick "$defdev" || true
if [ ! -s "$out" ]; then pick "" || true; fi
if [ ! -s "$out" ]; then echo "ctf-pasv-detect: no suitable IPv4 found" >&2; exit 1; fi
exit 0
