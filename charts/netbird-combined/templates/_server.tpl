{{/* Parent-owned combined server resources. */}}

{{- define "netbird-combined.server.configmap" -}}
{{- if .Values.server.enabled }}
# Combined server config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "netbird-combined.server.fullname" . }}-config
  labels:
    {{- include "netbird-combined.server.labels" . | nindent 4 }}
data:
  config.yaml: |-
    server:
      listenAddress: ":{{ .Values.server.listenPort }}"
      exposedAddress: {{ include "netbird-combined.server.exposedAddress" . | quote }}
      stunPorts: {{ .Values.server.stunPorts | toJson }}
      metricsPort: {{ .Values.server.metricsPort }}
      healthcheckAddress: ":{{ .Values.server.healthPort }}"
      logLevel: {{ .Values.server.logLevel | quote }}
      logFile: "console"
      dataDir: "/var/lib/netbird/"
      authSecret: {{ .Values.global.relay.secret | quote }}
      disableAnonymousMetrics: {{ not .Values.server.anonymousMetrics.enabled }}
      disableGeoliteUpdate: {{ not .Values.server.geoliteUpdate.enabled }}
      auth:
        issuer: {{ include "netbird-combined.auth.issuer" . | quote }}
        localAuthDisabled: {{ not .Values.global.auth.localAuth.enabled }}
        signKeyRefreshEnabled: {{ .Values.global.auth.signKeyRefresh.enabled }}
        dashboardRedirectURIs: {{ include "netbird-combined.auth.dashboardRedirectURIs" . }}
        cliRedirectURIs: {{ .Values.global.auth.cliRedirectURIs | toJson }}
        {{- if .Values.global.auth.owner.email }}
        owner:
          email: {{ .Values.global.auth.owner.email | quote }}
          password: {{ .Values.global.auth.owner.password | quote }}
        {{- end }}
      store:
        engine: {{ include "netbird-combined.server.store.engine" . | quote }}
        {{- if include "netbird-combined.postgresql.enabled" . }}
        dsn: {{ include "netbird-combined.postgresql.dsn" . | quote }}
        {{- end }}
        {{- if .Values.global.store.encryptionKey }}
        encryptionKey: {{ .Values.global.store.encryptionKey | quote }}
        {{- end }}
      {{- if .Values.global.activityStore.engine }}
      activityStore:
        engine: {{ .Values.global.activityStore.engine | quote }}
        {{- if .Values.global.activityStore.dsn }}
        dsn: {{ .Values.global.activityStore.dsn | quote }}
        {{- end }}
      {{- end }}
      {{- if .Values.global.authStore.engine }}
      authStore:
        engine: {{ .Values.global.authStore.engine | quote }}
        {{- if .Values.global.authStore.dsn }}
        dsn: {{ .Values.global.authStore.dsn | quote }}
        {{- end }}
      {{- end }}
      reverseProxy:
        trustedHTTPProxies: {{ .Values.global.reverseProxy.trustedHTTPProxies | toJson }}
        trustedHTTPProxiesCount: {{ .Values.global.reverseProxy.trustedHTTPProxiesCount }}
        trustedPeers: {{ .Values.global.reverseProxy.trustedPeers | toJson }}
        accessLogRetentionDays: {{ .Values.global.reverseProxy.accessLogRetentionDays | default 0 }}
        accessLogCleanupIntervalHours: {{ .Values.global.reverseProxy.accessLogCleanupIntervalHours | default 0 }}
      {{- if .Values.global.stuns }}
      stuns:
        {{- range .Values.global.stuns }}
        - uri: {{ .uri | quote }}
          {{- if .proto }}
          proto: {{ .proto | quote }}
          {{- end }}
        {{- end }}
      {{- end }}
      {{- if .Values.global.relays.addresses }}
      relays:
        addresses: {{ .Values.global.relays.addresses | toJson }}
        {{- if .Values.global.relays.credentialsTTL }}
        credentialsTTL: {{ .Values.global.relays.credentialsTTL | quote }}
        {{- end }}
        {{- if .Values.global.relays.secret }}
        secret: {{ .Values.global.relays.secret | quote }}
        {{- end }}
      {{- end }}
      {{- if .Values.global.signalUri }}
      signalUri: {{ .Values.global.signalUri | quote }}
      {{- end }}
{{- end }}
{{- end }}

{{- define "netbird-combined.server.secret" -}}
{{- if and .Values.server.enabled .Values.global.cache.redisAddress }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "netbird-combined.server.fullname" . }}-secrets
  labels:
    {{- include "netbird-combined.server.labels" . | nindent 4 }}
type: Opaque
stringData:
  NB_CACHE_REDIS_ADDRESS: {{ .Values.global.cache.redisAddress | quote }}
{{- end }}
{{- end }}
