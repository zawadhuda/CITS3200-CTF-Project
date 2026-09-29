"""
Helix Dynamics — corporate employee portal.

Run this version only in the isolated CTF VM.

Run (CTF VM):
    pip install flask
    python3 app.py
    # http://127.0.0.1:5000
"""
import base64
import hashlib
import json
import os
import pickle
import secrets
import sqlite3
from functools import wraps

from flask import (Flask, flash, jsonify, redirect, render_template, request,
                   session, url_for, Response, abort)
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


app = Flask(__name__)
app.secret_key = os.environ.get("HELIX_SECRET", "dev-only-change-me")
DB = os.path.join(os.path.dirname(__file__), "helix.db")
MAX_PROFILE_BYTES = 64 * 1024
REVIEW_KEY = os.environ.get("HELIX_REVIEW_KEY", "development-review-key")
ORACLE_WORKER_KEY = os.environ.get(
    "HELIX_ORACLE_WORKER_KEY", "development-oracle-key")

# --- Basic Auth for the dev infrastructure page ---
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
            id INTEGER PRIMARY KEY, subject TEXT, body TEXT,
            reviewed INTEGER DEFAULT 0,
            oracle_processed INTEGER DEFAULT 0,
            oracle_reply TEXT DEFAULT '');
        CREATE TABLE IF NOT EXISTS xss_reports(
            ticket_id INTEGER PRIMARY KEY,
            captured_data TEXT,
            FOREIGN KEY(ticket_id) REFERENCES tickets(id));
        """)
        # The supplied VM has an older database, so add the challenge columns
        # without deleting the existing tickets.
        columns = {row["name"] for row in c.execute(
            "PRAGMA table_info(tickets)").fetchall()}
        if "reviewed" not in columns:
            c.execute("ALTER TABLE tickets ADD COLUMN reviewed INTEGER DEFAULT 0")
        if "oracle_processed" not in columns:
            c.execute(
                "ALTER TABLE tickets ADD COLUMN oracle_processed INTEGER DEFAULT 0")
        if "oracle_reply" not in columns:
            c.execute("ALTER TABLE tickets ADD COLUMN oracle_reply TEXT DEFAULT ''")
        cur = c.execute("SELECT COUNT(*) n FROM employees").fetchone()
        if cur["n"] == 0:
            def junk():
                return hashlib.md5(os.urandom(24)).hexdigest()
            weak = hashlib.md5(FLAG_WEB_SQLI.encode()).hexdigest()
            rows = [
                ("alice.morgan@helix.local",  junk(), "Dr. Alice Morgan",
                 "Research Engineer", "RESEARCH"),
                ("bob.nkemdirim@helix.local", junk(), "Bob Nkemdirim",
                 "Infrastructure Engineer", "RESEARCH"),
                ("charlie.voss@helix.local",  weak, "Charlie Voss",
                 "Systems Analyst", "RESEARCH"),
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
        # Directory lookup for the result card below.
        query = "SELECT name, email, title FROM employees WHERE email='%s'" % email
        try:
            with db() as c:
                record = c.execute(query).fetchone()
        except sqlite3.Error:
            record = None

        # Authenticate against the employees table.
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
            cursor = c.execute(
                "INSERT INTO tickets(subject,body) VALUES(?,?)",
                (request.form.get("subject", "")[:200],
                 request.form.get("body", "")[:10000]))
            ticket_id = cursor.lastrowid
        flash("Ticket submitted. Awaiting automated administrator review.", "ok")
        return redirect(url_for("support_ticket", ticket_id=ticket_id))
    with db() as c:
        tickets = c.execute("SELECT * FROM tickets ORDER BY id DESC LIMIT 10").fetchall()
    return render_template("support.html", tickets=tickets)


@app.route("/support/ticket/<int:ticket_id>")
def support_ticket(ticket_id):
    with db() as c:
        ticket = c.execute(
            "SELECT * FROM tickets WHERE id=?", (ticket_id,)).fetchone()
        report = c.execute(
            "SELECT captured_data FROM xss_reports WHERE ticket_id=?",
            (ticket_id,)).fetchone()
    if ticket is None:
        abort(404)
    return render_template("support_ticket.html", ticket=ticket, report=report)


@app.route("/support/collect/<int:ticket_id>")
def collect_browser_report(ticket_id):
    """Record a browser report for a ticket."""
    captured = request.args.get("data", "")[:4096]
    with db() as c:
        exists = c.execute(
            "SELECT 1 FROM tickets WHERE id=?", (ticket_id,)).fetchone()
        if exists is None:
            abort(404)
        c.execute(
            "INSERT OR REPLACE INTO xss_reports(ticket_id,captured_data)"
            " VALUES(?,?)", (ticket_id, captured))
    return ("recorded", 200)


def valid_internal_key(provided, expected):
    return bool(provided) and secrets.compare_digest(provided, expected)


@app.route("/internal/next-ticket")
def internal_next_ticket():
    if not valid_internal_key(request.args.get("key"), REVIEW_KEY):
        abort(403)
    with db() as c:
        ticket = c.execute(
            "SELECT id FROM tickets WHERE reviewed=0 ORDER BY id LIMIT 1"
        ).fetchone()
    return jsonify({"ticket_id": ticket["id"] if ticket else None})


@app.route("/internal/review/<int:ticket_id>")
def internal_review(ticket_id):
    if not valid_internal_key(request.args.get("key"), REVIEW_KEY):
        abort(403)
    with db() as c:
        exists = c.execute(
            "SELECT 1 FROM tickets WHERE id=?", (ticket_id,)).fetchone()
    if exists is None:
        abort(404)
    return render_template(
        "admin_review.html", ticket_id=ticket_id, review_key=REVIEW_KEY)


@app.route("/internal/ticket-data/<int:ticket_id>")
def internal_ticket_data(ticket_id):
    if not valid_internal_key(request.args.get("key"), REVIEW_KEY):
        abort(403)
    with db() as c:
        ticket = c.execute(
            "SELECT id,subject,body FROM tickets WHERE id=?", (ticket_id,)
        ).fetchone()
    if ticket is None:
        abort(404)
    return jsonify(dict(ticket))


@app.route("/internal/mark-reviewed/<int:ticket_id>", methods=["POST"])
def internal_mark_reviewed(ticket_id):
    if not valid_internal_key(request.args.get("key"), REVIEW_KEY):
        abort(403)
    with db() as c:
        c.execute("UPDATE tickets SET reviewed=1 WHERE id=?", (ticket_id,))
    return jsonify({"ok": True})


@app.route("/internal/oracle-next")
def internal_oracle_next():
    if not valid_internal_key(request.args.get("key"), ORACLE_WORKER_KEY):
        abort(403)
    with db() as c:
        ticket = c.execute(
            "SELECT id,subject,body FROM tickets WHERE oracle_processed=0"
            " ORDER BY id LIMIT 1"
        ).fetchone()
    return jsonify(dict(ticket) if ticket else {"ticket_id": None})


@app.route("/internal/oracle-reply/<int:ticket_id>", methods=["POST"])
def internal_oracle_reply(ticket_id):
    if not valid_internal_key(request.args.get("key"), ORACLE_WORKER_KEY):
        abort(403)
    reply = request.get_json(silent=True) or {}
    with db() as c:
        cursor = c.execute(
            "UPDATE tickets SET oracle_reply=?, oracle_processed=1 WHERE id=?",
            (str(reply.get("reply", ""))[:10000], ticket_id))
    if cursor.rowcount == 0:
        abort(404)
    return jsonify({"ok": True})


# ---------- Profile ----------
@app.route("/profile")
@login_required
def profile():
    return render_template("profile.html", user=current_user())


@app.route("/profile/export")
@login_required
def profile_export():
    u = current_user()
    # Serialise the profile for the .hpf download.
    profile_data = {"email": u["email"], "name": u["name"],
                    "title": u["title"], "clearance": u["clearance"]}
    blob = base64.b64encode(pickle.dumps(profile_data, protocol=4))
    return Response(blob, mimetype="application/octet-stream",
                    headers={"Content-Disposition": "attachment; filename=profile.hpf"})


def load_profile_package(raw):
    """Decode a Helix profile package (.hpf)."""
    decoded = base64.b64decode(raw, validate=True)

    try:
        return pickle.loads(decoded)
    except (pickle.UnpicklingError, EOFError, AttributeError, ImportError, IndexError):
        # Profiles exported by the earlier JSON version still work.
        return json.loads(decoded.decode("utf-8"))


@app.route("/profile/import", methods=["POST"])
@login_required
def profile_import():
    f = request.files.get("profile")
    if not f:
        flash("No file provided.", "err")
        return redirect(url_for("profile"))
    try:
        raw = f.read(MAX_PROFILE_BYTES + 1)
        if len(raw) > MAX_PROFILE_BYTES:
            raise ValueError("Profile package is too large")

        data = load_profile_package(raw)
        if not isinstance(data, dict):
            raise ValueError("Profile package did not contain a profile")

        flash(f"Imported profile for {data.get('name','?')}.", "ok")
    except (ValueError, TypeError, UnicodeDecodeError, json.JSONDecodeError,
            pickle.UnpicklingError):
        flash("Invalid .hpf file.", "err")
    return redirect(url_for("profile"))


# ---------- Dev infrastructure (Basic Auth gated) ----------
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
    # Debug is OFF by default. The CTF VM must run with it off: the
    # Werkzeug debugger is an unauthenticated remote console.
    # Local dev only: HELIX_DEBUG=1 python3 app.py
    app.run(host="0.0.0.0", port=5000,
            debug=os.environ.get("HELIX_DEBUG") == "1")
