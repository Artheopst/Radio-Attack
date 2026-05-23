#!/bin/bash
# stop_evil_twin_simple.sh
echo "[*] Arrêt Evil Twin Simple..."
sudo pkill hostapd
sudo pkill dnsmasq
sudo pkill python3
sudo iptables -t nat -F
sudo iptables -F
sudo nmcli dev set wlan1 managed yes 2>/dev/null || true
echo "[✓] Arrêt terminé."
