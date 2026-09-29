# Helix Secure Vault — Advanced Challenge #2 (Cryptographic)

**Vuln in one line:** CBC padding oracle. The service leaks, via two
distinguishable error responses, whether PKCS#7 padding decrypted cleanly.
That one bit of feedback lets an attacker decrypt the sealed vault token
byte-by-byte **without the key**.

Covers two brief requirements at once: advanced challenge #2 **and**
"cryptographic vulnerabilities (no classical ciphers)".

## Files
- `vault_server.py` — the deployed service (the vulnerability). Listens on `:9000`.
- `solve.py` — reference exploit. From-scratch oracle attack, no padbuster.
- `_selftest.py` — spins up server, runs solver, asserts the flag. CI/sanity.

## Flag
`helix{vault_unsealed_oops}` — it *is* the decrypted plaintext, so
recovering it is the whole challenge (nothing to grep on disk).

## Deploy (VM)
```
apt install python3-cryptography   # not pip — see setup.sh
python3 vault_server.py        # 0.0.0.0:9000
```
Wire into systemd on Yash's box as its own low-priv service user. Players reach
`:9000` after REC-3 hands out the port. No other setup.

## Player path
1. `nc <host> 9000` → banner, `TOKEN` returns the sealed blob (hex).
2. Notice `UNSEAL` gives **two different errors**: `0x01 unseal-failed` vs
   `0x02 malformed-token`. That difference = padding validity = the oracle.
3. Write a solver that flips the last byte of the preceding block, queries the
   oracle 256×/byte to force valid padding, recovers the intermediate state,
   XORs back to plaintext. Repeat per block.

## Why it scores on the difficulty rubric
- **Not automatable.** padbuster/web oracle tools speak HTTP only. The custom
  TCP protocol means players must understand the attack and script it — exactly
  the "resists automated tools, research beyond unit material" band.
- **Chained-ready.** The recovered plaintext can hold a next-stage secret (e.g.
  a Vault key that unlocks another challenge) instead of the flag directly, if
  you want to push into the HD "sophisticated chaining" band later.
- Crypto isn't in the unit slides → clean "independent research" evidence for
  the individual mark.

## ⚠️ Q&A defense — you must be able to say all of this cold
The demo can ask *you* to reproduce and explain it. Minimum you own:

- **Why CBC leaks:** `P_i = D_K(C_i) XOR C_{i-1}`. You don't know `D_K(C_i)`,
  but you control `C_{i-1}`. The oracle tells you when your forged `C_{i-1}`
  makes the decrypted block end in valid PKCS#7 padding.
- **The last-byte step:** forge the previous block so the plaintext's last byte
  becomes `0x01`. When the oracle says padding is valid, you know
  `D_K(C_i)[15] = forged[15] XOR 0x01`. That's one intermediate byte with no key.
- **Marching left:** to attack byte `k`, fix all bytes right of it to produce
  pad value `p = 16-k`, brute the 256 values for byte `k` until padding is valid.
- **The false-positive guard** (in `solve.py`, `pad==1` case): a random forge can
  accidentally produce a *longer* valid pad (e.g. `02 02`). We perturb the
  second-last byte and re-query; if padding stays valid it was a true `0x01`.
- **Why IV is transmitted:** it's block 0. With IV+CT you recover *every*
  plaintext block, including the first.
- **The fix (don't implement — just be able to state it):** authenticated
  encryption (AES-GCM) or encrypt-then-MAC, so tampered ciphertext is rejected
  before any padding check runs, and both error paths become identical.

If you can whiteboard the four bullets above, this challenge is yours to claim.
