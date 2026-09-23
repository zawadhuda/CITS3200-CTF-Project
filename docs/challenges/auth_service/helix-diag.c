/*
 * helix-diag  ::  Chain C privesc (vertical) — SUID-root, PATH hijack.
 *
 * A "system diagnostics" helper left SUID-root on the box. The developer added
 * setuid(0) so it always has the perms it needs, but calls a helper by an
 * UNQUALIFIED name via system(), so /bin/sh resolves it through the caller's
 * $PATH. Anyone who can run this (the authsvc user reached in Chain C) can
 * drop a malicious `netcheck` earlier in $PATH and get root.
 *
 * This is NOT a bare GTFOBins SUID (those get auto-flagged and auto-exploited
 * by linpeas). The SUID bit alone gives nothing; the attacker must spot the
 * unqualified call in the binary and stage a hijack. See README.md.
 *
 * Build/deploy (needs root, on the VM):
 *     gcc -O1 -o helix-diag helix-diag.c
 *     sudo chown root:root helix-diag && sudo chmod 4755 helix-diag
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(void)
{
    (void)setreuid(0, 0);           /* dev added this so it "just works" */
    (void)setregid(0, 0);
    puts("helix-diag :: running system checks...");
    (void)system("date");           /* absolute-ish builtins, fine */
    (void)system("uptime");
    /* BUG: unqualified helper name -> resolved via caller-controlled $PATH */
    (void)system("netcheck");
    puts("helix-diag :: done.");
    return 0;
}
