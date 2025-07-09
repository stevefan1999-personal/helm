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