#!/bin/bash
set -euxo pipefail

# Paquetes base
if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y curl wget
elif command -v dnf >/dev/null 2>&1; then
  dnf -y install curl wget
elif command -v yum >/dev/null 2>&1; then
  yum -y install curl wget
elif command -v zypper >/dev/null 2>&1; then
  zypper --non-interactive install curl wget
fi

# IP pública desde la metadata de EC2
PUBIP="$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || true)"
SERVER_ADDR="${PUBIP:-$(curl -s ifconfig.me || echo 127.0.0.1)}"

# Descarga del instalador hwdsl2 (URL oficial)
wget -O /root/wireguard.sh https://get.vpnsetup.net/wg || \
curl -fL -o /root/wireguard.sh https://get.vpnsetup.net/wg
chmod +x /root/wireguard.sh

# Instalación no interactiva
bash /root/wireguard.sh --auto \
  --serveraddr "${SERVER_ADDR}" \
  --port 51820 \
  --clientname "endika"
