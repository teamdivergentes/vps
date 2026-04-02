# Dashboards Grafana

5 dashboards provisionnes automatiquement par Ansible. Chaque dashboard est un fichier JSON dans `roles/monitoring/templates/grafana/dashboards/`.

Les dashboards sont en **lecture seule** (provisionnes) — les modifications se font dans les fichiers JSON, pas dans l'UI Grafana.

---

## 01 — Vue d'ensemble

**Fichier** : `01-overview.json`

Dashboard de synthese rapide. C'est la page d'accueil Grafana.

### Rangee 1 : Status (stat panels)

| Panel | Metrique | Seuil vert | Seuil rouge |
|-------|----------|------------|-------------|
| Uptime VPS | `node_time_seconds - node_boot_time_seconds` | > 0 | — |
| CPU Usage | `100 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100` | < 70% | > 85% |
| RAM Usage | `(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100` | < 70% | > 85% |
| Disk Usage | `(1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes) * 100` | < 70% | > 85% |

### Rangee 2 : Services (stat panels avec etat up/down)

| Panel | Metrique |
|-------|----------|
| Backend Prod | `up{job="backend-prod"}` |
| Backend Preprod | `up{job="backend-preprod"}` |
| Frontend Prod | `up{job="nginx-prod"}` |
| Frontend Preprod | `up{job="nginx-preprod"}` |
| PostgreSQL | `pg_up` |
| Traefik | `up{job="traefik"}` |
| Discord Bot | `container_last_seen{name="discord-bot"}` |

### Rangee 3 : Alertes actives

| Panel | Type |
|-------|------|
| Alertes firing | Alert list (filtre: state=firing) |

### Rangee 4 : Trafic global (time series, 24h)

| Panel | Metrique |
|-------|----------|
| Requetes/s (Traefik) | `sum(rate(traefik_service_requests_total[5m]))` |
| Taux d'erreur 5xx | `sum(rate(traefik_service_requests_total{code=~"5.."}[5m]))` |

---

## 02 — Host (Node Exporter)

**Fichier** : `02-host-node.json`

Metriques systeme du VPS.

### Rangee 1 : CPU

| Panel | Type | Metrique |
|-------|------|----------|
| CPU Usage (%) | Time series | `rate(node_cpu_seconds_total[5m])` par mode (user, system, iowait, idle) |
| Load Average | Time series | `node_load1`, `node_load5`, `node_load15` |
| CPU par core | Time series | `rate(node_cpu_seconds_total{mode!="idle"}[5m])` par cpu |

### Rangee 2 : Memoire

| Panel | Type | Metrique |
|-------|------|----------|
| RAM Usage | Time series (stacked) | `node_memory_MemTotal_bytes`, `MemFree`, `Cached`, `Buffers`, `MemAvailable` |
| Swap Usage | Time series | `node_memory_SwapTotal_bytes - node_memory_SwapFree_bytes` |
| RAM disponible (%) | Gauge | `node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100` |

### Rangee 3 : Disque

| Panel | Type | Metrique |
|-------|------|----------|
| Filesystem Usage | Bar gauge | `(1 - node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100` par mountpoint |
| Disk I/O | Time series | `rate(node_disk_read_bytes_total[5m])`, `rate(node_disk_written_bytes_total[5m])` |
| Disk IOPS | Time series | `rate(node_disk_reads_completed_total[5m])`, `rate(node_disk_writes_completed_total[5m])` |

### Rangee 4 : Reseau

| Panel | Type | Metrique |
|-------|------|----------|
| Network Traffic | Time series | `rate(node_network_receive_bytes_total[5m])`, `rate(node_network_transmit_bytes_total[5m])` par interface |
| Network Errors | Time series | `rate(node_network_receive_errs_total[5m])`, `rate(node_network_transmit_errs_total[5m])` |

---

## 03 — PostgreSQL

**Fichier** : `03-postgresql.json`

Metriques de la base partagee `dvg-shared-postgres`.

### Rangee 1 : Connexions

| Panel | Type | Metrique |
|-------|------|----------|
| Connexions actives | Gauge | `pg_stat_activity_count{state="active"}` |
| Connexions par etat | Time series (stacked) | `pg_stat_activity_count` par state (active, idle, idle in transaction) |
| Connexions vs max | Gauge | `pg_stat_activity_count / pg_settings_max_connections * 100` |

### Rangee 2 : Performance

| Panel | Type | Metrique |
|-------|------|----------|
| Transactions/s | Time series | `rate(pg_stat_database_xact_commit[5m])` + `rate(pg_stat_database_xact_rollback[5m])` par database |
| Tuples fetched/s | Time series | `rate(pg_stat_database_tup_fetched[5m])` par database |
| Tuples modified/s | Time series | `rate(pg_stat_database_tup_inserted[5m])` + updated + deleted par database |

### Rangee 3 : Sante

| Panel | Type | Metrique |
|-------|------|----------|
| Dead tuples | Time series | `pg_stat_user_tables_n_dead_tup` par table (top 10) |
| Locks | Time series | `pg_locks_count` par mode |
| Database size | Bar gauge | `pg_database_size_bytes` par database |
| Deadlocks | Time series | `rate(pg_stat_database_deadlocks[5m])` |

### Rangee 4 : Cache

| Panel | Type | Metrique |
|-------|------|----------|
| Cache hit ratio | Gauge | `pg_stat_database_blks_hit / (pg_stat_database_blks_hit + pg_stat_database_blks_read) * 100` |
| Temp files | Time series | `rate(pg_stat_database_temp_bytes[5m])` |

---

## 04 — Traefik + Nginx

**Fichier** : `04-traefik-nginx.json`

Metriques du reverse proxy et des serveurs Nginx frontend.

### Rangee 1 : Traefik — Trafic

| Panel | Type | Metrique |
|-------|------|----------|
| Requetes/s par service | Time series | `sum(rate(traefik_service_requests_total[5m])) by (service)` |
| Codes de reponse | Time series (stacked) | `sum(rate(traefik_service_requests_total[5m])) by (code)` groupe par 2xx, 3xx, 4xx, 5xx |
| Taux d'erreur 5xx (%) | Time series | `sum(rate(traefik_service_requests_total{code=~"5.."}[5m])) / sum(rate(traefik_service_requests_total[5m])) * 100` |

### Rangee 2 : Traefik — Latence

| Panel | Type | Metrique |
|-------|------|----------|
| Latence P50 / P95 / P99 | Time series | `histogram_quantile(0.50/0.95/0.99, sum(rate(traefik_service_request_duration_seconds_bucket[5m])) by (le, service))` |
| Latence par service | Heatmap | `sum(rate(traefik_service_request_duration_seconds_bucket[5m])) by (le, service)` |

### Rangee 3 : Traefik — TLS & Connexions

| Panel | Type | Metrique |
|-------|------|----------|
| Connexions ouvertes | Time series | `traefik_entrypoint_open_connections` par entrypoint |
| TLS cert expiry | Table | `traefik_tls_certs_not_after` — jours restants avant expiration |

### Rangee 4 : Nginx — Prod & Preprod

| Panel | Type | Metrique |
|-------|------|----------|
| Connexions actives | Time series | `nginx_connections_active` par instance (prod/preprod) |
| Requetes/s | Time series | `rate(nginx_http_requests_total[5m])` par instance |
| Connexions acceptees/handled | Time series | `rate(nginx_connections_accepted[5m])`, `rate(nginx_connections_handled[5m])` |
| Waiting connections | Time series | `nginx_connections_waiting` par instance |

---

## 05 — Backend NestJS

**Fichier** : `05-backend-nestjs.json`

Metriques applicatives du backend (prod + preprod).

### Variable template

- `$environment` : `prod` / `preprod` (filtre sur le label `job`)

### Rangee 1 : HTTP

| Panel | Type | Metrique |
|-------|------|----------|
| Requetes/s | Time series | `sum(rate(http_requests_total[5m])) by (method)` |
| Requetes par route (top 10) | Table | `topk(10, sum(rate(http_requests_total[5m])) by (route))` |
| Taux d'erreur 5xx (%) | Stat | `sum(rate(http_requests_total{status_code=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100` |
| Codes de reponse | Time series (stacked) | `sum(rate(http_requests_total[5m])) by (status_code)` |

### Rangee 2 : Latence

| Panel | Type | Metrique |
|-------|------|----------|
| Latence P50 / P95 / P99 | Time series | `histogram_quantile(0.50/0.95/0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))` |
| Latence par route (top 10) | Table | `histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, route))` |

### Rangee 3 : Node.js Runtime

| Panel | Type | Metrique |
|-------|------|----------|
| Heap Memory | Time series | `process_heap_bytes` vs `process_resident_memory_bytes` |
| Event Loop Lag | Time series | `nodejs_eventloop_lag_p50_seconds`, `nodejs_eventloop_lag_p99_seconds` |
| GC Pauses | Time series | `rate(nodejs_gc_duration_seconds_sum[5m])` par gc_type (minor/major) |
| Active Handles | Time series | `nodejs_active_handles_total` |

### Rangee 4 : Containers (cAdvisor)

| Panel | Type | Metrique |
|-------|------|----------|
| CPU par container | Time series | `rate(container_cpu_usage_seconds_total{name=~"website.*\|discord-bot"}[5m])` |
| RAM par container | Time series | `container_memory_usage_bytes{name=~"website.*\|discord-bot"}` |
| Restarts | Stat | `container_restart_count{name=~"website.*\|discord-bot"}` |

---

## Variables globales

Tous les dashboards partagent ces variables template :

| Variable | Type | Valeurs | Dashboard |
|----------|------|---------|-----------|
| `$interval` | interval | `30s, 1m, 5m, 15m, 1h` | Tous |
| `$environment` | custom | `prod, preprod` | 04, 05 |
| `$database` | query | `label_values(pg_stat_database_xact_commit, datname)` | 03 |

## Theming

- Theme : **Dark** (coherent avec la charte DVG `#0C0D0C`)
- Couleur d'accent des graphes : `#32D299` (vert DVG) pour les metriques principales
- Seuils : vert -> orange -> rouge (standard Grafana)
