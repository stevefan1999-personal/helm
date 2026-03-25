{{- define "server.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "server.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "server.labels" -}}
helm.sh/chart: {{ include "server.chart" . }}
{{ include "server.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
PostgreSQL enabled check
*/}}
{{- define "server.postgresql.enabled" -}}
{{- if or .Values.global.postgresql.external.enabled .Values.global.postgresql.cnpg.enabled -}}true{{- end -}}
{{- end -}}

{{/*
PostgreSQL host
*/}}
{{- define "server.postgresql.host" -}}
{{- if .Values.global.postgresql.external.enabled -}}
{{- .Values.global.postgresql.external.host -}}
{{- else -}}
{{- printf "%s-postgresql-rw" .Release.Name -}}
{{- end -}}
{{- end -}}

{{/*
PostgreSQL port
*/}}
{{- define "server.postgresql.port" -}}
{{- if .Values.global.postgresql.external.enabled -}}
{{- .Values.global.postgresql.external.port | toString -}}
{{- else -}}
{{- print "5432" -}}
{{- end -}}
{{- end -}}

{{/*
PostgreSQL DSN
*/}}
{{- define "server.postgresql.dsn" -}}
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
Store engine
*/}}
{{- define "server.store.engine" -}}
{{- if include "server.postgresql.enabled" . -}}
{{- print "postgres" -}}
{{- else -}}
{{- .Values.global.store.engine | default "sqlite" -}}
{{- end -}}
{{- end -}}

{{/*
Exposed address - defaults to https://<server.fqdn>:443
*/}}
{{- define "server.exposedAddress" -}}
{{- printf "https://%s:443" (include "netbird-combined.server.fqdn" .) -}}
{{- end -}}

{{/*
Wait for DB command
*/}}
{{- define "server.wait-for-db" -}}
until nc -z {{ include "server.postgresql.host" . }} {{ include "server.postgresql.port" . }}; do echo waiting for postgresql; sleep 2; done;
{{- end -}}
