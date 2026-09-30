# Logic Gate — Reverse Engineering Challenge (local)

Small Linux program `logic_gate`. Asks for `HELIX_SEED`; the right number
prints a **hint** (not a flag) toward the next local-escalation hop. The
expected seed is computed at runtime from hardcoded constants — recover it
with Ghidra/objdump, don't `strings` it (XOR-obfuscated, reveals nothing).

## Files in this folder

- `logic_gate.cpp` — source (authors only, never on the VM).
- `setup.sh` — builds on the VM (`g++ -O0`, no strip) and installs the
  binary into `sys-user`'s home. Run it via `scripts/setup_vm.sh`.

## Manual equivalent

```
g++ -O0 -o logic_gate logic_gate.cpp   # keep -O0, no strip (Ghidra-readable)
install -o sys-user -g sys-user -m 0755 logic_gate /home/sys-user/logic_gate
chmod 750 /home/sys-user                # solvers only: svc-web-prod stays out
```

## Checks

```
./logic_gate                            # [-] HELIX_SEED not set. Denied.
HELIX_SEED=1 ./logic_gate               # [-] Invalid seed. Access denied.
strings logic_gate | grep -i mgmt       # nothing (hint is obfuscated)
```

## Solve (authors only)

Seed = `((0x5EED * 2) ^ 0x1234) - 0x777 + 42` = `43169`:

```
HELIX_SEED=43169 ./logic_gate
# [+] Seed accepted. Hint: The ops desk files its own reports. ...
```
