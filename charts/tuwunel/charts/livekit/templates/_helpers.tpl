{{- define "livekit.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "livekit.fullname" -}}
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

{{- define "livekit.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "livekit.labels" -}}
helm.sh/chart: {{ include "livekit.chart" . }}
{{ include "livekit.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "livekit.selectorLabels" -}}
app.kubernetes.io/name: {{ include "livekit.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "livekit.serverSelectorLabels" -}}
{{ include "livekit.selectorLabels" . }}
app.kubernetes.io/component: server
{{- end -}}

{{- define "livekit.jwtSelectorLabels" -}}
{{ include "livekit.selectorLabels" . }}
app.kubernetes.io/component: jwt
{{- end -}}

{{- define "livekit.publicUrl" -}}
{{- default (printf "https://%s" .Values.host) .Values.publicUrl -}}
{{- end -}}

{{- define "livekit.jwtLivekitUrl" -}}
{{- default (printf "wss://%s" .Values.host) .Values.livekitUrl -}}
{{- end -}}

{{- define "livekit.secretName" -}}
{{- printf "%s-secrets" (include "livekit.fullname" .) -}}
{{- end -}}

{{- define "livekit.certManagerAnnotations" -}}
{{- if .Values.certManager.enabled }}
cert-manager.io/{{ .Values.certManager.issuerKind | lower }}: {{ .Values.certManager.issuerName | quote }}
{{- end -}}
{{- end -}}
