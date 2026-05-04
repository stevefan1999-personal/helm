{{/*
Reusable NetBird reverse-proxy primitives. Callers pass a dict with:
root, values, fullname, labels, selectorLabels, managementAddress, tokenCreator,
portNames, volumeNames, proxySecretName, crowdsecSecretName, pvcName.
*/}}

{{- define "netbird-proxy-lib.secret" -}}
{{- $v := .values -}}
{{- if and $v.enabled (not $v.existingSecret) (or $v.token .createPlaceholderSecret) }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ .proxySecretName | default (printf "%s-proxy-secrets" .fullname) }}
  labels:
    {{- .labels | nindent 4 }}
type: Opaque
stringData:
  NB_PROXY_TOKEN: {{ $v.token | default "nbx_placeholder" | quote }}
{{- end }}
{{- end }}

{{- define "netbird-proxy-lib.crowdsecSecret" -}}
{{- $v := .values -}}
{{- if and $v.enabled $v.crowdsec.apiKey (not $v.crowdsec.existingSecret) }}
apiVersion: v1
kind: Secret
metadata:
  name: {{ .crowdsecSecretName | default (printf "%s-crowdsec-secrets" .fullname) }}
  labels:
    {{- .labels | nindent 4 }}
type: Opaque
stringData:
  NB_PROXY_CROWDSEC_API_KEY: {{ $v.crowdsec.apiKey | quote }}
{{- end }}
{{- end }}

{{- define "netbird-proxy-lib.acmeLeaseRBACEnabled" -}}
{{- $v := .values -}}
{{- $rbac := get $v "rbac" | default dict -}}
{{- $rbacCreate := true -}}
{{- if hasKey $rbac "create" -}}
{{- $rbacCreate = get $rbac "create" -}}
{{- end -}}
{{- $certLockMethod := $v.certLockMethod | default "auto" -}}
{{- if and $v.enabled $rbacCreate $v.tls.acme.enabled (or (eq $certLockMethod "auto") (eq $certLockMethod "k8s-lease")) -}}true{{- end -}}
{{- end }}

{{- define "netbird-proxy-lib.serviceAccountName" -}}
{{- $v := .values -}}
{{- $serviceAccount := get $v "serviceAccount" | default dict -}}
{{- $serviceAccountName := get $serviceAccount "name" | default "" -}}
{{- if $serviceAccountName -}}{{ $serviceAccountName }}{{- else -}}{{ .serviceAccountName | default .fullname }}{{- end -}}
{{- end }}

{{- define "netbird-proxy-lib.podServiceAccount" -}}
{{- $v := .values -}}
{{- $serviceAccount := get $v "serviceAccount" | default dict -}}
{{- $serviceAccountName := get $serviceAccount "name" | default "" -}}
{{- $automount := true -}}
{{- if hasKey $serviceAccount "automountServiceAccountToken" -}}
{{- $automount = get $serviceAccount "automountServiceAccountToken" -}}
{{- end -}}
{{- if or (include "netbird-proxy-lib.acmeLeaseRBACEnabled" .) $serviceAccountName }}
serviceAccountName: {{ include "netbird-proxy-lib.serviceAccountName" . }}
automountServiceAccountToken: {{ $automount }}
{{- end -}}
{{- end }}

{{- define "netbird-proxy-lib.acmeLeaseRBAC" -}}
{{- $v := .values -}}
{{- if include "netbird-proxy-lib.acmeLeaseRBACEnabled" . }}
{{- $serviceAccount := get $v "serviceAccount" | default dict -}}
{{- $serviceAccountCreate := true -}}
{{- if hasKey $serviceAccount "create" -}}
{{- $serviceAccountCreate = get $serviceAccount "create" -}}
{{- end -}}
{{- $automount := true -}}
{{- if hasKey $serviceAccount "automountServiceAccountToken" -}}
{{- $automount = get $serviceAccount "automountServiceAccountToken" -}}
{{- end -}}
{{- $serviceAccountName := include "netbird-proxy-lib.serviceAccountName" . -}}
{{- if $serviceAccountCreate }}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ $serviceAccountName }}
  labels:
    {{- .labels | nindent 4 }}
  {{- with (get $serviceAccount "annotations") }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
automountServiceAccountToken: {{ $automount }}
---
{{- end }}
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ .fullname }}-acme-lease
  labels:
    {{- .labels | nindent 4 }}
rules:
  - apiGroups: ["coordination.k8s.io"]
    resources: ["leases"]
    verbs: ["get", "create", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ .fullname }}-acme-lease
  labels:
    {{- .labels | nindent 4 }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: {{ .fullname }}-acme-lease
subjects:
  - kind: ServiceAccount
    name: {{ $serviceAccountName }}
    namespace: {{ .root.Release.Namespace }}
{{- end }}
{{- end }}

{{- define "netbird-proxy-lib.volumeMounts" -}}
{{- $v := .values -}}
{{- $volumeNames := .volumeNames | default dict -}}
- name: {{ $volumeNames.certs | default "certs" }}
  mountPath: /certs
{{- if $v.tls.certManager.secretName }}
- name: {{ $volumeNames.tlsCert | default "tls-cert" }}
  mountPath: /tls
  readOnly: true
{{- end }}
{{- end }}

{{- define "netbird-proxy-lib.volumes" -}}
{{- $v := .values -}}
{{- $volumeNames := .volumeNames | default dict -}}
- name: {{ $volumeNames.certs | default "certs" }}
  {{- if $v.persistence.enabled }}
  persistentVolumeClaim:
    claimName: {{ .pvcName | default (printf "%s-certs" .fullname) }}
  {{- else }}
  emptyDir: {}
  {{- end }}
{{- if $v.tls.certManager.secretName }}
- name: {{ $volumeNames.tlsCert | default "tls-cert" }}
  secret:
    secretName: {{ $v.tls.certManager.secretName }}
{{- end }}
{{- end }}

{{- define "netbird-proxy-lib.container" -}}
{{- $v := .values -}}
{{- $portNames := .portNames | default dict -}}
{{- $httpsPortName := $portNames.https | default "https" -}}
{{- $healthPortName := $portNames.health | default "health" -}}
{{- $acmePortName := $portNames.acme | default "acme-http" -}}
- name: {{ .containerName | default "proxy" }}
  image: "{{ $v.image.repository }}:{{ $v.image.tag }}"
  imagePullPolicy: {{ $v.image.pullPolicy }}
  env:
    - name: NB_PROXY_MANAGEMENT_ADDRESS
      value: {{ required "proxy managementAddress is required" .managementAddress | quote }}
    - name: NB_PROXY_DOMAIN
      value: {{ $v.domain | quote }}
    - name: NB_PROXY_LOG_LEVEL
      value: {{ $v.logLevel | quote }}
    - name: NB_PROXY_ADDRESS
      value: ":8443"
    - name: NB_PROXY_HEALTH_ADDRESS
      value: ":8080"
    - name: NB_PROXY_FORWARDED_PROTO
      value: {{ $v.forwardedProto | quote }}
    - name: NB_PROXY_DEBUG_ENDPOINT
      value: {{ $v.debugEndpoint.enabled | default false | quote }}
    - name: NB_PROXY_DEBUG_ENDPOINT_ADDRESS
      value: {{ $v.debugEndpoint.address | default "localhost:8444" | quote }}
    - name: NB_PROXY_CERT_LOCK_METHOD
      value: {{ $v.certLockMethod | default "auto" | quote }}
    - name: NB_PROXY_SUPPORTS_CUSTOM_PORTS
      value: {{ $v.supportsCustomPorts | default true | quote }}
    - name: NB_PROXY_REQUIRE_SUBDOMAIN
      value: {{ $v.requireSubdomain | default false | quote }}
    - name: NB_PROXY_GEO_DATA_DIR
      value: {{ $v.geolocation.dataDir | default "/var/lib/netbird/geolocation" | quote }}
    {{- if $v.allowInsecure }}
    - name: NB_PROXY_ALLOW_INSECURE
      value: "true"
    {{- end }}
    {{- if $v.trustedProxies }}
    - name: NB_PROXY_TRUSTED_PROXIES
      value: {{ $v.trustedProxies | quote }}
    {{- end }}
    {{- if $v.wildcardCertDir }}
    - name: NB_PROXY_WILDCARD_CERT_DIR
      value: {{ $v.wildcardCertDir | quote }}
    {{- end }}
    {{- if $v.wireguardPort }}
    - name: NB_PROXY_WG_PORT
      value: {{ $v.wireguardPort | quote }}
    {{- end }}
    {{- if $v.proxyProtocol }}
    - name: NB_PROXY_PROXY_PROTOCOL
      value: "true"
    {{- end }}
    {{- if $v.preSharedKey }}
    - name: NB_PROXY_PRESHARED_KEY
      value: {{ $v.preSharedKey | quote }}
    {{- end }}
    {{- if $v.timeouts.maxDial }}
    - name: NB_PROXY_MAX_DIAL_TIMEOUT
      value: {{ $v.timeouts.maxDial | quote }}
    {{- end }}
    {{- if $v.timeouts.maxSessionIdle }}
    - name: NB_PROXY_MAX_SESSION_IDLE_TIMEOUT
      value: {{ $v.timeouts.maxSessionIdle | quote }}
    {{- end }}
    {{- if $v.crowdsec.apiUrl }}
    - name: NB_PROXY_CROWDSEC_API_URL
      value: {{ $v.crowdsec.apiUrl | quote }}
    {{- end }}
    {{- if or $v.crowdsec.apiKey $v.crowdsec.existingSecret }}
    - name: NB_PROXY_CROWDSEC_API_KEY
      valueFrom:
        secretKeyRef:
          name: {{ $v.crowdsec.existingSecret | default (.crowdsecSecretName | default (printf "%s-crowdsec-secrets" .fullname)) }}
          key: NB_PROXY_CROWDSEC_API_KEY
    {{- end }}
    {{- if $v.tls.acme.enabled }}
    - name: NB_PROXY_ACME_CERTIFICATES
      value: "true"
    - name: NB_PROXY_ACME_CHALLENGE_TYPE
      value: {{ $v.tls.acme.challengeType | quote }}
    {{- if eq $v.tls.acme.challengeType "http-01" }}
    - name: NB_PROXY_ACME_ADDRESS
      value: ":{{ $v.tls.acme.httpPort }}"
    {{- end }}
    {{- if $v.tls.acme.directory }}
    - name: NB_PROXY_ACME_DIRECTORY
      value: {{ $v.tls.acme.directory | quote }}
    {{- end }}
    {{- if $v.tls.acme.eabKeyId }}
    - name: NB_PROXY_ACME_EAB_KID
      value: {{ $v.tls.acme.eabKeyId | quote }}
    - name: NB_PROXY_ACME_EAB_HMAC_KEY
      value: {{ $v.tls.acme.eabHmacKey | quote }}
    {{- end }}
    {{- end }}
    {{- if $v.tls.static.certFile }}
    - name: NB_PROXY_CERTIFICATE_FILE
      value: {{ $v.tls.static.certFile | quote }}
    - name: NB_PROXY_CERTIFICATE_KEY_FILE
      value: {{ $v.tls.static.keyFile | quote }}
    {{- end }}
    {{- if $v.tls.certManager.secretName }}
    - name: NB_PROXY_CERTIFICATE_DIRECTORY
      value: "/tls"
    - name: NB_PROXY_CERTIFICATE_FILE
      value: "tls.crt"
    - name: NB_PROXY_CERTIFICATE_KEY_FILE
      value: "tls.key"
    {{- end }}
    - name: NB_PROXY_TOKEN
      valueFrom:
        secretKeyRef:
          name: {{ $v.existingSecret | default (.proxySecretName | default (printf "%s-proxy-secrets" .fullname)) }}
          key: NB_PROXY_TOKEN
  ports:
    - name: {{ $httpsPortName }}
      containerPort: 8443
      protocol: TCP
    - name: {{ $healthPortName }}
      containerPort: 8080
      protocol: TCP
    {{- if and $v.tls.acme.enabled (eq $v.tls.acme.challengeType "http-01") }}
    - name: {{ $acmePortName }}
      containerPort: {{ $v.tls.acme.httpPort }}
      protocol: TCP
    {{- end }}
    {{- range $port := $v.service.extraPorts }}
    {{- if $port }}
    - name: {{ required "proxy.service.extraPorts[].name is required" $port.name }}
      containerPort: {{ $port.containerPort | default $port.port }}
      protocol: {{ $port.protocol | default "TCP" }}
    {{- end }}
    {{- end }}
  livenessProbe:
    httpGet:
      path: /healthz/live
      port: {{ $healthPortName }}
    initialDelaySeconds: 10
    periodSeconds: 10
  readinessProbe:
    httpGet:
      path: /healthz/ready
      port: {{ $healthPortName }}
    initialDelaySeconds: 5
    periodSeconds: 5
  startupProbe:
    httpGet:
      path: /healthz/startup
      port: {{ $healthPortName }}
    initialDelaySeconds: 5
    periodSeconds: 5
    failureThreshold: 30
  resources:
    {{- toYaml $v.resources | nindent 4 }}
  {{- with $v.securityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  volumeMounts:
    {{- include "netbird-proxy-lib.volumeMounts" . | nindent 4 }}
{{- end }}

{{- define "netbird-proxy-lib.deployment" -}}
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
      {{- include "netbird-proxy-lib.podServiceAccount" . | nindent 6 }}
      {{- with $v.podSecurityContext }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $v.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $v.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with $v.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      containers:
        {{- include "netbird-proxy-lib.container" . | nindent 8 }}
      volumes:
        {{- include "netbird-proxy-lib.volumes" . | nindent 8 }}
{{- end }}
{{- end }}

{{- define "netbird-proxy-lib.service" -}}
{{- $v := .values -}}
{{- if $v.enabled }}
{{- $portNames := .portNames | default dict -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ .fullname }}
  labels:
    {{- .labels | nindent 4 }}
  {{- with $v.service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ $v.service.type }}
  ports:
    - port: {{ $v.service.port }}
      targetPort: {{ $portNames.https | default "https" }}
      protocol: TCP
      name: https
    {{- if and $v.tls.acme.enabled (eq $v.tls.acme.challengeType "http-01") }}
    - port: {{ $v.tls.acme.servicePort | default 80 }}
      targetPort: {{ $portNames.acme | default "acme-http" }}
      protocol: TCP
      name: acme-http
    {{- end }}
    - port: 8080
      targetPort: {{ $portNames.health | default "health" }}
      protocol: TCP
      name: health
    {{- range $port := $v.service.extraPorts }}
    {{- if $port }}
    - name: {{ required "proxy.service.extraPorts[].name is required" $port.name }}
      port: {{ required "proxy.service.extraPorts[].port is required" $port.port }}
      targetPort: {{ $port.targetPort | default $port.name }}
      protocol: {{ $port.protocol | default "TCP" }}
      {{- if hasKey $port "nodePort" }}
      nodePort: {{ $port.nodePort }}
      {{- end }}
      {{- if $port.appProtocol }}
      appProtocol: {{ $port.appProtocol }}
      {{- end }}
    {{- end }}
    {{- end }}
  selector:
    {{- .selectorLabels | nindent 4 }}
{{- end }}
{{- end }}

{{- define "netbird-proxy-lib.ingress" -}}
{{- $v := .values -}}
{{- if and $v.enabled $v.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .fullname }}
  labels:
    {{- .labels | nindent 4 }}
  annotations:
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    {{- with $v.ingress.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  {{- with $v.ingress.className | default .ingressClassName }}
  ingressClassName: {{ . }}
  {{- end }}
  rules:
    - host: {{ $v.domain | quote }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ .fullname }}
                port:
                  number: {{ $v.service.port }}
{{- end }}
{{- end }}

{{- define "netbird-proxy-lib.pvc" -}}
{{- $v := .values -}}
{{- if and $v.enabled $v.persistence.enabled }}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ .pvcName | default (printf "%s-certs" .fullname) }}
  labels:
    {{- .labels | nindent 4 }}
spec:
  accessModes:
    - ReadWriteOnce
  {{- if $v.persistence.storageClass }}
  storageClassName: {{ $v.persistence.storageClass }}
  {{- end }}
  resources:
    requests:
      storage: {{ $v.persistence.size }}
{{- end }}
{{- end }}

{{- define "netbird-proxy-lib.tokenJob" -}}
{{- $v := .values -}}
{{- if and $v.enabled (not $v.token) (not $v.existingSecret) }}
{{- $tc := .tokenCreator | default dict -}}
{{- $waitForAvailable := true -}}
{{- if hasKey $tc "waitForAvailable" -}}
{{- $waitForAvailable = $tc.waitForAvailable -}}
{{- end -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ .fullname }}-token-creator
  labels:
    {{- .labels | nindent 4 }}
  annotations:
    "helm.sh/hook": post-install
    "helm.sh/hook-weight": "5"
    "helm.sh/hook-delete-policy": before-hook-creation
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ .fullname }}-token-creator
  labels:
    {{- .labels | nindent 4 }}
  annotations:
    "helm.sh/hook": post-install
    "helm.sh/hook-weight": "5"
    "helm.sh/hook-delete-policy": before-hook-creation
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["create", "get", "update", "patch"]
- apiGroups: [""]
  resources: ["pods", "pods/exec"]
  verbs: ["get", "list", "create"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ .fullname }}-token-creator
  labels:
    {{- .labels | nindent 4 }}
  annotations:
    "helm.sh/hook": post-install
    "helm.sh/hook-weight": "5"
    "helm.sh/hook-delete-policy": before-hook-creation
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: {{ .fullname }}-token-creator
subjects:
- kind: ServiceAccount
  name: {{ .fullname }}-token-creator
  namespace: {{ .root.Release.Namespace }}
---
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ .fullname }}-create-token
  labels:
    {{- .labels | nindent 4 }}
  annotations:
    "helm.sh/hook": post-install
    "helm.sh/hook-weight": "10"
    "helm.sh/hook-delete-policy": before-hook-creation
spec:
  backoffLimit: 5
  ttlSecondsAfterFinished: 300
  template:
    metadata:
      labels:
        {{- .selectorLabels | nindent 8 }}
    spec:
      serviceAccountName: {{ .fullname }}-token-creator
      restartPolicy: OnFailure
      containers:
        - name: create-token
          image: {{ $tc.kubectlImage | default "bitnami/kubectl:latest" | quote }}
          env:
            - name: SECRET_NAME
              value: {{ .proxySecretName | default (printf "%s-proxy-secrets" .fullname) }}
            - name: NAMESPACE
              value: {{ .root.Release.Namespace }}
            - name: SERVER_DEPLOY
              value: {{ required "proxy tokenCreator.deployment is required" $tc.deployment | quote }}
            - name: SERVER_APP_NAME
              value: {{ required "proxy tokenCreator.appName is required" $tc.appName | quote }}
            - name: SERVER_CONTAINER
              value: {{ $tc.container | default "" | quote }}
            - name: SERVER_COMMAND
              value: {{ $tc.command | default "/usr/local/bin/netbird-server" | quote }}
            - name: SERVER_CONFIG
              value: {{ $tc.configPath | default "/etc/netbird/config.yaml" | quote }}
            - name: PROXY_DEPLOY
              value: {{ $tc.restartDeployment | default .fullname | quote }}
            - name: WAIT_FOR_AVAILABLE
              value: {{ $waitForAvailable | quote }}
          command:
            - bash
            - -c
            - |
              set -euo pipefail

              EXISTING_TOKEN=$(kubectl -n "$NAMESPACE" get secret "$SECRET_NAME" -o jsonpath='{.data.NB_PROXY_TOKEN}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
              if [ -n "$EXISTING_TOKEN" ] && echo "$EXISTING_TOKEN" | grep -q "^nbx_"; then
                echo "Valid proxy token already exists in secret $SECRET_NAME"
                exit 0
              fi

              if [ "$WAIT_FOR_AVAILABLE" = "true" ]; then
                echo "Waiting for management deployment $SERVER_DEPLOY to be ready..."
                kubectl -n "$NAMESPACE" wait --for=condition=Available deployment/"$SERVER_DEPLOY" --timeout=300s
              else
                echo "Skipping Available wait for $SERVER_DEPLOY; sidecar mode may not be ready until the token exists."
              fi

              for i in $(seq 1 120); do
                SERVER_POD=$(kubectl -n "$NAMESPACE" get pods -l "app.kubernetes.io/name=$SERVER_APP_NAME,app.kubernetes.io/instance={{ .root.Release.Name }}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
                if [ -n "$SERVER_POD" ]; then
                  echo "Management pod: $SERVER_POD"
                  break
                fi
                sleep 1
              done

              if [ -z "${SERVER_POD:-}" ]; then
                echo "ERROR: could not find management pod for app.kubernetes.io/name=$SERVER_APP_NAME"
                exit 1
              fi

              EXEC_ARGS=()
              if [ -n "$SERVER_CONTAINER" ]; then
                EXEC_ARGS+=("-c" "$SERVER_CONTAINER")
              fi

              for i in $(seq 1 120); do
                TOKEN_OUTPUT=$(kubectl -n "$NAMESPACE" exec "$SERVER_POD" "${EXEC_ARGS[@]}" -- \
                  "$SERVER_COMMAND" token create \
                  --name "helm-proxy-{{ .root.Release.Name }}" \
                  --config "$SERVER_CONFIG" 2>&1) && break
                echo "Token command not ready yet: $TOKEN_OUTPUT"
                sleep 1
              done

              echo "Token output: $TOKEN_OUTPUT"
              TOKEN=$(echo "$TOKEN_OUTPUT" | grep -oE 'nbx_[a-zA-Z0-9]+' | head -1)

              if [ -z "$TOKEN" ]; then
                echo "ERROR: Failed to extract token from output"
                echo "Full output was: $TOKEN_OUTPUT"
                exit 1
              fi

              kubectl -n "$NAMESPACE" create secret generic "$SECRET_NAME" \
                --from-literal=NB_PROXY_TOKEN="$TOKEN" \
                --dry-run=client -o yaml | kubectl apply -f -

              if kubectl -n "$NAMESPACE" get deployment "$PROXY_DEPLOY" >/dev/null 2>&1; then
                kubectl -n "$NAMESPACE" rollout restart deployment "$PROXY_DEPLOY"
              fi

              echo "Done! Proxy token provisioned successfully."
{{- end }}
{{- end }}
