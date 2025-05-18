# infra-scripts – Kommandos

Diese Datei enthält alle wichtigen Shell-Befehle zur Verwaltung des Systems (Subdomain-Erstellung, WordPress-Provisionierung, Git-Synchronisierung etc.).

Pfad zum Repo: `/opt/infra-scripts`

---

## 1. GitHub-Synchronisation

```bash
# Repository aktualisieren (Code vom GitHub-Main-Branch holen)
pullinfra

# Änderungen lokal committen und pushen
git add . && git commit -m "Kommentar" && git push origin main
```

---

## 2. Subdomain-Management (Cloudflare)

```bash
# Neue Subdomain anlegen (inkl. Kollisionserkennung: -2, -3, ...)
create_cf_sub_auto <subdomain-name>

# Subdomain löschen (alle A-Records entfernen)
delete_cf_sub <subdomain-name>
```

---

## 3. WordPress-Installation

```bash
# WordPress auf der Subdomain installieren (mit vordefinierter Konfiguration)
install_wp <subdomain-name>

# Beispiel:
install_wp kunde5

# Zugangsdaten (werden automatisch verwendet):
# Benutzername: we-admin
# Passwort:     We-25-$$-Vo
# E-Mail:       admin@online-aesthetik.de
```

---

## 4. Apache / SSL

```bash
# Apache-Konfiguration prüfen
sudo apache2ctl configtest

# Apache neuladen (z. B. nach VHost-Änderung)
sudo systemctl reload apache2

# Problematische SSL-Site deaktivieren (z. B. wegen fehlender Zertifikate)
sudo a2dissite <site>-le-ssl.conf
```

---

## 5. DNS-Prüfung

```bash
# A-Record überprüfen (zeigt die Subdomain auf die richtige IP?)
dig <subdomain>.<domain> +short
```

---

## 6. SSH-Zugänge

```bash
# Mit Server verbinden (per SSH)
ssh serveradmin@<IP>
ssh root@<IP> -i ~/.ssh/id_rsa_ionos_cloud
```

---

## 7. SSH-Key Recovery (optional)

```bash
# SSH-Key für root wiederherstellen (vom serveradmin aus)
sudo mkdir -p /root/.ssh
echo '<PUBLIC-KEY>' | sudo tee -a /root/.ssh/authorized_keys
sudo chmod 700 /root/.ssh
sudo chmod 600 /root/.ssh/authorized_keys
```

---

Letzte Aktualisierung: Mai 2025
