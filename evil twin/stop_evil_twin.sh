#!/bin/bash
echo "========================================="
echo "   ARRÊT EVIL TWIN - Mcdo Free Wifi"
echo "========================================="

echo "[*] Arrêt de hostapd..."
sudo killall hostapd 2>/dev/null

echo "[*] Arrêt de dnsmasq..."
sudo killall dnsmasq 2>/dev/null

echo "[*] Arrêt du portail captif..."
sudo killall python3 2>/dev/null

echo "[*] Nettoyage des règles iptables..."
sudo iptables --flush
sudo iptables --table nat --flush

echo "[*] Désactivation de wlan1..."
sudo ip addr flush dev wlan1
sudo ip link set wlan1 down

echo "[*] Redémarrage de NetworkManager..."
sudo systemctl restart NetworkManager

echo ""
echo "========================================="
echo "[+] EVIL TWIN ÉTEINT"
echo "    NetworkManager redémarré"
echo "    Réseau normal restauré"
echo "========================================="
