# ftp-recon (10.20.30.41) — N1
# Anonymous vsftpd exposing a captured pcap that leaks HTTP Basic-auth
# creds and an SNMP community string. Also serves the basic-auth-protected
# basic-auth-protected /dev-infra-backup/ dir those creds unlock, purely so
# the pcap's request/response is grounded in something real on the wire.
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    vsftpd nginx-light apache2-utils ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --home /srv/ftp --no-create-home --shell /usr/sbin/nologin ftp || true \
    && mkdir -p /srv/ftp /var/www/dev-infra-backup

COPY vsftpd.conf /etc/vsftpd.conf
COPY nginx-devinfra.conf /etc/nginx/sites-enabled/default
COPY .htpasswd /etc/nginx/.htpasswd
COPY ftp_root/ /srv/ftp/
COPY web/dev-infra-backup/ /var/www/dev-infra-backup/
COPY entrypoint.sh /entrypoint.sh

RUN chmod -R a+rX /srv/ftp /var/www/dev-infra-backup \
    && chmod +x /entrypoint.sh \
    && rm -f /etc/nginx/sites-enabled/default.orig

EXPOSE 21 80 30000-30009

CMD ["/entrypoint.sh"]
