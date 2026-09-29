#!/usr/bin/env python3
"""
Helix Secure Vault  ::  advanced challenge #2 (cryptographic).

Deployed vulnerability: a CBC padding oracle over a custom TCP protocol.
The service decrypts an attacker-supplied blob and leaks, via two
distinguishable error responses, whether PKCS#7 padding was valid. That
single bit is enough to decrypt the sealed vault token one byte at a time,
with no key.

The custom line protocol (not HTTP) is deliberate: off-the-shelf tools like
padbuster speak HTTP oracles only, so players must understand the attack and
write their own solver. That is the difficulty lever — see README.md.

Run:  python3 vault_server.py           # listens on 0.0.0.0:9000
Deps: pip install cryptography
"""
import socketserver
import os

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives import padding

BLOCK = 16
PORT = 9000

# Server-side secret. Players never see this — they recover the plaintext
# through the oracle. Hardcoded so the box is deterministic for the demo;
# key secrecy is NOT what the challenge tests.
_KEY = bytes.fromhex("6b3a9f1c8d2e5740b1c6a9f30e7d4852"
                     "9a1f6c3b8e0d2749a5c8f1b4d6e39072")  # AES-256
_IV = bytes.fromhex("00112233445566778899aabbccddeeff")

# What the sealed token decrypts to. Recovering this string IS the win.
_SECRET = b"helix{adv_padding-oracle-cbc-vault}"

# The magic prefix a *real* token must start with once decrypted. Lets the
# server tell "padding was fine but this isn't a token" apart from
# "padding was broken" — that distinction is the leak.
_MAGIC = b"VLT1"


def _seal(plaintext: bytes) -> bytes:
    padder = padding.PKCS7(BLOCK * 8).padder()
    padded = padder.update(plaintext) + padder.finalize()
    enc = Cipher(algorithms.AES(_KEY), modes.CBC(_IV)).encryptor()
    return _IV + enc.update(padded) + enc.finalize()


# The token handed out on TOKEN. Prefixed with MAGIC so a correct decrypt is
# recognisable, then the secret. Players attack this blob.
_TOKEN = _seal(_MAGIC + b"|" + _SECRET)


def _oracle(blob: bytes) -> str:
    """Decrypt IV||CT and report status. The two ERR paths are the oracle."""
    if len(blob) < 2 * BLOCK or len(blob) % BLOCK != 0:
        return "ERR 0x03 bad-length"
    iv, ct = blob[:BLOCK], blob[BLOCK:]
    dec = Cipher(algorithms.AES(_KEY), modes.CBC(iv)).decryptor()
    padded = dec.update(ct) + dec.finalize()
    try:
        unpadder = padding.PKCS7(BLOCK * 8).unpadder()
        pt = unpadder.update(padded) + unpadder.finalize()
    except ValueError:
        return "ERR 0x01 unseal-failed"          # <-- invalid padding
    if not pt.startswith(_MAGIC):
        return "ERR 0x02 malformed-token"         # <-- valid padding, wrong body
    return "OK vault-open " + pt.decode(errors="replace")


BANNER = (b"HELIX SECURE VAULT v2.3\r\n"
          b"AES-256-CBC sealed storage. Commands: TOKEN | UNSEAL <hex> | HELP | QUIT\r\n")


class Handler(socketserver.StreamRequestHandler):
    def handle(self):
        self.wfile.write(BANNER)
        while True:
            line = self.rfile.readline()
            if not line:
                break
            parts = line.split()
            if not parts:
                continue
            cmd = parts[0].upper()
            if cmd == b"QUIT":
                self.wfile.write(b"BYE\r\n")
                break
            elif cmd == b"HELP":
                self.wfile.write(b"TOKEN -> sealed vault token (hex). "
                                 b"UNSEAL <hex> -> attempt to open.\r\n")
            elif cmd == b"TOKEN":
                self.wfile.write(_TOKEN.hex().encode() + b"\r\n")
            elif cmd == b"UNSEAL":
                if len(parts) != 2:
                    self.wfile.write(b"ERR 0x04 usage: UNSEAL <hex>\r\n")
                    continue
                try:
                    blob = bytes.fromhex(parts[1].decode())
                except ValueError:
                    self.wfile.write(b"ERR 0x05 not-hex\r\n")
                    continue
                self.wfile.write(_oracle(blob).encode() + b"\r\n")
            else:
                self.wfile.write(b"ERR 0x06 unknown-command\r\n")


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    with Server(("0.0.0.0", PORT), Handler) as s:
        print(f"[vault] listening on :{PORT}")
        s.serve_forever()
