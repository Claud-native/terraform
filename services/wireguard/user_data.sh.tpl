#!/bin/bash
set -e

# Install WireGuard (Amazon Linux 2 / RHEL-family compatible)
if command -v yum >/dev/null 2>&1; then
  yum update -y
  amazon-linux-extras install -y epel
  yum install -y wireguard-tools wireguard-dkms qrencode
elif command -v apt-get >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y wireguard qrencode
fi

WG_IFACE="${iface}"
WG_PORT=${listen_port}

# Generate server keys
umask 077
SERVER_PRIV_KEY=$(wg genkey)
SERVER_PUB_KEY=$(echo "$SERVER_PRIV_KEY" | wg pubkey)

CLIENT_PRIV_KEY=$(wg genkey)
CLIENT_PUB_KEY=$(echo "$CLIENT_PRIV_KEY" | wg pubkey)

SERVER_IP4="10.10.0.1/24"
CLIENT_IP4="10.10.0.2/32"

mkdir -p /etc/wireguard
cat >/etc/wireguard/${WG_IFACE}.conf <<EOF
[Interface]
Address = ${SERVER_IP4}
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_PRIV_KEY}

[Peer]
PublicKey = ${CLIENT_PUB_KEY}
AllowedIPs = ${CLIENT_IP4}
EOF

cat >/etc/wireguard/client.conf <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIV_KEY}
Address = ${CLIENT_IP4}
DNS = 1.1.1.1

[Peer]
PublicKey = ${SERVER_PUB_KEY}
Endpoint = $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):${WG_PORT}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

chmod 600 /etc/wireguard/${WG_IFACE}.conf /etc/wireguard/client.conf

systemctl enable --now wg-quick@${WG_IFACE}

# Save client config to /home/ec2-user for retrieval
if id ec2-user >/dev/null 2>&1; then
  cp /etc/wireguard/client.conf /home/ec2-user/wireguard-client.conf
  chown ec2-user:ec2-user /home/ec2-user/wireguard-client.conf
fi

echo "WireGuard setup complete"
