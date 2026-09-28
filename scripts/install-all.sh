#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_root

echo "=== Installing Node Exporter ==="
bash "${SCRIPT_DIR}/install-node-exporter.sh"

echo "=== Installing Prometheus ==="
bash "${SCRIPT_DIR}/install-prometheus.sh"

echo "=== Installing Loki ==="
bash "${SCRIPT_DIR}/install-loki.sh"

echo "Waiting for Loki to become ready..."
for _ in $(seq 1 30); do
  if curl -fsS --max-time 2 http://127.0.0.1:3100/ready >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

echo "=== Installing Promtail ==="
bash "${SCRIPT_DIR}/install-promtail.sh"

echo "=== Installing Grafana ==="
bash "${SCRIPT_DIR}/install-grafana.sh"

echo
echo "Stack installed. Next:"
echo "  sudo bash scripts/verify.sh"
echo "Open Grafana at http://127.0.0.1:3000 (or via SSH tunnel)."
