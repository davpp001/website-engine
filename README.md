# Website Engine

This repository contains the merged components of two previously separate repositories:

1. **infra-scripts** (previously `website-engine-infra-scripts`): Shell scripts and configuration tools for automated WordPress instance provisioning.
2. **infra-playbooks**: Ansible playbooks for server configuration and backups.

## Directory Structure

```
website-engine/
├── infra-scripts/          # Shell scripts for WordPress and DNS provisioning
│   ├── bin/                # Command symlinks
│   ├── cloudflare/         # Cloudflare DNS API scripts
│   └── wordpress/          # WordPress installation scripts
├── infra-playbooks/        # Ansible playbooks for server configuration
│   ├── roles/              # Ansible roles
│   ├── inventory.yml       # Server inventory
│   └── site.yml            # Main playbook
├── server-setup.sh         # Script to set up a new server
└── setup-symlinks.sh       # Script to create command symlinks
```

## Setup Instructions

### Setting Up a New Server

1. Clone this repository on your local machine:
   ```bash
   git clone https://github.com/YOUR_USERNAME/website-engine.git
   ```

2. Connect to your server:
   ```bash
   ssh -i ~/.ssh/id_rsa_ionos_cloud root@YOUR_SERVER_IP
   ```

3. Run the server setup script:
   ```bash
   # Upload the script to your server
   scp -i ~/.ssh/id_rsa_ionos_cloud server-setup.sh root@YOUR_SERVER_IP:/root/
   
   # On the server
   chmod +x /root/server-setup.sh
   /root/server-setup.sh
   ```

4. Follow the prompts to complete the setup.

### Command Line Tools

After setup, the following commands will be available:

- `create_cf_sub_auto <subdomain>` - Create a new subdomain
- `delete_cf_sub <subdomain>` - Delete a subdomain
- `install_wp <subdomain>` - Install WordPress on a subdomain
- `uninstall_wp <subdomain>` - Remove a WordPress installation
- `setup_wp <subdomain>` - Set up a WordPress site with DNS
- `cleanup_wp <subdomain>` - Clean up a WordPress installation
- `pullinfra` - Update both repositories from Git

### Configuration Files

Important configuration files:

- `/etc/profile.d/cloudflare.sh` - Cloudflare API credentials
- `/etc/setup_wp.env` - Environment variables for the setup script
- `/etc/restic.env` - Restic backup configuration

## Backup System

This system includes a comprehensive backup solution:

1. **MySQL Backups**: Daily at 03:00, kept for 14 days
2. **IONOS Volume Snapshots**: Daily at 01:00
3. **Restic Backups to S3**: Daily at 02:30, 14 daily + 4 weekly retention

## More Information

For detailed information, see:
- [infra-scripts README](./infra-scripts/README.md)
- [infra-playbooks README](./infra-playbooks/README.md)

## Updating

To update your local copy:

```bash
git pull
```

On the server, run:

```bash
pullinfra
```