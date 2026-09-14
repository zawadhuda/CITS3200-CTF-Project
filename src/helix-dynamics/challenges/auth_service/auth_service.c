/*
 * Helix Auth Service  ::  Chain C foothold (Reverse Engineering)
 *
 * A custom access-control daemon. Grants a shell as the service user to any
 * client that presents a username plus the matching access code. The code is
 * derived from the username by validate() below -- there is NO plaintext
 * password to `strings`. Players must read the disassembly, recover the
 * transform, and reimplement it (a keygen) to mint a valid code.
 *
 * Design note: the flag is read from the environment at runtime, so it is
 * present ONLY on the deployed :8888 service. The copy players pull to reverse
 * has no flag in it, and patching the compare in a local copy gets them
 * nothing -- they must recover the real algorithm and submit a valid code to
 * the live service. That is what makes it resist the usual "flip the jne"
 * shortcut. See README.md.
 *
 * Build:   gcc -O1 -fno-stack-protector -o auth_service auth_service.c
 * Run:     ./auth_service            # stdin mode (local testing / RE)
 *          ./auth_service --serve    # TCP daemon on :8888 (deploy)
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdint.h>
#include <arpa/inet.h>
#include <sys/socket.h>

#define PORT 8888
#define MASK48 0xFFFFFFFFFFFFULL

/* Recover THIS from the disassembly. DJB2-seeded rolling transform with a
 * per-byte XOR-multiply and a final constant fold, masked to 48 bits. */
static uint64_t __attribute__((noinline)) validate(const char *user)
{
    uint64_t code = 0x1505ULL;                 /* seed */
    for (const unsigned char *p = (const unsigned char *)user; *p; ++p) {
        code = ((code << 5) + code) ^ ((uint64_t)(*p) * 0x9EULL);
        code &= MASK48;
    }
    code ^= 0xC0FFEE1234ULL;                    /* final fold */
    return code & MASK48;
}

static char *fdgets(char *buf, int n, int fd);   /* fwd decl */

static void chomp(char *s) { s[strcspn(s, "\r\n")] = 0; }

/* Read "user" then "code" from fd, check, grant or deny. Returns 1 on grant. */
static int handle(int in, int out)
{
    char user[128], codebuf[64];
    dprintf(out, "helix auth-service :: username: ");
    if (!fdgets(user, sizeof user, in)) return 0;   /* see helper below */
    chomp(user);
    dprintf(out, "access-code (hex): ");
    if (!fdgets(codebuf, sizeof codebuf, in)) return 0;
    chomp(codebuf);

    uint64_t expect = validate(user);
    uint64_t given  = strtoull(codebuf, NULL, 16);

    if (given == expect) {
        const char *flag = getenv("FLAG");
        dprintf(out, "ACCESS GRANTED\n");
        if (flag) dprintf(out, "%s\n", flag);
        return 1;
    }
    dprintf(out, "ACCESS DENIED\n");
    return 0;
}

/* tiny fd-based line reader (avoids stdio buffering across sockets) */
static char *fdgets(char *buf, int n, int fd)
{
    int i = 0; char c;
    while (i < n - 1) {
        int r = read(fd, &c, 1);
        if (r <= 0) { if (i == 0) return NULL; break; }
        if (c == '\n') { buf[i++] = c; break; }
        buf[i++] = c;
    }
    buf[i] = 0;
    return buf;
}

static void serve(void)
{
    int s = socket(AF_INET, SOCK_STREAM, 0);
    int opt = 1; setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof opt);
    struct sockaddr_in a = {0};
    a.sin_family = AF_INET; a.sin_addr.s_addr = INADDR_ANY; a.sin_port = htons(PORT);
    if (bind(s, (struct sockaddr *)&a, sizeof a) < 0) { perror("bind"); exit(1); }
    listen(s, 8);
    fprintf(stderr, "[auth] listening on :%d\n", PORT);
    for (;;) {
        int c = accept(s, NULL, NULL);
        if (c < 0) continue;
        if (fork() == 0) {
            close(s);
            if (handle(c, c)) {          /* GRANT -> shell as the service user */
                dup2(c, 0); dup2(c, 1); dup2(c, 2);
                execl("/bin/sh", "sh", NULL);
            }
            close(c); _exit(0);
        }
        close(c);
    }
}

int main(int argc, char **argv)
{
    if (argc > 1 && strcmp(argv[1], "--serve") == 0) serve();
    else handle(0, 1);                    /* stdin mode: no shell, safe for RE */
    return 0;
}
