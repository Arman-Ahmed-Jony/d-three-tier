#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

NODE_EXPORTER_VERSION="${NODE_EXPORTER_VERSION:-1.12.1}"

require_root
ARCH="$(detect_arch)"
ensure_packages curl tar gzip

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

TARBALL="node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz"
URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${TARBALL}"

download "${URL}" "${TMP_DIR}/${TARBALL}"
tar -xzf "${TMP_DIR}/${TARBALL}" -C "${TMP_DIR}"

ensure_user node_exporter
install -m 0755 "${TMP_DIR}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}/node_exporter" /usr/local/bin/node_exporter
install_unit "${REPO_ROOT}/monitoring/node-exporter/node_exporter.service"

echo "Node Exporter ${NODE_EXPORTER_VERSION} installed."
echo "Metrics: http://127.0.0.1:9100/metrics"
