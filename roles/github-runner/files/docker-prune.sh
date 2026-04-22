#!/usr/bin/env bash
# {{ ansible_managed }} — managed by role github-runner
#
# Nettoie le cache de build Buildx et les images inutilisees depuis plus de 72h.
#
# Le runner self-hosted pousse beaucoup de couches dans le cache Buildx
# (multi-stage builds Angular/NestJS + cache-to type=gha en mirror local).
# Sans GC regulier, /var/lib/docker peut exploser en quelques semaines.
#
# Volontairement : pas de `volume prune` (risque de supprimer des volumes
# nommes utilises par d'autres stacks comme postgres, odoo, website_uploads).
# Seuls les volumes ANONYMES crees par des containers stoppes sont cibles
# via `container prune` (qui les supprime automatiquement pour les containers
# en etat `exited`).

set -euo pipefail

LOG_PREFIX="[docker-prune $(date -u +%FT%TZ)]"

echo "${LOG_PREFIX} Starting Docker GC..."

# 1) Containers stoppes (y compris leurs volumes anonymes)
echo "${LOG_PREFIX} Pruning stopped containers older than 24h..."
docker container prune -f --filter "until=24h"

# 2) Images non utilisees depuis 72h (y compris dangling)
echo "${LOG_PREFIX} Pruning unused images older than 72h..."
docker image prune -af --filter "until=72h"

# 3) Networks orphelins (compose cree des reseaux par projet)
echo "${LOG_PREFIX} Pruning unused networks..."
docker network prune -f --filter "until=24h"

# 4) Cache de build Buildx — garde 5 GB max
echo "${LOG_PREFIX} Pruning build cache (keep 5GB)..."
docker builder prune -af --keep-storage 5GB

# 5) Resume de l'espace disque
echo "${LOG_PREFIX} Disk usage after GC:"
docker system df

echo "${LOG_PREFIX} Done."
