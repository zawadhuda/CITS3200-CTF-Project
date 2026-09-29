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
| Auth service (RE) | `helix-auth.service` | `authsvc` | `:8888`, flag in unit `Environment=FLAG` | `challenges/auth_service/setup.sh` |
| SUID diag (privesc) | — (SUID binary) | root (`4755`) | `/opt/helix/helix-diag`, flag in `/root/root.flag` (`0600`) | `challenges/auth_service/setup.sh` |
| Secure vault (crypto) | `helix-vault.service` | `vaultsvc` | `:9000`, server `root:vaultsvc` `0750` | `challenges/vault/setup.sh` |

Bots `Require=flaskapp.service` and restart after it; auth/vault are
independent. Everything is reachable immediately after boot — no manual
staging per challenge.

## Build steps

Host (repo root):

```sh
git pull origin main
sh scripts/package_app.sh /tmp/app   # self-checks for solution strings
```

Transfer (as `sys-user` — bundle layout preserved so `setup_vm.sh` finds it):

```sh
scp -r /tmp/app sys-user@192.168.56.x:/tmp/app
scp -r scripts src challenges sys-user@192.168.56.x:/tmp/helix-src/
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
ss -ltn | grep -E ':(5000|8888|9000)'                  # all three listeners
# player view: http://192.168.56.x:5000/ + :5000/login UNION probe
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
