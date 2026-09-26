#!/bin/sh
set -eu

challenge_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
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

if ! command -v chromium >/dev/null 2>&1 || ! python3 -c 'import selenium' >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y chromium chromium-driver python3-selenium
fi

install -d -o root -g root -m 0755 "$flag_dir" "$bot_dir" "$config_dir"
printf '%s\n' 'helix{web_stored-xss-admin-bot}' > "$flag_dir/w3.txt"
printf '%s\n' 'helix{adv_indirect-prompt-injection}' > "$flag_dir/a1.txt"
chown root:w3-bot "$flag_dir/w3.txt"
chown root:oracle-bot "$flag_dir/a1.txt"
chmod 0640 "$flag_dir/w3.txt" "$flag_dir/a1.txt"

install -o root -g w3-bot -m 0750 "$challenge_dir/w3_admin_bot.py" "$bot_dir/w3_admin_bot.py"
install -o root -g oracle-bot -m 0750 "$challenge_dir/a1_oracle_worker.py" "$bot_dir/a1_oracle_worker.py"

# The application receives only worker keys. It never receives either flag.
cat > "$config_dir/app-challenges.env" <<'EOF'
HELIX_REVIEW_KEY=helix-review-6b8cb1e89e04
HELIX_ORACLE_WORKER_KEY=helix-oracle-3af705c1d294
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

install -d -o root -g root -m 0755 /etc/systemd/system/flaskapp.service.d
cat > /etc/systemd/system/flaskapp.service.d/challenges.conf <<'EOF'
[Service]
EnvironmentFile=/etc/helix/app-challenges.env
EOF

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
