# R2 activation challenge — build kit (for retheming / repointing)

You asked for: the zip-generation script, and for the activate script to take
input/output files as args instead of hardcoding. Both done. You can rebrand and
change the memo freely.

## Files
- `activate.py`   — the license checker (SOURCE). Compile to .pyc to ship.
- `build_archive.py` — generates the locked zip. Imports branding from activate.py.

## Rebrand / rename (change the theme, e.g. drop "Prometheus")
Edit ONLY the two lines at the top of `activate.py`:
    INCIDENT = "..."      # the reference string the key derives from
    VENDOR   = "..."      # vendor string the key derives from
`build_archive.py` imports these, so the license key + zip password stay in sync
automatically — you never edit them in two places.

## Change the memo content + make the locked zip
    # inline text:
    python3 build_archive.py --memo-text "your memo...
    flag: helix{your_flag}" --inner-name secret.txt --out archive.zip

    # or from a file:
    python3 build_archive.py --memo memo.txt --inner-name secret.txt --out archive.zip

It prints the LICENSE KEY and zip password (for your answer sheet / testing).
Needs `zip`:  sudo apt install zip

## Compile the checker to ship (.pyc is what players get; NOT the .py)
    python3 -m py_compile activate.py
    cp __pycache__/activate.cpython-*.pyc activate.pyc
IMPORTANT: compile on the same Python version as the target VM (a .pyc only runs
on the version it was built with).

## Run it (args for archive + output dir, as requested)
    python3 activate.pyc <LICENSE-KEY> --archive archive.zip --out ./out
Wrong key  -> "Invalid license key. Activation denied."
Right key  -> extracts the archive into --out.
Defaults if omitted: --archive archive.zip, --out current dir.

## Ship vs keep
- Deploy to the VM (players): activate.pyc + the locked zip ONLY.
- Keep private: activate.py, build_archive.py, and any answer notes.
- Compile the .pyc ON the VM so its Python version matches.
