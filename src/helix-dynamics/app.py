"""
Helix Dynamics — CITS3006 CTF target application (frontend + safe scaffold).

This is the BENIGN target app. It is safe by default: parameterised queries,
Jinja auto-escaping, no live deserializer. Each intended vulnerability has a
[CTF] hook marked in the code/templates. Inject the actual weaknesses yourself
so your group understands and can explain every one live (a grading criterion).

Run:
    pip install flask
    python3 app.py
    # http://127.0.0.1:5000
"""
import base64
import hashlib
import json
import os
import sqlite3
from functools import wraps

ITER = 200_000
def strong_hash(pw):
    salt = os.urandom(8)
    h = hashlib.pbkdf2_hmac('sha256', pw.encode(), salt, ITER)
    return "pbkdf2$%s$%s" % (salt.hex(), h.hex())     # on the VM: swap to bcrypt
def strong_verify(pw, stored):
    try:
        _, s, h = stored.split("$")
        return hashlib.pbkdf2_hmac('sha256', pw.encode(), bytes.fromhex(s), ITER).hex() == h
    except Exception:
        return False
FLAG_WEB_SQLI = "helix{websqli}"

from flask import (Flask, flash, redirect, render_template, request,
                   session, url_for, Response, abort)

app = Flask(__name__)
app.secret_key = os.environ.get("HELIX_SECRET", "dev-only-change-me")
DB = os.path.join(os.path.dirname(__file__), "helix.db")

# --- Basic Auth creds for the hidden dev page (creds should also appear in your FTP PCAP) ---
DEV_USER = "devops"
DEV_PASS = "helixbuild2026"


def db():
    c = sqlite3.connect(DB)
    c.row_factory = sqlite3.Row
    return c


def init_db():
    with db() as c:
        c.executescript("""
        CREATE TABLE IF NOT EXISTS employees(
            id INTEGER PRIMARY KEY,
            email TEXT UNIQUE, password TEXT,
            name TEXT, title TEXT, clearance TEXT);
        CREATE TABLE IF NOT EXISTS tickets(
            id INTEGER PRIMARY KEY, subject TEXT, body TEXT);
        """)
        cur = c.execute("SELECT COUNT(*) n FROM employees").fetchone()
        if cur["n"] == 0:
            def junk():
                return hashlib.md5(os.urandom(24)).hexdigest()   # uncrackable
            weak = hashlib.md5(FLAG_WEB_SQLI.encode()).hexdigest()  # crackable -> flag
            rows = [
                ("alice.morgan@helix.local",  junk(), "Dr. Alice Morgan",
                 "Research Engineer", "RESEARCH"),
                ("bob.nkemdirim@helix.local", junk(), "Bob Nkemdirim",
                 "Infrastructure Engineer", "RESEARCH"),
                ("charlie.voss@helix.local",  weak, "Charlie Voss",
                 "Systems Analyst", "RESEARCH"),   # <-- the crackable one
                ("dana.reid@helix.local",     junk(), "Dana Reid",
                 "Compliance Officer", "RESEARCH"),
            ]
            for email, pwhash, name, title, clr in rows:
                c.execute(
                    "INSERT INTO employees(email,password,name,title,clearance)"
                    " VALUES(?,?,?,?,?)",
                    (email, pwhash, name, title, clr))


def current_user():
    if "uid" not in session:
        return None
    with db() as c:
        return c.execute("SELECT * FROM employees WHERE id=?",
                         (session["uid"],)).fetchone()


def login_required(fn):
    @wraps(fn)
    def w(*a, **k):
        if not current_user():
            return redirect(url_for("login"))
        return fn(*a, **k)
    return w


# ---------- Public pages ----------
@app.route("/")
def index():
    return render_template("index.html")


@app.route("/about")
def about():
    return render_template("about.html")


@app.route("/research")
def research():
    return render_template("research.html")


@app.route("/research/prometheus")
def prometheus():
    return render_template("prometheus.html")


@app.route("/careers")
def careers():
    return render_template("careers.html")


# ---------- Employee login ----------
@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        email = request.form.get("email", "")
        pw = request.form.get("password", "")
        # [CTF][WEB-1] SQL INJECTION (in-band). The lookup is string-built, so
        # `<email>' -- ` comments out the "AND recovery_md5 IS NULL" filter and
        # returns that account's row, revealing the password hash it normally hides.
        query = "SELECT name, email, title FROM employees WHERE email='%s'" % email
        try:
            with db() as c:
                record = c.execute(query).fetchone()
        except sqlite3.Error:
            record = None

        # AUTH is separate and SAFE (parameterised): injection reveals data, never a session.
        with db() as c:
            acct = c.execute("SELECT * FROM employees WHERE email=?", (email,)).fetchone()
        if acct and hashlib.md5(pw.encode()).hexdigest() == acct["password"]:
            session["uid"] = acct["id"]
            return redirect(url_for("dashboard"))
        return render_template("login.html", searched=True, record=record)
    return render_template("login.html", searched=False, record=None)


@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("index"))


@app.route("/dashboard")
@login_required
def dashboard():
    return render_template("dashboard.html", user=current_user())


# ---------- Support ----------
@app.route("/support", methods=["GET", "POST"])
def support():
    if request.method == "POST":
        with db() as c:
            c.execute("INSERT INTO tickets(subject,body) VALUES(?,?)",
                      (request.form.get("subject", ""), request.form.get("body", "")))
        flash("Ticket submitted. Awaiting automated administrator review.", "ok")
        return redirect(url_for("support"))
    with db() as c:
        tickets = c.execute("SELECT * FROM tickets ORDER BY id DESC LIMIT 10").fetchall()
    return render_template("support.html", tickets=tickets)


# ---------- Profile ----------
@app.route("/profile")
@login_required
def profile():
    return render_template("profile.html", user=current_user())


@app.route("/profile/export")
@login_required
def profile_export():
    u = current_user()
    # SAFE, portable .hpf = base64(JSON). If you choose deserialization as your web vuln,
    # swap the *import* side to your chosen format (pickle/PHP/Java) — see profile_import.
    payload = {"email": u["email"], "name": u["name"],
               "title": u["title"], "clearance": u["clearance"]}
    blob = base64.b64encode(json.dumps(payload).encode())
    return Response(blob, mimetype="application/octet-stream",
                    headers={"Content-Disposition": "attachment; filename=profile.hpf"})


@app.route("/profile/import", methods=["POST"])
@login_required
def profile_import():
    f = request.files.get("profile")
    if not f:
        flash("No file provided.", "err")
        return redirect(url_for("profile"))
    # [CTF][DESERIALIZATION] SAFE parse only. Do NOT call pickle.loads / unserialize here in
    # its current form. When you build the challenge, do it deliberately and sandboxed to the
    # CTF VM, and record the exact trigger object in your matrix so the group can explain it.
    try:
        data = json.loads(base64.b64decode(f.read()))
        flash(f"Imported profile for {data.get('name','?')}.", "ok")
    except Exception:
        flash("Invalid .hpf file.", "err")
    return redirect(url_for("profile"))


# ---------- Hidden dev infrastructure (Basic Auth gated) ----------
def check_basic(auth):
    return auth and auth.username == DEV_USER and auth.password == DEV_PASS


@app.route("/dev-infra-backup/")
def dev_infra():
    auth = request.authorization
    if not check_basic(auth):
        return Response("Authentication required.", 401,
                        {"WWW-Authenticate": 'Basic realm="Helix Dev Infra"'})
    return render_template("dev_infra.html")


if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000, debug=True)
