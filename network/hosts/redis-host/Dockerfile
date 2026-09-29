# redis-host (10.20.30.42) — N2/F2, and the box where the F3 root privesc
# (SUID `sysmaint`, unlocked by the secret snmp-host leaks) actually happens.
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    redis-server openssh-server gcc libc6-dev ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Low-priv account the Redis authorized_keys write targets. Deliberately
# distinct from any web-server (www-data) identity so this foothold stays
# independent of other hosts in the range.
#
# Two Debian/Kali gotchas fixed here, found via live testing:
#  - `useradd -m` alone leaves the account password-LOCKED ("!" in shadow).
#    With UsePAM no, sshd's own account check rejects ANY login method
#    (including pubkey) to a locked account, independent of PubkeyAuthentication
#    and PasswordAuthentication — so we give it a throwaway password purely to
#    unlock the account; PasswordAuthentication stays "no" in sshd_config, so
#    this doesn't open an actual password-guessing path.
#  - the .ssh dir wasn't chowned to web-user (stayed root:root from the RUN
#    layer, mode 700). sshd reads authorized_keys as the TARGET user, not
#    root, so a root-owned 700 .ssh dir locks web-user out of its own
#    directory with "Permission denied" — confirmed via sshd -d debug
#    output during live testing. Not just a realism nit; without this the
#    foothold silently never works even with a perfectly valid key on disk.
RUN useradd -m -s /bin/bash web-user \
    && echo 'web-user:redisctf' | chpasswd \
    && mkdir -p /home/web-user/.ssh \
    && chown web-user:web-user /home/web-user/.ssh \
    && chmod 700 /home/web-user/.ssh \
    && ssh-keygen -A

COPY redis.conf /etc/redis.conf
COPY sshd_config /etc/ssh/sshd_config
COPY sysmaint.c /tmp/sysmaint.c
COPY flag2.txt /home/web-user/flag.txt
COPY flag3.txt /root/flag.txt
COPY profile-token.txt /root/profile-token.txt
COPY note.txt /root/note.txt
COPY entrypoint.sh /entrypoint.sh

RUN gcc -O2 -o /usr/local/bin/sysmaint /tmp/sysmaint.c \
    && chown root:root /usr/local/bin/sysmaint \
    && chmod 4755 /usr/local/bin/sysmaint \
    && rm -f /tmp/sysmaint.c \
    && chown web-user:web-user /home/web-user/flag.txt \
    && chmod 644 /home/web-user/flag.txt \
    && chown root:root /root/flag.txt /root/profile-token.txt /root/note.txt \
    && chmod 600 /root/flag.txt /root/profile-token.txt /root/note.txt \
    && chmod +x /entrypoint.sh \
    && mkdir -p /var/lib/redis /var/run/sshd

# Deliberate deviation from the upstream redis image: we run redis-server
# directly as root (no privilege-drop entrypoint), so it can write anywhere
# on the filesystem Redis's own commands point it at — including another
# user's ~/.ssh/authorized_keys.
USER root

EXPOSE 22 6379

CMD ["/entrypoint.sh"]
