# Boot TTY intro + theme voice guide — CTF AUTHORS ONLY

> The story copy is a draft — rewrite freely. What must NOT change without
> a matching code/docs update is called out inline.
>
> Theme: **intern vs cocky server**. The tty skit is a flashback (the night
> the intern fled). The live range speaks only server, everywhere.

## Voice guide (normative for all new flavor text)

- **Server** — terse audit-log mockery. Three channels:
  - cyan `[…DAEMON]` = genuine hints, always truthful about mechanics;
  - red = denial theater (`Login incorrect`, `Incident logged`, similarity scores);
  - green = false hope (progress bars that die at 99%).
  - The server never helps directly and never lies about mechanics.
- **Intern** — grey `[hw_ambient_mic]` panic transcript. Appears ONLY in
  this intro. Never in live services.
- Rule of thumb: if a player could mistake flavor for a hint, it must be
  either true (cyan) or obviously theater (red/green). No third category.

## Setup (as applied on the VM)

```
nano /usr/local/bin/ctf-intro.sh
chmod +x /usr/local/bin/ctf-intro.sh
truncate -s 0 /etc/issue
```

```
systemctl edit getty@tty1

[Service]
TTYVTDisallocate=no
ExecStartPre=-/bin/bash /usr/local/bin/ctf-intro.sh
ExecStart=
ExecStart=-/sbin/agetty -o '-p -- \\u' --noclear --keep-baud 115200,38400,9600 %I $TERM
```

```
systemctl daemon-reload
systemctl restart getty@tty1
```

Recommended hardening (not yet applied — do by hand on the VM):

- **Replay guard.** `ExecStartPre` fires on *every* getty start, including
  after each logout, so the ~90s skit replays endlessly. Add to the top of
  `ctf-intro.sh`:
  ```sh
  [ -f /var/lib/ctf-intro.done ] && exit 0
  # ... skit ...
  touch /var/lib/ctf-intro.done
  ```
- **Perms.** Script must stay `root:root 0755` — it runs as root pre-login.

## ctf-intro.sh (draft copy)

```bash
#!/bin/bash
# ==============================================================================
# CTF INTRO: INTERN BREAKDOWN + FAKE PROGRESS BAR GASLIGHTING
# ==============================================================================

clear

# Palette
DIM_GREY="\e[38;5;240m"   # Ambient mic whisper transcript
BRIGHT_WHITE="\e[97m"     # Authentic TTY login & typing
SERVER_RED="\e[91m"       # Denials & audit warnings
SERVER_GREEN="\e[92m"     # Fake success / hope
SERVER_CYAN="\e[96m"      # Automated compliance hints
YELLOW="\e[93m"           # Panic spam
RESET="\e[0m"

# Human jitter typing
typewrite() {
    local text="$1"
    local base_speed="${2:-5}"
    for (( i=0; i<${#text}; i++ )); do
        echo -ne "${text:$i:1}"
        local jitter=$(( (RANDOM % base_speed) + 4 ))
        if (( RANDOM % 13 == 0 )); then
            sleep 0.22 # Micro-hesitation
        else
            sleep "0.0${jitter}"
        fi
    done
    echo ""
}

# Ambient mic logging (dim grey)
audio_log() {
    local quote="$1"
    echo -e "${DIM_GREY}[hw_ambient_mic: \"$quote\"]${RESET}"
    sleep 0.5
}

pam_delay() {
    sleep 1.3
}

# Cruel, animated fake progress bar
fake_progress_bar() {
    local label="$1"
    echo -ne "${SERVER_CYAN}${label}: [${RESET}"
    for i in {1..20}; do
        echo -ne "${SERVER_GREEN}#${RESET}"
        sleep 0.08
    done
    echo -ne "${SERVER_CYAN}] 99% (Verifying entropy...)${RESET}"
    sleep 1.6
    echo -e "\n${SERVER_RED}[CRITICAL ERR] Checksum failed on last byte. Access Denied.${RESET}\n"
}

# ==============================================================================
# ACT I: THE STANDARD DEFAULTS
# ==============================================================================
sleep 0.8

audio_log "*metal door creaks shut, shivering in server exhaust*"
audio_log "okay... wipe the drop-table audit logs before morning standup..."

# Attempt 1: admin / admin
echo -ne "${BRIGHT_WHITE}NODE-722-DEB login: ${RESET}"
sleep 0.4
typewrite "admin" 5
echo -ne "${BRIGHT_WHITE}Password: ${RESET}"
sleep 0.3
typewrite "admin" 4
pam_delay
echo -e "${BRIGHT_WHITE}Login incorrect${RESET}\n"

# Attempt 2: root / toor
echo -ne "${BRIGHT_WHITE}NODE-722-DEB login: ${RESET}"
sleep 0.3
typewrite "root" 5
echo -ne "${BRIGHT_WHITE}Password: ${RESET}"
sleep 0.2
typewrite "toor" 4
pam_delay
echo -e "${BRIGHT_WHITE}Login incorrect${RESET}\n"

# ==============================================================================
# ACT II: POP CULTURE MEMES & SIMILARITY PERCENTAGE BAIT
# ==============================================================================

audio_log "what if the senior dev is an edgy nerd...?"

# Attempt 3: Mr. Robot meme
echo -ne "${BRIGHT_WHITE}NODE-722-DEB login: ${RESET}"
sleep 0.4
typewrite "elliot" 4
echo -ne "${BRIGHT_WHITE}Password: ${RESET}"
sleep 0.3
typewrite "fsociety00.dat" 3
pam_delay
echo -e "${SERVER_RED}Login incorrect (Notice: You are not Christian Slater. Put the hoodie down.)${RESET}\n"

# Attempt 4: IRC classic hunter2
audio_log "wait... what was that classic IRC joke password again?!"
echo -ne "${BRIGHT_WHITE}NODE-722-DEB login: ${RESET}"
sleep 0.3
typewrite "sysadmin" 4
echo -ne "${BRIGHT_WHITE}Password: ${RESET}"
sleep 0.2
typewrite "hunter2" 4
pam_delay
echo -e "${SERVER_RED}Login incorrect [Similarity Score: 12.4% - Cold]${RESET}\n"

# ==============================================================================
# ACT III: THE SERVER DROPS A FAKE PROGRESS BAR (THE 99% HEARTBREAK)
# ==============================================================================

audio_log "wait! what was written on the yellow sticky note by the coffee pot?!"

# Attempt 5: The dev sticky note (Triggers the 99% progress bar tease)
echo -ne "${BRIGHT_WHITE}NODE-722-DEB login: ${RESET}"
sleep 0.3
typewrite "sysadmin" 4
echo -ne "${BRIGHT_WHITE}Password: ${RESET}"
sleep 0.2
typewrite "Coffee!2024#DontForgetMeeting" 3
sleep 0.6
echo -e "${SERVER_CYAN}[PAM-COMPLIANCE-DAEMON]: Evaluating candidate hash against legacy cache...${RESET}"
echo -e "${SERVER_GREEN}[Similarity Match: 98.7% - ALMOST THERE]${RESET}"
sleep 0.8
fake_progress_bar "Decrypting Keystore"

audio_log "NO NO NO NO YOU WERE AT 99% WHAT DO YOU MEAN CHECKSUM FAILED?!"
audio_log "DID THEY CHANGE JUST ONE CHARACTER AFTER THE OUTAGE?!"

# Attempt 6: Intern tries altering the year
echo -ne "${BRIGHT_WHITE}NODE-722-DEB login: ${RESET}"
sleep 0.3
typewrite "sysadmin" 4
echo -ne "${BRIGHT_WHITE}Password: ${RESET}"
sleep 0.2
typewrite "Coffee!2025#DontForgetMeeting" 3
pam_delay
echo -e "${SERVER_RED}Login incorrect [Similarity Score: 0.0% - Nice try. Incident logged.]${RESET}\n"

# ==============================================================================
# ACT IV: FAKE BUFFER OVERFLOW
# ==============================================================================

audio_log "maybe i can just crash the auth daemon with junk strings..."

# Attempt 7: Buffer overflow attempt
echo -ne "${BRIGHT_WHITE}NODE-722-DEB login: ${RESET}"
sleep 0.3
typewrite "admin" 4
echo -ne "${BRIGHT_WHITE}Password: ${RESET}"
sleep 0.2
typewrite "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" 2
pam_delay
echo -e "${SERVER_CYAN}*** Segmentation fault (core dumped) ***${RESET}"
sleep 1.2
echo -e "${SERVER_CYAN}Psych. TTY login buffers don't overflow on ASCII As. Sit down.${RESET}\n"
sleep 0.6

# ==============================================================================
# ACT V: THE STT TRANSCRIPT DISCOVERY & PANIC
# ==============================================================================

audio_log "YOU DECEITFUL PIECE OF SILICON! LET ME IN OR I PULL THE POWER CORD!"
sleep 0.9
audio_log "...wait. Why is there tiny faint grey text printing under the prompt?"
sleep 1.4
audio_log "IS THAT A MICROPHONE?! HAS THIS BOX BEEN WRITING DOWN MY WORDS THE WHOLE TIME?!"
sleep 0.6

# Server diagnostic daemon notes acoustic shift
echo -e "${SERVER_CYAN}[hw_ambient_mic_daemon]: Acoustic sensor: Decibels 84dB. Vocal pitch indicates acute panic.${RESET}"
echo -e "${SERVER_CYAN}[hw_ambient_mic_daemon]: Audio clarity: 100%. Hi there.${RESET}\n"
sleep 0.8

# Intern panics and tries to clear the terminal history
echo -ne "${YELLOW}NODE-722-DEB login: ^C${RESET}"
sleep 0.09
echo ""
echo -ne "${YELLOW}NODE-722-DEB login: ^C${RESET}"
sleep 0.08
echo ""
echo -ne "${YELLOW}NODE-722-DEB login: ^C${RESET}"
sleep 0.07
echo ""
echo -ne "${YELLOW}NODE-722-DEB login: ${RESET}"
typewrite "clear" 2
echo -e "${SERVER_RED}bash: clear: command not found (The screen stays. The shame remains.)${RESET}"

echo -ne "${YELLOW}NODE-722-DEB login: ${RESET}"
typewrite "cls" 2
echo -e "${SERVER_RED}bash: cls: Windows cmd habits won't delete evidence.${RESET}"

echo -ne "${YELLOW}NODE-722-DEB login: ${RESET}"
typewrite "history -c" 2
echo -e "${SERVER_RED}pam_deny: Buffer is write-only / immutable. Your manager has already received the digest.${RESET}\n"

audio_log "*frantic desk pounding* IT WON'T CLEAR! IT LOGGED EVERYTHING I SAID!"
audio_log "SOMEONE JUST OPENED THE SECURITY AIRLOCK DOWN THE CORRIDOR"

# ==============================================================================
# ACT VI: THE SERVER CHUCKLE & INCIDENT LOCKDOWN
# =============================================================================
sleep 0.6

echo -e "${SERVER_RED}[kernel]: lol.${RESET}"
sleep 0.4
echo -e "${SERVER_RED}[kernel]: lmao, even.${RESET}"
sleep 0.8

# Snapshot & Dispatch
echo -e "\n${BRIGHT_WHITE}[CRITICAL AUDIT DISPATCH]${RESET}"
sleep 0.3
echo -e "${DIM_GREY}[hw_rack_camera]: Snapshot captured: 'sweating_perpetrator_shivering_in_rack_b.raw'${RESET}"
sleep 0.3
echo -e "${DIM_GREY}[ticket_dispatch]: Audio transcripts & security footage forwarded to Legal & Campus Recruiter.${RESET}"
sleep 0.6

audio_log "*sound of VGA cable being violently ripped out of the port*"
audio_log "*sneakers skidding on the raised metal tiles in full sprint*"
sleep 1.2

# The Final Lockdown & CTF Wire Nudge
echo -e "\n${SERVER_RED}================================================================================${RESET}"
echo -e "${SERVER_RED}[LOCAL TTY CONSOLE DECOMMISSIONED - CRIME SCENE PRESERVED]${RESET}"
echo -e "${SERVER_RED}Physical access is restricted. The intern has fled the building.${RESET}"
echo -e "${SERVER_RED}Stop staring at the glass. Go back to your workstation and sweep the wire.${RESET}"
echo -e "${SERVER_RED}================================================================================${RESET}\n"

sleep 1.4
exit 0
```

> Deliberately cut from the draft: the RECOVERY-WIZARD bit (`Master
> recovery format…`, `production_customers…DROP`, Attempt 8). No recovery
> feature exists, so it would send players down an undesigned hole. Do not
> re-add flavor that names mechanics unless they are real (voice rule).

## Insertion points (samples — finals are yours)

Wording only; DOM/keys/trigger-words are load-bearing and stay as-is.

| Surface | Sample voice |
|---|---|
| `dashboard.html` announcements | `IT #441: Redis is exposed again. Touch it and Legal gets a digest. — MGMT` |
| `dev_infra.html` TODOs | `TODO: fix auth_service before production (audit finding #12, still open, still ignored)` |
| Oracle generic reply | `Ticket received. The support team will review it, eventually. Incident logged.` |
| Vault banner | `HELIX SECURE VAULT v2.3 — sealed storage. Tampering is logged. Hi there.` |
| Auth service `ACCESS DENIED` | `ACCESS DENIED. Similarity Score: 0.0% - Cold. Incident logged.` |
| `helix-diag` output | `helix-diag :: running system checks... (2 failed, 0 fixed, 1 blamed on the intern)` |
| `leak_cmd.sh` echo | keep the leak verbatim; prefix flavor lives in the runbook, not the command output |
| ftp `runbook.txt` | sign notes `- devops (do NOT revert my changes)` |
| Flask flashes | `Invalid profile token. The restore desk is unimpressed. Incident logged.` / keep `Invalid .hpf file` ice-cold with no joke (a joke here would read as a hint) |
| `note.txt` breadcrumb | server taunt (already rewritten — see `network/hosts/redis-host/note.txt`) |
| sysmaint prompts | `sysmaint - internal maintenance utility (abandon hope, interns)` / `Access denied. Incident logged. Legal has been notified, again.` — password logic untouched |
| SNMP `snmpd.conf`/`leak_cmd` | config comments only; the `extend` output line must stay byte-identical (it's the leaked secret) |
| vsftpd/nginx | server banners stay stock (`Server: nginx`, FTP `220`); a cocky banner would fingerprint the box as a CTF — stock is stealthier |
| `offer.txt` (real root) | already written — see `challenges/auth_service/setup.sh` |
| support ticket flow | `Ticket submitted. Awaiting automated administrator review. (The administrator is automated. The review is not.)` |

## Pre-ship checklist (theme)

1. No flavor names a mechanic that isn't real (voice rule).
2. No flavor contains a real credential, key, or flag.
3. `bash -n` on any script touched; packaged-app self-check still green.
