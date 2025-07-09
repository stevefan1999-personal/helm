{{/*
Expand the name of the chart.
*/}}
{{- define "netbird.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "netbird.fullname" -}}
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
{{- define "netbird.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "netbird.labels" -}}
helm.sh/chart: {{ include "netbird.chart" . }}
{{ include "netbird.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "netbird.selectorLabels" -}}
app.kubernetes.io/name: {{ include "netbird.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Coalesce helper for common auth fields
*/}}
{{- define "netbird.auth.coalesce" -}}
{{- $ctx := .Context -}}
{{- $authKind := index $ctx.Values.global.auth .AuthKind -}}
{{- $globalAuth := $ctx.Values.global.auth -}}
{{- $key := .Key -}}
{{- $default := .Default -}}

{{- if $authKind -}}
{{- coalesce (index $authKind $key) (index $globalAuth $key) $default -}}
{{- else -}}
{{- coalesce (index $globalAuth $key) $default -}}
{{- end -}}
{{- end -}}

{{/*
Coalesce helper for PKCE related auth fields
*/}}
{{- define "netbird.auth.pkce.audience" -}}
{{- include "netbird.auth.coalesce" (dict "AuthKind" "pkce" "Key" "audience" "Default" $.Values.global.auth.audience "Context" $) -}}
{{- end -}}
{{- define "netbird.auth.pkce.clientId" -}}
{{- include "netbird.auth.coalesce" (dict "AuthKind" "pkce" "Key" "clientId" "Default" $.Values.global.auth.clientId "Context" $) -}}
{{- end -}}
{{- define "netbird.auth.pkce.clientSecret" -}}
{{- include "netbird.auth.coalesce" (dict "AuthKind" "pkce" "Key" "clientSecret" "Default" $.Values.global.auth.clientSecret "Context" $) -}}
{{- end -}}
{{- define "netbird.auth.pkce.tokenEndpoint" -}}
{{- include "netbird.auth.coalesce" (dict "AuthKind" "pkce" "Key" "tokenEndpoint" "Default" (include "netbird.keycloak.tokenUrl" .) "Context" $) -}}
{{- end -}}
{{- define "netbird.auth.pkce.authorizationEndpoint" -}}
{{- include "netbird.auth.coalesce" (dict "AuthKind" "pkce" "Key" "authorizationEndpoint" "Default" (include "netbird.keycloak.authUrl" .) "Context" $) -}}
{{- end -}}
{{- define "netbird.auth.pkce.scope" -}}
{{- include "netbird.auth.coalesce" (dict "AuthKind" "pkce" "Key" "scope" "Default" $.Values.global.auth.supportedScopes "Context" $) -}}
{{- end -}}

{{/*
Coalesce helper for Device Authorization Flow related auth fields
*/}}
{{- define "netbird.auth.deviceAuth.audience" -}}
{{- include "netbird.auth.coalesce" (dict "AuthKind" "deviceAuthorizationFlow" "Key" "audience" "Default" $.Values.global.auth.audience "Context" $) -}}
{{- end -}}
{{- define "netbird.auth.deviceAuth.clientId" -}}
{{- include "netbird.auth.coalesce" (dict "AuthKind" "deviceAuthorizationFlow" "Key" "clientId" "Default" $.Values.global.auth.clientId "Context" $) -}}
{{- end -}}
{{- define "netbird.auth.deviceAuth.tokenEndpoint" -}}
{{- include "netbird.auth.coalesce" (dict "AuthKind" "deviceAuthorizationFlow" "Key" "tokenEndpoint" "Default" (include "netbird.keycloak.tokenUrl" .) "Context" $) -}}
{{- end -}}
{{- define "netbird.auth.deviceAuth.deviceAuthEndpoint" -}}
{{- include "netbird.auth.coalesce" (dict "AuthKind" "deviceAuthorizationFlow" "Key" "deviceAuthEndpoint" "Default" (include "netbird.keycloak.deviceAuthUrl" .) "Context" $) -}}
{{- end -}}
{{- define "netbird.auth.deviceAuth.scope" -}}
{{- include "netbird.auth.coalesce" (dict "AuthKind" "deviceAuthorizationFlow" "Key" "scope" "Default" $.Values.global.auth.supportedScopes "Context" $) -}}
{{- end -}}

{{/*
Coalesce helper for IdpManager related auth fields
*/}}
{{- define "netbird.auth.idpManager.issuer" -}}
{{- include "netbird.auth.coalesce" (dict "AuthKind" "idpManager.clientConfig" "Key" "issuer" "Default" (include "netbird.auth.authority" .) "Context" $) -}}
{{- end -}}
{{- define "netbird.auth.idpManager.tokenEndpoint" -}}
{{- include "netbird.auth.coalesce" (dict "AuthKind" "idpManager.clientConfig" "Key" "tokenEndpoint" "Default" (include "netbird.keycloak.tokenUrl" .) "Context" $) -}}
{{- end -}}
{{- define "netbird.auth.idpManager.clientID" -}}
{{- include "netbird.auth.coalesce" (dict "AuthKind" "idpManager.clientConfig" "Key" "clientID" "Default" $.Values.global.auth.clientId "Context" $) -}}
{{- end -}}
{{- define "netbird.auth.idpManager.clientSecret" -}}
{{- include "netbird.auth.coalesce" (dict "AuthKind" "idpManager.clientConfig" "Key" "clientSecret" "Default" $.Values.global.auth.clientSecret "Context" $) -}}
{{- end -}}

{{/*
Create the OIDC config endpoint URL
*/}}
{{- define "netbird.auth.oidcConfigEndpoint" -}}
{{- printf "%s/.well-known/openid-configuration" (include "netbird.auth.authority" .) -}}
{{- end -}}

{{/*
Coalesce helper for Management API FQDN
*/}}
{{- define "netbird.management.apiFqdn" -}}
{{- coalesce $.Values.global.netbird.management.ingress.http.host $.Values.global.netbird.fqdn -}}
{{- end -}}

{{/*
Coalesce helper for Management gRPC FQDN
*/}}
{{- define "netbird.management.grpcFqdn" -}}
{{- coalesce $.Values.global.netbird.management.ingress.grpc.host $.Values.global.netbird.fqdn -}}
{{- end -}}

{{/*
Coalesce helper for Signal FQDN
*/}}
{{- define "netbird.signal.fqdn" -}}
{{- coalesce $.Values.global.netbird.signal.ingress.host $.Values.global.netbird.fqdn -}}
{{- end -}}

{{/*
Coalesce helper for Relay FQDN
*/}}
{{- define "netbird.relay.fqdn" -}}
{{- coalesce $.Values.global.netbird.relay.ingress.host $.Values.global.netbird.fqdn -}}
{{- end -}}

{{/*
Constructs the Relay.Addresses JSON array for management.json.
*/}}
{{- define "netbird.relay.addresses" -}}
{{- $addresses := list (printf "rels://%s:443" (include "netbird.relay.fqdn" .)) -}}
{{- if .Values.global.netbird.relay.extraAddresses -}}
{{- $addresses = append $addresses .Values.global.netbird.relay.extraAddresses -}}
{{- end -}}
{{- $addresses | toJson -}}
{{- end -}}