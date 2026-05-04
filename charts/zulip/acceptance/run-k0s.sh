#!/usr/bin/env bash
set -euo pipefail

NS="${NS:-zulip-e2e}"
RELEASE="${RELEASE:-zulip-e2e}"
CHART_DIR="${CHART_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
VALUES_FILE="${VALUES_FILE:-$CHART_DIR/acceptance/values-k0s.yaml}"
EXTRA_VALUES_FILES="${EXTRA_VALUES_FILES:-}"
RESET_NAMESPACE="${RESET_NAMESPACE:-false}"
RUN_MULTI_USER_E2E="${RUN_MULTI_USER_E2E:-true}"
ZULIP_E2E_EXPECT_SHARDS="${ZULIP_E2E_EXPECT_SHARDS:-}"

kubectl get nodes >/dev/null
if [ "$RESET_NAMESPACE" = "true" ]; then
  kubectl delete namespace "$NS" --ignore-not-found=true
  while kubectl get namespace "$NS" >/dev/null 2>&1; do
    sleep 2
  done
fi
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$NS" delete job/zulip-juicefs-create-buckets --ignore-not-found=true >/dev/null
kubectl -n "$NS" apply -f "$CHART_DIR/acceptance/juicefs-s3-gateway.yaml"
kubectl -n "$NS" rollout status deploy/zulip-juicefs-s3 --timeout=180s
kubectl -n "$NS" rollout status deploy/zulip-juicefs-s3-tls --timeout=180s
kubectl -n "$NS" wait --for=condition=complete job/zulip-juicefs-create-buckets --timeout=180s

helm_args=(
  upgrade --install "$RELEASE" "$CHART_DIR"
  --namespace "$NS"
  --values "$VALUES_FILE"
  --wait
  --timeout 15m
)
for extra_values_file in $EXTRA_VALUES_FILES; do
  helm_args+=(--values "$extra_values_file")
done
helm "${helm_args[@]}"

# The migration Job is not a Helm hook by default; wait for it explicitly.
kubectl -n "$NS" wait --for=condition=complete job/zulip-e2e-migrate --timeout=15m
kubectl -n "$NS" rollout status deployment -l app.kubernetes.io/component=django --timeout=5m
kubectl -n "$NS" rollout status deployment -l app.kubernetes.io/component=web --timeout=5m
kubectl -n "$NS" rollout status deployment -l app.kubernetes.io/component=tornado --timeout=5m

django_pod="$(kubectl -n "$NS" get pod -l app.kubernetes.io/component=django --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')"

kubectl -n "$NS" exec "$django_pod" -c django -- runuser -u zulip -- \
  /home/zulip/deployments/current/manage.py shell -c '
from io import BytesIO
from django.conf import settings
from zerver.lib.upload import save_attachment_contents, store_message_attachment
assert settings.LOCAL_UPLOADS_DIR is None, settings.LOCAL_UPLOADS_DIR
assert settings.S3_ENDPOINT_URL == "https://zulip-juicefs-s3-tls", settings.S3_ENDPOINT_URL
assert settings.S3_AVATAR_PUBLIC_URL_PREFIX == "https://192.168.2.190.nip.io/s3-avatar/", settings.S3_AVATAR_PUBLIC_URL_PREFIX
assert settings.S3_ADDRESSING_STYLE == "path", settings.S3_ADDRESSING_STYLE
payload = b"zulip juicefs object storage e2e\n"
store_message_attachment("e2e/juicefs-object-storage.txt", "juicefs-object-storage.txt", "text/plain", payload, None, None)
buf = BytesIO()
save_attachment_contents("e2e/juicefs-object-storage.txt", buf)
assert buf.getvalue() == payload, buf.getvalue()
print("object storage roundtrip ok")
'

kubectl -n "$NS" run zulip-s3-check \
  --rm -i --restart=Never \
  --image=amazon/aws-cli:2.24.13 \
  --env=AWS_ACCESS_KEY_ID=minioadmin \
  --env=AWS_SECRET_ACCESS_KEY=minioadmin \
  --env=AWS_EC2_METADATA_DISABLED=true \
  --command -- sh -ec '
    aws --endpoint-url http://zulip-juicefs-s3:9000 s3 ls s3://zulip-uploads/e2e/juicefs-object-storage.txt
  '

if [ "$RUN_MULTI_USER_E2E" = "true" ]; then
  e2e_args=(--namespace "$NS")
  if [ -n "$ZULIP_E2E_EXPECT_SHARDS" ]; then
    e2e_args+=(--expect-shards "$ZULIP_E2E_EXPECT_SHARDS")
  fi
  "$CHART_DIR/acceptance/multi-user-e2e.py" "${e2e_args[@]}"
fi
