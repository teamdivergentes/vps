# GitHub Actions — Runner self-hosted

Ce document explique comment mettre en place, côté GitHub, le runner
self-hosted déployé par le rôle Ansible `github-runner` sur le VPS.

Le runner tourne dans un ou plusieurs conteneurs Docker (image
[`myoung34/github-runner`](https://github.com/myoung34/docker-github-actions-runner))
et s'enregistre automatiquement auprès de GitHub au démarrage à l'aide d'un
Personal Access Token (PAT).

## Prérequis

Avant de déployer ce rôle, vérifier que :

1. Le rôle `docker` a été exécuté et le daemon Docker tourne sur l'hôte.
2. L'utilisateur `deploy` est membre du groupe `docker`
   (configuré par le rôle `docker` — vérifiable via `id deploy`).
3. Le vault Ansible contient `vault_github_runner_token` (voir section ci-dessous).

## Architecture multi-runner

```
┌────────────────────────────┐         ┌──────────────────────────────────────┐
│  GitHub Actions (cloud)    │  jobs   │  VPS TeamDivergentes                 │
│  workflows teamdivergentes │────────▶│  ┌──────────────────────────────┐    │
│  (repos privés)            │         │  │ github-runner-1  (container) │    │
│                            │         │  │ github-runner-2  (container) │    │
│                            │         │  │ github-runner-N  (container) │    │
│                            │         │  └──────────────────────────────┘    │
│                            │         │  volumes: runner-work-N (par runner) │
│                            │         │           buildx-cache (partagé)     │
│                            │         │  socket:  /var/run/docker.sock        │
└────────────────────────────┘         └──────────────────────────────────────┘
```

Le nombre de runners est contrôlé par `github_runner_replicas` (défaut 2).
GitHub dispatche les jobs en parallèle sur les runners idle : avec 2 runners,
2 jobs peuvent s'exécuter simultanément.

Au démarrage, chaque conteneur :

1. Lit `ACCESS_TOKEN` (le PAT) depuis son fichier `.env`
2. Appelle l'API GitHub pour obtenir un **registration token** éphémère
3. Enregistre le runner dans l'organisation avec les labels configurés
   (`self-hosted,linux,vps,docker`) et un nom unique `vps-runner-<hash>`
4. Se met en attente de jobs

Chaque runner a accès au **socket Docker de l'hôte** (`/var/run/docker.sock`),
ce qui lui permet de builder et lancer des images Docker pendant les jobs.

### Volumes

| Volume | Monté sur | Rôle |
|--------|-----------|------|
| `runner-work-N` | `/tmp/runner` | Workdir isolé par runner — évite les collisions entre jobs parallèles |
| `buildx-cache` | `/home/runner/.cache/buildx` | Cache Buildx partagé entre tous les runners — layers Docker réutilisables |

### Réseau

Le runner tourne en `network_mode: host` (partage la stack réseau de l'hôte).
Ce mode est requis pour les jobs qui exécutent `docker compose up` puis
`curl http://localhost:<port>` (ex : `e2e-fullstack.yml`).

> **Sécurité** — monter le socket Docker donne un accès root effectif
> à l'hôte depuis n'importe quel job. **N'utilise ce runner que pour des
> repos privés et de confiance** (pas de fork PR qui exécutent du code
> inconnu avec `pull_request_target`).

## Ephemeral vs persistent

| Mode | `github_runner_ephemeral` | Comportement | Quand l'utiliser |
|------|--------------------------|--------------|-----------------|
| **Persistent** (défaut) | `false` | Le runner reste enregistré après le job. Économise ~30s de re-registration. | Repos privés de confiance uniquement |
| **Ephemeral** | `true` | Le runner se désenregistre après chaque job. État totalement isolé entre les jobs. | Si un repo public ou un fork externe peut soumettre des jobs |

> **Pourquoi `false` par défaut ?**
> Sur des repos privés dont seule l'équipe maîtrise les workflows, la menace
> de fuite d'état entre jobs est théorique. En revanche, le surcoût de
> re-registration (~30s/job) est systématique et pénalise la queue.
> Avec 25 jobs en attente et 2 runners, passer de `true` à `false` économise
> ~12 minutes de latence cumulée sur le vidage de la queue.

## Prérequis côté GitHub

### 1. Créer un Personal Access Token

Le PAT sert uniquement à générer des registration tokens — il n'est pas
partagé avec les workflows eux-mêmes.

**Option A — PAT fine-grained (recommandé)** (plus sécurisé, permissions minimales)

1. <https://github.com/settings/personal-access-tokens/new>
2. Resource owner : `teamdivergentes`
3. Repository access : *All repositories* (pour un runner org) ou la liste ciblée
4. Permissions :
   - **Organization permissions** → *Self-hosted runners* = **Read & Write**
     (uniquement pour scope `org`)
   - **Repository permissions** → *Administration* = **Read & Write**
     (uniquement pour scope `repo`)
5. *Generate token*

**Option B — PAT classique (déprécié, à éviter)**

1. Aller sur <https://github.com/settings/tokens> → *Generate new token (classic)*
2. Nom : `vps-github-runner`
3. Expiration : 1 an (à renouveler ensuite)
4. Scopes à cocher :
   - Pour un runner **d'organisation** : `admin:org` (full control)
   - Pour un runner **de repo** : `repo` (full control)
5. *Generate token* — copier le token (commence par `ghp_...`)

> Préférer Option A : les PAT fine-grained limitent les permissions au strict
> nécessaire et réduisent le rayon d'action en cas de compromission.

> **Un seul PAT suffit pour tous les runners.** Le même `vault_github_runner_token`
> est utilisé par les N instances : chaque conteneur génère son propre
> registration token à partir du PAT au démarrage.

### 2. Stocker le PAT dans le vault Ansible

```bash
ansible-vault edit inventory/group_vars/all/vault.yml
```

Ajouter (ou remplir) :

```yaml
vault_github_runner_token: "ghp_xxxxxxxxxxxxxxxxxxxx"
```

### 3. Vérifier les variables du rôle

Dans `inventory/group_vars/all/main.yml` (valeurs par défaut) :

| Variable | Défaut | Rôle |
|---|---|---|
| `github_runner_scope` | `org` | `org` ou `repo` |
| `github_runner_org` | `teamdivergentes` | Nom de l'organisation (ou propriétaire du repo) |
| `github_runner_repo` | `vps` | Nom du repo (si scope=`repo`) |
| `github_runner_name_prefix` | `vps-runner` | Préfixe du nom (suffixé par un hash unique par instance) |
| `github_runner_labels` | `self-hosted,linux,vps,docker` | Labels utilisables dans `runs-on` |
| `github_runner_ephemeral` | `false` | `false` = runner persistent (économise ~30s/job) — voir section Ephemeral |
| `github_runner_replicas` | `2` | Nombre de containers runner (max documenté : 4) |
| `github_runner_network_mode` | `host` | `host` (partage la stack réseau de l'hôte, requis pour les jobs `curl localhost` en e2e) ou `bridge` (isolation stricte). |
| `github_runner_network` | `github-runner-net` | Réseau bridge dédié — ignoré si `network_mode=host` |
| `github_runner_mem_limit` | `4g` | Limite mémoire **par runner**. Un build NestJS/Angular + Buildx consomme 2-3 GB, **ne jamais descendre sous 3g**. |
| `github_runner_cpus` | `2.0` | Quota CPU **par runner**. 1.0 rend les builds multi-stage très lents (30+ min). |
| `github_runner_prune_hour` | `3` | Heure (24h) à laquelle le GC Docker tourne |
| `github_runner_prune_minute` | `30` | Minute à laquelle le GC Docker tourne |

### Dimensionnement VPS selon les replicas

| `github_runner_replicas` | RAM totale runners | vCPU totaux | VPS minimum recommandé |
|---|---|---|---|
| 1 | 4 Go | 2 | 4 vCPU / 8 Go RAM |
| 2 (défaut) | 8 Go | 4 | 4 vCPU / 10 Go RAM |
| 3 | 12 Go | 6 | 6 vCPU / 14 Go RAM |
| 4 (max) | 16 Go | 8 | 8 vCPU / 20 Go RAM |

> Ces valeurs s'appliquent **aux runners seuls**. Le VPS héberge aussi Traefik,
> PostgreSQL, l'application website, Odoo, etc. Prévoir un overhead système de
> 2-3 Go RAM et 1-2 vCPU supplémentaires.

Override possible via `-e` en CLI ou en éditant `main.yml`.

> **Pourquoi `network_mode: host` ?**
> Le runner exécute des jobs qui lancent souvent `docker compose up` puis font
> `curl http://localhost:<port>` pour attendre qu'un service soit prêt (ex :
> `e2e-fullstack.yml`). En mode `bridge`, `localhost` dans le runner pointe
> vers **le runner lui-même**, pas vers les containers démarrés par le job ;
> les `curl` échouent. `host` résout le problème et n'augmente pas la surface
> d'attaque dans notre contexte (le socket Docker donne déjà root sur l'hôte).

> **Pourquoi 4 GB / 2 CPU par runner ?**
> Un build Buildx multi-stage (Dockerfile NestJS ou Angular) monopolise
> facilement 2-3 GB et plusieurs cœurs. Avec 1 GB / 1 CPU, on observait des
> jobs `docker` qui duraient 30+ min avant d'être cancel manuellement
> (symptôme : OOM-kill pendant le build, Buildx retry, boucle).

## Garbage collection Docker

Le rôle installe un script `/usr/local/sbin/github-runner-docker-prune.sh`
exécuté chaque nuit par cron (défaut 03:30 UTC). Il supprime :

- les containers exited depuis plus de 24h (et leurs volumes anonymes) ;
- les images non utilisées depuis plus de 72h ;
- les networks orphelins (compose en crée un par projet) ;
- le cache de build Buildx au-delà de 5 GB.

> **Note multi-runner** : le volume `buildx-cache` est partagé entre tous les
> runners. Le prune nocturne gère le cache global Buildx via `docker buildx prune`
> (seuil 5 Go) — cela couvre l'ensemble du cache partagé.

Le script **ne purge pas** les volumes nommés (postgres, uploads, runner-work-N,
buildx-cache) — cette opération est volontairement exclue pour éviter toute
perte de données ou invalidation du cache Buildx.

Logs : `/var/log/github-runner-prune.log` (rotation hebdomadaire, 8 semaines).

### 4. Recommandation : approuver les runners externes

Côté GitHub Settings, activer :
**Settings → Actions → General → "Require approval for all outside collaborators"**

Cette option empêche des fork PR externes de déclencher automatiquement des
jobs sur votre runner self-hosted sans approbation explicite d'un mainteneur.

## Déploiement

```bash
# Première fois ou après changement de config
ansible-playbook site.yml --ask-vault-pass --tags github-runner
```

Puis vérifier sur le VPS :

```bash
ssh deploy@<IP_DU_VPS>
docker ps | grep github-runner
# Doit lister github-runner-1, github-runner-2 (selon github_runner_replicas)

docker logs -f github-runner-1
```

On doit voir pour chaque runner :

```
√ Connected to GitHub
√ Runner successfully added
√ Runner connection is good
Listening for Jobs
```

## Vérification côté GitHub

- **Scope `org`** : <https://github.com/organizations/teamdivergentes/settings/actions/runners>

Le runner apparaît avec :
- autant d'entrées que `github_runner_replicas` (toutes en statut **Idle** vert)
- noms `vps-runner-<hash1>`, `vps-runner-<hash2>`...
- les labels `self-hosted`, `linux`, `vps`, `docker`

## Ajouter ou retirer des runners

Pour passer de 2 à 3 runners (par exemple) :

```bash
# 1. Éditer main.yml
#    github_runner_replicas: 3

# 2. Redéployer uniquement le rôle runner
ansible-playbook site.yml --ask-vault-pass --tags github-runner
```

Ansible génère le nouveau `docker-compose.yml`, lance `docker compose up -d`
qui crée le container manquant sans toucher aux runners existants déjà actifs.

Pour revenir à 2 runners : passer `github_runner_replicas: 2` et redéployer.
Docker Compose retire le container `github-runner-3` et laisse `github-runner-1`
et `github-runner-2` intacts.

> **Attention** : ne jamais réduire `replicas` pendant qu'un job tourne sur le
> runner qui sera supprimé — le job sera interrompu.

## Utiliser le runner dans un workflow

Dans n'importe quel workflow du repo (ou de l'org, selon le scope) :

```yaml
jobs:
  build:
    # Au lieu de ubuntu-latest, on cible le runner self-hosted
    runs-on: [self-hosted, linux, vps, docker]
    steps:
      - uses: actions/checkout@v4
      - name: Build Docker image
        run: docker build -t myapp .
```

Les labels listés dans `runs-on` doivent **tous** être présents sur le
runner — c'est un `AND`, pas un `OR`.

## Opérations courantes

### Voir les logs

```bash
# Tous les runners en temps réel
docker logs -f github-runner-1
docker logs -f github-runner-2

# Depuis Ansible (relit le compose)
ansible-playbook site.yml --ask-vault-pass --tags github-runner
```

### Redémarrer les runners

```bash
cd /opt/apps/github-runner
docker compose restart
```

ou via Ansible :

```bash
ansible-playbook site.yml --ask-vault-pass --tags github-runner
```

### Renouveler le PAT

1. Générer un nouveau PAT (étape 1 ci-dessus)
2. `ansible-vault edit inventory/group_vars/all/vault.yml` → mettre à jour `vault_github_runner_token`
3. `ansible-playbook site.yml --ask-vault-pass --tags github-runner`
4. Tous les conteneurs redémarrent et s'enregistrent avec un nouveau registration token

### Supprimer tous les runners proprement

```bash
# Sur le VPS
cd /opt/apps/github-runner
docker compose down -v
```

Puis côté GitHub, supprimer les entrées dans *Settings → Actions → Runners*
(ou elles disparaîtront d'elles-mêmes après expiration).

## Procédure de rollback

Si la configuration multi-runner pose problème (OOM, conflit Docker, etc.),
revenir au runner unique en 3 étapes :

```bash
# Étape 1 : éditer main.yml
#   github_runner_replicas: 1
#   github_runner_ephemeral: false   # ou true selon préférence

# Étape 2 : redéployer
ansible-playbook site.yml --ask-vault-pass --tags github-runner
# Docker Compose supprime github-runner-2..N, conserve github-runner-1

# Étape 3 : vérifier
ssh deploy@<VPS_IP>
docker ps | grep github-runner
# Doit lister uniquement github-runner-1
```

## Dépannage

| Symptôme | Cause probable | Fix |
|---|---|---|
| `HTTP 401 Unauthorized` dans les logs | PAT invalide ou expiré | Regénérer un PAT, mettre à jour le vault, redéployer |
| `HTTP 403 Forbidden` | PAT sans les bons scopes | Vérifier les permissions (fine-grained) ou `admin:org`/`repo` (classic) |
| Un runner apparaît *Offline* sur GitHub | Container arrêté | `docker ps -a` puis `docker logs github-runner-N` |
| Tous les runners *Offline* | Plantage collectif | `cd /opt/apps/github-runner && docker compose up -d` |
| Job en attente indéfiniment | Labels workflow ≠ labels runner | Vérifier `github_runner_labels` vs `runs-on` dans le workflow |
| Jobs ne démarrent pas malgré runners Idle | Runner Group restreint (org) | GitHub → Org Settings → Actions → Runner Groups → activer "Allow public repositories" si repo public |
| `permission denied /var/run/docker.sock` | Runner sans accès au socket | Vérifier que `deploy` est dans le groupe `docker` (`id deploy`) |
| OOM Kill pendant un build Docker | `mem_limit` trop bas ou trop de runners parallèles | Augmenter `github_runner_mem_limit` ou réduire `github_runner_replicas` |
| Queue qui n'avance pas (jobs en attente) | Tous les runners occupés | Augmenter `github_runner_replicas` (vérifier le dimensionnement VPS avant) |
| Cache Buildx corrompu (erreur `failed to solve`) | Volume `buildx-cache` corrompu | `docker volume rm github-runner_buildx-cache` puis redémarrer les runners — le cache se reconstruit au prochain build |
| Capabilities manquantes (`Operation not permitted` dans tar/chmod) | cap_add incomplet | Vérifier que CHOWN, SETGID, SETUID, DAC_OVERRIDE, FOWNER sont bien dans `cap_add` du compose |
| `docker compose down` ne supprime que N-1 runners | Compose a été généré avec un replicas différent | Redéployer avec Ansible pour regénérer le compose avant de down |

## Sécurité — à retenir

- Le PAT donne accès à l'enregistrement des runners sur l'org — garder dans le vault, **jamais** dans le code.
- Le socket Docker monté = équivalent root sur l'hôte → **repos privés uniquement**.
- Le mode **ephemeral est désactivé par défaut** (`github_runner_ephemeral: false`) — économise ~30s/job sur des repos privés de confiance. Passer à `true` si un repo public ou un fork externe peut soumettre des jobs (état isolé garanti entre jobs).
- Ne pas utiliser le runner pour des workflows déclenchés par des PRs de forks.
- Activer côté GitHub : *Settings → Actions → General → "Require approval for all outside collaborators"* (recommandé — voir SEC-009).
- En `network_mode: host`, les runners n'ont pas de réseau bridge dédié isolé. Cette configuration est intentionnelle pour la compatibilité e2e — le socket Docker est le vecteur d'accès principal de toute façon.
