#!/usr/bin/env python3
"""
License-key activation utility. Unlocks a sealed data archive when given a valid
license key. The key is derived from the project's reference strings below, so no
secret is stored in plaintext -- the logic must be recovered from this file.

    python3 activate.pyc <LICENSE-KEY> [--archive PATH] [--out DIR]

Defaults: --archive ./archive.zip   --out .
Internal build. Do not distribute source.
"""
import os, hashlib, zipfile, argparse

# ============================================================================
#  REBRAND HERE. Change these two strings to retheme the challenge.
#  build_archive.py imports them from this file, so the key/password stay in
#  sync automatically -- you only edit them in ONE place (here).
# ============================================================================
INCIDENT = "PRM-403-9182"
VENDOR   = "helix-research"
# ============================================================================

def derive_key(incident: str = INCIDENT, vendor: str = VENDOR) -> str:
    seed   = (vendor + ":" + incident + ":activation").encode()
    digest = hashlib.sha256(seed).hexdigest()
    parts  = [digest[0:4], digest[8:12], digest[16:20], digest[24:28]]
    return "HELIX-" + "-".join(p.upper() for p in parts)

def zip_password(license_key: str) -> str:
    return hashlib.md5(license_key.encode()).hexdigest()[:12]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("key", help="license key")
    ap.add_argument("--archive", default="archive.zip", help="locked archive path (default: archive.zip)")
    ap.add_argument("--out",     default=".",           help="extract directory (default: current dir)")
    args = ap.parse_args()

    expected = derive_key()
    if args.key.strip() != expected:
        print("[-] Invalid license key. Activation denied."); return
    try:
        with zipfile.ZipFile(args.archive) as z:
            z.extractall(path=args.out, pwd=zip_password(expected).encode())
        print("[+] License valid. Archive unlocked ->", os.path.abspath(args.out))
    except FileNotFoundError:
        print("[-] Archive not found:", args.archive)
    except Exception as e:
        print("[-] Archive error:", e)

if __name__ == "__main__":
    main()
