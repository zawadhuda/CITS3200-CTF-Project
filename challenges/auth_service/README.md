# Chain C — Recon → RE → Root (Auth Service + SUID)

**Owner:** Zawad. Self-contained root path #3. Demoable end-to-end without any
other member's code.

## What it covers (one chain, flag at the end only)
| Stage | Category | Payoff |
|---|---|---|
| Pull + reverse `auth_service` → keygen → shell as `authsvc` | **RE** + network foothold | shell + diagnostics taunt nudging at the next step (no flag) |
| SUID `helix-diag` PATH hijack → root | **vertical** privesc | `helix{ok_fine_youre_hired}` (submitted) |

Pairs with the padding-oracle vault (advanced/crypto) to form your full
individual contribution: RE + crypto + a distinct root path, all beyond the
unit slides.

## Files
- `auth_service.c` / `auth_service` — the RE target + the `:8888` daemon.
- `keygen.py` — reference solver (recovers the code from any username).
- `helix-diag.c` / `helix-diag` — the SUID-root privesc target.
- `privesc.sh` — reference privesc (PATH hijack).

## Build
```
gcc -O1 -fno-stack-protector -o auth_service auth_service.c
gcc -O1 -Wno-unused-result -o helix-diag helix-diag.c
```

## Deploy (VM — automated by `setup.sh`; manual equivalent below)
- Run `auth_service --serve` as a systemd service under a dedicated **`authsvc`**
  user (see `helix-auth.service` — no flag env; a grant prints a taunt).
  Confirm `:8888` is listed in the REC-3 dev-infra page.
- Distribute a copy of `auth_service` for players to pull (via the
  FTP box / backup share). The binary carries no secret either way — the
  code is derived from the username by the algorithm, so there is nothing
  to `strings` out of it.
- Install the privesc target:
  ```
  cp helix-diag /opt/helix/helix-diag
  chown root:root /opt/helix/helix-diag
  chmod 4755 /opt/helix/helix-diag      # SUID root
  ```
  Make it reachable/known to `authsvc` (e.g. in its PATH or a discoverable dir).
- Drop `helix{ok_fine_youre_hired}` in `/root/root.flag` (the privesc reads it).

## Player walkthrough
1. Obtain the binary; `objdump -d auth_service`, find `<validate>`.
2. Read the loop: seed `0x1505`, per byte `code = code*33 ^ (byte*0x9e)`, mask to
   48 bits, final `xor 0xc0ffee1234`. Reimplement (`keygen.py`).
3. `nc <host> 8888`, send a username + the computed hex code → shell as `authsvc`
   + diagnostics taunt pointing at the next step (no flag here).
4. On the box: notice `helix-diag` is SUID-root; `strings`/objdump shows it calls
   `netcheck` unqualified. Plant a malicious `netcheck`, prepend to `$PATH`, run
   it → root + submitted flag. (`privesc.sh` automates this.)

## Why it scores on the difficulty rubric
- **RE stage resists `strings` and patching.** No plaintext secret — the secret
  is the *algorithm*. Flipping the compare in a local copy yields no shell;
  players must recover the real transform and submit a valid code to the
  live service. That defeats the standard "patch the jne" shortcut.
- **Privesc resists linpeas auto-exploit.** It's a custom SUID binary, not a
  GTFOBins entry — scanners flag the SUID bit but can't auto-own it; you must
  read the binary and stage the hijack.
- Both stages are "research beyond unit material" evidence for the individual
  mark.

## ⚠️ Q&A defense — say all of this cold
**RE stage**
- Where the secret lives: it's the transform in `validate()`, recovered from the
  disassembly — not a string.
- Read the constants off the asm: `mov $0x1505` (seed), `shl $5 + add` = ×33,
  `imul $0x9e` (per-byte), `and $0xffffffffffff` (48-bit), `xor $0xc0ffee1234`
  (fold). Be able to point at each instruction.
- Why patching doesn't win: a locally-patched "always accept" copy yields no
  shell on the live box — only a valid code submitted to `:8888` does.

**Privesc stage**
- Why SUID matters: the binary runs with the owner's (root's) euid, so anything
  it execs runs as root.
- The exact bug: `system("netcheck")` with no absolute path → `/bin/sh` resolves
  `netcheck` via the *caller's* `$PATH`, which the attacker controls.
- Why `setreuid(0,0)` is in there: the dev added it so the tool always had perms;
  it's what guarantees the hijacked `netcheck` runs as full root rather than
  getting privileges dropped.
- The fix (state, don't build): call helpers by absolute path and reset `$PATH`
  inside the binary; don't leave SUID debug tools on the box.
