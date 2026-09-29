#!/usr/bin/env python3
"""
Reference keygen for the Helix Auth Service.

Recovered from validate() in the binary via `objdump -d auth_service`.
This is the group's canonical solution -- you must be able to re-derive this
loop from the disassembly on request during the demo.

The transform (per username byte, seed 0x1505):
    code = ((code << 5) + code) ^ (byte * 0x9E)   # i.e. code*33 ^ (byte*0x9E)
    code &= 0xFFFFFFFFFFFF                          # 48-bit mask
after all bytes:
    code ^= 0xC0FFEE1234
    code &= 0xFFFFFFFFFFFF

Usage:  python3 keygen.py <username>
        python3 keygen.py authadmin
"""
import sys

MASK48 = 0xFFFFFFFFFFFF


def keygen(user: str) -> int:
    code = 0x1505
    for b in user.encode():
        code = (((code << 5) + code) ^ (b * 0x9E)) & MASK48
    code ^= 0xC0FFEE1234
    return code & MASK48


if __name__ == "__main__":
    user = sys.argv[1] if len(sys.argv) > 1 else "authadmin"
    print(f"user: {user}")
    print(f"code: {keygen(user):x}")
