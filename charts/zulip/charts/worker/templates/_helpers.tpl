{{- define "worker.baseName" -}}
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

{{- define "worker.name" -}}
{{- default "zulip" .Values.appName | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "worker.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-worker" (include "worker.baseName" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end }}

{{- define "worker.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "worker.selectorLabels" -}}
app.kubernetes.io/name: {{ include "worker.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: worker
{{- end }}

{{- define "worker.labels" -}}
helm.sh/chart: {{ include "worker.chart" . }}
{{ include "worker.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "worker.serviceAccountName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $globalName := get $zulip "serviceAccountName" | default "" -}}
{{- default (default (include "worker.baseName" .) $globalName) .Values.serviceAccountName -}}
{{- end }}

{{- define "worker.imageRepository" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $globalImage := get $zulip "image" | default dict -}}
{{- default (default "ghcr.io/zulip/zulip-server" (get $globalImage "repository")) .Values.image.repository -}}
{{- end }}

{{- define "worker.imageTag" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $globalImage := get $zulip "image" | default dict -}}
{{- default (default .Chart.AppVersion (get $globalImage "tag")) .Values.image.tag -}}
{{- end }}

{{- define "worker.imagePullPolicy" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $globalImage := get $zulip "image" | default dict -}}
{{- default (default "IfNotPresent" (get $globalImage "pullPolicy")) .Values.image.pullPolicy -}}
{{- end }}

{{- define "worker.image" -}}
{{- printf "%s:%s" (include "worker.imageRepository" .) (include "worker.imageTag" .) -}}
{{- end }}

{{- define "worker.imagePullSecrets" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- if .Values.imagePullSecrets }}
{{- toYaml .Values.imagePullSecrets -}}
{{- else if get $zulip "imagePullSecrets" }}
{{- toYaml (get $zulip "imagePullSecrets") -}}
{{- end }}
{{- end }}

{{- define "worker.configMapName" -}}
{{- printf "%s-config" (include "worker.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "worker.secretName" -}}
{{- printf "%s-secrets" (include "worker.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "worker.sharedEnvConfigMapName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $globalName := get $zulip "envConfigMapName" | default "" -}}
{{- default (default (printf "%s-env" (include "worker.baseName" .)) $globalName) .Values.sharedEnv.configMapName -}}
{{- end }}

{{- define "worker.sharedEnvSecretName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $globalName := get $zulip "envSecretName" | default "" -}}
{{- default (default (printf "%s-env" (include "worker.baseName" .)) $globalName) .Values.sharedEnv.secretName -}}
{{- end }}

{{- define "worker.runtimeConfigMapName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- default (printf "%s-runtime" (include "worker.baseName" .)) (get $zulip "runtimeConfigMapName" | default "") | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "worker.appConfigMapName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- default (printf "%s-app-config" (include "worker.baseName" .)) (get $zulip "appConfigMapName" | default "") | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "worker.volumeMounts" -}}
- name: zulip-runtime
  mountPath: /opt/zulip-k8s
  readOnly: true
- name: zulip-config-template
  mountPath: /etc/zulip-template
  readOnly: true
- name: zulip-etc
  mountPath: /etc/zulip
{{- end }}

{{- define "worker.podVolumes" -}}
- name: zulip-runtime
  configMap:
    name: {{ include "worker.runtimeConfigMapName" . }}
    defaultMode: 0755
- name: zulip-config-template
  configMap:
    name: {{ include "worker.appConfigMapName" . }}
    defaultMode: 0444
- name: zulip-etc
  emptyDir: {}
{{- end }}


{{- define "worker.initContainers" -}}
{{- if .Values.dependencyGuard.enabled }}
- name: wait-database-migrations
  image: {{ include "worker.image" . | quote }}
  imagePullPolicy: {{ include "worker.imagePullPolicy" . }}
  command:
    - /bin/bash
    - /opt/zulip-k8s/wait-database-migrations.sh
  envFrom:
    {{- include "worker.envFrom" . | nindent 4 }}
  env:
    {{- include "worker.secretEnv" . | nindent 4 }}
    - name: ZULIP_K8S_WAIT_ATTEMPTS
      value: {{ .Values.dependencyGuard.attempts | default 120 | quote }}
    - name: ZULIP_K8S_WAIT_SLEEP_SECONDS
      value: {{ .Values.dependencyGuard.sleepSeconds | default 5 | quote }}
  volumeMounts:
    {{- include "worker.volumeMounts" . | nindent 4 }}
- name: wait-object-storage
  image: {{ include "worker.image" . | quote }}
  imagePullPolicy: {{ include "worker.imagePullPolicy" . }}
  command:
    - /bin/bash
    - /opt/zulip-k8s/wait-object-storage.sh
  envFrom:
    {{- include "worker.envFrom" . | nindent 4 }}
  env:
    {{- include "worker.secretEnv" . | nindent 4 }}
    - name: ZULIP_K8S_WAIT_ATTEMPTS
      value: {{ .Values.dependencyGuard.attempts | default 120 | quote }}
    - name: ZULIP_K8S_WAIT_SLEEP_SECONDS
      value: {{ .Values.dependencyGuard.sleepSeconds | default 5 | quote }}
  volumeMounts:
    {{- include "worker.volumeMounts" . | nindent 4 }}
{{- end }}
{{- end }}

{{- define "worker.envFrom" -}}
- configMapRef:
    name: {{ include "worker.sharedEnvConfigMapName" . }}
- secretRef:
    name: {{ include "worker.sharedEnvSecretName" . }}
    optional: true
- configMapRef:
    name: {{ include "worker.configMapName" . }}
- secretRef:
    name: {{ include "worker.secretName" . }}
    optional: true
{{- end }}

{{- define "worker.postgresPasswordSecretName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $postgresql := get $zulip "postgresql" | default dict -}}
{{- $globalName := get $postgresql "appSecretName" | default "" -}}
{{- default (default (printf "%s-postgresql-app" (include "worker.baseName" .)) $globalName) .Values.connections.postgresql.passwordSecretName -}}
{{- end }}

{{- define "worker.rabbitmqDefaultUserSecretName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $rabbitmq := get $zulip "rabbitmq" | default dict -}}
{{- $globalName := get $rabbitmq "defaultUserSecretName" | default "" -}}
{{- default (default (printf "%s-rabbitmq-default-user" (include "worker.baseName" .)) $globalName) .Values.connections.rabbitmq.passwordSecretName -}}
{{- end }}

{{- define "worker.rabbitmqUsernameSecretName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $rabbitmq := get $zulip "rabbitmq" | default dict -}}
{{- $globalName := get $rabbitmq "defaultUserSecretName" | default "" -}}
{{- default (default (printf "%s-rabbitmq-default-user" (include "worker.baseName" .)) $globalName) .Values.connections.rabbitmq.usernameSecretName -}}
{{- end }}

{{- define "worker.redisSecretName" -}}
{{- $global := .Values.global | default dict -}}
{{- $zulip := get $global "zulip" | default dict -}}
{{- $redis := get $zulip "redis" | default dict -}}
{{- $globalName := get $redis "secretName" | default "" -}}
{{- default (default (printf "%s-redis-auth" (include "worker.baseName" .)) $globalName) .Values.connections.redis.passwordSecretName -}}
{{- end }}

{{- define "worker.secretEnv" -}}
{{- if .Values.connections.postgresql.passwordFromSecret }}
- name: ZULIP_SECRET_postgres_password
  valueFrom:
    secretKeyRef:
      name: {{ include "worker.postgresPasswordSecretName" . }}
      key: {{ .Values.connections.postgresql.passwordKey | default "password" }}
{{- end }}
{{- if .Values.connections.rabbitmq.usernameFromSecret }}
- name: ZULIP_SETTING_RABBITMQ_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ include "worker.rabbitmqUsernameSecretName" . }}
      key: {{ .Values.connections.rabbitmq.usernameKey | default "username" }}
{{- end }}
{{- if .Values.connections.rabbitmq.passwordFromSecret }}
- name: ZULIP_SECRET_rabbitmq_password
  valueFrom:
    secretKeyRef:
      name: {{ include "worker.rabbitmqDefaultUserSecretName" . }}
      key: {{ .Values.connections.rabbitmq.passwordKey | default "password" }}
{{- end }}
{{- if .Values.connections.redis.passwordFromSecret }}
- name: ZULIP_SECRET_redis_password
  valueFrom:
    secretKeyRef:
      name: {{ include "worker.redisSecretName" . }}
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

{{- define "worker.groupName" -}}
{{- printf "%s-%s" (include "worker.fullname" .root) .name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "worker.groupSelectorLabels" -}}
app.kubernetes.io/name: {{ include "worker.name" .root }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/component: worker
app.kubernetes.io/worker-group: {{ .name }}
{{- end }}

{{- define "worker.groupLabels" -}}
helm.sh/chart: {{ include "worker.chart" .root }}
{{ include "worker.groupSelectorLabels" . }}
{{- if .root.Chart.AppVersion }}
app.kubernetes.io/version: {{ .root.Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
{{- end }}
