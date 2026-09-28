#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

PROMETHEUS_VERSION="${PROMETHEUS_VERSION:-3.14.0}"

require_root
ARCH="$(detect_arch)"
ensure_packages curl tar gzip

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

TARBALL="prometheus-${PROMETHEUS_VERSION}.linux-${ARCH}.tar.gz"
URL="https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/${TARBALL}"
EXTRACT_DIR="${TMP_DIR}/prometheus-${PROMETHEUS_VERSION}.linux-${ARCH}"

download "${URL}" "${TMP_DIR}/${TARBALL}"
tar -xzf "${TMP_DIR}/${TARBALL}" -C "${TMP_DIR}"

ensure_user prometheus
ensure_dir /etc/prometheus prometheus:prometheus
ensure_dir /var/lib/prometheus prometheus:prometheus

install -m 0755 "${EXTRACT_DIR}/prometheus" /usr/local/bin/prometheus
install -m 0755 "${EXTRACT_DIR}/promtool" /usr/local/bin/promtool
cp -r "${EXTRACT_DIR}/consoles" /etc/prometheus/
cp -r "${EXTRACT_DIR}/console_libraries" /etc/prometheus/
install -m 0644 "${REPO_ROOT}/monitoring/prometheus/prometheus.yml" /etc/prometheus/prometheus.yml
chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus

install_unit "${REPO_ROOT}/monitoring/prometheus/prometheus.service"

echo "Prometheus ${PROMETHEUS_VERSION} installed."
echo "UI: http://127.0.0.1:9090"
echo "Targets: http://127.0.0.1:9090/targets"
