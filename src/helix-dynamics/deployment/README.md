# Helix Dynamics challenge workers (W2, W3, A1)

Runtime support for the W2, W3 and A1 challenges, kept alongside the Flask
app they serve rather than in a separate top-level folder.

## Contents

- `../app.py` — Flask routes and database changes.
- `../templates/` — the changed or added templates.
- `../workers/w3_admin_bot.py` — required W3 browser service.
- `../workers/a1_oracle_worker.py` — required A1 ticket service.
- `flaskapp.service` — the VM systemd unit (fixed; no stray lines, reads
  `/etc/helix/app-challenges.env`). Installed by `setup_w3_a1.sh`.
- `w2_setup.sh` — installs the W2 flag permissions.
- `setup_w3_a1.sh` — installs the Flask unit, the W3 and A1 services,
  the static flags, and a generated `HELIX_SECRET` (preserved on re-runs).

No solution scripts, sample payloads, walkthroughs or test files are included.

## What NEVER ships to the VM web directory

`workers/` (bot source) and this `deployment/` directory (setup scripts
containing worker keys and flag strings) must never land in
`/home/svc-web-prod/app/`. That directory is readable by the service
account — i.e. by the attacker after the W2 RCE. Use the packaging
script so only the runnable app is copied:

```sh
sh scripts/package_app.sh /tmp/app          # builds app.py + templates/ + static/ only
scp -r /tmp/app sys-user@192.168.56.x:/tmp/
```

On the VM as root:

```sh
rm -rf /home/svc-web-prod/app
mv /tmp/app /home/svc-web-prod/app
chown -R svc-web-prod:svc-web-prod /home/svc-web-prod/app
sh <repo>/src/helix-dynamics/deployment/w2_setup.sh
sh <repo>/src/helix-dynamics/deployment/setup_w3_a1.sh
systemctl daemon-reload && systemctl restart flaskapp.service
```

## Notes

- Flags are static by design (see `docs/FLAGS.md`, authors only) so they
  can be registered in the submissions backend. Never copy `docs/` to the VM.
- `HELIX_SECRET` is generated at install; none of the implemented
  challenges depend on the weak default. If HZ-2 (forged Flask cookie) is
  ever adopted, pin a known weak secret instead.
- Debug is off unless `HELIX_DEBUG=1` is set — never set it on the VM.
- For the assessed A1 demonstration, add `ORACLE_API_URL`, `ORACLE_MODEL`,
  `ORACLE_REQUIRE_MODEL=1` and, if required, `ORACLE_API_TOKEN` to
  `/etc/helix/oracle-bot.env`, then restart `helix-oracle-worker.service`.
- After `pip` removal on the VM, verify `python3 -c "import flask"` still
  works before considering the build done.
