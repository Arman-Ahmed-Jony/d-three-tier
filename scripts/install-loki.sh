#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

LOKI_VERSION="${LOKI_VERSION:-3.7.8}"

require_root
ARCH="$(detect_arch)"
ensure_packages curl unzip

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

ZIP="loki-linux-${ARCH}.zip"
URL="https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/${ZIP}"

download "${URL}" "${TMP_DIR}/${ZIP}"
unzip -o "${TMP_DIR}/${ZIP}" -d "${TMP_DIR}"

BINARY="${TMP_DIR}/loki-linux-${ARCH}"
if [[ ! -f "${BINARY}" ]]; then
  BINARY="$(find "${TMP_DIR}" -type f -name 'loki*' ! -name '*.zip' -print -quit)"
fi
if [[ -z "${BINARY}" || ! -f "${BINARY}" ]]; then
  echo "Could not find Loki binary in ${ZIP}" >&2
  exit 1
fi

ensure_user loki
ensure_dir /etc/loki loki:loki
ensure_dir /var/lib/loki loki:loki
ensure_dir /var/lib/loki/chunks loki:loki
ensure_dir /var/lib/loki/rules loki:loki

install -m 0755 "${BINARY}" /usr/local/bin/loki
install -m 0644 "${REPO_ROOT}/monitoring/loki/loki-config.yml" /etc/loki/loki-config.yml
chown -R loki:loki /etc/loki /var/lib/loki

install_unit "${REPO_ROOT}/monitoring/loki/loki.service"

echo "Loki ${LOKI_VERSION} installed."
echo "Ready: http://127.0.0.1:3100/ready"
