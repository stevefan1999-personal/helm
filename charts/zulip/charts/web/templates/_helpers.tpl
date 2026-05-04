{{- define "web.baseName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- if get $zulip "name" -}}
{{- get $zulip "name" | trunc 49 | trimSuffix "-" -}}
{{- else if contains "zulip" .Release.Name -}}
{{- .Release.Name | trunc 49 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-zulip" .Release.Name | trunc 49 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{- define "web.name" -}}
{{- default "zulip" .Values.appName | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "web.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-web" (include "web.baseName" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{- define "web.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "web.selectorLabels" -}}
app.kubernetes.io/name: {{ include "web.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: web
{{- end }}

{{- define "web.labels" -}}
helm.sh/chart: {{ include "web.chart" . }}
{{ include "web.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "web.serviceAccountName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $globalName := get $zulip "serviceAccountName" | default "" -}}
{{- default (default (include "web.baseName" .) $globalName) .Values.serviceAccountName -}}
{{- end }}

{{- define "web.imageRepository" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $globalImage := get $zulip "image" | default dict -}}
{{- default (default "ghcr.io/zulip/zulip-server" (get $globalImage "repository")) .Values.image.repository -}}
{{- end }}

{{- define "web.imageTag" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $globalImage := get $zulip "image" | default dict -}}
{{- default (default .Chart.AppVersion (get $globalImage "tag")) .Values.image.tag -}}
{{- end }}

{{- define "web.imagePullPolicy" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $globalImage := get $zulip "image" | default dict -}}
{{- default (default "IfNotPresent" (get $globalImage "pullPolicy")) .Values.image.pullPolicy -}}
{{- end }}

{{- define "web.image" -}}
{{- printf "%s:%s" (include "web.imageRepository" .) (include "web.imageTag" .) -}}
{{- end }}

{{- define "web.imagePullSecrets" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- if .Values.imagePullSecrets }}
{{- toYaml .Values.imagePullSecrets -}}
{{- else if get $zulip "imagePullSecrets" }}
{{- toYaml (get $zulip "imagePullSecrets") -}}
{{- end }}
{{- end }}

{{- define "web.configMapName" -}}
{{- printf "%s-config" (include "web.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "web.secretName" -}}
{{- printf "%s-secrets" (include "web.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "web.sharedEnvConfigMapName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $globalName := get $zulip "envConfigMapName" | default "" -}}
{{- default (default (printf "%s-env" (include "web.baseName" .)) $globalName) .Values.sharedEnv.configMapName -}}
{{- end }}

{{- define "web.sharedEnvSecretName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $globalName := get $zulip "envSecretName" | default "" -}}
{{- default (default (printf "%s-env" (include "web.baseName" .)) $globalName) .Values.sharedEnv.secretName -}}
{{- end }}

{{- define "web.runtimeConfigMapName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- default (printf "%s-runtime" (include "web.baseName" .)) (get $zulip "runtimeConfigMapName" | default "") | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "web.appConfigMapName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- default (printf "%s-app-config" (include "web.baseName" .)) (get $zulip "appConfigMapName" | default "") | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "web.volumeMounts" -}}
- name: zulip-runtime
  mountPath: /opt/zulip-k8s
  readOnly: true
- name: zulip-config-template
  mountPath: /etc/zulip-template
  readOnly: true
- name: zulip-etc
  mountPath: /etc/zulip
{{- end }}

{{- define "web.podVolumes" -}}
- name: zulip-runtime
  configMap:
    name: {{ include "web.runtimeConfigMapName" . }}
    defaultMode: 0755
- name: zulip-config-template
  configMap:
    name: {{ include "web.appConfigMapName" . }}
    defaultMode: 0444
- name: zulip-etc
  emptyDir: {}
{{- end }}


{{- define "web.initContainers" -}}
{{- if .Values.dependencyGuard.enabled }}
- name: wait-database-migrations
  image: {{ include "web.image" . | quote }}
  imagePullPolicy: {{ include "web.imagePullPolicy" . }}
  command:
    - /bin/bash
    - /opt/zulip-k8s/wait-database-migrations.sh
  envFrom:
    {{- include "web.envFrom" . | nindent 4 }}
  env:
    {{- include "web.secretEnv" . | nindent 4 }}
    - name: ZULIP_K8S_WAIT_ATTEMPTS
      value: {{ .Values.dependencyGuard.attempts | default 120 | quote }}
    - name: ZULIP_K8S_WAIT_SLEEP_SECONDS
      value: {{ .Values.dependencyGuard.sleepSeconds | default 5 | quote }}
  volumeMounts:
    {{- include "web.volumeMounts" . | nindent 4 }}
- name: wait-object-storage
  image: {{ include "web.image" . | quote }}
  imagePullPolicy: {{ include "web.imagePullPolicy" . }}
  command:
    - /bin/bash
    - /opt/zulip-k8s/wait-object-storage.sh
  envFrom:
    {{- include "web.envFrom" . | nindent 4 }}
  env:
    {{- include "web.secretEnv" . | nindent 4 }}
    - name: ZULIP_K8S_WAIT_ATTEMPTS
      value: {{ .Values.dependencyGuard.attempts | default 120 | quote }}
    - name: ZULIP_K8S_WAIT_SLEEP_SECONDS
      value: {{ .Values.dependencyGuard.sleepSeconds | default 5 | quote }}
  volumeMounts:
    {{- include "web.volumeMounts" . | nindent 4 }}
{{- end }}
{{- end }}

{{- define "web.envFrom" -}}
- configMapRef:
    name: {{ include "web.sharedEnvConfigMapName" . }}
- secretRef:
    name: {{ include "web.sharedEnvSecretName" . }}
    optional: true
- configMapRef:
    name: {{ include "web.configMapName" . }}
- secretRef:
    name: {{ include "web.secretName" . }}
    optional: true
{{- end }}

{{- define "web.postgresPasswordSecretName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $postgresql := get $zulip "postgresql" | default dict -}}
{{- $globalName := get $postgresql "appSecretName" | default "" -}}
{{- default (default (printf "%s-postgresql-app" (include "web.baseName" .)) $globalName) .Values.connections.postgresql.passwordSecretName -}}
{{- end }}

{{- define "web.rabbitmqDefaultUserSecretName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $rabbitmq := get $zulip "rabbitmq" | default dict -}}
{{- $globalName := get $rabbitmq "defaultUserSecretName" | default "" -}}
{{- default (default (printf "%s-rabbitmq-default-user" (include "web.baseName" .)) $globalName) .Values.connections.rabbitmq.passwordSecretName -}}
{{- end }}

{{- define "web.rabbitmqUsernameSecretName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $rabbitmq := get $zulip "rabbitmq" | default dict -}}
{{- $globalName := get $rabbitmq "defaultUserSecretName" | default "" -}}
{{- default (default (printf "%s-rabbitmq-default-user" (include "web.baseName" .)) $globalName) .Values.connections.rabbitmq.usernameSecretName -}}
{{- end }}

{{- define "web.redisSecretName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $redis := get $zulip "redis" | default dict -}}
{{- $globalName := get $redis "secretName" | default "" -}}
{{- default (default (printf "%s-redis-auth" (include "web.baseName" .)) $globalName) .Values.connections.redis.passwordSecretName -}}
{{- end }}

{{- define "web.secretEnv" -}}
{{- if .Values.connections.postgresql.passwordFromSecret }}
- name: ZULIP_SECRET_postgres_password
  valueFrom:
    secretKeyRef:
      name: {{ include "web.postgresPasswordSecretName" . }}
      key: {{ .Values.connections.postgresql.passwordKey | default "password" }}
{{- end }}
{{- if .Values.connections.rabbitmq.usernameFromSecret }}
- name: ZULIP_SETTING_RABBITMQ_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ include "web.rabbitmqUsernameSecretName" . }}
      key: {{ .Values.connections.rabbitmq.usernameKey | default "username" }}
{{- end }}
{{- if .Values.connections.rabbitmq.passwordFromSecret }}
- name: ZULIP_SECRET_rabbitmq_password
  valueFrom:
    secretKeyRef:
      name: {{ include "web.rabbitmqDefaultUserSecretName" . }}
      key: {{ .Values.connections.rabbitmq.passwordKey | default "password" }}
{{- end }}
{{- if .Values.connections.redis.passwordFromSecret }}
- name: ZULIP_SECRET_redis_password
  valueFrom:
    secretKeyRef:
      name: {{ include "web.redisSecretName" . }}
      key: {{ .Values.connections.redis.passwordKey | default "redis-password" }}
{{- end }}
{{- $global := .Values.global | default dict }}
{{- $zulip := get $global "zulip" | default dict }}
{{- $extraEnv := get $zulip "extraEnv" | default dict }}
{{- range $key, $value := $extraEnv }}
{{- if kindIs "map" $value }}
- name: {{ $key }}
  {{- toYaml $value | nindent 2 }}
{{- end }}
{{- end }}
{{- range $item := .Values.extraEnv }}
- {{ toYaml $item | nindent 2 | trim }}
{{- end }}
{{- end }}

{{- define "web.tornadoServicePrefix" -}}
{{- default (printf "%s-tornado" (include "web.baseName" .)) .Values.tornadoProxy.servicePrefix -}}
{{- end }}

{{- define "web.outboundTornadoProxyContainer" -}}
- name: tornado-proxy
  image: {{ printf "%s:%s" .Values.tornadoProxy.image.repository .Values.tornadoProxy.image.tag | quote }}
  imagePullPolicy: {{ .Values.tornadoProxy.image.pullPolicy }}
  command:
    - /bin/sh
    - -ec
  args:
    - |
      for port in ${ZULIP_K8S_TORNADO_PORTS}; do
        socat "TCP-LISTEN:${port},bind=127.0.0.1,fork,reuseaddr" "TCP:${ZULIP_K8S_TORNADO_SERVICE_PREFIX}-${port}:${port}" &
      done
      wait
  env:
    - name: ZULIP_K8S_TORNADO_PORTS
      value: {{ join " " (toStrings .Values.tornadoProxy.ports) | quote }}
    - name: ZULIP_K8S_TORNADO_SERVICE_PREFIX
      value: {{ include "web.tornadoServicePrefix" . | quote }}
  resources:
    {{- toYaml .Values.tornadoProxy.resources | nindent 4 }}
{{- end }}

{{- define "web.djangoName" -}}
{{- printf "%s-django" (include "web.baseName" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "web.djangoSelectorLabels" -}}
app.kubernetes.io/name: {{ include "web.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: django
{{- end }}

{{- define "web.djangoLabels" -}}
helm.sh/chart: {{ include "web.chart" . }}
{{ include "web.djangoSelectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
