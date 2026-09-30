/*
 * ops-report — remote-ops-owned helper with a command-injection bug.
 *
 * Deployed SUID remote-ops, group-executable by sys-user ONLY (4750
 * remote-ops:sys-user). Anyone in the group can run it;
 * the title argument is interpolated into a shell command unsanitised, so
 * shell metacharacters (`;`, `$()`) execute with the owner's (remote-ops)
 * privileges. Deliberately a DIFFERENT bug class from helix-diag's
 * unqualified-PATH hijack: here the issue is data interpolated into a
 * fixed command line. No setuid(0) games — euid is remote-ops, never root.
 *
 * Build:  gcc -O2 -o ops-report ops-report.c
 */
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

int main(int argc, char **argv)
{
    char cmd[512];
    pid_t pid;
    int status;

    if (argc != 2) {
        printf("usage: ops-report \"<title>\"\n");
        return 1;
    }
    /* BUG: title interpolated into a shell command unquoted and
     * unsanitised, so shell metacharacters execute with the owner's
     * (remote-ops) privileges. */
    snprintf(cmd, sizeof cmd,
             "/bin/echo report filed: %s >> /srv/ops-reports/inbox.log",
             argv[1]);
    /* The desk runs filings through bash in privileged mode so the log
     * write keeps the helper's identity no matter who files. */
    pid = fork();
    if (pid < 0) {
        printf("filing failed.\n");
        return 1;
    }
    if (pid == 0) {
        execl("/bin/bash", "bash", "-p", "-c", cmd, (char *)NULL);
        _exit(127);
    }
    if (waitpid(pid, &status, 0) < 0 || status != 0) {
        printf("filing failed.\n");
        return 1;
    }
    printf("report filed.\n");
    return 0;
}
