#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

GRAFANA_VERSION="${GRAFANA_VERSION:-13.2.2}"
GRAFANA_BUILD="${GRAFANA_BUILD:-34846740809}"

require_root
ARCH="$(detect_arch)"
ensure_packages curl adduser libfontconfig1 musl

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

if [[ "${ARCH}" == "amd64" ]]; then
  DEB="grafana_${GRAFANA_VERSION}_${GRAFANA_BUILD}_linux_amd64.deb"
else
  DEB="grafana_${GRAFANA_VERSION}_${GRAFANA_BUILD}_linux_arm64.deb"
fi
URL="https://dl.grafana.com/grafana/release/${GRAFANA_VERSION}/${DEB}"

download "${URL}" "${TMP_DIR}/${DEB}"
apt-get install -y "${TMP_DIR}/${DEB}"

ensure_dir /etc/grafana/provisioning/datasources
ensure_dir /etc/grafana/provisioning/dashboards
ensure_dir /var/lib/grafana/dashboards grafana:grafana

install -m 0644 "${REPO_ROOT}/monitoring/grafana/datasources.yaml" /etc/grafana/provisioning/datasources/datasources.yaml
install -m 0644 "${REPO_ROOT}/monitoring/grafana/dashboards.yaml" /etc/grafana/provisioning/dashboards/dashboards.yaml
install -m 0644 "${REPO_ROOT}/monitoring/grafana/node-overview.json" /var/lib/grafana/dashboards/node-overview.json
chown -R grafana:grafana /var/lib/grafana/dashboards

systemctl daemon-reload
systemctl enable --now grafana-server
systemctl restart grafana-server

echo "Grafana ${GRAFANA_VERSION} installed."
echo "UI: http://127.0.0.1:3000  (default login admin / admin — change it on the server, do not commit it)"
