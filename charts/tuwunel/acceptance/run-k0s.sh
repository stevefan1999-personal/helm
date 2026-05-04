#!/usr/bin/env bash
set -euo pipefail

NS="${NS:-tuwunel-acceptance-e2e}"
CHART_DIR="${CHART_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
NODE_IP="${NODE_IP:-192.168.2.190}"
SERVER_NAME="${SERVER_NAME:-tuwunel.${NODE_IP//./-}.nip.io}"
PUBLIC_URL="${PUBLIC_URL:-https://${SERVER_NAME}}"
LIVEKIT_URL="${LIVEKIT_URL:-wss://${SERVER_NAME}}"
VALUES_EXTRA="${VALUES_EXTRA:-}"
APPLY_LOCAL_TLS="${APPLY_LOCAL_TLS:-false}"

run_matrix_e2e() {
  local phase="$1"
  local job="tuwunel-matrix-e2e-${phase}"

  kubectl -n "$NS" delete job "$job" --ignore-not-found=true >/dev/null
  cat <<YAML | kubectl -n "$NS" apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: ${job}
  labels:
    app.kubernetes.io/name: tuwunel-matrix-e2e
spec:
  activeDeadlineSeconds: 900
  backoffLimit: 0
  ttlSecondsAfterFinished: 600
  template:
    metadata:
      labels:
        app.kubernetes.io/name: tuwunel-matrix-e2e
    spec:
      restartPolicy: Never
      containers:
        - name: matrix-e2e
          image: python:3.12-slim
          imagePullPolicy: IfNotPresent
          env:
            - name: PYTHONUNBUFFERED
              value: "1"
            - name: PHASE
              value: "${phase}"
            - name: BASE_URL
              value: http://tuwunel:8008
            - name: SERVER_NAME
              value: "${SERVER_NAME}"
            - name: REGISTRATION_TOKEN
              value: acceptance-token
            - name: STATE_FILE
              value: /state/e2e.json
            - name: RAUTHY_ISSUER
              value: http://tuwunel-rauthy:8080/auth/v1/
            - name: IDP_ID
              value: tuwunel-acceptance
            - name: OIDC_CALLBACK_URL
              value: http://tuwunel:8008/_matrix/client/unstable/login/sso/callback/tuwunel-acceptance
            - name: LIVEKIT_HEALTH_URL
              value: http://tuwunel-livekit-jwt:8081/healthz
          command:
            - sh
            - -ec
            - |
              python -m pip install --no-cache-dir --quiet matrix-nio==0.25.2
              python /e2e/matrix_e2e.py "\$PHASE"
          volumeMounts:
            - name: script
              mountPath: /e2e
              readOnly: true
            - name: state
              mountPath: /state
      volumes:
        - name: script
          configMap:
            name: tuwunel-matrix-e2e
            defaultMode: 0555
        - name: state
          persistentVolumeClaim:
            claimName: tuwunel-matrix-e2e-state
YAML

  if ! kubectl -n "$NS" wait --for=condition=complete "job/${job}" --timeout=15m; then
    kubectl -n "$NS" describe "job/${job}" || true
    kubectl -n "$NS" logs "job/${job}" --all-containers=true || true
    return 1
  fi
  kubectl -n "$NS" logs "job/${job}" --all-containers=true
}

kubectl get nodes >/dev/null
if [ "${RESET_NAMESPACE:-false}" = "true" ]; then
  kubectl delete namespace "$NS" --ignore-not-found=true
  while kubectl get namespace "$NS" >/dev/null 2>&1; do
    sleep 2
  done
fi
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" delete job/tuwunel-juicefs-create-bucket --ignore-not-found=true >/dev/null
kubectl -n "$NS" apply -f "$CHART_DIR/acceptance/juicefs-s3-gateway.yaml"
kubectl -n "$NS" rollout status deploy/tuwunel-juicefs-s3 --timeout=180s
kubectl -n "$NS" wait --for=condition=complete job/tuwunel-juicefs-create-bucket --timeout=180s

kubectl -n "$NS" apply -f "$CHART_DIR/acceptance/rauthy.yaml"
kubectl -n "$NS" rollout status sts/tuwunel-rauthy --timeout=5m

if [ "$APPLY_LOCAL_TLS" = "true" ]; then
  kubectl -n "$NS" apply -f "$CHART_DIR/acceptance/local-tls-cert-manager.yaml"
  kubectl -n "$NS" wait --for=condition=Ready certificate/tuwunel-lan-ip-tls --timeout=180s
fi

helm_args=(
  upgrade --install tuwunel "$CHART_DIR"
  --namespace "$NS"
  --values "$CHART_DIR/acceptance/values-k0s.yaml"
)

if [ -n "$VALUES_EXTRA" ]; then
  for values_file in $VALUES_EXTRA; do
    if [ ! -f "$values_file" ] && [ -f "$CHART_DIR/acceptance/$values_file" ]; then
      values_file="$CHART_DIR/acceptance/$values_file"
    fi
    helm_args+=(--values "$values_file")
  done
fi

helm_args+=(
  --set-string "serverName=${SERVER_NAME}"
  --set-string "publicUrl=${PUBLIC_URL}"
  --set-string "livekit.host=${SERVER_NAME}"
  --set-string "livekit.publicUrl=${PUBLIC_URL}"
  --set-string "livekit.livekitUrl=${LIVEKIT_URL}"
  --set-string "livekit.fullAccessHomeservers=${SERVER_NAME}"
  --set-string "cinny.publicUrl=${PUBLIC_URL}"
  --set-string "cinny.config.homeserverList[0]=${PUBLIC_URL}"
  --set-string "cinny.ingress.hosts[0].host=${SERVER_NAME}"
  --set-string "cinny.homeserverProxy.ingress.hosts[0].host=${SERVER_NAME}"
  --wait
  --timeout 10m
)

helm "${helm_args[@]}"

helm -n "$NS" test tuwunel --timeout 5m

kubectl -n "$NS" run tuwunel-acceptance-curl \
  --rm -i --restart=Never \
  --image=curlimages/curl:8.11.1 \
  --env="SERVER_NAME=${SERVER_NAME}" \
  --command -- sh -ec '
    base=http://tuwunel:8008
    curl -fsS "$base/_matrix/client/versions" | grep -q "versions"
    curl -fsS "$base/.well-known/matrix/client" | grep -q "m.homeserver"
    curl -fsS "$base/_matrix/client/v3/login" | grep -q "m.login.sso"
    curl -fsS "$base/_matrix/client/v1/auth_issuer" | grep -q "issuer"
    curl -fsS "$base/.well-known/matrix/client" | grep -q "livekit"
    curl -fsS http://tuwunel-livekit-jwt:8081/healthz
    curl -sS --connect-timeout 5 http://tuwunel-livekit:7880 >/dev/null
    curl -fsS http://tuwunel-web/config.json | grep -q "$SERVER_NAME"
  '

kubectl -n "$NS" apply -f "$CHART_DIR/acceptance/matrix-e2e.yaml"
run_matrix_e2e bootstrap

kubectl -n "$NS" rollout restart deploy/tuwunel-juicefs-s3
kubectl -n "$NS" rollout status deploy/tuwunel-juicefs-s3 --timeout=180s
kubectl -n "$NS" rollout restart sts/tuwunel-rauthy
kubectl -n "$NS" rollout status sts/tuwunel-rauthy --timeout=5m
kubectl -n "$NS" rollout restart sts/tuwunel
kubectl -n "$NS" rollout status sts/tuwunel --timeout=5m

run_matrix_e2e verify
