# Flag registry — CTF AUTHORS ONLY

> Never copy this file (or `docs/`) to the CTF VM. Players must only
> discover these values by exploiting the matching challenge.

All flags are **static** so they can be registered once in the flag
submission backend. Do not randomise them at install time. All six are
installed by `scripts/setup_vm.sh` (per-service scripts below) — see
`docs/VM.md`.

Policy: one flag per exploit chain, at the end of the chain only.
Mid-chain wins pay out as cryptic server-taunt nudges, never flags.

| # | Flag | Chain end | Where it lives on the VM | How the player earns it |
|---|---|---|---|---|
| 1 | `helix{web_insecure-deserialization}` | Web chain → RCE as `svc-web-prod` | `/opt/helix/flags/w2.txt` (`root:svc-web-prod`, `0640`) | SQLi → crack → login → token-gated pickle payload → shell → read `w2.txt` |
| 2 | `helix{web_stored-xss-admin-bot}` | Stored XSS → admin cookie | `/opt/helix/flags/w3.txt` (`root:w3-bot`, `0640`); value is the `helix_admin` cookie | Stored XSS in ticket body → bot cookie exfiltrated via `/support/collect` |
| 3 | `helix{adv_indirect-prompt-injection}` | Prompt injection → private note | `/opt/helix/flags/a1.txt` (`root:oracle-bot`, `0640`); value is the Oracle private note | Crafted ticket triggers the workflow-directive disclosure |
| 4 | `FLAG{pr0cess_l1st_s3crets}` | Network chain → container root | `/root/flag.txt` (`0600`) inside the redis container | FTP/pcap → dev-infra → unauth-Redis SSH write → SNMP secret → SUID `sysmaint` → container root |
| 5 | `helix{vert_suid-binary-authsvc}` | Chain C → real root | `/root/root.flag` (`0600`) on the VM | RE `validate()` → keygen → shell as `authsvc` → `PATH` hijack on SUID `helix-diag` → root |
| 6 | `helix{adv_padding-oracle-cbc-vault}` | Vault oracle → plaintext | Nowhere on disk — it *is* the decrypted vault plaintext (`_SECRET` in `vault_server.py`, readable only by the vault service user) | Custom TCP padding-oracle attack → decrypt the sealed token |

## Delisted (mechanism retained, nothing submitted)

| Value | Where it was | What replaced it |
|---|---|---|
| `helix{websqli}` | Cracked Charlie password | Still the login password (mechanism unchanged) — no submission; the dashboard IT #447 note nudges onward |
| `helix{re_auth-service-backdoor}` | Auth-service grant output | Removed entirely — a grant prints a diagnostics taunt pointing at the next step instead |
| `FLAG{pcap_h1dd3n_1n_pla1n_s1ght}` | Pcap response comment | Same-length taunt (`MGMT: plaintext never lies, kid.`) — capture stays byte-consistent |
| `FLAG{r3dis_wr1tes_wh3rever_1t_wants}` | `/home/web-user/flag.txt` | `~/note.txt` nudge toward the SNMP secret, in server voice |

## Keys (not flags — never submitted)

| Key | Value | Lives in | Consumed by |
|---|---|---|---|
| HPF restore token | `helix-hpf-restore-7f3a` | `/root/profile-token.txt` (`0600`) in the redis container (docker-root loot) → `HELIX_HPF_TOKEN` in `/etc/helix/app-challenges.env` (`root:svc-web-prod`, `0640`) | `X-Profile-Token` header on `/profile/import`; gates the W2 deserialiser |
| Review key | `helix-review-6b8cb1e89e04` | `/etc/helix/{app-challenges,w3-bot}.env` | bot ticket polling |
| Oracle worker key | `helix-oracle-3af705c1d294` | `/etc/helix/{app-challenges,oracle-bot}.env` | oracle ticket polling |
