# Helix Dynamics — CTF Requirement Matrix (Draft)

Status: **DRAFT — no vulnerabilities have been implemented yet.** This is the
planning document called for by the `[CTF]` hooks in
[`src/helix-dynamics/app.py`](../src/helix-dynamics/app.py) and its templates.
Every hook stays a safe no-op until a row below is finalised and someone
deliberately builds it.

Two things are still open and need a team decision before anyone writes vuln
code:

1. The **three horizontal privilege escalations** (same clearance tier,
   account-to-account — e.g. alice → bob).
2. The **three distinct root paths** (three separate ways to reach full
   system/OS compromise, not the same local-privesc trick reused three times).

Both are worked out as concrete options in §3 and §4. Everything else in the
matrix (§2) reflects what the existing hooks already imply, plus a couple of
small secondary choices called out inline — pick and adjust freely.

**Flag format** — draft convention only: `helix{category_short-description}`.
Actual random flag strings and their storage/drop mechanism (file on disk,
DB row, HTTP response) are a build-time detail, not a design blocker.

**Access-level ladder** used in the "Resulting access" column:

| Level | Meaning |
|---|---|
| L0 — Public | Unauthenticated, any visitor |
| L1 — OSINT | Information only, no system access |
| L2 — Employee (self) | Logged in as *some* employee account |
| L3 — Employee (peer) | Logged in as a *specific other* employee via takeover |
| L4 — Infra-visibility | Internal topology/creds known, no shell yet |
| L5 — Service shell | Remote code execution as a low-privileged OS/service user |
| L6 — Root | Full OS compromise |

---

## 1. Category legend

| Category | What it tests |
|---|---|
| `network` | Recon, sniffing, service/credential exposure, unauthenticated network services |
| `web` | Classic web app vulns (injection, XSS, deserialization, access control) |
| `horizontal` | Same-tier account takeover (peer → peer) |
| `vertical` | Local privilege escalation (service user → root) |
| `RE` | Reverse engineering a binary/service |
| `advanced` | AI/LLM-specific or otherwise non-classical vector |

---

## 2. Resolved rows (from existing hooks)

| ID | Vulnerability / challenge | Category | Prerequisite | Resulting access | Flag | Next clue |
|---|---|---|---|---|---|---|
| REC-1 | Staff enumeration — `/about` lists full names + `@helix.local` emails | `network` | None (public page) | L1 — OSINT: valid username list (alice.morgan, bob.nkemdirim, charlie.voss) | — (clue only) | Seeds every later login/SQLi/horizontal target |
| REC-2 | Credentials in FTP capture (PCAP handed out as a challenge artifact) | `network` | Access to the provided PCAP / ability to capture the segment | L1 — OSINT: `devops:R3dacted_But_Weak!` (single source of truth for both dev-infra pages) | `helix{net_ftp-plaintext-creds}` | Unlocks `/dev-infra-backup/` (Basic Auth) |
| REC-3 | `/dev-infra-backup/` — Basic Auth-gated internal infra page | `network` | Creds from REC-2 | L4 — Infra-visibility: internal IPs/ports for Redis (`:6379`), Auth Service (`:8888`), Secure Vault (`:9000`); "TODO: rotate SNMP creds" note | `helix{net_dev-infra-exposed}` | Internal host `10.0.0.12` + 3 service ports feed directly into the three root paths (§4) |
| REC-4 | SNMP community-string recon against `10.0.0.12` (weak/default community string, per the dev-infra TODO) | `network` | Host IP from REC-3 | L1 — OSINT: service/OS/version banner, or a hint string tucked in a custom MIB value | `helix{net_snmp-public-community}` | Confirms which service/version to target for Root Path 3 (§4.3) |
| WEB-1 | SQL injection (auth bypass) at `/login` — currently parameterised; hook says to make it string-built | `web` | One plausible email from REC-1 | L2/L3 — logs in as whichever row the injection selects (attacker can target a specific victim row, see HZ-1 in §3) | `helix{web_sqli-auth-bypass}` | Landing in a real dashboard exposes the announcement hints (Redis, Oracle) already written into `dashboard.html` |
| WEB-2 | Stored XSS in support ticket body → rendered unescaped on the admin/Oracle review view | `web` | None — `/support` is public | Payload executes in the admin/Oracle review context; admin cookie is intentionally non-`HttpOnly` | `helix{web_stored-xss-admin-bot}` | Stolen admin session/cookie, or a note the admin view leaks, pointing at the Vault/Auth Service |
| ADV-1 | Indirect prompt injection — ticket text is later fed to Oracle as trusted context when an admin queries it | `advanced` | Ticket delivered via WEB-2's sink | Oracle performs an attacker-chosen action outside the naive "ignore previous instructions" jailbreak (which must NOT work) | `helix{adv_indirect-prompt-injection}` | Oracle's response is the intended vehicle to leak a Vault secret or trigger an infra action — **minor decision:** pick the exact privileged action Oracle can be tricked into (e.g. "paste the Vault decryption key", "email the devops Basic Auth creds again", "summarize `/dev-infra-backup/`") |
| WEB-3 | Insecure deserialization via `.hpf` import (`/profile/import`) | `web` | Valid employee session (any) | L5 — RCE as the Flask process's OS user | `helix{web_insecure-deserialization}` | Shell is the foothold for Root Path 2 (§4.2) — **minor decision:** confirm the payload format; **recommend `pickle`** since the backend is Python (PHP/Java would need an extra interpreter on the box for no real benefit) |
| CLUE-1 | `/research/prometheus` — 403 page with `Incident ID: PRM-403-9182` | `web` | None (public) | L1 — OSINT only | — (clue only) | **Minor decision:** what consumes this ID? Recommend making it a required `X-Incident-Id` header (or query param) that the Auth Service on `:8888` checks before it will respond at all — ties this clue into Root Path 3 (§4.3) instead of leaving it a dead end |

That covers every hook currently in the code. `network`, `web`, and
`advanced` all have at least one resolved row; `horizontal`, `vertical`, and
`RE` are the categories carried entirely by the two open decisions below.

---

## 3. 🔶 DECISION NEEDED — Three horizontal escalations

Requirement: three same-tier account takeovers. All three Helix employees
(alice, bob, charlie) share `clearance = RESEARCH`, so "vertical" doesn't
apply here — each of these must land the attacker in a *specific other*
employee's session/data without ever knowing their password.

Recommendation: use a **different technique for each of the three**, so the
row also teaches a distinct access-control concept instead of the same bug
three times.

### HZ-1 — SQLi-driven auth bypass targeting a specific victim (recommended)
- **Category:** `horizontal`
- **Prerequisite:** WEB-1 built as a *string-built* query; attacker supplies `alice.morgan@helix.local' -- ` in the email field
- **Mechanism:** classic `' OR '1'='1' --` bypass logs in as the *first matching row*; because the email is attacker-controlled, they can target **alice specifically** by supplying her exact address with a trailing comment, without ever knowing `Spring2026!`
- **Resulting access:** L3 — full session as Alice Morgan
- **Flag:** `helix{hz_sqli-impersonate-alice}`
- **Next clue:** Alice's dashboard/profile surfaces the Redis + Oracle hints already written into `dashboard.html`

### HZ-2 — Forged session cookie via weak/leaked Flask secret (recommended)
- **Category:** `horizontal`
- **Prerequisite:** attacker already holds *some* employee session (from HZ-1); the Flask secret is left at a weak/guessable value (today's `dev-only-change-me` default is exactly this bug) — decide whether it's "guess the default" or "leaked via a config file found somewhere in REC-3's infra page / a `.git` exposure"
- **Mechanism:** `session["uid"]` is just an integer signed by `itsdangerous`; knowing the secret lets the attacker mint a cookie with `uid=2` (Bob) directly, no credentials needed. Employee IDs are sequential/enumerable (1, 2, 3), which the about-page ordering (REC-1) already hints at
- **Resulting access:** L3 — full session as Bob Nkemdirim
- **Flag:** `helix{hz_forged-session-cookie-bob}`
- **Next clue:** Bob's `.hpf` export (WEB-3's sibling) is the natural bridge into the deserialization stage

### HZ-3 — IDOR on a peer-profile action (recommended)
- **Category:** `horizontal`
- **Prerequisite:** authenticated as *any* employee (from HZ-1 or HZ-2); requires adding one small, deliberate access-control gap: a colleague-lookup or profile action that takes an `id`/`email` parameter without checking it matches the caller (e.g. `/profile/export?uid=3` reusing the existing export route, or a "view teammate" feature on the dashboard)
- **Mechanism:** broken object-level authorization — swap the ID, get someone else's record
- **Resulting access:** L3 — read (and optionally write) Charlie Voss's profile data
- **Flag:** `helix{hz_idor-peer-profile-charlie}`
- **Next clue:** Charlie's profile/title data is the piece that ties REC-4's SNMP clue to a specific internal service

**Alternatives considered, not recommended as the default three** (swap in if
the team prefers): predictable password-reset token; IDOR replayed through
the `.hpf` import itself (crafted package claims another employee's `id`);
using ADV-1 to make Oracle reset a named colleague's password on the
attacker's behalf. Any of these can replace one of HZ-1..3 above — just keep
the technique distinct from the other two rows.

**To decide:** confirm HZ-1/HZ-2/HZ-3 as written, or swap in an alternative
per slot, then delete this callout.

---

## 4. 🔶 DECISION NEEDED — Three distinct root paths

Requirement: three separate chains to L6 — Root, each ending in a genuinely
different local-privilege-escalation technique (not the same trick three
times). Each path is recon/foothold → **RCE as a low-priv user** →
**distinct vertical privesc** → root. All three footholds are already staged
by REC-3, which hands out the IPs/ports for exactly three internal services.

### 4.1 Root Path 1 — Redis (network → vertical)
- **Foothold — category `network`:** Redis at `10.0.0.12:6379` is unauthenticated (dev-infra note: "TODO: add Redis authentication"). Classic unauth-Redis RCE: `CONFIG SET dir` / `CONFIG SET dbfilename` to write a cron entry or an SSH `authorized_keys` file, or `MODULE LOAD` if module loading is enabled.
  - Prerequisite: ports/IP from REC-3
  - Resulting access: L5 — shell as the `redis` service user
  - Flag: `helix{net_redis-unauth-rce}`
- **Privesc — category `vertical`:** land the low-priv shell next to a **misconfigured sudoers entry** (e.g. `redis ALL=(root) NOPASSWD: /usr/bin/some-maintenance-script`) that the challenge box grants to the `redis` account specifically.
  - Resulting access: L6 — Root
  - Flag: `helix{vert_sudo-nopasswd-redis}`
  - Next clue: n/a — this is a terminus flag

### 4.2 Root Path 2 — Deserialization (web → vertical)
- **Foothold — category `web`:** WEB-3's `.hpf` deserialization RCE.
  - Resulting access: L5 — shell as the Flask app's OS user (e.g. `helix-app`)
  - Flag: already covered by `helix{web_insecure-deserialization}` in §2
- **Privesc — category `vertical`:** a **world-writable file owned/executed by root** — e.g. a root-owned cron job under `/etc/cron.d/` that's group- or world-writable, or a log-rotation script the app user can edit that root executes on a timer. Chosen deliberately different from Path 1's sudo misconfig.
  - Resulting access: L6 — Root
  - Flag: `helix{vert_writable-root-cron}`
  - Next clue: n/a — terminus flag

### 4.3 Root Path 3 — Auth Service / RE (network → RE → vertical)
- **Foothold — category `network` then `RE`:** REC-3 exposes a custom "Auth Service" at `10.0.0.12:8888` (dev-infra note: "TODO: fix auth_service before production"). Ship a small custom binary for this service; players pull it (e.g. via an exposed backup share, or the FTP server from REC-2) and reverse-engineer it to find either a hardcoded backdoor credential/command, or a memory-corruption bug (simple stack buffer overflow is plenty for a CITS3006-level RE challenge). CLUE-1's incident ID (`PRM-403-9182`) gates the service if you take the recommendation in §2 (required header before it responds).
  - Prerequisite: binary obtained + REC-3 IP/port + CLUE-1 header value
  - Resulting access: L5 — shell as a distinct low-priv `authsvc` user
  - Flag: `helix{re_auth-service-backdoor}`
- **Privesc — category `vertical`:** a **SUID binary** reachable only by the `authsvc` account (e.g. a small internal tool with `cap_setuid`/SUID-root left over from debugging — classic GTFOBins-style abuse). Third distinct technique, so no privesc method repeats across the three paths.
  - Resulting access: L6 — Root
  - Flag: `helix{vert_suid-binary-authsvc}`
  - Next clue: n/a — terminus flag

**Note on the Secure Vault (`:9000`):** not used as a root path above — it
reads better as the *payoff* for ADV-1 (Oracle prompt injection) and/or HZ-3:
something the "Advanced cryptographic storage" service actually protects
(e.g. a decryption key or the master flag index), rather than a fourth way to
root. Keep it as a narrative reward node, not a fourth privesc chain, unless
the team specifically wants a 4th path.

**To decide:** confirm the three chains above (Redis/sudo, deserialization/cron,
auth-service-RE/SUID), or substitute a different vertical technique for any
one slot — the only hard constraint is that all three privesc techniques stay
distinct from each other.

---

## 5. Coverage check against the category legend

| Category | Rows covering it |
|---|---|
| `network` | REC-1, REC-2, REC-3, REC-4, Root Path 1 foothold, Root Path 3 foothold |
| `web` | WEB-1, WEB-2, WEB-3, CLUE-1 |
| `horizontal` | HZ-1, HZ-2, HZ-3 |
| `vertical` | Root Path 1/2/3 privesc rows |
| `RE` | Root Path 3 foothold (auth-service binary) |
| `advanced` | ADV-1 |

All six categories are represented at least once once §3 and §4 are signed
off.

---

## 6. Open items summary (for quick reference)

- [ ] Pick/confirm HZ-1, HZ-2, HZ-3 (§3)
- [ ] Pick/confirm Root Paths 1–3 and their three *distinct* privesc techniques (§4)
- [ ] Minor: deserialization payload format — recommend `pickle` (§2, WEB-3)
- [ ] Minor: what CLUE-1's incident ID actually gates — recommend Auth Service header (§2, CLUE-1)
- [ ] Minor: exact privileged action ADV-1's prompt injection triggers (§2, ADV-1)
- [ ] Minor: whether Secure Vault (`:9000`) stays a narrative reward node or becomes a 4th path (§4.3 note)

Once these are checked off, hooks can be implemented one at a time, each
mapped back to its row/flag/clue here.
