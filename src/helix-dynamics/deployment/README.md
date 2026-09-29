# Helix Dynamics challenge workers (W2, W3, A1)

Runtime support for the W2, W3 and A1 challenges, kept alongside the Flask
app they serve rather than in a separate top-level folder.

## Contents

- `../app.py` — Flask routes and database changes.
- `../templates/` — the four changed or added templates.
- `../workers/w3_admin_bot.py` — required W3 browser service.
- `../workers/a1_oracle_worker.py` — required A1 ticket service.
- `w2_setup.sh` — installs the W2 flag permissions.
- `setup_w3_a1.sh` — installs the W3 and A1 services.

No solution scripts, sample payloads, walkthroughs or test files are included.
Do not place this directory inside a player-readable web directory.

## Integration

1. If another branch has changed `../app.py`, merge the relevant sections rather
   than replacing that file blindly.
2. From the repository root, run as root:

   ```sh
   sh src/helix-dynamics/deployment/w2_setup.sh
   sh src/helix-dynamics/deployment/setup_w3_a1.sh
   ```

3. For the assessed A1 demonstration, add `ORACLE_API_URL`, `ORACLE_MODEL`,
   `ORACLE_REQUIRE_MODEL=1` and, if required, `ORACLE_API_TOKEN` to
   `/etc/helix/oracle-bot.env`, then restart `helix-oracle-worker.service`.
4. Test all three challenges again after the other branches are merged.
