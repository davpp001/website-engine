# infra-scripts

Dieses Repository enthält alle Shell-Skripte und Konfigurationshilfen zur automatisierten Bereitstellung von WordPress-Instanzen auf Subdomains – inklusive DNS-Einrichtung über Cloudflare, Wildcard-SSL-Zertifikat, Apache-Vhost und WordPress-Vorkonfiguration.

---

## ✅ Features

- 🔧 Automatisierte Subdomain-Erstellung mit Cloudflare API
- 🌐 Automatisierte DNS-Zuweisung der öffentlichen IP
- ⚙️ Vollständige WordPress-Installation pro Subdomain (inkl. Apache-VHost + DB)
- 🔐 SSL-Verschlüsselung über Wildcard-Zertifikat (`*.s-neue.website`)
- 🔄 Automatische Erneuerung des Zertifikats via Certbot (Cloudflare DNS)
- 🔁 GitHub-gesteuerter Update-Workflow über `pullinfra`

---

## 📁 Projektstruktur

```bash
infra-scripts/
├── bin/                      # Symlinks für Kommandos wie install_wp
├── cloudflare/               # DNS-Management via Cloudflare API
│   ├── create_cf_sub_auto.sh
│   └── delete_cf_sub.sh
├── wordpress/                # WordPress-Installationsskripte
│   └── install_wp.sh
├── README.md                 # Diese Datei
├── COMMANDS.md               # Nützliche Befehle
└── SERVER_REQUIREMENTS.md    # Anforderungen für den Server

---

⚙️ Voraussetzungen

→ Details siehe SERVER_REQUIREMENTS.md

Technikstack:
	•	Ubuntu 22.04 LTS
	•	Apache2 + PHP + MySQL/MariaDB
	•	Certbot + DNS-Plugin für Cloudflare
	•	WP-CLI
	•	Git + SSH-Deployment via GitHub

---

🚀 Schnellstart

# Auf dem Server einloggen
ssh serveradmin@217.160.252.118

# Skripte aus GitHub aktualisieren
pullinfra

# Subdomain automatisch erstellen
create_cf_sub_auto kunde5

# WordPress auf dieser Subdomain installieren
install_wp kunde5

# WordPress-Instanz entfernen
uninstall_wp kunde1

---

🔐 Zugangsdaten (Standard)
	•	Benutzername: we-admin
	•	Passwort: We-25-$$-Vo
	•	E-Mail: admin@online-aesthetik.de

---

🌐 Live-System

Die Subdomains werden nach Erstellung direkt unter
https://<subdomain>.s-neue.website erreichbar und verschlüsselt ausgeliefert.

---

ℹ️ Hinweise
	•	Bei Namenskollisionen wird automatisch -2, -3, … angehängt.
	•	Der Apache-Vhost wird automatisch aktiviert und mit SSL konfiguriert.
	•	Das System nutzt ein Wildcard-SSL-Zertifikat, welches regelmäßig durch Certbot automatisch erneuert wird.
	•	Änderungen an den Skripten erfolgen lokal und werden via GitHub auf den Server synchronisiert.

---

Letzte Aktualisierung: Mai 2025