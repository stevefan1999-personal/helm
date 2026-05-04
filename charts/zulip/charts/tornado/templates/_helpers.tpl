{{- define "tornado.baseName" -}}
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

{{- define "tornado.name" -}}
{{- default "zulip" .Values.appName | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "tornado.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-tornado" (include "tornado.baseName" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{- define "tornado.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "tornado.selectorLabels" -}}
app.kubernetes.io/name: {{ include "tornado.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: tornado
{{- end }}

{{- define "tornado.labels" -}}
helm.sh/chart: {{ include "tornado.chart" . }}
{{ include "tornado.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "tornado.serviceAccountName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $globalName := get $zulip "serviceAccountName" | default "" -}}
{{- default (default (include "tornado.baseName" .) $globalName) .Values.serviceAccountName -}}
{{- end }}

{{- define "tornado.imageRepository" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $globalImage := get $zulip "image" | default dict -}}
{{- default (default "ghcr.io/zulip/zulip-server" (get $globalImage "repository")) .Values.image.repository -}}
{{- end }}

{{- define "tornado.imageTag" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $globalImage := get $zulip "image" | default dict -}}
{{- default (default .Chart.AppVersion (get $globalImage "tag")) .Values.image.tag -}}
{{- end }}

{{- define "tornado.imagePullPolicy" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $globalImage := get $zulip "image" | default dict -}}
{{- default (default "IfNotPresent" (get $globalImage "pullPolicy")) .Values.image.pullPolicy -}}
{{- end }}

{{- define "tornado.image" -}}
{{- printf "%s:%s" (include "tornado.imageRepository" .) (include "tornado.imageTag" .) -}}
{{- end }}

{{- define "tornado.imagePullSecrets" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- if .Values.imagePullSecrets }}
{{- toYaml .Values.imagePullSecrets -}}
{{- else if get $zulip "imagePullSecrets" }}
{{- toYaml (get $zulip "imagePullSecrets") -}}
{{- end }}
{{- end }}

{{- define "tornado.configMapName" -}}
{{- printf "%s-config" (include "tornado.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "tornado.secretName" -}}
{{- printf "%s-secrets" (include "tornado.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "tornado.sharedEnvConfigMapName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $globalName := get $zulip "envConfigMapName" | default "" -}}
{{- default (default (printf "%s-env" (include "tornado.baseName" .)) $globalName) .Values.sharedEnv.configMapName -}}
{{- end }}

{{- define "tornado.sharedEnvSecretName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $globalName := get $zulip "envSecretName" | default "" -}}
{{- default (default (printf "%s-env" (include "tornado.baseName" .)) $globalName) .Values.sharedEnv.secretName -}}
{{- end }}

{{- define "tornado.runtimeConfigMapName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- default (printf "%s-runtime" (include "tornado.baseName" .)) (get $zulip "runtimeConfigMapName" | default "") | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "tornado.appConfigMapName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- default (printf "%s-app-config" (include "tornado.baseName" .)) (get $zulip "appConfigMapName" | default "") | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "tornado.volumeMounts" -}}
- name: zulip-runtime
  mountPath: /opt/zulip-k8s
  readOnly: true
- name: zulip-config-template
  mountPath: /etc/zulip-template
  readOnly: true
- name: zulip-etc
  mountPath: /etc/zulip
{{- end }}

{{- define "tornado.podVolumes" -}}
- name: zulip-runtime
  configMap:
    name: {{ include "tornado.runtimeConfigMapName" . }}
    defaultMode: 0755
- name: zulip-config-template
  configMap:
    name: {{ include "tornado.appConfigMapName" . }}
    defaultMode: 0444
- name: zulip-etc
  emptyDir: {}
{{- end }}


{{- define "tornado.initContainers" -}}
{{- if .Values.dependencyGuard.enabled }}
- name: wait-database-migrations
  image: {{ include "tornado.image" . | quote }}
  imagePullPolicy: {{ include "tornado.imagePullPolicy" . }}
  command:
    - /bin/bash
    - /opt/zulip-k8s/wait-database-migrations.sh
  envFrom:
    {{- include "tornado.envFrom" . | nindent 4 }}
  env:
    {{- include "tornado.secretEnv" . | nindent 4 }}
    - name: ZULIP_K8S_WAIT_ATTEMPTS
      value: {{ .Values.dependencyGuard.attempts | default 120 | quote }}
    - name: ZULIP_K8S_WAIT_SLEEP_SECONDS
      value: {{ .Values.dependencyGuard.sleepSeconds | default 5 | quote }}
  volumeMounts:
    {{- include "tornado.volumeMounts" . | nindent 4 }}
- name: wait-object-storage
  image: {{ include "tornado.image" . | quote }}
  imagePullPolicy: {{ include "tornado.imagePullPolicy" . }}
  command:
    - /bin/bash
    - /opt/zulip-k8s/wait-object-storage.sh
  envFrom:
    {{- include "tornado.envFrom" . | nindent 4 }}
  env:
    {{- include "tornado.secretEnv" . | nindent 4 }}
    - name: ZULIP_K8S_WAIT_ATTEMPTS
      value: {{ .Values.dependencyGuard.attempts | default 120 | quote }}
    - name: ZULIP_K8S_WAIT_SLEEP_SECONDS
      value: {{ .Values.dependencyGuard.sleepSeconds | default 5 | quote }}
  volumeMounts:
    {{- include "tornado.volumeMounts" . | nindent 4 }}
{{- end }}
{{- end }}

{{- define "tornado.envFrom" -}}
- configMapRef:
    name: {{ include "tornado.sharedEnvConfigMapName" . }}
- secretRef:
    name: {{ include "tornado.sharedEnvSecretName" . }}
    optional: true
- configMapRef:
    name: {{ include "tornado.configMapName" . }}
- secretRef:
    name: {{ include "tornado.secretName" . }}
    optional: true
{{- end }}

{{- define "tornado.postgresPasswordSecretName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $postgresql := get $zulip "postgresql" | default dict -}}
{{- $globalName := get $postgresql "appSecretName" | default "" -}}
{{- default (default (printf "%s-postgresql-app" (include "tornado.baseName" .)) $globalName) .Values.connections.postgresql.passwordSecretName -}}
{{- end }}

{{- define "tornado.rabbitmqDefaultUserSecretName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $rabbitmq := get $zulip "rabbitmq" | default dict -}}
{{- $globalName := get $rabbitmq "defaultUserSecretName" | default "" -}}
{{- default (default (printf "%s-rabbitmq-default-user" (include "tornado.baseName" .)) $globalName) .Values.connections.rabbitmq.passwordSecretName -}}
{{- end }}

{{- define "tornado.rabbitmqUsernameSecretName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $rabbitmq := get $zulip "rabbitmq" | default dict -}}
{{- $globalName := get $rabbitmq "defaultUserSecretName" | default "" -}}
{{- default (default (printf "%s-rabbitmq-default-user" (include "tornado.baseName" .)) $globalName) .Values.connections.rabbitmq.usernameSecretName -}}
{{- end }}

{{- define "tornado.redisSecretName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $redis := get $zulip "redis" | default dict -}}
{{- $globalName := get $redis "secretName" | default "" -}}
{{- default (default (printf "%s-redis-auth" (include "tornado.baseName" .)) $globalName) .Values.connections.redis.passwordSecretName -}}
{{- end }}

{{- define "tornado.secretEnv" -}}
{{- if .Values.connections.postgresql.passwordFromSecret }}
- name: ZULIP_SECRET_postgres_password
  valueFrom:
    secretKeyRef:
      name: {{ include "tornado.postgresPasswordSecretName" . }}
      key: {{ .Values.connections.postgresql.passwordKey | default "password" }}
{{- end }}
{{- if .Values.connections.rabbitmq.usernameFromSecret }}
- name: ZULIP_SETTING_RABBITMQ_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ include "tornado.rabbitmqUsernameSecretName" . }}
      key: {{ .Values.connections.rabbitmq.usernameKey | default "username" }}
{{- end }}
{{- if .Values.connections.rabbitmq.passwordFromSecret }}
- name: ZULIP_SECRET_rabbitmq_password
  valueFrom:
    secretKeyRef:
      name: {{ include "tornado.rabbitmqDefaultUserSecretName" . }}
      key: {{ .Values.connections.rabbitmq.passwordKey | default "password" }}
{{- end }}
{{- if .Values.connections.redis.passwordFromSecret }}
- name: ZULIP_SECRET_redis_password
  valueFrom:
    secretKeyRef:
      name: {{ include "tornado.redisSecretName" . }}
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

{{- define "tornado.portName" -}}
{{- printf "%s-%v" (include "tornado.fullname" .root) .port | trunc 63 | trimSuffix "-" -}}
{{- end }}
