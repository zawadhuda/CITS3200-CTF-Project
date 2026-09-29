#!/bin/bash
set -e

mkdir -p /var/run/vsftpd/empty
service nginx start
vsftpd /etc/vsftpd.conf &
VSFTPD_PID=$!

trap 'kill -TERM $VSFTPD_PID 2>/dev/null; service nginx stop' TERM INT
wait $VSFTPD_PID
