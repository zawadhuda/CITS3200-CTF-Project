#!/bin/bash
set -e

mkdir -p /run/sshd
/usr/sbin/sshd

exec redis-server /etc/redis.conf
