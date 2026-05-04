{{/*
Reusable NetBird dashboard primitives. Callers pass a dict with:
root, values, fullname, labels, selectorLabels, config, auth, secret, ingress, portName.
*/}}

{{- define "netbird-dashboard-lib.configmap" -}}
{{- $v := .values -}}
{{- if $v.enabled }}
{{- $config := .config | default dict -}}
{{- $auth := .auth | default dict -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .configMapName | default (printf "%s-config" .fullname) }}
  labels:
    {{- .labels | nindent 4 }}
data:
  NETBIRD_MGMT_API_ENDPOINT: {{ required "dashboard config.managementEndpoint is required" $config.managementEndpoint | quote }}
  NETBIRD_MGMT_GRPC_API_ENDPOINT: {{ required "dashboard config.managementGrpcEndpoint is required" $config.managementGrpcEndpoint | quote }}
  {{- with $config.signalEndpoint }}
  NETBIRD_SIGNAL_ENDPOINT: {{ . | quote }}
  {{- end }}
  {{- with $config.relayEndpoint }}
  NETBIRD_RELAY_ENDPOINT: {{ . | quote }}
  {{- end }}
  AUTH_AUDIENCE: {{ required "dashboard auth.audience is required" $auth.audience | quote }}
  AUTH_CLIENT_ID: {{ required "dashboard auth.clientId is required" $auth.clientId | quote }}
  AUTH_AUTHORITY: {{ required "dashboard auth.authority is required" $auth.authority | quote }}
  USE_AUTH0: "false"
  AUTH_SUPPORTED_SCOPES: {{ default "openid profile email" $auth.supportedScopes | quote }}
  NETBIRD_TOKEN_SOURCE: {{ default "accessToken" $auth.tokenSource | quote }}
  AUTH_REDIRECT_URI: {{ default "/nb-auth" $config.redirectURI | quote }}
  AUTH_SILENT_REDIRECT_URI: {{ default "/nb-silent-auth" $config.silentRedirectURI | quote }}
  LETSENCRYPT_DOMAIN: "none"
{{- end }}
{{- end }}

{{- define "netbird-dashboard-lib.secret" -}}
{{- $v := .values -}}
{{- $secret := .secret | default dict -}}
{{- $auth := .auth | default dict -}}
{{- if and $v.enabled $secret.enabled }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ $secret.name | default (printf "%s-secrets" .fullname) }}
  labels:
    {{- .labels | nindent 4 }}
type: Opaque
data:
  AUTH_CLIENT_SECRET: {{ default "" $auth.clientSecret | b64enc | quote }}
{{- end }}
{{- end }}

{{- define "netbird-dashboard-lib.container" -}}
{{- $root := .root -}}
{{- $v := .values -}}
{{- $secret := .secret | default dict -}}
{{- $portName := .portName | default "http" -}}
{{- $rootValues := $root.Values | toJson | fromJson -}}
- name: {{ .containerName | default "dashboard" }}
  image: "{{ $v.image.repository }}:{{ $v.image.tag }}"
  imagePullPolicy: {{ $v.image.pullPolicy }}
  env:
    - name: TZ
      value: {{ dig "global" "timezone" "UTC" $rootValues | quote }}
  envFrom:
    - configMapRef:
        name: {{ .configMapName | default (printf "%s-config" .fullname) }}
    {{- if $secret.enabled }}
    - secretRef:
        name: {{ $secret.name | default (printf "%s-secrets" .fullname) }}
    {{- end }}
  ports:
    - name: {{ $portName }}
      containerPort: {{ $v.service.port }}
      protocol: TCP
  livenessProbe:
    httpGet:
      path: /
      port: {{ $portName }}
    initialDelaySeconds: 10
    periodSeconds: 10
  readinessProbe:
    httpGet:
      path: /
      port: {{ $portName }}
    initialDelaySeconds: 5
    periodSeconds: 5
  resources:
    {{- toYaml $v.resources | nindent 4 }}
  securityContext:
    {{- toYaml ($v.securityContext | default dict) | nindent 4 }}
  volumeMounts: []
{{- end }}

{{- define "netbird-dashboard-lib.deployment" -}}
{{- $v := .values -}}
{{- if $v.enabled }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .fullname }}
  labels:
    {{- .labels | nindent 4 }}
spec:
  replicas: {{ $v.replicas }}
  selector:
    matchLabels:
      {{- .selectorLabels | nindent 6 }}
  template:
    metadata:
      labels:
        {{- .selectorLabels | nindent 8 }}
    spec:
      containers:
        {{- include "netbird-dashboard-lib.container" . | nindent 8 }}
      volumes: []
{{- end }}
{{- end }}

{{- define "netbird-dashboard-lib.service" -}}
{{- $v := .values -}}
{{- if $v.enabled }}
{{- $portName := .portName | default "http" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ .fullname }}
  labels:
    {{- .labels | nindent 4 }}
spec:
  type: {{ $v.service.type }}
  ports:
    - port: {{ $v.service.port }}
      targetPort: {{ $portName }}
      protocol: TCP
      name: http
  selector:
    {{- .selectorLabels | nindent 4 }}
{{- end }}
{{- end }}

{{- define "netbird-dashboard-lib.ingress" -}}
{{- $v := .values -}}
{{- $ingress := .ingress | default dict -}}
{{- if and $v.enabled $ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .fullname }}
  labels:
    {{- .labels | nindent 4 }}
  {{- with $ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- with $ingress.className }}
  ingressClassName: {{ . }}
  {{- end }}
  {{- if $ingress.tls.enabled }}
  tls:
    - hosts:
        - {{ $ingress.host | quote }}
      {{- with $ingress.tls.secretName }}
      secretName: {{ . }}
      {{- end }}
  {{- end }}
  rules:
    - host: {{ $ingress.host | quote }}
      http:
        paths:
          - path: {{ $ingress.path | default "/" }}
            pathType: Prefix
            backend:
              service:
                name: {{ .fullname }}
                port:
                  number: {{ $v.service.port }}
{{- end }}
{{- end }}
