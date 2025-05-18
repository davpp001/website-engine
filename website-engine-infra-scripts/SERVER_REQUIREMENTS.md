# Server-Voraussetzungen

Diese Anwendung wurde für **Ubuntu 22.04 LTS** getestet. Die folgenden Komponenten sind erforderlich, damit alle Skripte und Automatisierungen reibungslos funktionieren.

---

## 1. Grundlegende Pakete

```bash
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y \
  git \
  curl \
  jq \
  unzip \
  zip \
  nano \
  apache2 \
  mysql-server \
  php \
  php-cli \
  php-mysql \
  php-curl \
  php-xml \
  php-mbstring \
  php-zip \
  php-gd \
  php-intl \
  libapache2-mod-php \
  software-properties-common \
  bash-completion \
  shellcheck
```

---

## 2. WP-CLI (WordPress Command Line Interface)

```bash
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp
```

---

## 3. Apache Setup

```bash
# Apache aktivieren und starten
sudo systemctl enable apache2
sudo systemctl start apache2

# mod_rewrite aktivieren
sudo a2enmod rewrite
sudo systemctl reload apache2
```

---

## 4. SSL mit Certbot (optional für Wildcard-SSL)

```bash
sudo apt install -y certbot python3-certbot-apache
# Wildcard-SSL via Cloudflare DNS-Challenge (optional, erfordert DNS-API-Key)
sudo apt install -y python3-certbot-dns-cloudflare
```

---

## 5. GitHub Deployment Support

Für automatische Pulls via GitHub Actions:

```bash
# SSH-Key auf dem Server ablegen (z. B. /etc/ssh/deploy_key) und Berechtigungen setzen
sudo chmod 600 /etc/ssh/deploy_key
sudo chown root:root /etc/ssh/deploy_key
```

Falls du den Key global aktivieren willst:

```bash
sudo tee /etc/ssh/ssh_config.d/10-github.conf > /dev/null << EOF
Host github.com
  IdentityFile /etc/ssh/deploy_key
  IdentitiesOnly yes
EOF
```

---

## 6. Cloudflare DNS API Zugriff

Lege diese Datei an:

```bash
sudo nano /etc/profile.d/cloudflare.sh
```

Inhalt:

```bash
export CF_API_TOKEN="dein-token"
export ZONE_ID="deine-zone-id"
```

Aktivieren:

```bash
source /etc/profile.d/cloudflare.sh
```

---

## 7. Benutzer & Berechtigungen

* Empfohlen wird ein nicht-root Benutzer (z. B. `serveradmin`) mit `sudo`-Rechten
* Verzeichnisstruktur:

  * Skripte unter `/opt/infra-scripts/`
  * WordPress-Instanzen unter `/var/www/<subdomain>/`

---

## 8. Sicherheit & SSH

* Root-SSH kann deaktiviert werden (`/etc/ssh/sshd_config`)
* Ein separater Benutzer (z. B. `serveradmin`) kann im Notfall SSH-Keys wiederherstellen
