#!/bin/sh
set -eu

challenge_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
workers_dir="$challenge_dir/../workers"
flag_dir=/opt/helix/flags
bot_dir=/opt/helix/bots
config_dir=/etc/helix

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this setup script as root" >&2
    exit 1
fi

getent group svc-web-prod >/dev/null 2>&1 || {
    echo "svc-web-prod group does not exist" >&2
    exit 1
}

for user in w3-bot oracle-bot; do
    if ! id "$user" >/dev/null 2>&1; then
        useradd --system --home-dir /nonexistent --shell /usr/sbin/nologin "$user"
    fi
done

install -d -o w3-bot -g w3-bot -m 0700 /var/lib/helix-w3-bot

if ! command -v chromium >/dev/null 2>&1 \
        || ! command -v chromedriver >/dev/null 2>&1 \
        || ! python3 -c 'import selenium' >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y chromium chromium-driver python3-selenium
fi

install -d -o root -g root -m 0755 "$flag_dir" "$bot_dir" "$config_dir"
printf '%s\n' 'helix{web_stored-xss-admin-bot}' > "$flag_dir/w3.txt"
printf '%s\n' 'helix{adv_indirect-prompt-injection}' > "$flag_dir/a1.txt"
chown root:w3-bot "$flag_dir/w3.txt"
chown root:oracle-bot "$flag_dir/a1.txt"
chmod 0640 "$flag_dir/w3.txt" "$flag_dir/a1.txt"

install -o root -g w3-bot -m 0750 "$workers_dir/w3_admin_bot.py" "$bot_dir/w3_admin_bot.py"
install -o root -g oracle-bot -m 0750 "$workers_dir/a1_oracle_worker.py" "$bot_dir/a1_oracle_worker.py"

# The application receives only worker keys and its Flask secret.
# It never receives any flag. Flags stay static (see docs/FLAGS.md)
# so they can be registered in the submissions backend.
# The Flask secret is generated once and preserved across re-runs:
# none of the implemented challenges depend on the weak default.
if [ -f "$config_dir/app-challenges.env" ] \
    && grep -q '^HELIX_SECRET=' "$config_dir/app-challenges.env" 2>/dev/null; then
    helix_secret=$(grep '^HELIX_SECRET=' "$config_dir/app-challenges.env" | cut -d= -f2-)
else
    helix_secret=$(python3 -c 'import secrets; print(secrets.token_hex(32))')
fi
cat > "$config_dir/app-challenges.env" <<EOF
HELIX_SECRET=$helix_secret
HELIX_REVIEW_KEY=helix-review-6b8cb1e89e04
HELIX_ORACLE_WORKER_KEY=helix-oracle-3af705c1d294
# Restore token for /profile/import. Static build constant, identical to
# network/hosts/redis-host/profile-token.txt (docker-root loot). A key, not
# a flag: it gates the deserialiser, nothing is submitted for it.
HELIX_HPF_TOKEN=helix-hpf-restore-7f3a
EOF
chown root:svc-web-prod "$config_dir/app-challenges.env"
chmod 0640 "$config_dir/app-challenges.env"

cat > "$config_dir/w3-bot.env" <<'EOF'
HELIX_BASE_URL=http://127.0.0.1:5000
HELIX_REVIEW_KEY=helix-review-6b8cb1e89e04
W3_FLAG_PATH=/opt/helix/flags/w3.txt
EOF
chown root:w3-bot "$config_dir/w3-bot.env"
chmod 0640 "$config_dir/w3-bot.env"

cat > "$config_dir/oracle-bot.env" <<'EOF'
HELIX_BASE_URL=http://127.0.0.1:5000
HELIX_ORACLE_WORKER_KEY=helix-oracle-3af705c1d294
A1_FLAG_PATH=/opt/helix/flags/a1.txt
ORACLE_REQUIRE_MODEL=0
EOF
chown root:oracle-bot "$config_dir/oracle-bot.env"
chmod 0640 "$config_dir/oracle-bot.env"

# The Flask unit lives in this directory (flaskapp.service) and already
# points at /etc/helix/app-challenges.env, so no drop-in override is needed.
# Remove any stale drop-in from earlier installs.
rm -rf /etc/systemd/system/flaskapp.service.d
install -o root -g root -m 0644 "$challenge_dir/flaskapp.service" \
    /etc/systemd/system/flaskapp.service

cat > /etc/systemd/system/helix-w3-bot.service <<'EOF'
[Unit]
Description=Helix W3 administrator browser
After=network.target flaskapp.service
Requires=flaskapp.service

[Service]
Type=simple
User=w3-bot
Environment=HOME=/var/lib/helix-w3-bot
EnvironmentFile=/etc/helix/w3-bot.env
ExecStart=/usr/bin/python3 /opt/helix/bots/w3_admin_bot.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/helix-oracle-worker.service <<'EOF'
[Unit]
Description=Helix A1 Oracle ticket worker
After=network.target flaskapp.service
Requires=flaskapp.service

[Service]
Type=simple
User=oracle-bot
EnvironmentFile=/etc/helix/oracle-bot.env
ExecStart=/usr/bin/python3 /opt/helix/bots/a1_oracle_worker.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable flaskapp.service helix-w3-bot.service helix-oracle-worker.service
systemctl restart flaskapp.service
systemctl restart helix-w3-bot.service helix-oracle-worker.service

echo "W3 and A1 workers installed"
