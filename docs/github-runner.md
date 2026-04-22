# GitHub Actions — Runner self-hosted

Ce document explique comment mettre en place, côté GitHub, le runner
self-hosted déployé par le rôle Ansible `github-runner` sur le VPS.

Le runner tourne dans un conteneur Docker (image
[`myoung34/github-runner`](https://github.com/myoung34/docker-github-actions-runner))
et s'enregistre automatiquement auprès de GitHub au démarrage à l'aide d'un
Personal Access Token (PAT).

## Prérequis

Avant de déployer ce rôle, vérifier que :

1. Le rôle `docker` a été exécuté et le daemon Docker tourne sur l'hôte.
2. L'utilisateur `deploy` est membre du groupe `docker`
   (configuré par le rôle `docker` — vérifiable via `id deploy`).
3. Le vault Ansible contient `vault_github_runner_token` (voir section ci-dessous).

## Architecture

```
┌────────────────────────────┐        ┌───────────────────────────┐
│  GitHub Actions (cloud)    │ jobs   │  VPS TeamDivergentes      │
│  workflows dans les repos  │───────▶│  conteneur github-runner  │
│  teamdivergentes/*         │        │  (docker socket monté)    │
└────────────────────────────┘        └───────────────────────────┘
```

Au démarrage, le conteneur :

1. Lit `ACCESS_TOKEN` (le PAT) depuis son fichier `.env`
2. Appelle l'API GitHub pour obtenir un **registration token** éphémère
3. Enregistre le runner dans l'organisation (ou le repo) avec les labels
   configurés (`self-hosted,linux,vps,docker`)
4. Se met en attente de jobs

Le runner a accès au **socket Docker de l'hôte** (`/var/run/docker.sock`),
ce qui lui permet de builder et lancer des images Docker pendant les jobs.

### Réseau

Le runner tourne sur un réseau bridge dédié `github-runner-net`, **isolé de
`traefik-public`**. Il n'a besoin que d'un accès Internet sortant (GitHub API,
GHCR) et ne doit en aucun cas être exposé via Traefik.

> **Sécurité** — monter le socket Docker donne un accès root effectif
> à l'hôte depuis n'importe quel job. **N'utilise ce runner que pour des
> repos privés et de confiance** (pas de fork PR qui exécutent du code
> inconnu avec `pull_request_target`).

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
| `github_runner_name_prefix` | `vps-runner` | Préfixe du nom (suffixé par l'ID conteneur) |
| `github_runner_labels` | `self-hosted,linux,vps,docker` | Labels utilisables dans `runs-on` |
| `github_runner_ephemeral` | `true` | `true` = le runner se dés-enregistre après chaque job (défaut sécurisé) |
| `github_runner_network_mode` | `host` | `host` (partage la stack réseau de l'hôte, requis pour les jobs `curl localhost` en e2e) ou `bridge` (isolation stricte). |
| `github_runner_network` | `github-runner-net` | Réseau bridge dédié — ignoré si `network_mode=host` |
| `github_runner_mem_limit` | `4g` | Limite mémoire du conteneur. Un build NestJS/Angular + Buildx consomme 2-3 GB, **ne jamais descendre sous 3g**. |
| `github_runner_cpus` | `2.0` | Quota CPU. 1.0 rend les builds multi-stage très lents (30+ min). |
| `github_runner_prune_hour` | `3` | Heure (24h) à laquelle le GC Docker tourne |
| `github_runner_prune_minute` | `30` | Minute à laquelle le GC Docker tourne |

Override possible via `-e` en CLI ou en éditant `main.yml`.

> **Pourquoi `network_mode: host` ?**
> Le runner exécute des jobs qui lancent souvent `docker compose up` puis font
> `curl http://localhost:<port>` pour attendre qu'un service soit prêt (ex :
> `e2e-fullstack.yml`). En mode `bridge`, `localhost` dans le runner pointe
> vers **le runner lui-même**, pas vers les containers démarrés par le job ;
> les `curl` échouent. `host` résout le problème et n'augmente pas la surface
> d'attaque dans notre contexte (le socket Docker donne déjà root sur l'hôte).

> **Pourquoi 4 GB / 2 CPU ?**
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

Le script **ne purge pas** les volumes nommés (postgres, uploads, etc.) —
cette opération est volontairement exclue pour éviter toute perte de données.

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
docker logs -f github-runner
```

On doit voir :

```
√ Connected to GitHub
√ Runner successfully added
√ Runner connection is good
Listening for Jobs
```

## Vérification côté GitHub

- **Scope `org`** : <https://github.com/organizations/teamdivergentes/settings/actions/runners>
- **Scope `repo`** : `https://github.com/<owner>/<repo>/settings/actions/runners`

Le runner apparaît avec :
- statut **Idle** (vert)
- nom `vps-runner-<hash>`
- les labels configurés

## Utiliser le runner dans un workflow

Dans n'importe quel workflow du repo (ou de l'org, selon le scope) :

```yaml
jobs:
  build:
    # Au lieu de ubuntu-latest, on cible le runner self-hosted
    runs-on: [self-hosted, linux, vps]
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
docker logs -f github-runner
```

### Redémarrer le runner

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
4. Le conteneur redémarre, s'enregistre avec un nouveau registration token

### Supprimer le runner proprement

```bash
# Sur le VPS
cd /opt/apps/github-runner
docker compose down -v
```

Puis côté GitHub, supprimer l'entrée dans *Settings → Actions → Runners*
(ou elle disparaîtra d'elle-même après expiration).

## Dépannage

| Symptôme | Cause probable | Fix |
|---|---|---|
| `HTTP 401 Unauthorized` dans les logs | PAT invalide ou expiré | Regénérer un PAT, mettre à jour le vault, redéployer |
| `HTTP 403 Forbidden` | PAT sans les bons scopes | Vérifier les permissions (fine-grained) ou `admin:org`/`repo` (classic) |
| Le runner apparaît *Offline* sur GitHub | Conteneur arrêté | `docker ps -a` puis `docker logs github-runner` |
| Job en attente indéfiniment | Labels du workflow ≠ labels du runner | Vérifier `github_runner_labels` vs `runs-on` |
| `permission denied /var/run/docker.sock` dans un job | Runner sans accès au socket | Vérifier que `deploy` est dans le groupe `docker` (`id deploy`) |

## Sécurité — à retenir

- Le PAT donne accès à l'enregistrement des runners sur l'org — garder dans le vault, **jamais** dans le code.
- Le socket Docker monté = équivalent root sur l'hôte → **repos privés uniquement**.
- Le mode **ephemeral est activé par défaut** (`github_runner_ephemeral: true`) — chaque job obtient un runner vierge, évitant toute fuite d'état ou de credentials entre les jobs.
- Ne pas utiliser le runner pour des workflows déclenchés par des PRs de forks.
- Activer côté GitHub : *Settings → Actions → General → "Require approval for all outside collaborators"* (recommandé — voir SEC-009).
- Le runner est sur un réseau dédié `github-runner-net`, isolé de `traefik-public`.
