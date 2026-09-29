#!/bin/sh
# Simulates a plaintext-credential leak: an admin's backup cron job passes
# a password on the command line, so it ends up wherever process-list /
# command-history-style leaks show up. Exposed here via NET-SNMP's
# extend mechanism so a single `snmpwalk` with the community string pulled
# from N1's pcap is enough to read it back out.
echo "mysqldump -u root -p'B4ckup_S3cret_99!' appdb > /backup/appdb-\$(date +%Y%m%d).sql"
