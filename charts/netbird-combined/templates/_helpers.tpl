{{/*
Determine if PostgreSQL is enabled.
Returns non-empty string (truthy) when enabled, empty (falsy) when not.
*/}}
{{- define "netbird-combined.postgresql.enabled" -}}
{{- if or .Values.global.postgresql.external.enabled .Values.global.postgresql.cnpg.enabled -}}true{{- end -}}
{{- end -}}

{{- define "netbird-combined.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
PostgreSQL host
*/}}
{{- define "netbird-combined.postgresql.host" -}}
{{- if .Values.global.postgresql.external.enabled -}}
{{- .Values.global.postgresql.external.host -}}
{{- else -}}
{{- printf "%s-postgresql-rw" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/*
PostgreSQL port
*/}}
{{- define "netbird-combined.postgresql.port" -}}
{{- if .Values.global.postgresql.external.enabled -}}
{{- .Values.global.postgresql.external.port | toString -}}
{{- else -}}
{{- print "5432" -}}
{{- end -}}
{{- end -}}

{{/*
PostgreSQL DSN
*/}}
{{- define "netbird-combined.postgresql.dsn" -}}
{{- if .Values.global.postgresql.external.enabled -}}
{{- printf "host=%s user=%s password=%s dbname=%s port=%s"
    .Values.global.postgresql.external.host
    .Values.global.postgresql.external.user
    .Values.global.postgresql.external.password
    .Values.global.postgresql.external.database
    (.Values.global.postgresql.external.port | toString) -}}
{{- else if .Values.global.postgresql.cnpg.enabled -}}
{{- printf "host=%s-postgresql-rw user=postgres password=%s dbname=postgres port=5432"
    .Release.Name
    (.Values.global.postgresql.cnpg.password | default "postgres") -}}
{{- end -}}
{{- end -}}

{{/*
Auth issuer - defaults to https://<fqdn>/oauth2
*/}}
{{- define "netbird-combined.auth.issuer" -}}
{{- if .Values.global.auth.issuer -}}
{{- .Values.global.auth.issuer -}}
{{- else -}}
{{- printf "https://%s/oauth2" .Values.global.fqdn -}}
{{- end -}}
{{- end -}}

{{/*
Dashboard redirect URIs - defaults based on fqdn
*/}}
{{- define "netbird-combined.auth.dashboardRedirectURIs" -}}
{{- if .Values.global.auth.dashboardRedirectURIs -}}
{{- .Values.global.auth.dashboardRedirectURIs | toJson -}}
{{- else -}}
{{- $dashboardFqdn := include "netbird-combined.dashboard.fqdn" . -}}
{{- list (printf "https://%s/nb-auth" $dashboardFqdn) (printf "https://%s/nb-silent-auth" $dashboardFqdn) | toJson -}}
{{- end -}}
{{- end -}}

{{/*
Server FQDN
*/}}
{{- define "netbird-combined.server.fqdn" -}}
{{- coalesce .Values.global.server.ingress.host .Values.global.fqdn -}}
{{- end -}}

{{/*
Server store engine
*/}}
{{- define "netbird-combined.server.store.engine" -}}
{{- if include "netbird-combined.postgresql.enabled" . -}}
{{- print "postgres" -}}
{{- else -}}
{{- .Values.global.store.engine | default "sqlite" -}}
{{- end -}}
{{- end -}}

{{/*
Exposed address - defaults to https://<server.fqdn>:443
*/}}
{{- define "netbird-combined.server.exposedAddress" -}}
{{- coalesce .Values.global.server.exposedAddress (printf "https://%s:443" (include "netbird-combined.server.fqdn" .)) -}}
{{- end -}}

{{/*
Wait for DB command
*/}}
{{- define "netbird-combined.server.wait-for-db" -}}
until nc -z {{ include "netbird-combined.postgresql.host" . }} {{ include "netbird-combined.postgresql.port" . }}; do echo waiting for postgresql; sleep 2; done;
{{- end -}}

{{/*
Dashboard FQDN
*/}}
{{- define "netbird-combined.dashboard.fqdn" -}}
{{- coalesce .Values.global.dashboard.ingress.host .Values.global.fqdn -}}
{{- end -}}

{{/*
Combined server pod selector labels. Sidecar Services target the server pod.
*/}}
{{- define "netbird-combined.server.name" -}}
{{- default "server" .Values.server.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "netbird-combined.server.fullname" -}}
{{- if .Values.server.fullnameOverride }}
{{- .Values.server.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := include "netbird-combined.server.name" . }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "netbird-combined.server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "netbird-combined.server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "netbird-combined.server.labels" -}}
helm.sh/chart: {{ include "netbird-combined.chart" . }}
{{ include "netbird-combined.server.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "netbird-combined.dashboard.labels" -}}
app.kubernetes.io/name: dashboard
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.dashboard.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "netbird-combined.dashboard.checksumInput" -}}
{{- dict "global" .Values.global "dashboard" .Values.dashboard | toJson -}}
{{- end -}}

{{- define "netbird-combined.proxy.labels" -}}
app.kubernetes.io/name: proxy
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.proxy.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
