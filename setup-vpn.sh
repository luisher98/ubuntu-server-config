#!/bin/bash

# Exit on error
set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Install WireGuard
apt update
apt install -y wireguard

# Create WireGuard directory
mkdir -p /etc/wireguard

# Generate server keys
cd /etc/wireguard
wg genkey | tee server_private.key | wg pubkey > server_public.key
wg genkey | tee client_private.key | wg pubkey > client_public.key

# Create server configuration
cat > /etc/wireguard/wg0.conf << EOF
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = $(cat server_private.key)
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $(cat client_public.key)
AllowedIPs = 10.0.0.2/32
EOF

# Create client configuration
cat > /etc/wireguard/client.conf << EOF
[Interface]
PrivateKey = $(cat client_private.key)
Address = 10.0.0.2/24
DNS = 8.8.8.8

[Peer]
PublicKey = $(cat server_public.key)
Endpoint = $(curl -s ifconfig.me):51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-wireguard.conf
sysctl -p /etc/sysctl.d/99-wireguard.conf

# Start WireGuard
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# Display client configuration
echo "Client configuration (save this):"
cat /etc/wireguard/client.conf

# Display server public key
echo "Server public key:"
cat /etc/wireguard/server_public.key 