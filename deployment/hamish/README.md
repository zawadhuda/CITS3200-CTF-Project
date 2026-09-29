# Hamish challenge integration bundle

This folder contains the runtime changes for W2, W3 and A1. It is an overlay
for the current team repository rather than a complete copy of the website.

## Contents

- `src/helix-dynamics/app.py` — Flask routes and database changes.
- `src/helix-dynamics/templates/` — the four changed or added templates.
- `deployment/hamish/w2_setup.sh` — installs the W2 flag permissions.
- `deployment/hamish/setup_w3_a1.sh` — installs the W3 and A1 services.
- `deployment/hamish/w3_admin_bot.py` — required W3 browser service.
- `deployment/hamish/a1_oracle_worker.py` — required A1 ticket service.

No solution scripts, sample payloads, walkthroughs or test files are included.
Do not place the `deployment` directory inside a player-readable web directory.

## Integration

1. Merge the supplied `src/helix-dynamics` files into the latest team copy.
   If another branch has changed `app.py`, merge the relevant sections rather
   than replacing that file blindly.
2. From the repository root, run as root:

   ```sh
   sh deployment/hamish/w2_setup.sh
   sh deployment/hamish/setup_w3_a1.sh
   ```

3. For the assessed A1 demonstration, add `ORACLE_API_URL`, `ORACLE_MODEL`,
   `ORACLE_REQUIRE_MODEL=1` and, if required, `ORACLE_API_TOKEN` to
   `/etc/helix/oracle-bot.env`, then restart `helix-oracle-worker.service`.
4. Test all three challenges again after the other branches are merged.
