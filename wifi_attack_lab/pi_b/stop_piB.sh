#!/bin/bash
echo "[*] Arrêt du réseau légitime Pi B..."
sudo pkill hostapd
sudo pkill dnsmasq
sudo nmcli dev set wlan0 managed yes
echo "[+] Réseau éteint"
