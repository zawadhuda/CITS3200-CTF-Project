#!/bin/bash
set -e

mkdir -p /var/run/vsftpd/empty

# Passive FTP advertises an IP to the client. The baked-in 127.0.0.1 only
# works on-host; off-host players need the docker host's address, supplied
# as PASV_ADDRESS (see docs/VM.md). Rewritten at boot so the image stays
# environment-independent.
if [ -n "${PASV_ADDRESS:-}" ]; then
    sed -i "s/^pasv_address=.*/pasv_address=${PASV_ADDRESS}/" /etc/vsftpd.conf
fi

service nginx start
vsftpd /etc/vsftpd.conf &
VSFTPD_PID=$!

trap 'kill -TERM $VSFTPD_PID 2>/dev/null; service nginx stop' TERM INT
wait $VSFTPD_PID
