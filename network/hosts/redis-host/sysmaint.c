/*
 * sysmaint — deliberately vulnerable SUID-root "maintenance" utility.
 *
 * The maintenance password below is the SAME plaintext secret that the
 * snmp-host's NET-SNMP-EXTEND-MIB script leaks (a stand-in for "an admin
 * put a password on a command line and it ended up somewhere it
 * shouldn't have"). Anyone who recovers that secret via SNMP can use it
 * here to escalate a low-privilege shell (obtained via the Redis /
 * authorized_keys foothold) to root.
 *
 * Build: gcc -O2 -o sysmaint sysmaint.c && chown root:root sysmaint && chmod 4755 sysmaint
 */
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define MAINT_PASSWORD "B4ckup_S3cret_99!"

int main(void) {
    char buf[128];

    printf("sysmaint - internal maintenance utility\n");
    printf("Enter maintenance password: ");
    fflush(stdout);

    if (!fgets(buf, sizeof(buf), stdin)) {
        return 1;
    }
    buf[strcspn(buf, "\n")] = '\0';

    if (strcmp(buf, MAINT_PASSWORD) != 0) {
        printf("Access denied.\n");
        return 1;
    }

    printf("Password accepted. Dropping into maintenance shell as root.\n");
    fflush(stdout); /* execl() never returns, so flush now: without this a
                     * piped (non-tty) run prints nothing on success and a
                     * correct password is indistinguishable from a hang. */
    if (setgid(0) != 0 || setuid(0) != 0) {
        perror("setuid/setgid");
        return 1;
    }
    execl("/bin/bash", "bash", "-p", (char *)NULL);
    perror("execl");
    return 1;
}
