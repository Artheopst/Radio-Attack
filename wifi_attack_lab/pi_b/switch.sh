#!/bin/bash
# ===========================================
# WIFI LAB SWITCH — Pi B
# Usage: ./switch.sh {wep|wpa1|wpa2|pmf1|pmf2|wpa3|stop}
# ===========================================

IFACE=wlan0
CONFDIR=~/wifi_lab/configs

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

stop_all() {
    echo -e "${YELLOW}[*] Arrêt des services...${NC}"
    sudo systemctl stop NetworkManager 2>/dev/null
    sudo pkill -9 wpa_supplicant 2>/dev/null
    sudo pkill hostapd 2>/dev/null
    sudo pkill dnsmasq 2>/dev/null
    sleep 2
    echo -e "${GREEN}[+] Services arrêtés${NC}"
}

start_ap() {
    local CONF=$1
    local DESC=$2
    stop_all
    echo -e "${CYAN}[*] Démarrage : $DESC${NC}"
    sudo pkill wpa_supplicant 2>/dev/null
    sudo wpa_cli -i wlan0 disconnect 2>/dev/null
    sudo wpa_cli -i wlan0 terminate 2>/dev/null
    sleep 1
    sudo ip link set wlan0 down
    sleep 2
    sudo ip link set wlan0 up
    sleep 2
    sudo hostapd $CONF &
    sleep 2
    sudo ip addr add 192.168.50.1/24 dev wlan0 2>/dev/null
    sudo dnsmasq --interface=wlan0 \
      --bind-interfaces \
      --dhcp-range=192.168.50.10,192.168.50.50,255.255.255.0,1h \
      --dhcp-option=3,192.168.50.1 \
      --no-resolv &
    echo -e "${GREEN}[+] DHCP actif : 192.168.50.10-50${NC}"
    if pgrep hostapd > /dev/null; then
        echo -e "${GREEN}[+] AP actif : $DESC${NC}"
        echo -e "${GREEN}[+] Config  : $CONF${NC}"
        sudo iw dev wlan0 info | grep -E "ssid|type"
    else
        echo -e "${RED}[-] Échec hostapd — vérifier avec: sudo hostapd $CONF${NC}"
    fi
}

case "$1" in
    wep)
        start_ap "$CONFDIR/hostapd_wep.conf" "WEP — clé: AABBCCDDEE"
        echo -e "${RED}[!] VULNÉRABLE : crack en ~3 min avec aircrack-ng${NC}"
        ;;
    wpa1)
        start_ap "$CONFDIR/hostapd_wpa1.conf" "WPA1-TKIP — pass: password123"
        echo -e "${RED}[!] VULNÉRABLE : handshake + dico / TKIP MIC exploit${NC}"
        ;;
    wpa2)
        start_ap "$CONFDIR/hostapd_wpa2.conf" "WPA2-PSK sans PMF — pass: password123"
        echo -e "${RED}[!] VULNÉRABLE : deauth + handshake + dico${NC}"
        ;;
    pmf1)
        start_ap "$CONFDIR/hostapd_wpa2_pmf1.conf" "WPA2 + PMF optionnel — pass: password123"
        echo -e "${YELLOW}[~] PARTIELLEMENT PROTÉGÉ : deauth parfois bloqué${NC}"
        ;;
    pmf2)
        start_ap "$CONFDIR/hostapd_wpa2_pmf2.conf" "WPA2 + PMF obligatoire — pass: password123"
        echo -e "${GREEN}[+] PROTÉGÉ : deauth ignoré — crack dico toujours possible${NC}"
        ;;
    wpa3)
        start_ap "$CONFDIR/hostapd_wpa3.conf" "WPA3-SAE — pass: password123"
        echo -e "${GREEN}[+] PROTÉGÉ : PMF obligatoire + Forward Secrecy + anti-dico${NC}"
        ;;
    stop)
        stop_all
        ;;
    *)
        echo ""
        echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║        WIFI ATTACK LAB — Pi B            ║${NC}"
        echo -e "${CYAN}╠══════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║  ./switch.sh wep     → WEP (1997)        ║${NC}"
        echo -e "${CYAN}║  ./switch.sh wpa1    → WPA1-TKIP (2003)  ║${NC}"
        echo -e "${CYAN}║  ./switch.sh wpa2    → WPA2 sans PMF     ║${NC}"
        echo -e "${CYAN}║  ./switch.sh pmf1    → WPA2 + PMF opt    ║${NC}"
        echo -e "${CYAN}║  ./switch.sh pmf2    → WPA2 + PMF oblig  ║${NC}"
        echo -e "${CYAN}║  ./switch.sh wpa3    → WPA3-SAE (2018)   ║${NC}"
        echo -e "${CYAN}║  ./switch.sh stop    → Tout arrêter      ║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
        ;;
esac
