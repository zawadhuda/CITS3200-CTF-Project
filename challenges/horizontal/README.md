# Local horizontals — CTF AUTHORS ONLY

No-sudo, live-off-the-land hops between the VM's local accounts. No flags
at either hop (chain-end-only policy) — each landing drops a cryptic
server taunt pointing onward.

## Hop 1 — `svc-web-prod` → `sys-user`: backup SSH key

`sys-user_backup_key` (+`.pub`) is a sloppy backup of `sys-user`'s SSH key,
deployed world-readable under `/srv/backups/sys-user/`. The key carries a
passphrase (`dragon`, top-wordlist — crack via `ssh2john` + wordlist, echoing
the Alice entry). Attacker tools: `find` + `ssh` + wordlist. `setup.sh`
appends the public half to `~sys-user/.ssh/authorized_keys` (never clobbers).

## Hop 2 — `sys-user` → `remote-ops`: SUID command injection

`ops-report` (`/opt/helix/ops-report`, `4750 remote-ops:sys-user`) files a
report titled by its argument — interpolated into a shell command
unsanitised, so metacharacters execute as `remote-ops`. Deliberately a
different bug class from `helix-diag`'s PATH hijack (interpolation, not
lookup). `sys-user` reaches it via primary group; `svc-web-prod` and
everyone else get `Permission denied` (no hop-skipping). No sudo anywhere.

## Pointers in play

- Hop 1 has no pointer — post-RCE enumeration (`find`) is the canonical
  discovery, and the backup-dir naming stays boring on purpose.
- Hop 2 is pointed at by the logic-gate hint (`/home/sys-user/logic_gate`,
  solved as `sys-user`): "filing reports … punctuation in the title".
