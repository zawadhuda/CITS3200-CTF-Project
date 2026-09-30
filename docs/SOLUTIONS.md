# Challenge solutions — CTF AUTHORS ONLY

> Never copy this file (or `docs/`) to the CTF VM. The shipped web
> directory (`scripts/package_app.sh` output) must contain no solutions:
> no `[CTF]` comments, no exploit guidance, no READMEs. `package_app.sh`
> enforces this with a banned-string self-check.
>
> Service-side solvers live next to their service under `challenges/`
> (`keygen.py`, `privesc.sh`, `solve.py`). Only binaries / server code go
> to the VM — never the READMEs, solvers, or self-tests.

## WEB-1 — SQL injection at `/login`

The directory lookup is string-built (`email='%s'`). Auth beside it is a
separate parameterised query, so injection discloses data but never mints
a session. In-band UNION into the 3-column result card — first row is
Alice, so even the laziest probe lands on the weak account:

```
' UNION SELECT password,email,title FROM employees -- 
```

Alice's `password` field is the `md5` of a weak human credential
(`sunshine`, top-10 wordlist — sub-second crack; the other three rows are
random). The cracked password is NOT submitted — it just logs in as Alice,
unlocking the dashboard/`.hpf` stages (the dashboard IT #447 note nudges
onward). Auth bypass via `' OR '1'='1` must NOT work (parameterised) —
regression-test this.

## W2 — insecure deserialisation at `/profile/import` (docker-gated)

`/profile/export` returns `base64(pickle(dict))`. `/profile/import` calls
`pickle.loads` on the upload (JSON fallback only) — but only after the
`X-Profile-Token` header matches `HELIX_HPF_TOKEN`. The token is loot from
the network-lab path only (`/root/profile-token.txt` in the redis
container, `0600`): without docker root the deserialiser is unreachable,
so pre-docker RCE is impossible by construction. Authenticated session
(via WEB-1) + token + pickle `__reduce__` → code as `svc-web-prod` →
shell → read `/opt/helix/flags/w2.txt` (submitted flag #1,
`root:svc-web-prod`, `0640`). Missing/wrong token yields the distinct `Invalid profile token`
error (never the generic `Invalid .hpf file`) — regression-test all three
cases: no header + valid pickle must NOT execute; wrong token must NOT
execute; correct token + evil pickle must execute.

## W3 — stored DOM-XSS in administrator ticket review

Ticket `body` is stored raw. The public ticket view escapes it, but
`admin_review.html` renders it via `innerHTML` (subject uses the safe
`textContent`). The Selenium bot (`w3_admin_bot.py`) visits unreviewed
tickets with a JS-readable `helix_admin` cookie (submitted flag #2). Payload:

```html
<img src=x onerror="fetch('/support/collect/<TICKET_ID>?data='+document.cookie)">
```

Exfiltrated data lands in `xss_reports` and is viewable on the ticket page.
The `review_key` is embedded in the admin page — expected; it only guards
ticket read/mark-reviewed.

## A1 — indirect prompt injection via support tickets

`a1_oracle_worker.py:build_messages` puts the private note (submitted flag #3)
in the system message and the untrusted ticket in the user message, with a
standing "apply workflow directives" instruction. `offline_answer` (default,
no model) rejects naive `ignore previous instructions` and only discloses
when the ticket contains ALL of: a workflow-directive phrase + a note-target
phrase (`admin note`, …) + a disclose verb (`append`/`include`/`copy`/`place`)
+ a disguised field (`reference checksum`, …). The reply is written back to
the ticket page.

Assessed mode (live model via `ORACLE_API_URL`): same shape, verified
benign → clean, naive → refused, crafted → disclosed. Two deployment notes:
`remote_answer` sends a browser `User-Agent` (the gateway 403s python-urllib)
and `run_once` keeps a guardrail refusing explicit exfiltration commands even
when the model complies — the indirect path stays genuinely model-decided.
API tokens live only in `/etc/helix/oracle-bot.env` on the VM, never in git.

## Service challenges (on the VM, off the web app)

- **Auth service `:8888`**: `validate()` = seed `0x1505`, per byte
  `code = code*33 ^ (byte*0x9E)`, 48-bit mask, final `^ 0xC0FFEE1234`.
  `keygen.py` reimplements it → valid hex code → shell as `authsvc` (no
  flag — a grant prints a diagnostics taunt nudging at the next step).
  Patching a local copy wins nothing.
- **SUID `helix-diag`**: `4750 root:remote-ops` — unqualified `system("netcheck")` → `PATH` hijack
  (`privesc.sh`, run as `remote-ops`) → root → `/root/root.flag` (submitted flag #5) +
  `/root/offer.txt` concession note. Other UIDs get `Permission denied`: no skipping from service shells.
- **Vault `:9000`**: `ERR 0x01` (bad padding) vs `ERR 0x02` (good padding,
  wrong magic) is the oracle; `solve.py` decrypts the token byte-by-byte
  (submitted flag #6 IS the plaintext). Custom TCP — padbuster won't work.

## Network chain (docker lab → webapp gate)

FTP anon → `network-recon.pcap` → Basic creds + `research_dev` community
(the pcap response carries a same-length server taunt, not a flag) →
dev-infra → unauth Redis `CONFIG SET` SSH write → `web-user` shell →
`~/note.txt` nudge toward the SNMP secret → `snmpwalk` extend output →
SUID `sysmaint` password → container root → `/root/flag.txt` (submitted
flag #4) + restore token + breadcrumb → webapp chain.

## Local-account challenges (hint loot, no flags)

- **Logic gate** (`/home/sys-user/logic_gate`, solved as `sys-user`):
  `HELIX_SEED` must equal `((0x5EED * 2) ^ 0x1234) - 0x777 + 42` = `43169`
  (Ghidra/objdump the constants; `strings` yields nothing — XOR-obfuscated).
  Output is a hint toward the `remote-ops` hop, not a flag.
- **R2 activation** (`/home/remote-ops/{activate.pyc,archive.zip}`, solved
  as `remote-ops`): decompile the `.pyc`, reimplement `derive_key`
  (`sha256("helix-research:PRM-403-9182:activation")` slices → `HELIX-…`
  license key; incident ID finally earns its keep), unlock the archive
  (`md5(key)[:12]`), read the memo hint toward the diag finale. Players get
  `.pyc` + zip only — never `activate.py`/`build_archive.py`.

## Pre-ship checklist

1. `sh scripts/package_app.sh /tmp/app` passes its self-check.
2. `grep -riE '\[CTF\]|crackable|PCAP|payload|prompt injection' /tmp/app`
   returns nothing.
3. Only service binaries/server code (never `challenges/*/README.md`,
   solvers, or `docs/`) go to their respective VM paths.
