# Resource Limits Docker

## Contexte

VPS : **6 CPU / 12 Go RAM**. Aucun container n'a de resource limit aujourd'hui (sauf Odoo qui a des limits applicatives internes).

L'objectif est de proteger le VPS contre un container qui consomme toute la RAM (OOM killer) ou tout le CPU (starvation). Les limits sont des **caps de securite**, pas des reservations — un container peut consommer moins.

## Limits par container

### Services applicatifs

| Container | `mem_limit` | `cpus` | Justification |
|-----------|-------------|--------|---------------|
| `website-prod-backend` | 512 Mo | 0.5 | NestJS + Prisma, trafic prod |
| `website-prod-frontend` | 128 Mo | 0.2 | Nginx serveur statique |
| `website-preprod-backend` | 512 Mo | 0.5 | Meme stack que prod |
| `website-preprod-frontend` | 128 Mo | 0.2 | Meme stack que prod |
| `dvg-shared-postgres` | 1024 Mo | 1.0 | 3 bases (preprod, prod, discord) |
| `discord-bot` | 256 Mo | 0.3 | Node.js, usage modere |
| **Sous-total applicatif** | **2816 Mo** | **2.7** | |

### Services infrastructure

| Container | `mem_limit` | `cpus` | Justification |
|-----------|-------------|--------|---------------|
| Traefik | 128 Mo | 0.3 | Reverse proxy, faible conso |
| Portainer | 128 Mo | 0.2 | UI Docker, usage ponctuel |
| pgAdmin | 256 Mo | 0.2 | UI PostgreSQL, usage ponctuel |
| **Sous-total infra** | **512 Mo** | **0.7** | |

### Services monitoring (nouveaux)

| Container | `mem_limit` | `cpus` | Justification |
|-----------|-------------|--------|---------------|
| Prometheus | 300 Mo | 0.5 | TSDB en memoire, 30j retention |
| Grafana | 200 Mo | 0.3 | Rendu dashboards |
| Alertmanager | 50 Mo | 0.1 | Tres leger |
| node-exporter | 30 Mo | 0.1 | Collecteur passif |
| postgres-exporter | 30 Mo | 0.1 | Collecteur passif |
| nginx-exporter-prod | 20 Mo | 0.1 | Collecteur passif |
| nginx-exporter-preprod | 20 Mo | 0.1 | Collecteur passif |
| cAdvisor | 100 Mo | 0.2 | Metriques containers |
| **Sous-total monitoring** | **750 Mo** | **1.5** | |

### Odoo (non modifie)

| Container | Limits | Type |
|-----------|--------|------|
| `odoo-web` | 2 Go soft / 2.5 Go hard par worker (x4) | Applicatif (odoo.conf) |
| `odoo-db` | Non limite | PostgreSQL interne Odoo |
| `odoo-nginx` | Non limite | Nginx proxy |

> Odoo utilise ses propres mecanismes de gestion memoire par worker. Ajouter des `mem_limit` Docker risquerait de tuer des workers actifs. On ne touche pas a cette stack.

### TeamSpeak

| Container | `mem_limit` | `cpus` |
|-----------|-------------|--------|
| `teamspeak` | 128 Mo | 0.2 |

## Budget total

| Categorie | RAM caps | CPU caps |
|-----------|----------|----------|
| Applicatif | 2 816 Mo | 2.7 |
| Infrastructure | 512 Mo | 0.7 |
| Monitoring | 750 Mo | 1.5 |
| TeamSpeak | 128 Mo | 0.2 |
| **Total (hors Odoo)** | **4 206 Mo** | **5.1** |
| Odoo (estimation) | ~4 000 Mo | ~2.0 |
| **Total estime** | **~8 200 Mo** | **~7.1** |
| **Disponible** | **12 288 Mo** | **6 CPU** |
| **Marge** | **~4 Go** | CPU oversub acceptable |

### Notes

- Les **caps RAM** sont des limites hautes. L'usage reel sera 40-60% des caps.
- Le **CPU oversubscription** (7.1 vs 6 CPU) est acceptable car les containers n'utilisent jamais leur cap simultanement. Les `cpus` sont des quotas CFS, pas des reservations.
- La **marge de 4 Go** couvre les pics Odoo, le cache filesystem Linux, et les processus systeme.
- Si le VPS est upgrade (ex: 16 Go), augmenter en priorite : Prometheus (500 Mo), PostgreSQL (2 Go), backends (768 Mo).

## Implementation

Les limits s'ajoutent dans chaque `docker-compose.yml.j2` Ansible :

```yaml
services:
  backend:
    image: ...
    mem_limit: 512m
    cpus: 0.5
    # ... reste de la config
```

> On utilise `mem_limit` / `cpus` (syntaxe Compose v2) plutot que `deploy.resources` (syntaxe Swarm mode) car les stacks tournent en `docker compose` simple, pas en Swarm.
