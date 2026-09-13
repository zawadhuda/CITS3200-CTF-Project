#!/usr/bin/env python3
"""
Reference exploit for the Helix Secure Vault padding oracle.

No padbuster: the vault speaks a custom TCP protocol, so we drive the oracle
ourselves. This file is the group's canonical solution — read it until you can
re-derive it on a whiteboard, because the live demo can ask you to.

Usage:  python3 solve.py [host] [port]      # defaults 127.0.0.1 9000
"""
import socket
import sys

BLOCK = 16
HOST = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 9000


def connect():
    s = socket.create_connection((HOST, PORT))
    f = s.makefile("rwb")
    f.readline(); f.readline()          # eat 2-line banner
    return s, f


def get_token(f):
    f.write(b"TOKEN\r\n"); f.flush()
    return bytes.fromhex(f.readline().decode().strip())


def valid_padding(f, blob: bytes) -> bool:
    """One oracle query. True iff PKCS#7 padding decrypted cleanly.

    ERR 0x01 = bad padding (False). Anything else — 0x02 malformed-token or an
    OK — means padding was valid (True).
    """
    f.write(b"UNSEAL " + blob.hex().encode() + b"\r\n"); f.flush()
    resp = f.readline()
    return b"0x01" not in resp


def recover_block(f, prev: bytes, target: bytes) -> bytes:
    """Recover the intermediate state D(target), then caller XORs with prev."""
    inter = bytearray(BLOCK)            # D_K(target), unknown
    forged = bytearray(BLOCK)          # the C' block we control
    for pad in range(1, BLOCK + 1):
        idx = BLOCK - pad
        # set already-known tail so it decrypts to the pad value
        for j in range(idx + 1, BLOCK):
            forged[j] = inter[j] ^ pad
        for guess in range(256):
            forged[idx] = guess
            if valid_padding(f, bytes(forged) + target):
                # guard against the false hit where we landed a longer valid
                # pad by luck: bump the previous byte and re-check.
                if pad == 1:
                    forged[idx - 1] ^= 0xFF
                    ok = valid_padding(f, bytes(forged) + target)
                    forged[idx - 1] ^= 0xFF
                    if not ok:
                        continue
                inter[idx] = guess ^ pad
                break
        else:
            raise RuntimeError(f"no valid byte at pad={pad}")
    return bytes(inter)


def main():
    s, f = connect()
    token = get_token(f)
    blocks = [token[i:i + BLOCK] for i in range(0, len(token), BLOCK)]
    # blocks[0] is the IV; each subsequent block decrypts using the one before.
    plain = b""
    for i in range(1, len(blocks)):
        prev, target = blocks[i - 1], blocks[i]
        inter = recover_block(f, prev, target)
        plain += bytes(a ^ b for a, b in zip(inter, prev))
        print(f"[+] block {i}/{len(blocks)-1} recovered", file=sys.stderr)
    s.close()

    # strip PKCS#7 padding
    plain = plain[:-plain[-1]]
    print("[*] recovered plaintext:", plain.decode(errors="replace"))
    flag = plain.split(b"|", 1)[-1] if b"|" in plain else plain
    print("[*] FLAG:", flag.decode(errors="replace"))


if __name__ == "__main__":
    main()
