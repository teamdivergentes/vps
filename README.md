# VPS Infrastructure - TeamDivergentes

Infrastructure as Code pour le VPS TeamDivergentes, déployée via Ansible.

## Architecture

```
teamdivergentes.fr          -> Website (prod)
www.teamdivergentes.fr      -> Website (prod)
preprod.teamdivergentes.fr  -> Website (preprod)
odoo.teamdivergentes.fr     -> Odoo ERP
ts3.teamdivergentes.fr      -> TeamSpeak 3 (ports UDP 9987, TCP 30033, 10011)
portainer.teamdivergentes.fr -> Portainer (Docker UI)
```

```
┌─────────────────────────────────────────────────┐
│                   Traefik                        │
│            (Reverse Proxy + SSL)                 │
├────────┬────────┬────────┬────────┬─────────────┤
│Website │Website │  Odoo  │Portainer│            │
│ Prod   │Preprod │        │        │             │
├────────┼────────┼────────┼────────┤  TeamSpeak  │
│Frontend│Frontend│ Odoo   │Portainer│  (direct)  │
│Backend │Backend │ DB     │        │             │
│  DB    │  DB    │        │        │  Discord Bot│
└────────┴────────┴────────┴────────┴─────────────┘
```

## Prérequis

- Python 3.8+
- Ansible 2.15+
- Accès SSH au VPS

## Installation rapide

```bash
# 1. Installer les dépendances Ansible
ansible-galaxy install -r requirements.yml

# 2. Copier et remplir le vault
cp inventory/group_vars/vault.yml.example inventory/group_vars/vault.yml
vim inventory/group_vars/vault.yml

# 3. Chiffrer le vault
ansible-vault encrypt inventory/group_vars/vault.yml

# 4. Déployer
ansible-playbook site.yml --ask-vault-pass
```

## Déploiement sélectif (tags)

```bash
# Sécurité et mise à jour système uniquement
ansible-playbook site.yml --ask-vault-pass --tags common

# Docker uniquement
ansible-playbook site.yml --ask-vault-pass --tags docker

# Site web uniquement
ansible-playbook site.yml --ask-vault-pass --tags website

# Odoo uniquement
ansible-playbook site.yml --ask-vault-pass --tags odoo

# TeamSpeak uniquement
ansible-playbook site.yml --ask-vault-pass --tags teamspeak

# Discord bot uniquement
ansible-playbook site.yml --ask-vault-pass --tags discord

# Portainer uniquement
ansible-playbook site.yml --ask-vault-pass --tags portainer
```

## CI/CD (GitHub Actions)

Le pipeline se déclenche automatiquement sur push vers `main`, ou manuellement via `workflow_dispatch`.

### Secrets GitHub requis

| Secret                    | Description                          |
|--------------------------|--------------------------------------|
| `SSH_PRIVATE_KEY`        | Clé SSH privée (ed25519)            |
| `SSH_PORT`               | Port SSH du VPS                      |
| `VPS_IP`                 | Adresse IP du VPS                    |
| `ANSIBLE_VAULT_PASSWORD` | Mot de passe du vault Ansible        |

## Sécurité

- SSH : clé uniquement, root désactivé, port personnalisé
- Firewall UFW : seuls les ports nécessaires sont ouverts
- Fail2ban : protection contre le bruteforce
- Traefik : TLS 1.2+, headers de sécurité, rate limiting
- Docker : `no-new-privileges`, réseaux internes isolés
- Mises à jour automatiques via unattended-upgrades
- Les bases de données ne sont **jamais** exposées publiquement

## Structure

```
.
├── ansible.cfg                    # Configuration Ansible
├── site.yml                       # Playbook principal
├── requirements.yml               # Dépendances Galaxy
├── inventory/
│   ├── hosts.yml                  # Inventaire
│   └── group_vars/
│       ├── all.yml                # Variables globales
│       └── vault.yml.example      # Template des secrets
├── roles/
│   ├── common/                    # Sécurité, SSH, firewall, updates
│   ├── docker/                    # Docker CE + Compose
│   ├── traefik/                   # Reverse proxy + SSL
│   ├── website/                   # Site web (preprod + prod)
│   ├── odoo/                      # Odoo ERP
│   ├── teamspeak/                 # TeamSpeak 3
│   ├── discord-bot/               # Bot Discord
│   └── portainer/                 # Docker UI
└── .github/
    └── workflows/
        └── deploy.yml             # CI/CD pipeline
```
