#!/usr/bin/env bash

cd /etc/wireguard

read DNS < ./dns.var
read ENDPOINT < ./endpoint.var
read VPN_SUBNET < ./vpn_subnet.var
read SERVER_PUBLIC_KEY < /etc/wireguard/server_public.key
ALLOWED_IP="0.0.0.0/24, ::/24"

# Set VPN user name
if [ -z "$1" ]
  then
    read -p "Enter VPN user name: " USERNAME
    if [ -z $USERNAME ]
      then
      echo "Empty VPN user name. Exit"
      exit 1;
    fi
  else USERNAME=$1
fi

# Create a directory structure for VPN user
mkdir -p ./clients
cd ./clients
mkdir ./$USERNAME
cd ./$USERNAME
umask 077

# Generate private and public key
CLIENT_PRESHARED_KEY=$( wg genpsk )
CLIENT_PRIVKEY=$( wg genkey )
CLIENT_PUBLIC_KEY=$( echo $CLIENT_PRIVKEY | wg pubkey )

# Get client IP address
read OCTET_IP < /etc/wireguard/last_used_ip.var
OCTET_IP=$(($OCTET_IP+1))
echo $OCTET_IP > /etc/wireguard/last_used_ip.var

CLIENT_IP="$VPN_SUBNET$OCTET_IP/32"

# Create a blank configuration file client
cat > /etc/wireguard/clients/$USERNAME/$USERNAME.conf << EOF
[Interface]
PrivateKey = $CLIENT_PRIVKEY
Address = $CLIENT_IP
DNS = $DNS
[Peer]
PublicKey = $SERVER_PUBLIC_KEY
PresharedKey = $CLIENT_PRESHARED_KEY
AllowedIPs = $ALLOWED_IP
Endpoint = $ENDPOINT
PersistentKeepalive=25
EOF

# Add new client data to the Wireguard configuration file
cat >> /etc/wireguard/wg0.conf << EOF
[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
PresharedKey = $CLIENT_PRESHARED_KEY
AllowedIPs = $CLIENT_IP
EOF

# Restart Wireguard
systemctl stop wg-quick@wg0
systemctl start wg-quick@wg0

# Show QR config to display
qrencode -t ansiutf8 < ./$USERNAME.conf

# Show config file
echo "# Display $USERNAME.conf"
cat ./$USERNAME.conf

# Save QR config to png file
qrencode -t png -o ./$USERNAME.png < ./$USERNAME.conf
