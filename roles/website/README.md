# Role : website

Deploie les stacks Docker preprod et prod du site teamdivergentes.fr.

Les images sont pre-construites par les CI GitHub Actions (frontend, backend) et poussees sur GHCR. Ce role les pull puis les demarre via Docker Compose derriere Traefik.

## Environnements

| Environnement | Domaine | Tag image | Indexation |
|---------------|---------|-----------|-----------|
| Preprod | `preprod.teamdivergentes.fr` | `PREPROD` | non (`ROBOTS_ALLOW=false`) |
| Prod | `teamdivergentes.fr` + `www.` | `RELEASE` | oui (`ROBOTS_ALLOW=true`) |

## Variables d'environnement injectees dans le conteneur frontend

| Variable | Preprod | Prod | Obligatoire |
|----------|---------|------|-------------|
| `BACKEND_URL` | `http://website-preprod-backend:3000` | `http://website-prod-backend:3000` | oui |
| `SITE_URL` | `https://preprod.teamdivergentes.fr` | `https://teamdivergentes.fr` | **oui — SEO** |
| `ROBOTS_ALLOW` | `false` | `true` | oui |
| `GOOGLE_ANALYTICS_ID` | `G-1WVR4Z1VG1` | `G-73G860CZKB` | non |
| `MATOMO_URL` | `https://matomo.tellebma.fr/` | `https://matomo.tellebma.fr/` | non |
| `MATOMO_SITE_ID` | `5` | `6` | non |

### SITE_URL — detail SEO (EPIC-25)

`SITE_URL` est construite automatiquement dans `docker-compose-website.yml.j2` :

```yaml
- SITE_URL=https://{{ site_domain }}
```

`site_domain` recoit `preprod_domain` ou `prod_domain` selon l'environnement cible (voir `tasks/main.yml`, blocs `vars:`).

Le frontend lit cette valeur via `RuntimeConfigService` (expose par `/assets/config.json` genere par `entrypoint.sh` au demarrage du conteneur). Elle est consommee par `SeoService` pour resoudre :

- `<link rel="canonical">`
- `og:image` / `twitter:image`
- URLs JSON-LD (`mainEntityOfPage`, `image`)

**Ne jamais hardcoder** `https://teamdivergentes.fr` dans le code applicatif. Toujours passer par `RuntimeConfigService.siteUrl`.

## Variables Ansible requises

Toutes definies dans `inventory/group_vars/all/main.yml` :

- `preprod_domain` / `prod_domain` — domaines (source de `SITE_URL`)
- `preprod_google_analytics_id` / `prod_google_analytics_id`
- `preprod_matomo_site_id` / `prod_matomo_site_id`
- `matomo_url`
- `preprod_robots_allow` / `prod_robots_allow`

Secrets dans `vault.yml` :

- `vault_preprod_db_password` / `vault_prod_db_password`
- `vault_preprod_jwt_secret` / `vault_prod_jwt_secret`
- `vault_ghcr_user` / `vault_ghcr_token`

## Deploiement selectif

```bash
# Deployer uniquement le site (preprod + prod)
ansible-playbook site.yml --ask-vault-pass --tags website

# Deployer uniquement la preprod
ansible-playbook site.yml --ask-vault-pass --tags website -e deploy_environment=PREPROD

# Deployer uniquement la prod
ansible-playbook site.yml --ask-vault-pass --tags website -e deploy_environment=PROD
```
