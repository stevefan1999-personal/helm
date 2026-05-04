# Tuwunel Helm Chart

This chart deploys [Tuwunel](https://github.com/matrix-construct/tuwunel), a single-node Matrix homeserver backed by RocksDB.

## Source-Code Findings Behind This Chart

- Tuwunel reads `TUWUNEL_CONFIG`, then config files, then `TUWUNEL_*` environment variables; the chart mounts `tuwunel.toml` and uses env vars only for secret-bearing fields.
- The container must bind `address = "0.0.0.0"`; otherwise Tuwunel defaults to loopback listeners.
- The StatefulSet disables Kubernetes service-link env vars so generated `TUWUNEL_PORT` service variables cannot override Tuwunel's own `port` config.
- OAuth/OIDC providers are configured as repeated `[[global.identity_provider]]` tables. Tuwunel requires either `client_secret` or `client_secret_file` per provider.
- The built-in Matrix next-gen OIDC server starts only when at least one identity provider and `[global.well_known].client` are configured.
- Media can use a top-level `media_storage_providers` list plus `[global.storage_provider.<name>.s3]`; S3 access key and secret are supplied as `TUWUNEL_STORAGE_PROVIDER__<NAME>__S3__KEY/SECRET`.
- MatrixRTC/Element Call needs an external LiveKit SFU plus `lk-jwt-service`; Tuwunel advertises LiveKit through `[global.well_known].livekit_url`.

## Install

```bash
helm install tuwunel ./charts/tuwunel \
  --set serverName=matrix.example.com \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=matrix.example.com
```

## OIDC/OAuth

```yaml
oidc:
  enabled: true
  oidcAwarePreferred: true
  providers:
    - brand: Keycloak
      name: Keycloak
      clientId: tuwunel
      clientSecret: change-me
      issuerUrl: https://sso.example.com/realms/matrix
      callbackUrl: https://matrix.example.com/_matrix/client/unstable/login/sso/callback/tuwunel
      default: true
      trusted: true
      useridClaims: [preferred_username]
```

## Ingress and cert-manager TLS

```yaml
certManager:
  enabled: true
  issuerKind: ClusterIssuer
  issuerName: letsencrypt-prod

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: matrix.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    enabled: true
```

## S3 Media Storage

The chart expects a separately managed S3-compatible endpoint. For local acceptance testing, use `acceptance/juicefs-s3-gateway.yaml`; it is intentionally not part of the chart.

```yaml
mediaStorage:
  s3:
    enabled: true
    providerName: media_on_s3
    bucket: matrix-media
    endpoint: http://tuwunel-juicefs-s3:9000
    accessKey: minioadmin
    secretKey: minioadmin
    useVhostRequest: false
    useHttps: false
    startupCheck: false
```

Tuwunel implements Matrix v1.11 authenticated media by default. If a legacy
client or a browser-only file-open compatibility path still needs the deprecated
unauthenticated media routes, enable them explicitly:

```yaml
config:
  allowLegacyMedia: true
```

## LiveKit Subchart

LiveKit is bundled as the `livekit` subchart and stays disabled by default.

```yaml
livekit:
  enabled: true
  host: matrix-rtc.example.com
  publicUrl: https://matrix-rtc.example.com
  livekitUrl: wss://matrix-rtc.example.com
  fullAccessHomeservers: matrix.example.com
  apiKey: replace-with-random-key
  apiSecret: replace-with-random-secret
  ingress:
    enabled: true
    className: nginx
    tls:
      enabled: true
  certManager:
    enabled: true
    issuerKind: ClusterIssuer
    issuerName: letsencrypt-prod
```

## Lightweight Web Client

For a small self-hosted browser client, enable the bundled `cinny` subchart.
Cinny is lighter than Element Web and is served by nginx; the parent Tuwunel
chart renders its `config.json` so it can point users at this homeserver.

```yaml
serverName: matrix.example.com
publicUrl: https://matrix.example.com

cinny:
  enabled: true
  publicUrl: https://chat.example.com
  config:
    # Optional. Leave empty to auto-point Cinny at serverName.
    homeserverList: []
    allowCustomHomeservers: false
  ingress:
    enabled: true
    className: nginx
    hosts:
      - host: chat.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      enabled: true
  certManager:
    enabled: true
    issuerKind: ClusterIssuer
    issuerName: letsencrypt-prod
```

If `cinny.config.homeserverList` is empty, the parent chart renders it as
`[serverName]` and sets `defaultHomeserver: 0`, so users land on the Tuwunel
homeserver by default.

For local clusters without an Ingress controller, expose both services with NodePort and point Cinny at the homeserver NodePort:

```yaml
publicUrl: http://<node-ip>:30088
service:
  type: NodePort
  nodePort: 30088

cinny:
  enabled: true
  publicUrl: http://<node-ip>:30081
  service:
    type: NodePort
    nodePort: 30081
  config:
    homeserverList: ["http://<node-ip>:30088"]
```

Some browser/client combinations still open Matrix v1.11 authenticated media
URLs without attaching an `Authorization` header. For local user tests only,
you can expose Cinny through a homeserver compatibility proxy and enable
Tuwunel's deprecated unauthenticated media endpoints:

```yaml
config:
  allowLegacyMedia: true

livekit:
  publicUrl: http://<node-ip>:30089
  livekitUrl: ws://<node-ip>:30090
  livekitServer:
    service:
      type: NodePort
      httpNodePort: 30090
      tcpNodePort: 30091
  jwtService:
    service:
      type: ClusterIP
      port: 8081

cinny:
  enabled: true
  config:
    homeserverList: ["http://<node-ip>:30089"]
    compatibility:
      useBaseUrlForAuthenticatedDiscovery: true
  homeserverProxy:
    enabled: true
    upstream: http://tuwunel:8008
    livekitJwt:
      enabled: true
      upstream: http://tuwunel-livekit-jwt:8081
    service:
      type: NodePort
      nodePort: 30089
```

## Local k0s Acceptance

The acceptance path deploys supporting services separately from the chart, installs Tuwunel with S3/OIDC/LiveKit enabled, then runs module-level E2E checks from inside the cluster:

- Rauthy is deployed as the real OIDC provider with a bootstrapped Tuwunel OAuth client and PVC-backed Hiqlite data.
- JuiceFS S3 gateway is deployed separately as the S3-compatible media backend with PVC-backed object and metadata storage.
- Cinny is deployed as the lightweight self-hosted web client and checked for a generated homeserver config.
- A `matrix-nio` client job registers two Matrix users, creates a room, exchanges messages, uploads/downloads media through S3, then stores test state on a PVC.
- The runner restarts JuiceFS, Rauthy, and Tuwunel, then logs the Matrix users back in, verifies persisted room history and media, and sends a post-restart message.
- LiveKit remains a bundled subchart; acceptance verifies Tuwunel's well-known LiveKit advertisement and `lk-jwt-service` health.

```bash
charts/tuwunel/acceptance/run-k0s.sh
```

This script uses namespace `tuwunel-acceptance-e2e` by default. Override with `NS=...`; use `RESET_NAMESPACE=true` for a clean local run.
