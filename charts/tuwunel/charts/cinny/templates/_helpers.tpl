{{- define "cinny.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "cinny.fullname" -}}
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

{{- define "cinny.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "cinny.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cinny.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: web-client
{{- end -}}

{{- define "cinny.labels" -}}
helm.sh/chart: {{ include "cinny.chart" . }}
{{ include "cinny.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "cinny.certManagerAnnotations" -}}
{{- if .Values.certManager.enabled }}
cert-manager.io/{{ .Values.certManager.issuerKind | lower }}: {{ .Values.certManager.issuerName | quote }}
{{- end -}}
{{- end -}}

{{- define "cinny.configMapName" -}}
{{- default (printf "%s-config" (include "cinny.fullname" .)) .Values.config.existingConfigMap -}}
{{- end -}}

{{- define "cinny.homeserverProxyName" -}}
{{- if .Values.homeserverProxy.fullnameOverride -}}
{{- .Values.homeserverProxy.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-homeserver-proxy" (include "cinny.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "cinny.homeserverProxySelectorLabels" -}}
app.kubernetes.io/name: {{ include "cinny.name" . }}-homeserver-proxy
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: homeserver-proxy
{{- end -}}

{{- define "cinny.homeserverProxyLabels" -}}
helm.sh/chart: {{ include "cinny.chart" . }}
{{ include "cinny.homeserverProxySelectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
