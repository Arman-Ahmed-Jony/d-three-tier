#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

GITHUB_REPO_URL="${GITHUB_REPO_URL:-https://github.com/Arman-Ahmed-Jony/d-three-tier}"
RUNNER_LABELS="${RUNNER_LABELS:-ostad_runner}"
RUNNER_DIR="${RUNNER_DIR:-/opt/actions-runner}"
RUNNER_USER="${RUNNER_USER:-github-runner}"

require_root

if [[ -z "${RUNNER_TOKEN:-}" ]]; then
  echo "Set RUNNER_TOKEN from GitHub → Settings → Actions → Runners → New self-hosted runner." >&2
  echo "Do not commit the token." >&2
  echo "Example:" >&2
  echo "  export RUNNER_TOKEN='...'" >&2
  echo "  sudo -E bash scripts/install-github-runner.sh" >&2
  exit 1
fi

ensure_packages curl tar gzip jq libicu-dev

if ! id "${RUNNER_USER}" >/dev/null 2>&1; then
  useradd --system --create-home --home-dir "${RUNNER_DIR}" --shell /bin/bash "${RUNNER_USER}"
fi

ensure_dir "${RUNNER_DIR}" "${RUNNER_USER}:${RUNNER_USER}"

ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64) RUNNER_ARCH="x64" ;;
  aarch64|arm64) RUNNER_ARCH="arm64" ;;
  *)
    echo "Unsupported architecture: ${ARCH}" >&2
    exit 1
    ;;
esac

RUNNER_VERSION="$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/^v//')"
TARBALL="actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${TARBALL}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT
download "${URL}" "${TMP_DIR}/${TARBALL}"

# config.sh refuses to run if the directory already looks configured unless --replace is used.
if [[ -x "${RUNNER_DIR}/svc.sh" ]]; then
  "${RUNNER_DIR}/svc.sh" stop || true
  "${RUNNER_DIR}/svc.sh" uninstall || true
fi
if [[ -x "${RUNNER_DIR}/config.sh" && -f "${RUNNER_DIR}/.runner" ]]; then
  sudo -u "${RUNNER_USER}" "${RUNNER_DIR}/config.sh" remove --token "${RUNNER_TOKEN}" || true
fi

tar -xzf "${TMP_DIR}/${TARBALL}" -C "${RUNNER_DIR}"
chown -R "${RUNNER_USER}:${RUNNER_USER}" "${RUNNER_DIR}"

sudo -u "${RUNNER_USER}" "${RUNNER_DIR}/config.sh" \
  --unattended \
  --replace \
  --url "${GITHUB_REPO_URL}" \
  --token "${RUNNER_TOKEN}" \
  --name "$(hostname)-ostad" \
  --labels "${RUNNER_LABELS}" \
  --work _work

cd "${RUNNER_DIR}"
./svc.sh install "${RUNNER_USER}"
./svc.sh start

echo "GitHub Actions runner ${RUNNER_VERSION} installed at ${RUNNER_DIR}"
echo "Label: ${RUNNER_LABELS}"
echo "Confirm it is Online: GitHub → Settings → Actions → Runners"
echo "Never commit RUNNER_TOKEN or ${RUNNER_DIR}/.runner"
