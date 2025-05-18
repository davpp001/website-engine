# Infrastructure & Backup Overview

Dieses Repo enthält Ansible-Playbooks zur automatisierten Einrichtung und zum Backup einer IONOS-Server-Umgebung:

- **Phase 1**: Apache & UFW (SSH, HTTP, HTTPS)
- **Phase 2**: MySQL-Dumps → /var/backups/mysql (täglich 03:00, 14 Tage)
- **Phase 3**: IONOS-Volume-Snapshots (täglich 01:00)
- **Phase 4**: Restic-Backups → S3 (täglich 02:30, 14 daily / 4 weekly)

**Voraussetzungen**  
- Ansible & Git  
- SSH-Deploy-Key  
- Ansible-Vault für Secrets  

**Wichtige Dateien**  
- `inventory.yml`  
- `site.yml`  
- `group_vars/all/vault.yml` (verschlüsselt)  
- `docs/backup.md` (Detail-Dokumentation)  

**Restore-Schritte**  
- MySQL: `gunzip -c backup-YYYY-MM-DD.sql.gz | mysql -u root -p`  
- Restic: `restic restore latest --target /pfad`  
- Snapshots: IONOS-Portal / API  

----

# Infra-Playbooks für s-neue.website

## 1. Deployment

1. Vault-Pass eingeben und Playbook ausführen:  
   cd /opt/infra-playbooks  
   git pull --ff-only origin main  
   ansible-playbook -i inventory.yml site.yml --ask-vault-pass

2. Webhook-Token anpassen:  
   In group_vars/all.yml (oder in Eurer Vault-Datei) den Wert webhook_token setzen.

3. DNS-Record sicherstellen:  
   Jede Subdomain wird automatisch via Cloudflare angelegt. Vorher muss ein A-Record für s-neue.website existieren.

## 2. Webhook-Setup & Test

- Trigger-URL: https://s-neue.website/api/trigger-setup.php
- Headers:
  - Content-Type: application/json
  - X-Webhook-Token: <Euer-Token>
- Beispiel:  
  curl -i \
    --resolve s-neue.website:443:$(curl -s https://ifconfig.co) \
    -X POST https://s-neue.website/api/trigger-setup.php \
    -H "Content-Type: application/json" \
    -H "X-Webhook-Token: mein-geheimes-webhook-token-123" \
    -d '{"subdomain":"testkunde123"}'

Erwartete Antwort:  
HTTP/1.1 202 Accepted  
Triggered: testkunde123