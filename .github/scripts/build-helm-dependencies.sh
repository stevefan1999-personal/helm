#!/usr/bin/env bash
set -euo pipefail

# Build nested library dependencies before parent charts so clean CI checkouts
# can lint, render, test, and package charts without ignored *.tgz artifacts.
charts=(
  charts/netbird/charts/dashboard
  charts/netbird/charts/proxy
  charts/netbird
  charts/netbird-combined
)

for chart in "${charts[@]}"; do
  if [[ -f "${chart}/Chart.yaml" ]]; then
    echo "==> Building Helm dependencies for ${chart}"
    helm dependency build "${chart}"
  fi
done
