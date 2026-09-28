#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

# Promtail binaries stopped shipping with Loki 3.7+. 3.4.2 is the last zip release.
PROMTAIL_VERSION="${PROMTAIL_VERSION:-3.4.2}"

require_root
ARCH="$(detect_arch)"
ensure_packages curl unzip

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

ZIP="promtail-linux-${ARCH}.zip"
URL="https://github.com/grafana/loki/releases/download/v${PROMTAIL_VERSION}/${ZIP}"

download "${URL}" "${TMP_DIR}/${ZIP}"
unzip -o "${TMP_DIR}/${ZIP}" -d "${TMP_DIR}"

BINARY="${TMP_DIR}/promtail-linux-${ARCH}"
if [[ ! -f "${BINARY}" ]]; then
  BINARY="$(find "${TMP_DIR}" -type f -name 'promtail*' ! -name '*.zip' -print -quit)"
fi
if [[ -z "${BINARY}" || ! -f "${BINARY}" ]]; then
  echo "Could not find Promtail binary in ${ZIP}" >&2
  exit 1
fi

ensure_user promtail
if getent group systemd-journal >/dev/null 2>&1; then
  usermod -aG systemd-journal promtail
fi
if getent group adm >/dev/null 2>&1; then
  usermod -aG adm promtail
fi

ensure_dir /etc/promtail promtail:promtail
ensure_dir /var/lib/promtail promtail:promtail

install -m 0755 "${BINARY}" /usr/local/bin/promtail
install -m 0644 "${REPO_ROOT}/monitoring/promtail/promtail-config.yml" /etc/promtail/promtail-config.yml
chown -R promtail:promtail /etc/promtail /var/lib/promtail

install_unit "${REPO_ROOT}/monitoring/promtail/promtail.service"

echo "Promtail ${PROMTAIL_VERSION} installed (ships journal logs to Loki)."
echo "Ready: http://127.0.0.1:9080/ready"
