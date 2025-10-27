#!/bin/bash
set -eux

# Install WireGuard on Ubuntu Jammy
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends wireguard iproute2 curl

umask 077
# Generate keys
SERVER_PRIVKEY=$(wg genkey)
SERVER_PUBKEY=$(echo "$SERVER_PRIVKEY" | wg pubkey)
CLIENT_PRIVKEY=$(wg genkey)
CLIENT_PUBKEY=$(echo "$CLIENT_PRIVKEY" | wg pubkey)

# Template variable assigned to shell variable
WG_PORT=${wireguard_port}
SERVER_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || hostname -I | awk '{print $1}')

cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.0.0.1/24
ListenPort = $${WG_PORT}
PrivateKey = $${SERVER_PRIVKEY}
PostUp = sysctl -w net.ipv4.ip_forward=1; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
EOF

cat > /etc/wireguard/client.conf <<EOF
[Interface]
PrivateKey = $${CLIENT_PRIVKEY}
Address = 10.0.0.2/24
DNS = 1.1.1.1

[Peer]
PublicKey = $${SERVER_PUBKEY}
AllowedIPs = 0.0.0.0/0
Endpoint = $${SERVER_IP}:$${WG_PORT}
PersistentKeepalive = 25
EOF

chmod 600 /etc/wireguard/*.conf
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# Copy client config to home for retrieval
if id ubuntu >/dev/null 2>&1; then
  cp /etc/wireguard/client.conf /home/ubuntu/wireguard-client.conf
  chown ubuntu:ubuntu /home/ubuntu/wireguard-client.conf
else
  cp /etc/wireguard/client.conf /root/wireguard-client.conf
fi
