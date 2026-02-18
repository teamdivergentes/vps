# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ansible IaC project managing complete VPS infrastructure for TeamDivergentes (teamdivergentes.fr). Deploys 10 roles (common, docker, traefik, postgresql, website, odoo, teamspeak, discord-bot, portainer, pgadmin) to a single VPS host via Docker Compose stacks behind a Traefik reverse proxy.

## Key Commands

```bash
# Install Ansible Galaxy dependencies
ansible-galaxy install -r requirements.yml

# Lint
ansible-lint site.yml

# First-time bootstrap (fresh VPS, as root with password)
# IMPORTANT: use bootstrap_user/bootstrap_port (NOT ansible_user/ansible_port)
ansible-playbook bootstrap.yml --ask-vault-pass -e "bootstrap_user=root" -e "bootstrap_port=22" --ask-pass

# Full deployment
ansible-playbook site.yml --ask-vault-pass

# Deploy a single service by tag
ansible-playbook site.yml --ask-vault-pass --tags website
# Available tags: common, docker, traefik, postgresql, website, odoo, teamspeak, discord, portainer, pgadmin
```

## Architecture

### Deployment Strategy — Pull Pre-Built Images

All application Docker images are built by their respective CI pipelines and pushed to **GitHub Container Registry (GHCR)**. Ansible **pulls** these pre-built images — it never clones source code or builds images on the VPS.

| Service | Image Source | Tags |
|---------|-------------|------|
| Website Backend | `ghcr.io/teamdivergentes/website_backend/dvg_web_backend` | `PREPROD`, `RELEASE` |
| Website Frontend | `ghcr.io/teamdivergentes/website_frontend/dvg_web_frontend` | `PREPROD`, `RELEASE` |
| Discord Bot | `ghcr.io/teamdivergentes/discord-js-dvg` | `PREPROD`, `RELEASE` |
| Odoo | `tellebma/isii_app` (Docker Hub) | `odoo-19-arm-latest` |

The docker role handles GHCR authentication using `vault_ghcr_user` and `vault_ghcr_token`.

### Playbook Flow

- **bootstrap.yml** — Two-phase playbook run once on a fresh VPS:
  - **Phase 1 (root):** Updates system, creates `deploy` user with SSH keys, configures UFW/fail2ban, deploys hardened sshd_config, restarts SSH asynchronously. The root connection drops at this point (expected).
  - **Phase 2 (deploy):** Reconnects as `deploy` user (key-based auth), verifies connectivity.
  - After bootstrap: root login disabled, password auth disabled, key-only for `deploy` user.
- **site.yml** — Main playbook run as `deploy` user (sudo). Orchestrates all 10 roles in dependency order with tag-based selective deployment.

### Two-PostgreSQL Strategy

- **Shared PG 17** (`roles/postgresql/`): serves website (prod + preprod) and discord-bot. Users/databases isolated via SQL grants in `init-databases.sql.j2`.
- **Dedicated PG 16** (inside `roles/odoo/`): Odoo requires CREATEDB privileges and custom schema management, so it gets its own instance on an isolated `odoo-internal` Docker network.

### Networking

All public services connect to a shared `traefik-public` Docker network (created by the docker role). Traefik auto-discovers services via Docker labels. Database containers are never exposed to the host — only reachable within Docker networks.

### Variable & Secrets Organization

- `inventory/group_vars/all/main.yml` — All non-secret configuration (domains, GHCR image references, image tags, DB names, user names).
- `inventory/group_vars/all/vault.yml` — Ansible Vault-encrypted secrets (IP, SSH port, passwords, tokens, GHCR credentials). Template at `vault.yml.example`.
- Vault variables are prefixed `vault_*` and referenced from `main.yml`.

### Role Conventions

Each role follows: `tasks/main.yml`, optional `templates/`, optional `handlers/main.yml`. All Jinja2 templates start with `{{ ansible_managed }}`. Docker Compose stacks deploy to `/opt/apps/{service}/` on the VPS. Services use Traefik labels for routing with `security-headers@file` and `rate-limit@file` middleware.

### Website Role

Pulls pre-built backend and frontend images from GHCR, then deploys separate preprod and prod stacks. The same `docker-compose-website.yml.j2` template is reused for both environments with different variables (image tags, domains, DB credentials). Routes `/api/*` to NestJS backend, `/` to Angular frontend.

## CI/CD

GitHub Actions (`.github/workflows/deploy.yml`): lint job runs `ansible-lint`, then deploy job SSHs to VPS and runs `ansible-playbook`. Triggered on push to `main` or manual dispatch with optional tags. Required secrets: `SSH_PRIVATE_KEY`, `SSH_PORT`, `VPS_IP`, `ANSIBLE_VAULT_PASSWORD`.

### Cross-Repo Deployment Trigger

Application CIs (backend, frontend, discord-bot) trigger this workflow via `workflow_dispatch` after pushing Docker images to GHCR. Each app CI passes the appropriate Ansible tag:
- Backend/Frontend CI → `--tags website`
- Discord Bot CI → `--tags discord`

The app repos use `DEPLOY_REPO` and `DEPLOY_TOKEN` (PAT with `actions:write`) secrets to trigger the dispatch.

## Dependencies

Galaxy collections (in `requirements.yml`): `community.docker`, `community.general`, `ansible.posix`.
