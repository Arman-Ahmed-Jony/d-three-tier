#!/usr/bin/env bash
# Shared helpers for Ubuntu monitoring install scripts. Sourced, not executed.

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "This script must be run as root (sudo)." >&2
    exit 1
  fi
}

detect_arch() {
  case "$(uname -m)" in
    x86_64) echo amd64 ;;
    aarch64|arm64) echo arm64 ;;
    *)
      echo "Unsupported architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

ensure_user() {
  local user="$1"
  if ! id "$user" >/dev/null 2>&1; then
    useradd --system --no-create-home --shell /usr/sbin/nologin "$user"
  fi
}

ensure_dir() {
  local dir="$1"
  local owner="${2:-root:root}"
  mkdir -p "$dir"
  chown "$owner" "$dir"
}

download() {
  local url="$1"
  local dest="$2"
  echo "Downloading ${url}"
  curl -fsSL -o "$dest" "$url"
}

ensure_packages() {
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

install_unit() {
  local src="$1"
  local name
  name="$(basename "$src")"
  install -m 0644 "$src" "/etc/systemd/system/${name}"
  systemctl daemon-reload
  systemctl enable --now "${name%.service}"
  systemctl restart "${name%.service}"
}
