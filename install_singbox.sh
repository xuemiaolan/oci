#!/usr/bin/env bash
set -euo pipefail

echo "===== Install sing-box + Cloudflare WARP ====="

if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

echo "[1/6] Install basic dependencies..."
$SUDO apt-get update
$SUDO apt-get install -y \
  curl \
  ca-certificates \
  gnupg \
  lsb-release \
  iptables \
  iptables-persistent \
  netfilter-persistent

echo "[2/6] Add sing-box repository..."
$SUDO install -d -m 0755 /etc/apt/keyrings

$SUDO curl -fsSL https://sing-box.app/gpg.key \
  -o /etc/apt/keyrings/sagernet.asc

$SUDO chmod a+r /etc/apt/keyrings/sagernet.asc

ARCH="$(dpkg --print-architecture)"

echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/sagernet.asc] https://deb.sagernet.org/ * *" \
  | $SUDO tee /etc/apt/sources.list.d/sagernet.list >/dev/null

echo "[3/6] Install sing-box..."
$SUDO apt-get update
$SUDO apt-get install -y sing-box

echo "[4/6] Add Cloudflare WARP repository..."
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg \
  | $SUDO gpg --yes --dearmor \
      --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg

CODENAME="$(lsb_release -cs)"

echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ ${CODENAME} main" \
  | $SUDO tee /etc/apt/sources.list.d/cloudflare-client.list >/dev/null

echo "[5/6] Install Cloudflare WARP..."
$SUDO apt-get update
$SUDO apt-get install -y cloudflare-warp

echo "[6/6] Configure firewall rules..."
$SUDO iptables -C INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null \
  || $SUDO iptables -I INPUT -p tcp --dport 80 -j ACCEPT

$SUDO iptables -C INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null \
  || $SUDO iptables -I INPUT -p tcp --dport 443 -j ACCEPT

$SUDO iptables -C INPUT -p udp --dport 8443 -j ACCEPT 2>/dev/null \
  || $SUDO iptables -I INPUT -p udp --dport 8443 -j ACCEPT

$SUDO iptables -C INPUT -p tcp --dport 48255 -j ACCEPT 2>/dev/null \
  || $SUDO iptables -I INPUT -p tcp --dport 48255 -j ACCEPT

echo "[7/7] Save firewall rules..."
$SUDO netfilter-persistent save

echo "===== Done ====="
echo "sing-box version:"
sing-box version || true

echo
echo "warp-cli version:"
warp-cli --version || true
