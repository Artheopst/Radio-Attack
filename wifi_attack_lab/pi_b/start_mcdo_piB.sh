#!/bin/bash
# ===========================================
# RÉSEAU LÉGITIME — Pi B (kali-raspberrypi-B)
# Émet "Mcdo Free Wifi" ouvert (comme un vrai réseau public)
# ===========================================

IFACE=wlan0
SSID="Mcdo Free Wifi"
CHANNEL=6
AP_IP="192.168.50.1"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}[*] Démarrage réseau légitime : $SSID${NC}"

# Créer config à la volée (évite le "file not found" au reboot)
cat > /tmp/hostapd_mcdo.conf << EOF
interface=$IFACE
driver=nl80211
ssid=$SSID
hw_mode=g
channel=$CHANNEL
auth_algs=1
wpa=0
ieee80211n=1
EOF

# Libérer wlan0
sudo systemctl stop NetworkManager 2>/dev/null
sudo pkill -9 wpa_supplicant 2>/dev/null
sudo pkill hostapd 2>/dev/null
sleep 1
sudo ip link set $IFACE down
sleep 1
sudo ip link set $IFACE up
sleep 1

# Lancer AP
sudo hostapd /tmp/hostapd_mcdo.conf &
sleep 2

# DHCP
sudo ip addr add $AP_IP/24 dev $IFACE 2>/dev/null
sudo dnsmasq --interface=$IFACE \
    --bind-interfaces \
    --dhcp-range=192.168.50.10,192.168.50.50,255.255.255.0,1h \
    --dhcp-option=3,$AP_IP \
    --no-resolv &

echo -e "${GREEN}[+] $SSID actif sur canal $CHANNEL${NC}"
echo -e "${GREEN}[+] Réseau ouvert (WPA=0) — comme un vrai réseau public${NC}"
echo -e "${GREEN}[+] Gateway : $AP_IP${NC}"
