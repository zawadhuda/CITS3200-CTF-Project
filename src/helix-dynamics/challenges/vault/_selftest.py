import subprocess, socket, time, sys, os

HERE = os.path.dirname(os.path.abspath(__file__))
srv = subprocess.Popen([sys.executable, "vault_server.py"], cwd=HERE,
                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
try:
    time.sleep(2)
    if srv.poll() is not None:
        sys.exit("server died: " + srv.stderr.read().decode())

    s = socket.create_connection(("127.0.0.1", 9000)); f = s.makefile("rwb")
    f.readline(); f.readline()
    f.write(b"TOKEN\r\n"); f.flush()
    tok = f.readline().strip()
    print("token bytes:", len(bytes.fromhex(tok.decode())))

    f.write(b"UNSEAL " + tok + b"\r\n"); f.flush()
    print("real token   ->", f.readline().strip().decode())
    bad = bytearray(bytes.fromhex(tok.decode())); bad[-1] ^= 0x01
    f.write(b"UNSEAL " + bad.hex().encode() + b"\r\n"); f.flush()
    print("tampered CT  ->", f.readline().strip().decode())
    s.close()

    out = subprocess.run([sys.executable, "solve.py", "127.0.0.1", "9000"],
                         cwd=HERE, capture_output=True, text=True)
    print("--- solver stdout ---"); print(out.stdout.strip())
    assert "helix{adv_padding-oracle-cbc-vault}" in out.stdout, "FLAG NOT RECOVERED"
    print("=== SELFTEST PASS ===")
finally:
    srv.terminate(); srv.wait()
