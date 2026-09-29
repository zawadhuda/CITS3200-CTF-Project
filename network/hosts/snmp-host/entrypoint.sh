#!/bin/bash
set -e

# net-snmp writes registered `extend` entries (among other things) to
# /var/lib/snmp/ across restarts. Not currently the cause of any crash
# (see below), but cleared on every boot anyway since snmpd.conf is the
# single source of truth here and nothing needs to persist.
rm -rf /var/lib/snmp/*

# IMPORTANT: no `-c /etc/snmp/snmpd.conf` here. /etc/snmp/ is already
# snmpd's default config search path — passing it again via -c makes
# snmpd load that same file TWICE in one startup, which registers the
# `extend backup-job` directive against itself and crashes immediately
# with "duplicate table data ... row exists" / "possibly duplicate name",
# even on a completely fresh container with an empty /var/lib/snmp. This
# was the real bug behind that error, found via live testing — the
# /var/lib/snmp persistence angle above was a red herring.
exec /usr/sbin/snmpd -f -Lo
