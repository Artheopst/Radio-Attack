#!/bin/bash
echo "========================================="
echo "   LANCEMENT RESEAU LEGITIME - Pi B"
echo "      Mcdo Free Wifi (réseau innocent)"
echo "========================================="

IFACE="wlan0"
SSID="Mcdo Free Wifi"
IP="192.168.50.1"

# Créer le fichier de config hostapd
cat > /tmp/hostapd_mcdo.conf << EOF
interface=$IFACE
driver=nl80211
ssid=$SSID
hw_mode=g
channel=6
auth_algs=1
wpa=0
ignore_broadcast_ssid=0
ieee80211n=1
EOF

# Tuer les processus existants
sudo pkill hostapd 2>/dev/null
sudo pkill dnsmasq 2>/dev/null
sleep 1

# Prendre le contrôle de wlan0
sudo nmcli dev set $IFACE managed no
sudo ip addr flush dev $IFACE
sudo ip addr add $IP/24 dev $IFACE
sudo ip link set $IFACE up
sleep 1

# Lancer hostapd
sudo hostapd /tmp/hostapd_mcdo.conf &
sleep 2

# Vérifier que hostapd tourne
if ! pgrep -x hostapd > /dev/null; then
    echo "[-] Erreur : hostapd n'a pas démarré"
    exit 1
fi

# Lancer dnsmasq
sudo dnsmasq \
  --conf-file=/dev/null \
  --interface=$IFACE \
  --bind-interfaces \
  --dhcp-range=192.168.50.10,192.168.50.50,12h \
  --no-daemon &

sleep 1

echo ""
echo "========================================="
echo "[+] RÉSEAU LÉGITIME OPÉRATIONNEL"
echo "    SSID    : $SSID"
echo "    IP      : $IP"
echo "    Sécurité: Ouvert (comme un vrai Mcdo)"
echo "========================================="
echo ""
echo "Pour arrêter : sudo ./stop_mcdo_piB.sh"

wait
