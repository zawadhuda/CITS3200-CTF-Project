# Flag registry — CTF AUTHORS ONLY

> Never copy this file (or `docs/`) to the CTF VM. Players must only
> discover these values by exploiting the matching challenge.

All flags are **static** so they can be registered once in the flag
submission backend. Do not randomise them at install time.

| # | Flag | Challenge | Where it lives on the VM | How the player earns it |
|---|---|---|---|---|
| 1 | `helix{websqli}` | WEB-1 SQLi (`/login`) | `md5` hash in the `employees` row for `charlie.voss@helix.local`; plaintext only in `app.py:FLAG_WEB_SQLI` (readable post-RCE, which itself requires this flag — not a shortcut) | UNION-inject `/login` → crack the `md5` → log in as Charlie |
| 2 | `helix{web_insecure-deserialization}` | W2 pickle RCE (`/profile/import`) | `/opt/helix/flags/w2.txt` (`root:svc-web-prod`, `0640`) | Authenticated pickle payload → shell as `svc-web-prod` → read `w2.txt` |
| 3 | `helix{web_stored-xss-admin-bot}` | W3 stored DOM-XSS | `/opt/helix/flags/w3.txt` (`root:w3-bot`, `0640`); value is the `helix_admin` cookie | Stored XSS in ticket body → bot cookie exfiltrated via `/support/collect` |
| 4 | `helix{adv_indirect-prompt-injection}` | A1 Oracle prompt injection | `/opt/helix/flags/a1.txt` (`root:oracle-bot`, `0640`); value is the Oracle private note | Crafted ticket triggers the workflow-directive disclosure |
| 5 | `helix{re_auth-service-backdoor}` | RE auth service (`:8888`) | `FLAG` env of the `authsvc` systemd service only — never on disk, never in the player-reversible binary copy | Reverse `validate()` → `keygen.py` → valid access code → shell as `authsvc` |
| 6 | `helix{vert_suid-binary-authsvc}` | SUID privesc (`helix-diag`) | `/root/root.flag` | `PATH` hijack on the SUID-root `helix-diag` → root |
| 7 | `helix{adv_padding-oracle-cbc-vault}` | Vault padding oracle (`:9000`) | Nowhere on disk — it *is* the decrypted vault plaintext (`_SECRET` in `vault_server.py`, readable only by the vault service user) | Custom TCP padding-oracle attack → decrypt the sealed token |

## If the flag count needs trimming

Every flag above is the natural payoff of a distinct exploited vuln, so
prefer keeping all seven. If the CTF structure needs fewer, demote in this
order (flag → hint to the next stage) without breaking chains:

1. **#2 first** — replace `w2.txt` with a hint file pointing at the dev-infra
   page or vault port; the shell itself is the real milestone.
2. **#1 second** — make Charlie's password the flag-less crack that only
   yields a login (the session is the clue to `.hpf`/deserialisation).

Never demote #5, #6, or #7: each is the sole payoff of its root path.
