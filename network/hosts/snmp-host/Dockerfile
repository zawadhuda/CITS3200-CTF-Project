# snmp-host (10.20.30.43) — N3
# Purely network-reachable: no interactive foothold is expected here. A
# player who has recovered the "research_dev" community string from N1's
# pcap can snmpwalk this host and pull the leaked mysqldump password
# straight out of the NET-SNMP-EXTEND-MIB output.
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    snmpd snmp \
    && rm -rf /var/lib/apt/lists/*

COPY snmpd.conf /etc/snmp/snmpd.conf
COPY leak_cmd.sh /usr/local/bin/leak_cmd.sh
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /usr/local/bin/leak_cmd.sh /entrypoint.sh

EXPOSE 161/udp

CMD ["/entrypoint.sh"]
