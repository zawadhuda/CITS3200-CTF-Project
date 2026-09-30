# CITS3006 CTF Project — Helix Dynamics

Vulnerable corporate portal + Docker network lab + local privilege-escalation
chain, packaged as a VirtualBox OVA for the CITS3006 penetration-testing
group project. Group report: `CITS3006-Report.md`.

## Team

| Member | Student ID |
|---|---|
| Zawad Huda | 23102177 |
| Michael Ang | 24258101 |
| Dhava Wikhananda Adhi | 24149342 |
| Hamish Haslam | 24498604 |
| Yashwardhan Laharia | 24295462 |

## Project Overview

Six flags across three exploit chains (network → container root, web → RCE
→ real root, plus standalone XSS / Oracle / vault legs). See
`CITS3006-Report.md` for the exploit map, sample solutions, and flag list.

## Repository Structure

- `src/` - Flask app, challenge workers/bots, VM deployment units
- `scripts/` - `package_app.sh` builds the clean VM app dir, `setup_vm.sh` provisions the whole VM (see `docs/VM.md`)
- `challenges/` - Standalone CTF services (auth service, vault) + local-account challenges (logic-gate, r2-activation, horizontals)
- `network/` - Docker network lab (FTP/recon, redis, SNMP) + compose boot unit + PASV auto-detect
- `docs/` - Author-only documentation (`FLAGS.md`, `SOLUTIONS.md`, `VM.md` — never ship to the VM)

## Important

All penetration-testing activities must only be performed against systems
and targets authorised for the CITS3006 project.
