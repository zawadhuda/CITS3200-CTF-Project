# Helix Dynamics — CTF target site (CITS3006)

Benign, runnable Flask app for the "Breach Helix" CTF. Safe by default; each
intended vulnerability is a marked `[CTF]` hook for your group to inject and own.

## Run
```
pip install flask
python3 app.py          # http://127.0.0.1:5000  (0.0.0.0:5000 on the VM)
```
Seed logins (in `helix.db`, auto-created):
- alice.morgan@helix.local / sunshine  (weak credential — the intended entry point)
- Basic Auth for /dev-infra-backup/ : devops / R3dacted_But_Weak!  (same creds as the FTP PCAP teaches)

## Pages → challenge hooks
| Route | Hook |
|---|---|
| /login | SQLi (query is parameterised — make it string-built) |
| /support | stored/DOM-XSS to admin bot + indirect prompt injection (Oracle) |
| /profile/import | insecure deserialization (.hpf — pick pickle/PHP/Java) |
| /dev-infra-backup/ | Basic-Auth gate discovered via FTP PCAP |
| /research/prometheus | incident-ID clue (PRM-403-9182) |
| /about | recon: staff emails → username list |

## Before writing any vuln code
Fill the requirement matrix first (per your design notes): every vuln → category,
prereq, resulting access, flag, next clue. The empty cells are still the three
horizontal escalations and the three distinct root paths — resolve those next.
