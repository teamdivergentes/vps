# Regles d'alerte

## Routing

Toutes les alertes sont envoyees vers un **webhook Discord** sur le channel `#monitoring`.

- Severite `critical` : prefixe `@here` pour notifier les membres en ligne
- Severite `warning` : notification silencieuse (pas de mention)
- **Group by** : `alertname`, `instance` (evite le spam de notifs identiques)
- **Group wait** : 30s (attend 30s avant d'envoyer le premier groupe)
- **Group interval** : 5min (attend 5min avant d'envoyer un nouveau message pour le meme groupe)
- **Repeat interval** : 4h (re-notifie toutes les 4h si l'alerte persiste)

## Alertes Host (node-exporter)

| Alerte | Expression PromQL | Duree | Severite |
|--------|-------------------|-------|----------|
| `HostHighCpuUsage` | `100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 85` | 5 min | warning |
| `HostHighMemoryUsage` | `(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 85` | 5 min | warning |
| `HostHighMemoryCritical` | `(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > 95` | 2 min | critical |
| `HostDiskSpaceLow` | `(1 - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes) * 100 > 85` | 5 min | warning |
| `HostDiskSpaceCritical` | `(1 - node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes) * 100 > 95` | 2 min | critical |
| `HostHighSwapUsage` | `(1 - node_memory_SwapFree_bytes / node_memory_SwapTotal_bytes) * 100 > 80` | 5 min | warning |
| `HostHighNetworkErrors` | `rate(node_network_receive_errs_total[5m]) + rate(node_network_transmit_errs_total[5m]) > 10` | 5 min | warning |

## Alertes PostgreSQL (postgres-exporter)

| Alerte | Expression PromQL | Duree | Severite |
|--------|-------------------|-------|----------|
| `PostgresConnectionsHigh` | `pg_stat_activity_count / pg_settings_max_connections * 100 > 80` | 5 min | warning |
| `PostgresConnectionsCritical` | `pg_stat_activity_count / pg_settings_max_connections * 100 > 95` | 2 min | critical |
| `PostgresDeadLocks` | `rate(pg_stat_database_deadlocks[5m]) > 0` | 5 min | warning |
| `PostgresSlowQueries` | `pg_stat_activity_max_tx_duration{state="active"} > 60` | 2 min | warning |
| `PostgresHighDeadTuples` | `pg_stat_user_tables_n_dead_tup > 100000` | 15 min | warning |
| `PostgresDown` | `pg_up == 0` | 1 min | critical |

## Alertes Traefik

| Alerte | Expression PromQL | Duree | Severite |
|--------|-------------------|-------|----------|
| `TraefikHighErrorRate` | `sum(rate(traefik_service_requests_total{code=~"5.."}[5m])) / sum(rate(traefik_service_requests_total[5m])) * 100 > 5` | 5 min | critical |
| `TraefikHigh4xxRate` | `sum(rate(traefik_service_requests_total{code=~"4.."}[5m])) / sum(rate(traefik_service_requests_total[5m])) * 100 > 25` | 10 min | warning |
| `TraefikHighLatency` | `histogram_quantile(0.95, sum(rate(traefik_service_request_duration_seconds_bucket[5m])) by (le, service)) > 2` | 5 min | warning |
| `TraefikCertExpirySoon` | `traefik_tls_certs_not_after - time() < 7 * 24 * 3600` | 1h | critical |

## Alertes Nginx (nginx-exporter)

| Alerte | Expression PromQL | Duree | Severite |
|--------|-------------------|-------|----------|
| `NginxDown` | `nginx_up == 0` | 2 min | critical |
| `NginxHighConnections` | `nginx_connections_active > 500` | 5 min | warning |

## Alertes Backend NestJS (prom-client)

| Alerte | Expression PromQL | Duree | Severite |
|--------|-------------------|-------|----------|
| `BackendHighErrorRate` | `sum(rate(http_requests_total{status_code=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100 > 5` | 5 min | critical |
| `BackendHighLatency` | `histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le)) > 2` | 5 min | warning |
| `BackendHighHeapUsage` | `process_heap_bytes / 1024 / 1024 > 400` | 10 min | warning |
| `BackendEventLoopLag` | `nodejs_eventloop_lag_p99_seconds > 0.5` | 5 min | warning |

## Alertes Containers (cAdvisor)

| Alerte | Expression PromQL | Duree | Severite |
|--------|-------------------|-------|----------|
| `ContainerDown` | `up == 0` | 2 min | critical |
| `ContainerHighCpu` | `rate(container_cpu_usage_seconds_total[5m]) > 0.8` | 5 min | warning |
| `ContainerHighMemory` | `container_memory_usage_bytes / container_spec_memory_limit_bytes * 100 > 90` | 5 min | warning |
| `ContainerRestarting` | `increase(container_restart_count[15m]) > 3` | 0 | warning |
| `DiscordBotDown` | `absent(container_last_seen{name="discord-bot"}) OR (time() - container_last_seen{name="discord-bot"}) > 120` | 2 min | critical |

## Alertes Monitoring (auto-surveillance)

| Alerte | Expression PromQL | Duree | Severite |
|--------|-------------------|-------|----------|
| `PrometheusStorageHigh` | `prometheus_tsdb_storage_blocks_bytes / 1024 / 1024 / 1024 > 0.9` | 30 min | warning |
| `AlertmanagerDown` | `up{job="alertmanager"} == 0` | 2 min | critical |

## Format du message Discord

```
🔴 [CRITICAL] HostDiskSpaceCritical
Instance: vps-prod
Valeur: 96.2%
Description: Espace disque critique (> 95%) sur /dev/sda1
Depuis: 2026-04-02 14:32 UTC
```

```
🟡 [WARNING] HostHighCpuUsage
Instance: vps-prod
Valeur: 87.3%
Description: CPU eleve (> 85%) depuis 5 minutes
Depuis: 2026-04-02 14:32 UTC
```

```
✅ [RESOLVED] HostHighCpuUsage
Instance: vps-prod
Description: CPU revenu a la normale
Resolu: 2026-04-02 14:45 UTC
```
