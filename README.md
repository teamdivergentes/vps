# VPS Infrastructure - TeamDivergentes

Infrastructure as Code pour le VPS TeamDivergentes, deployee via Ansible. 100% idempotent.

## Architecture

```
teamdivergentes.fr           -> Website (prod)     - Frontend Angular + Backend NestJS
www.teamdivergentes.fr       -> Website (prod)
preprod.teamdivergentes.fr   -> Website (preprod)  - Meme stack, branche feat/backend
odoo.teamdivergentes.fr      -> Odoo 19 ERP
ts3.teamdivergentes.fr       -> TeamSpeak 3        - Ports UDP 9987, TCP 30033, 10011
portainer.teamdivergentes.fr -> Portainer           - Docker UI
pgadmin.teamdivergentes.fr   -> pgAdmin             - PostgreSQL UI
```

```
                        ┌──────────────────────────┐
                        │      Traefik v3.1        │
                        │  (Reverse Proxy + SSL)   │
                        └─────┬──────┬──────┬──────┘
                              │      │      │
          ┌───────────────────┼──────┼──────┼───────────────┐
          │                   │      │      │               │
    ┌─────▼─────┐  ┌─────────▼──┐  ┌▼──────▼──┐  ┌────────▼────┐
    │  Website  │  │  Website   │  │   Odoo   │  │  Portainer  │
    │   Prod    │  │  Preprod   │  │    19    │  │  + pgAdmin  │
    ├───────────┤  ├────────────┤  ├──────────┤  └─────────────┘
    │ Frontend  │  │ Frontend   │  │ Odoo Web │
    │ Backend   │  │ Backend    │  │          │     ┌───────────┐
    └─────┬─────┘  └─────┬──────┘  └────┬─────┘     │ TeamSpeak │
          │              │              │           │  (direct) │
    ┌─────▼──────────────▼───┐    ┌─────▼─────┐     └───────────┘
    │   PostgreSQL 17        │    │  PG 16    │
    │  (shared: prod,        │    │ (dedié    │     ┌───────────┐
    │   preprod, discord)    │    │  Odoo)    │     │Discord Bot│
    └────────────────────────┘    └───────────┘     │ (interne) │
                                                    └───────────┘
```

### Strategie base de donnees

| Instance | Version | Databases | Justification |
|----------|---------|-----------|---------------|
| **Shared PG** | PostgreSQL 17 | dvg_prod, dvg_preprod, discord_bot | Economie RAM, isolation par users/grants |
| **Odoo PG** | PostgreSQL 16 | odoo19 | Odoo gere ses propres schemas, besoin CREATEDB |

## Prerequis

- Python 3.8+
- Ansible 2.15+
- Acces SSH au VPS

## Installation rapide

```bash
# 1. Installer les dependances Ansible
ansible-galaxy install -r requirements.yml

# 2. Copier et remplir le vault
cp inventory/group_vars/vault.yml.example inventory/group_vars/vault.yml
vim inventory/group_vars/vault.yml

# 3. Chiffrer le vault
ansible-vault encrypt inventory/group_vars/vault.yml

# 4. Deployer toute l'infra
ansible-playbook site.yml --ask-vault-pass
```

## Deploiement selectif (tags)

```bash
# Securite et mise a jour systeme
ansible-playbook site.yml --ask-vault-pass --tags common

# Docker uniquement
ansible-playbook site.yml --ask-vault-pass --tags docker

# Base de donnees partagee
ansible-playbook site.yml --ask-vault-pass --tags postgresql

# Site web (preprod + prod)
ansible-playbook site.yml --ask-vault-pass --tags website

# Odoo uniquement
ansible-playbook site.yml --ask-vault-pass --tags odoo

# TeamSpeak uniquement
ansible-playbook site.yml --ask-vault-pass --tags teamspeak

# Discord bot uniquement
ansible-playbook site.yml --ask-vault-pass --tags discord

# Portainer uniquement
ansible-playbook site.yml --ask-vault-pass --tags portainer

# pgAdmin uniquement
ansible-playbook site.yml --ask-vault-pass --tags pgadmin
```

## CI/CD (GitHub Actions)

Le pipeline se declenche automatiquement sur push vers `main`, ou manuellement via `workflow_dispatch` avec choix des tags.

### Secrets GitHub requis

| Secret | Description |
|--------|-------------|
| `SSH_PRIVATE_KEY` | Cle SSH privee (ed25519) |
| `SSH_PORT` | Port SSH du VPS |
| `VPS_IP` | Adresse IP du VPS |
| `ANSIBLE_VAULT_PASSWORD` | Mot de passe du vault Ansible |

## Securite

- **SSH** : cle ED25519 uniquement, root desactive, port 2222, MaxAuthTries 3
- **Firewall UFW** : deny par defaut, seuls HTTP/HTTPS/TS3/SSH ouverts
- **Fail2ban** : ban 2h apres 3 tentatives
- **Traefik** : TLS 1.2+, HSTS, XSS protection, rate limiting
- **Docker** : `no-new-privileges`, reseaux internes isoles
- **BDD** : PostgreSQL jamais expose, isolation par users/grants
- **Mises a jour automatiques** : unattended-upgrades active
- **Kernel** : sysctl hardening (rp_filter, syncookies, no redirects)

## Structure

```
.
├── ansible.cfg                        # Configuration Ansible
├── site.yml                           # Playbook principal
├── requirements.yml                   # Dependances Galaxy
├── inventory/
│   ├── hosts.yml                      # Inventaire
│   └── group_vars/
│       ├── all.yml                    # Variables globales
│       └── vault.yml.example          # Template des secrets
├── roles/
│   ├── common/                        # Securite, SSH, firewall, updates
│   ├── docker/                        # Docker CE + Compose
│   ├── traefik/                       # Reverse proxy + SSL auto
│   ├── postgresql/                    # PG 17 partage (website + discord)
│   ├── website/                       # Site web (preprod + prod)
│   ├── odoo/                          # Odoo 19 + PG 16 dedie
│   ├── teamspeak/                     # TeamSpeak 3
│   ├── discord-bot/                   # Bot Discord.js
│   ├── portainer/                     # Docker UI
│   └── pgadmin/                       # PostgreSQL UI
└── .github/
    └── workflows/
        └── deploy.yml                 # CI/CD pipeline
```
