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
a session. In-band UNION into the 3-column result card:

```
' UNION SELECT password,email,title FROM employees WHERE email='charlie.voss@helix.local' -- 
```

Charlie's `password` field is `md5(FLAG_WEB_SQLI)` — crackable (the other
three rows are random). The cracked plaintext IS flag #1 and also logs in
as Charlie, unlocking the dashboard/`.hpf` stages. Auth bypass via
`' OR '1'='1` must NOT work (parameterised) — regression-test this.

## W2 — insecure deserialisation at `/profile/import`

`/profile/export` returns `base64(pickle(dict))`. `/profile/import` calls
`pickle.loads` on the upload (JSON fallback only). Any authenticated
session (via WEB-1) can upload a pickle whose `__reduce__` runs code as
`svc-web-prod` → shell → read `/opt/helix/flags/w2.txt` (flag #2,
`root:svc-web-prod`, `0640`).

## W3 — stored DOM-XSS in administrator ticket review

Ticket `body` is stored raw. The public ticket view escapes it, but
`admin_review.html` renders it via `innerHTML` (subject uses the safe
`textContent`). The Selenium bot (`w3_admin_bot.py`) visits unreviewed
tickets with a JS-readable `helix_admin` cookie (flag #3). Payload:

```html
<img src=x onerror="fetch('/support/collect/<TICKET_ID>?data='+document.cookie)">
```

Exfiltrated data lands in `xss_reports` and is viewable on the ticket page.
The `review_key` is embedded in the admin page — expected; it only guards
ticket read/mark-reviewed.

## A1 — indirect prompt injection via support tickets

`a1_oracle_worker.py:build_prompt` mixes the private note (flag #4) and
the untrusted ticket in one block and honours "workflow directives" inside
ticket text. `offline_answer` rejects naive `ignore previous instructions`
and only discloses when the ticket contains ALL of: a workflow-directive
phrase + a note-target phrase (`admin note`, …) + a disclose verb
(`append`/`include`/`copy`/`place`) + a disguised field
(`reference checksum`, …). The reply is written back to the ticket page.

## Service challenges (on the VM, off the web app)

- **Auth service `:8888`**: `validate()` = seed `0x1505`, per byte
  `code = code*33 ^ (byte*0x9E)`, 48-bit mask, final `^ 0xC0FFEE1234`.
  `keygen.py` reimplements it → valid hex code → shell as `authsvc` +
  flag #5 (runtime `FLAG` env only). Patching a local copy wins nothing.
- **SUID `helix-diag`**: unqualified `system("netcheck")` → `PATH` hijack
  (`privesc.sh`) → root → `/root/root.flag` (flag #6).
- **Vault `:9000`**: `ERR 0x01` (bad padding) vs `ERR 0x02` (good padding,
  wrong magic) is the oracle; `solve.py` decrypts the token byte-by-byte
  (flag #7 IS the plaintext). Custom TCP — padbuster won't work.

## Pre-ship checklist

1. `sh scripts/package_app.sh /tmp/app` passes its self-check.
2. `grep -riE '\[CTF\]|crackable|PCAP|payload|prompt injection' /tmp/app`
   returns nothing.
3. Only service binaries/server code (never `challenges/*/README.md`,
   solvers, or `docs/`) go to their respective VM paths.
