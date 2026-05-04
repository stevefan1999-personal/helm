# Zulip Helm chart

This chart is a Kubernetes-native meta chart for Zulip. The parent chart owns
shared infrastructure and configuration; the role subcharts own Zulip runtime
roles as separate Kubernetes objects.

It intentionally avoids external infrastructure chart dependencies:

- CloudNativePG `Cluster` for PostgreSQL when `cnpg.enabled=true`.
- RabbitMQ Cluster Operator `RabbitmqCluster` when `rabbitmq.enabled=true`.
- Lightweight in-chart Redis and Memcached Deployments/Services when enabled.
- Shared runtime/config ConfigMaps, native env ConfigMap/Secret, migration Job,
  ServiceAccount, and extra objects.

## Runtime dependencies

Install these operators before enabling managed services:

- CloudNativePG `postgresql.cnpg.io/v1` CRDs/controllers: https://cloudnative-pg.io/docs/1.29/
- RabbitMQ Cluster Operator `rabbitmq.com/v1beta1` CRDs/controllers: https://www.rabbitmq.com/kubernetes/operator/operator-overview

Set `cnpg.enabled=false`, `rabbitmq.enabled=false`, `redis.enabled=false`, or
`memcached.enabled=false` to use externally managed services through the matching
`external*` values blocks.

## Role model

The chart no longer uses docker-zulip post-setup scripts, Docker-style env names,
or Supervisor patching to split roles. Pods bypass the image entrypoint and run
Zulip commands directly from a mounted runtime ConfigMap.

- `web`: public nginx gateway Deployment/Service/Ingress plus a separate Django
  uWSGI Deployment/Service.
- `tornado`: one Deployment and Service per configured Tornado port; each port
  stays single-replica because it owns in-memory event queues.
- `worker`: one Deployment per `worker.groups` entry; each group can run a
  multi-queue worker or a single queue/worker number for sharded queues.
- `singleton`: one Deployment per enabled singleton process (`fts-updater`,
  `scheduled-emails`, `scheduled-messages`, optional `email-server`).
- `migration`: a dedicated Job runs checks, migrations, and cache table setup.

## Important values

- `zulip.settings.externalHost`: public Zulip hostname.
- `zulip.settings.administratorEmail`: administrator email.
- `zulip.secrets.secretKey`, `sharedSecret`, `avatarSalt`: required Zulip secrets.
- `zulip.tornadoSharding.rules`: optional `[tornado_sharding]` rules.
- `tornado.ports`: every Tornado port referenced by sharding rules.
- `worker.groups`: independently scalable worker Deployments.
- `singleton.processes`: exactly-one background singleton Deployments.
- `zulip.objectStorage`: durable upload backend for files, avatars, and icons.
- `cnpg.imageName`: defaults to vanilla `ghcr.io/cloudnative-pg/postgresql:14`.
- `cnpg.pgroonga`: optional PGroonga bootstrap and Zulip configuration.

## PostgreSQL image and extensions

Zulip's baseline schema works on vanilla PostgreSQL, so this chart defaults to a
CloudNativePG-compatible vanilla PostgreSQL 14 image instead of Zulip's standalone
PostgreSQL image.

Zulip can optionally use PGroonga for multilingual full-text search:

```yaml
cnpg:
  imageName: your-registry/postgresql-14-pgroonga:tag
  pgroonga:
    enabled: true
    createExtension: true
    configureZulip: true
```

The PostgreSQL image, or another CNPG-supported extension delivery mechanism,
must already contain PGroonga binaries/control files. SQL can create the
extension only after those files exist in the PostgreSQL image.

## Tornado sharding and scaling

Zulip's source maps Django event-queue registration calls to
`http://127.0.0.1:<tornado-port>`. This chart preserves that localhost
contract with lightweight `socat` sidecars on Django and Tornado pods: Django
opens the hardcoded loopback port, and each Tornado Service targets a pod-local
`socat` listener that forwards to the real Tornado process on `127.0.0.1`.
Worker and singleton roles publish live events through RabbitMQ and do not need
Tornado sidecars.

Sharding rules map existing realm hosts to Tornado port groups; they do not
create realms. A single-root-realm test can be sharded by mapping the public
host to multiple ports, for example `"9800_9801_9802":
"192.168.2.190.nip.io"`.
If you change shared config without changing subchart-local values, bump
`global.zulip.configRevision` so role pods restart with the new ConfigMap data.

```yaml
zulip:
  tornadoSharding:
    enabled: true
    rules:
      "9800": "small"
      "9801_9802": "large"

tornado:
  ports: [9800, 9801, 9802]
  localhostProxy:
    enabled: true
    portOffset: 10000

web:
  replicas: 2
  tornadoProxy:
    ports: [9800, 9801, 9802]

worker:
  replicas: 2
  groups:
    default:
      queues:
        - deferred_work
        - digest_emails
        - email_mirror
        - embed_links
        - embedded_bots
        - email_senders
        - deferred_email_senders
        - missedmessage_emails
        - missedmessage_mobile_notifications
        - outgoing_webhooks
        - thumbnail
        - user_activity
        - user_activity_interval
```

Use dedicated worker groups for sharded queues when `worker.shards` is greater
than `1`, e.g. `queue: user_activity` with `workerNum: 1` and another group with
`workerNum: 2`.

## Upload storage

The chart does not create Zulip upload PVCs. Configure `zulip.objectStorage`
for durable uploads; local filesystem uploads are intentionally not modeled in
Kubernetes because they do not scale across role replicas.

For local k0s E2E, `acceptance/run-k0s.sh` deploys a JuiceFS S3 gateway as a
separate fixture, creates `zulip-uploads` and `zulip-avatars` buckets, installs
the chart with `zulip.objectStorage`, and verifies a write/read round trip
through Zulip's S3 upload backend. It then runs
`acceptance/multi-user-e2e.py` to create test users, create channels, exchange
channel and direct messages, add review reactions, mark messages read, verify
Tornado event delivery, and refresh/check analytics chart data.

## Validation

```bash
helm lint charts/zulip
helm unittest charts/zulip
helm template zulip charts/zulip
```
