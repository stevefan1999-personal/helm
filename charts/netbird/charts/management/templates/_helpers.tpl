{{/*
Expand the name of the chart.
*/}}
{{- define "management.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "management.fullname" -}}
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

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "management.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "management.labels" -}}
helm.sh/chart: {{ include "management.chart" . }}
{{ include "management.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "management.selectorLabels" -}}
app.kubernetes.io/name: {{ include "management.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the authority URL
*/}}
{{- define "netbird.auth.authority" -}}
{{- coalesce .Values.global.auth.authority (include "netbird.keycloak.realmUrl" .) -}}
{{- end -}}

{{/*
Create the keycloak realm URL
*/}}
{{- define "netbird.keycloak.realmUrl" -}}
{{- printf "https://%s/realms/%s" .Values.global.keycloak.fqdn .Values.global.keycloak.realm -}}
{{- end -}}

{{/*
Create the keycloak token endpoint URL
*/}}
{{- define "netbird.keycloak.tokenUrl" -}}
{{- printf "%s/protocol/openid-connect/token" (include "netbird.auth.authority" .) -}}
{{- end -}}

{{/*
Create the keycloak authorization endpoint URL
*/}}
{{- define "netbird.keycloak.authUrl" -}}
{{- printf "%s/protocol/openid-connect/auth" (include "netbird.auth.authority" .) -}}
{{- end -}}

{{/*
Create the keycloak device authorization endpoint URL
*/}}
{{- define "netbird.keycloak.deviceAuthUrl" -}}
{{- printf "%s/protocol/openid-connect/auth/device" (include "netbird.auth.authority" .) -}}
{{- end -}}

{{/*
Create the store engine
*/}}
{{- define "netbird.store.engine" -}}
{{- if include "netbird.postgresql.enabled" . -}}
{{- print "postgres" -}}
{{- else -}}
{{- print .Values.store.engine -}}
{{- end -}}
{{- end -}}

{{/*
Create the stuns json array
*/}}
{{- define "netbird.stuns" -}}
{{- $stuns := list -}}
{{- range .Values.global.auth.stuns.servers -}}
{{- $stuns = append $stuns (dict "Proto" .proto "URI" .uri) -}}
{{- end -}}
{{- $stuns | toJson -}}
{{- end -}}

{{/*
Create the turns json array
*/}}
{{- define "netbird.turns" -}}
{{- $turns := list -}}
{{- range .Values.global.auth.turn.servers -}}
{{- $turns = append $turns (dict "Proto" .proto "URI" .uri "Username" .user "Password" .password) -}}
{{- end -}}
{{- $turns | toJson -}}
{{- end -}}

{{/*
Create the redirect urls json array
*/}}
{{- define "netbird.redirectURLs" -}}
{{- .Values.global.auth.pkce.redirectURLs | toJson -}}
{{- end -}}

{{/*
Create the wait-for-db command
*/}}
{{- define "netbird.postgresql.enabled" -}}
{{- or .Values.global.postgresql.external.enabled .Values.global.postgresql.cnpg.enabled -}}
{{- end -}}

{{- define "netbird.postgresql.host" -}}
{{- if .Values.global.postgresql.external.enabled -}}
{{- .Values.global.postgresql.external.host -}}
{{- else -}}
{{- printf "%s-postgresql-rw" .Release.Name -}}
{{- end -}}
{{- end -}}

{{- define "netbird.postgresql.port" -}}
{{- if .Values.global.postgresql.external.enabled -}}
{{- .Values.global.postgresql.external.port -}}
{{- else -}}
{{- print "5432" -}}
{{- end -}}
{{- end -}}

{{- define "netbird.wait-for-db" -}}
'until nc -z {{ include "netbird.postgresql.host" . }} {{ include "netbird.postgresql.port" . }}; do echo waiting for postgresql; sleep 2; done;'
{{- end -}}
