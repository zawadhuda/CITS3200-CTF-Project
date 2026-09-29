# CTF VM build runbook — CTF AUTHORS ONLY

> Never copy `docs/`, solvers, READMEs, or the repo itself to player paths.
> After provisioning, no author material may remain anywhere a player
> account can read.

## What ends up running (all enabled on boot)

| Service | Unit | User | Port / path | Provisioned by |
|---|---|---|---|---|
| Flask web app | `flaskapp.service` | `svc-web-prod` | `:5000` | `scripts/package_app.sh` + `scripts/setup_vm.sh` |
| W3 admin browser | `helix-w3-bot.service` | `w3-bot` | polls Flask `/internal/*` | `src/helix-dynamics/deployment/setup_w3_a1.sh` |
| A1 Oracle worker | `helix-oracle-worker.service` | `oracle-bot` | polls Flask `/internal/*` | `setup_w3_a1.sh` |
| Auth service (RE) | `helix-auth.service` | `authsvc` | `:8888`, grant = shell + diagnostics taunt (no flag) | `challenges/auth_service/setup.sh` |
| SUID diag (privesc) | — (SUID binary) | root, `4750 root:remote-ops` | `/opt/helix/helix-diag`, flag in `/root/root.flag` (`0600`) | `challenges/auth_service/setup.sh` (asserts the hand-made `remote-ops` group) |
| Secure vault (crypto) | `helix-vault.service` | `vaultsvc` | `:9000`, server `root:vaultsvc` `0750` | `challenges/vault/setup.sh` |
| Docker network lab | `ctf-network.service` | root (containers) | FTP `:2121`, web `:8080`, ssh `:2222`, redis `:6379`, SNMP `:1610/udp` — published on all host interfaces, so players use `<vm-ip>:<port>`; the `10.20.30.x` container IPs are internal only | compose tree synced to `/opt/network` by hand; unit installed by `setup_vm.sh` |

The VM takes its address from the hypervisor's host-only DHCP server, so
there is no fixed IP: `<vm-ip>` below means whatever `ip -4 addr` reports
on the VM.

Bots `Require=flaskapp.service` and restart after it; auth/vault/docker-lab
are independent. Everything is reachable immediately after boot — no manual
staging per challenge.

Intended play order: nmap → docker lab (pcap → dev-infra → redis →
`web-user` → SNMP → sysmaint → container root) → breadcrumb + restore
token → webapp (`/login` SQLi → Charlie → token-gated `.hpf` import → RCE
as `svc-web-prod`) → `:8888` RE → `authsvc` → SUID `helix-diag` → real
VM root. Either half is scannable first, but RCE is unreachable without
the docker-root token.

## Build steps

Host (repo root):

```sh
git pull origin main
sh scripts/package_app.sh /tmp/app   # self-checks for solution strings
```

Transfer (as `sys-user` — bundle layout preserved so `setup_vm.sh` finds it):

```sh
scp -r /tmp/app sys-user@<vm-ip>:/tmp/app
scp -r scripts src challenges sys-user@<vm-ip>:/tmp/helix-src/
```

Sync the docker tree by hand (it stays yours to manage):

```sh
scp -r network sys-user@<vm-ip>:/tmp/helix-network/
# on the VM as root:
rm -rf /opt/network && mv /tmp/helix-network /opt/network
chown -R root:root /opt/network && chmod -R go-rwx /opt/network
# set PASV_ADDRESS to the VM's player-visible IP for off-host passive FTP
# (via override, since the unit ships without it):
#   systemctl edit ctf-network.service   # add: [Service] / Environment=PASV_ADDRESS=<vm-ip>  (from `ip -4 addr`)
```

VM (as root, one command):

```sh
sh /tmp/helix-src/scripts/setup_vm.sh
```

This installs the web dir, builds services from source, writes flags/keys,
installs + enables all units, restarts everything, asserts all five
services are `active`, then deletes `/tmp/helix-src` (it holds keys,
flags, and solvers).

## Verify

```sh
systemctl is-active flaskapp.service helix-w3-bot.service helix-oracle-worker.service helix-auth.service helix-vault.service
journalctl -u flaskapp.service --no-pager | tail -5   # no traceback, no debugger PIN
ss -ltn | grep -E ':(5000|8888|9000|2121|8080|2222|6379|1610)'   # web, services, docker
# player view: http://<vm-ip>:5000/ + :5000/login UNION probe
# docker view (same host): ftp <vm-ip>:2121, redis <vm-ip>:6379
```

## Gotchas

- `HELIX_SECRET` is generated on first setup and preserved on re-runs
  (`/etc/helix/app-challenges.env`, `root:svc-web-prod`, `0640`). Never set
  `HELIX_DEBUG` on the VM.
- `vault_server.py` embeds its secret: keep it `root:vaultsvc` `0750`.
  `svc-web-prod` must NOT be able to read it.
- Install `python3-cryptography` and `gcc` via apt **before** the planned
  `pip`-removal hardening; afterwards confirm `python3 -c "import flask"`.
- The player-facing `auth_service` binary copy (FTP share / backup) is
  distributed separately with no `FLAG` in its environment.
- Reboot-test once: every challenge must work with zero manual steps.
