{{/*
Determine if PostgreSQL is enabled.
Returns non-empty string (truthy) when enabled, empty (falsy) when not.
*/}}
{{- define "netbird-combined.postgresql.enabled" -}}
{{- if or .Values.global.postgresql.external.enabled .Values.global.postgresql.cnpg.enabled -}}true{{- end -}}
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
{{- list (printf "https://%s/nb-auth" .Values.global.fqdn) (printf "https://%s/nb-silent-auth" .Values.global.fqdn) | toJson -}}
{{- end -}}
{{- end -}}

{{/*
Server FQDN
*/}}
{{- define "netbird-combined.server.fqdn" -}}
{{- coalesce .Values.global.server.ingress.host .Values.global.fqdn -}}
{{- end -}}

{{/*
Dashboard FQDN
*/}}
{{- define "netbird-combined.dashboard.fqdn" -}}
{{- coalesce .Values.global.dashboard.ingress.host .Values.global.fqdn -}}
{{- end -}}
