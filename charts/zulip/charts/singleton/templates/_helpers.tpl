{{- define "singleton.baseName" -}}
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

{{- define "singleton.name" -}}
{{- default "zulip" .Values.appName | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "singleton.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-singleton" (include "singleton.baseName" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{- define "singleton.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "singleton.selectorLabels" -}}
app.kubernetes.io/name: {{ include "singleton.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: singleton
{{- end }}

{{- define "singleton.labels" -}}
helm.sh/chart: {{ include "singleton.chart" . }}
{{ include "singleton.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "singleton.serviceAccountName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $globalName := get $zulip "serviceAccountName" | default "" -}}
{{- default (default (include "singleton.baseName" .) $globalName) .Values.serviceAccountName -}}
{{- end }}

{{- define "singleton.imageRepository" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $globalImage := get $zulip "image" | default dict -}}
{{- default (default "ghcr.io/zulip/zulip-server" (get $globalImage "repository")) .Values.image.repository -}}
{{- end }}

{{- define "singleton.imageTag" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $globalImage := get $zulip "image" | default dict -}}
{{- default (default .Chart.AppVersion (get $globalImage "tag")) .Values.image.tag -}}
{{- end }}

{{- define "singleton.imagePullPolicy" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $globalImage := get $zulip "image" | default dict -}}
{{- default (default "IfNotPresent" (get $globalImage "pullPolicy")) .Values.image.pullPolicy -}}
{{- end }}

{{- define "singleton.image" -}}
{{- printf "%s:%s" (include "singleton.imageRepository" .) (include "singleton.imageTag" .) -}}
{{- end }}

{{- define "singleton.imagePullSecrets" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- if .Values.imagePullSecrets }}
{{- toYaml .Values.imagePullSecrets -}}
{{- else if get $zulip "imagePullSecrets" }}
{{- toYaml (get $zulip "imagePullSecrets") -}}
{{- end }}
{{- end }}

{{- define "singleton.configMapName" -}}
{{- printf "%s-config" (include "singleton.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "singleton.secretName" -}}
{{- printf "%s-secrets" (include "singleton.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "singleton.sharedEnvConfigMapName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $globalName := get $zulip "envConfigMapName" | default "" -}}
{{- default (default (printf "%s-env" (include "singleton.baseName" .)) $globalName) .Values.sharedEnv.configMapName -}}
{{- end }}

{{- define "singleton.sharedEnvSecretName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $globalName := get $zulip "envSecretName" | default "" -}}
{{- default (default (printf "%s-env" (include "singleton.baseName" .)) $globalName) .Values.sharedEnv.secretName -}}
{{- end }}

{{- define "singleton.runtimeConfigMapName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- default (printf "%s-runtime" (include "singleton.baseName" .)) (get $zulip "runtimeConfigMapName" | default "") | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "singleton.appConfigMapName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- default (printf "%s-app-config" (include "singleton.baseName" .)) (get $zulip "appConfigMapName" | default "") | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "singleton.volumeMounts" -}}
- name: zulip-runtime
  mountPath: /opt/zulip-k8s
  readOnly: true
- name: zulip-config-template
  mountPath: /etc/zulip-template
  readOnly: true
- name: zulip-etc
  mountPath: /etc/zulip
{{- end }}

{{- define "singleton.podVolumes" -}}
- name: zulip-runtime
  configMap:
    name: {{ include "singleton.runtimeConfigMapName" . }}
    defaultMode: 0755
- name: zulip-config-template
  configMap:
    name: {{ include "singleton.appConfigMapName" . }}
    defaultMode: 0444
- name: zulip-etc
  emptyDir: {}
{{- end }}


{{- define "singleton.initContainers" -}}
{{- if .Values.dependencyGuard.enabled }}
- name: wait-database-migrations
  image: {{ include "singleton.image" . | quote }}
  imagePullPolicy: {{ include "singleton.imagePullPolicy" . }}
  command:
    - /bin/bash
    - /opt/zulip-k8s/wait-database-migrations.sh
  envFrom:
    {{- include "singleton.envFrom" . | nindent 4 }}
  env:
    {{- include "singleton.secretEnv" . | nindent 4 }}
    - name: ZULIP_K8S_WAIT_ATTEMPTS
      value: {{ .Values.dependencyGuard.attempts | default 120 | quote }}
    - name: ZULIP_K8S_WAIT_SLEEP_SECONDS
      value: {{ .Values.dependencyGuard.sleepSeconds | default 5 | quote }}
  volumeMounts:
    {{- include "singleton.volumeMounts" . | nindent 4 }}
- name: wait-object-storage
  image: {{ include "singleton.image" . | quote }}
  imagePullPolicy: {{ include "singleton.imagePullPolicy" . }}
  command:
    - /bin/bash
    - /opt/zulip-k8s/wait-object-storage.sh
  envFrom:
    {{- include "singleton.envFrom" . | nindent 4 }}
  env:
    {{- include "singleton.secretEnv" . | nindent 4 }}
    - name: ZULIP_K8S_WAIT_ATTEMPTS
      value: {{ .Values.dependencyGuard.attempts | default 120 | quote }}
    - name: ZULIP_K8S_WAIT_SLEEP_SECONDS
      value: {{ .Values.dependencyGuard.sleepSeconds | default 5 | quote }}
  volumeMounts:
    {{- include "singleton.volumeMounts" . | nindent 4 }}
{{- end }}
{{- end }}

{{- define "singleton.envFrom" -}}
- configMapRef:
    name: {{ include "singleton.sharedEnvConfigMapName" . }}
- secretRef:
    name: {{ include "singleton.sharedEnvSecretName" . }}
    optional: true
- configMapRef:
    name: {{ include "singleton.configMapName" . }}
- secretRef:
    name: {{ include "singleton.secretName" . }}
    optional: true
{{- end }}

{{- define "singleton.postgresPasswordSecretName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $postgresql := get $zulip "postgresql" | default dict -}}
{{- $globalName := get $postgresql "appSecretName" | default "" -}}
{{- default (default (printf "%s-postgresql-app" (include "singleton.baseName" .)) $globalName) .Values.connections.postgresql.passwordSecretName -}}
{{- end }}

{{- define "singleton.rabbitmqDefaultUserSecretName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $rabbitmq := get $zulip "rabbitmq" | default dict -}}
{{- $globalName := get $rabbitmq "defaultUserSecretName" | default "" -}}
{{- default (default (printf "%s-rabbitmq-default-user" (include "singleton.baseName" .)) $globalName) .Values.connections.rabbitmq.passwordSecretName -}}
{{- end }}

{{- define "singleton.rabbitmqUsernameSecretName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $rabbitmq := get $zulip "rabbitmq" | default dict -}}
{{- $globalName := get $rabbitmq "defaultUserSecretName" | default "" -}}
{{- default (default (printf "%s-rabbitmq-default-user" (include "singleton.baseName" .)) $globalName) .Values.connections.rabbitmq.usernameSecretName -}}
{{- end }}

{{- define "singleton.redisSecretName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $redis := get $zulip "redis" | default dict -}}
{{- $globalName := get $redis "secretName" | default "" -}}
{{- default (default (printf "%s-redis-auth" (include "singleton.baseName" .)) $globalName) .Values.connections.redis.passwordSecretName -}}
{{- end }}

{{- define "singleton.secretEnv" -}}
{{- if .Values.connections.postgresql.passwordFromSecret }}
- name: ZULIP_SECRET_postgres_password
  valueFrom:
    secretKeyRef:
      name: {{ include "singleton.postgresPasswordSecretName" . }}
      key: {{ .Values.connections.postgresql.passwordKey | default "password" }}
{{- end }}
{{- if .Values.connections.rabbitmq.usernameFromSecret }}
- name: ZULIP_SETTING_RABBITMQ_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ include "singleton.rabbitmqUsernameSecretName" . }}
      key: {{ .Values.connections.rabbitmq.usernameKey | default "username" }}
{{- end }}
{{- if .Values.connections.rabbitmq.passwordFromSecret }}
- name: ZULIP_SECRET_rabbitmq_password
  valueFrom:
    secretKeyRef:
      name: {{ include "singleton.rabbitmqDefaultUserSecretName" . }}
      key: {{ .Values.connections.rabbitmq.passwordKey | default "password" }}
{{- end }}
{{- if .Values.connections.redis.passwordFromSecret }}
- name: ZULIP_SECRET_redis_password
  valueFrom:
    secretKeyRef:
      name: {{ include "singleton.redisSecretName" . }}
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

{{- define "singleton.processName" -}}
{{- printf "%s-%s" (include "singleton.fullname" .root) .name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "singleton.processSelectorLabels" -}}
app.kubernetes.io/name: {{ include "singleton.name" .root }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: singleton
app.kubernetes.io/singleton-process: {{ .name }}
{{- end }}

{{- define "singleton.processLabels" -}}
helm.sh/chart: {{ include "singleton.chart" .root }}
{{ include "singleton.processSelectorLabels" . }}
{{- if .root.Chart.AppVersion }}
app.kubernetes.io/version: {{ .root.Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
{{- end }}
