# Server-Migration: Website Engine

Diese Anleitung beschreibt die Schritte, um die Website Engine auf einen neuen Server zu übertragen.

## Vorbereitung

1. **Zugangsdaten für den neuen Server bereithalten**
   - SSH-Zugangsdaten
   - Root-Zugang oder sudo-Berechtigungen
   - Cloudflare API-Token und Zone-ID

2. **Voraussetzungen auf dem neuen Server sicherstellen**
   - Ubuntu 22.04 LTS (empfohlen)
   - Öffentliche IP-Adresse

## Schritt 1: Grundlegende Systemkonfiguration

```bash
# Mit dem neuen Server verbinden
ssh -i ~/.ssh/id_rsa_ionos_cloud root@NEUE_SERVER_IP

# Paketquellen aktualisieren und System updaten
apt update && apt upgrade -y

# Grundlegende Pakete installieren
apt install -y git curl jq unzip zip nano apache2 mysql-server php php-cli php-mysql \
  php-curl php-xml php-mbstring php-zip php-gd php-intl libapache2-mod-php \
  software-properties-common bash-completion shellcheck python3-pip certbot python3-certbot-apache python3-certbot-dns-cloudflare
```

## Schritt 2: Repository klonen und Verzeichnisstruktur anlegen

```bash
# Verzeichnisstruktur anlegen
mkdir -p /opt/infra-scripts /opt/infra-playbooks

# Git-Repository klonen (ersetze "USERNAME" durch deinen GitHub-Benutzernamen)
cd /opt
git clone https://github.com/USERNAME/website-engine.git temp-repo

# Dateien in die richtige Struktur kopieren
cp -r temp-repo/infra-scripts/* /opt/infra-scripts/
cp -r temp-repo/infra-playbooks/* /opt/infra-playbooks/
rm -rf temp-repo
```

## Schritt 3: Benutzerrechte und Symlinks einrichten

```bash
# Apache-Module aktivieren
a2enmod rewrite ssl headers

# MySQL starten und sichern
systemctl enable mysql
systemctl start mysql
mysql_secure_installation

# WordPress-User in MySQL anlegen
mysql -u root -p -e "CREATE USER 'wordpressuser'@'localhost' IDENTIFIED BY 'password';"
mysql -u root -p -e "GRANT ALL PRIVILEGES ON *.* TO 'wordpressuser'@'localhost';"
mysql -u root -p -e "FLUSH PRIVILEGES;"

# WP-CLI installieren
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# Symlinks für die Befehle erstellen
ln -sf /opt/infra-scripts/wordpress/setup_wp.sh /usr/local/bin/setup_wp
ln -sf /opt/infra-scripts/wordpress/cleanup_wp.sh /usr/local/bin/cleanup_wp
ln -sf /opt/infra-scripts/wordpress/install_wp.sh /usr/local/bin/install_wp
ln -sf /opt/infra-scripts/wordpress/uninstall_wp.sh /usr/local/bin/uninstall_wp
ln -sf /opt/infra-scripts/cloudflare/create_cf_sub_auto.sh /usr/local/bin/create_cf_sub_auto
ln -sf /opt/infra-scripts/cloudflare/delete_cf_sub.sh /usr/local/bin/delete_cf_sub
ln -sf /opt/infra-scripts/fix-wp-permissions.sh /usr/local/bin/fix-wp-permissions

# pullinfra-Befehl erstellen
cat > /usr/local/bin/pullinfra << 'EOF'
#!/bin/bash
cd /opt/infra-scripts && git pull origin main
cd /opt/infra-playbooks && git pull origin main
EOF
chmod +x /usr/local/bin/pullinfra
```

## Schritt 4: Cloudflare-Konfiguration

```bash
# Cloudflare-Konfiguration erstellen
cat > /etc/profile.d/cloudflare.sh << 'EOF'
export CF_API_TOKEN="lLrGrv3Q8hmj-Db4ncotnGqbaE0IFX9oKvD8yxQV"
export ZONE_ID="d7e5b4cfe310063ede065b1ba06bcdf7"
export DOMAIN="s-neue.website"
EOF
chmod +x /etc/profile.d/cloudflare.sh
source /etc/profile.d/cloudflare.sh

# Verzeichnis für Cloudflare-Credentials für Certbot anlegen
mkdir -p /etc/letsencrypt/cloudflare
cat > /etc/letsencrypt/cloudflare/credentials.ini << 'EOF'
# Cloudflare API credentials used by Certbot
dns_cloudflare_api_token = lLrGrv3Q8hmj-Db4ncotnGqbaE0IFX9oKvD8yxQV
EOF
chmod 600 /etc/letsencrypt/cloudflare/credentials.ini
```

## Schritt 5: SSL-Konfiguration mit Wildcard-Zertifikat (optional)

```bash
# Wildcard-Zertifikat erstellen
certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /etc/letsencrypt/cloudflare/credentials.ini \
  --non-interactive \
  --agree-tos \
  --email admin@online-aesthetik.de \
  -d "*.s-neue.website" \
  -d "s-neue.website"
```

## Schritt 6: Test-Installation durchführen

```bash
# Test-Installation durchführen
setup_wp test

# Berechtigungen optimieren
fix-wp-permissions test
```

## Schritt 7: Daten migrieren (falls notwendig)

Um Daten vom alten Server zu migrieren:

### WordPress-Seiten migrieren

Für jede WordPress-Seite, die du migrieren möchtest:

1. **Datenbank auf dem alten Server exportieren**
   ```bash
   # Auf dem alten Server
   mysqldump -u root -p SUBDOMAIN > SUBDOMAIN_db.sql
   ```

2. **Dateien auf dem alten Server archivieren**
   ```bash
   # Auf dem alten Server
   cd /var/www
   tar -czf SUBDOMAIN_files.tar.gz SUBDOMAIN
   ```

3. **Dateien zum neuen Server übertragen**
   ```bash
   # Auf deinem lokalen Computer
   scp -i ~/.ssh/id_rsa_ionos_cloud root@ALTE_SERVER_IP:/path/to/SUBDOMAIN_* .
   scp -i ~/.ssh/id_rsa_ionos_cloud SUBDOMAIN_* root@NEUE_SERVER_IP:/tmp/
   ```

4. **WordPress auf dem neuen Server installieren**
   ```bash
   # Auf dem neuen Server
   setup_wp SUBDOMAIN
   ```

5. **Daten auf dem neuen Server importieren**
   ```bash
   # Auf dem neuen Server
   mysql -u root -p SUBDOMAIN < /tmp/SUBDOMAIN_db.sql
   rm -rf /var/www/SUBDOMAIN/*
   tar -xzf /tmp/SUBDOMAIN_files.tar.gz -C /var/www/
   fix-wp-permissions SUBDOMAIN
   ```

## Fehlerbehebung

Falls Probleme auftreten:

1. **Apache-Fehler**: `/var/log/apache2/error.log` prüfen
2. **DNS-Probleme**: `dig @1.1.1.1 subdomain.s-neue.website` zur Überprüfung verwenden
3. **MySQL-Probleme**: `mysql -u root -p -e "SHOW DATABASES;"` zur Überprüfung
4. **Berechtigungsprobleme**: Nutze `fix-wp-permissions subdomain` für die betroffene Subdomain

## Automatisierter Deployment-Prozess (optional)

Für größere Deployments kannst du ein Skript erstellen:

```bash
cat > /opt/server-setup.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Server Setup Script
# Führt alle notwendigen Schritte für die Website Engine aus

# 1. Pakete installieren
apt update && apt upgrade -y
apt install -y git curl jq unzip zip nano apache2 mysql-server php php-cli php-mysql \
  php-curl php-xml php-mbstring php-zip php-gd php-intl libapache2-mod-php \
  software-properties-common bash-completion shellcheck python3-pip certbot python3-certbot-apache python3-certbot-dns-cloudflare

# ... Restliche Installationsschritte hier ...

echo "✅ Server-Setup abgeschlossen!"
EOF
chmod +x /opt/server-setup.sh
```

## Nach der Migration

- DNS-Einträge aktualisieren, um auf den neuen Server zu zeigen
- SSL-Zertifikate auf funktionierende Erneuerung prüfen
- Backup-Strategie einrichten
- Monitoring-Lösung implementieren