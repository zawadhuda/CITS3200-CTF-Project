#!/usr/bin/env python3
"""
Build the license-locked archive. Imports the branding (INCIDENT/VENDOR) and the
key/password derivation from activate.py, so you only ever set the theme in ONE
place: activate.py. Input memo + output zip path are given as arguments.

Usage:
  python3 build_archive.py --memo memo.txt --out archive.zip
  python3 build_archive.py --memo-text "flag: helix{...}" --out archive.zip --inner-name secret.txt

Requires: system `zip` (sudo apt install zip).
"""
import argparse, os, subprocess, sys, tempfile
import activate   # single source of truth for INCIDENT/VENDOR + derivation

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True, help="output zip path")
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--memo",      help="path to a text file to place inside the zip")
    g.add_argument("--memo-text", help="literal text to place inside the zip")
    ap.add_argument("--inner-name", default="memo.txt", help="filename inside the zip (default: memo.txt)")
    args = ap.parse_args()

    key = activate.derive_key()
    zpw = activate.zip_password(key)

    workdir = tempfile.mkdtemp()
    inner = os.path.join(workdir, args.inner_name)
    content = open(args.memo).read() if args.memo else args.memo_text
    open(inner, "w").write(content)

    if os.path.exists(args.out): os.remove(args.out)
    r = subprocess.run(["zip", "-j", "-P", zpw, args.out, inner], capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit("zip failed (install it: sudo apt install zip):\n" + r.stderr)

    print("[+] built:", args.out)
    print("    using INCIDENT =", activate.INCIDENT, "| VENDOR =", activate.VENDOR, "(from activate.py)")
    print("    LICENSE KEY   :", key)
    print("    zip password  :", zpw, "(= md5(key)[:12]; activate.pyc computes this itself)")

if __name__ == "__main__":
    main()
