{{/* Expand the name of the chart. */}}
{{- define "tuwunel.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Create a default fully qualified app name. */}}
{{- define "tuwunel.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Create chart name and version label. */}}
{{- define "tuwunel.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Common labels. */}}
{{- define "tuwunel.labels" -}}
helm.sh/chart: {{ include "tuwunel.chart" . }}
{{ include "tuwunel.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/* Selector labels. */}}
{{- define "tuwunel.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tuwunel.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "tuwunel.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "tuwunel.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "tuwunel.publicUrl" -}}
{{- default (printf "https://%s" .Values.serverName) .Values.publicUrl -}}
{{- end -}}

{{- define "tuwunel.wellKnownClient" -}}
{{- default (include "tuwunel.publicUrl" .) .Values.wellKnown.client -}}
{{- end -}}

{{- define "tuwunel.wellKnownServer" -}}
{{- default (printf "%s:443" .Values.serverName) .Values.wellKnown.server -}}
{{- end -}}

{{- define "tuwunel.secretName" -}}
{{- printf "%s-secrets" (include "tuwunel.fullname" .) -}}
{{- end -}}

{{- define "tuwunel.hasGeneratedSecret" -}}
{{- $has := false -}}
{{- if and .Values.registration.enabled .Values.registration.token -}}{{- $has = true -}}{{- end -}}
{{- if and .Values.jwt.enabled .Values.jwt.key -}}{{- $has = true -}}{{- end -}}
{{- if and .Values.turn.secret -}}{{- $has = true -}}{{- end -}}
{{- if .Values.mediaStorage.s3.enabled -}}{{- $has = true -}}{{- end -}}
{{- if .Values.oidc.enabled -}}
{{- range .Values.oidc.providers -}}
{{- if .clientSecret -}}{{- $has = true -}}{{- end -}}
{{- end -}}
{{- end -}}
{{- ternary "true" "false" $has -}}
{{- end -}}

{{- define "tuwunel.mountGeneratedSecret" -}}
{{- $mount := false -}}
{{- if and .Values.registration.enabled .Values.registration.token -}}{{- $mount = true -}}{{- end -}}
{{- if and .Values.turn.secret -}}{{- $mount = true -}}{{- end -}}
{{- if .Values.oidc.enabled -}}
{{- range .Values.oidc.providers -}}
{{- if .clientSecret -}}{{- $mount = true -}}{{- end -}}
{{- end -}}
{{- end -}}
{{- ternary "true" "false" $mount -}}
{{- end -}}

{{- define "tuwunel.s3Endpoint" -}}
{{- default "" .Values.mediaStorage.s3.endpoint -}}
{{- end -}}

{{- define "tuwunel.s3AccessKey" -}}
{{- .Values.mediaStorage.s3.accessKey -}}
{{- end -}}

{{- define "tuwunel.s3SecretKey" -}}
{{- .Values.mediaStorage.s3.secretKey -}}
{{- end -}}

{{- define "tuwunel.livekitPublicUrl" -}}
{{- default (printf "https://%s" .Values.livekit.host) .Values.livekit.publicUrl -}}
{{- end -}}

{{- define "tuwunel.livekitJwtLivekitUrl" -}}
{{- default (printf "wss://%s" .Values.livekit.host) .Values.livekit.livekitUrl -}}
{{- end -}}

{{- define "tuwunel.livekitAdvertisedUrl" -}}
{{- if .Values.wellKnown.livekitUrl -}}
{{- .Values.wellKnown.livekitUrl -}}
{{- else if .Values.livekit.enabled -}}
{{- include "tuwunel.livekitPublicUrl" . -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{- define "tuwunel.certManagerAnnotations" -}}
{{- if .Values.certManager.enabled }}
cert-manager.io/{{ .Values.certManager.issuerKind | lower }}: {{ .Values.certManager.issuerName | quote }}
{{- end -}}
{{- end -}}

{{- define "tuwunel.cinnyName" -}}
{{- $base := include "tuwunel.fullname" . -}}
{{- if .Values.cinny.fullnameOverride -}}
{{- .Values.cinny.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "cinny" .Values.cinny.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "tuwunel.cinnySelectorLabels" -}}
app.kubernetes.io/name: {{ include "tuwunel.cinnyName" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: web-client
{{- end -}}

{{- define "tuwunel.cinnyLabels" -}}
helm.sh/chart: {{ printf "%s-%s" "cinny" "0.1.0" | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "tuwunel.cinnySelectorLabels" . }}
app.kubernetes.io/version: "latest"
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "tuwunel.cinnyConfigMapName" -}}
{{- default (printf "%s-config" (include "tuwunel.cinnyName" .)) .Values.cinny.config.existingConfigMap -}}
{{- end -}}

{{- define "tuwunel.cinnyHomeserverProxyName" -}}
{{- if .Values.cinny.homeserverProxy.fullnameOverride -}}
{{- .Values.cinny.homeserverProxy.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-homeserver-proxy" (include "tuwunel.cinnyName" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
