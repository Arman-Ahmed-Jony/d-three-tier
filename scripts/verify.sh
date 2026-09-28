#!/usr/bin/env bash
set -euo pipefail

fail=0

check_active() {
  local unit="$1"
  if systemctl is-active --quiet "$unit"; then
    echo "OK  systemd ${unit} is active"
  else
    echo "FAIL systemd ${unit} is not active"
    fail=1
  fi
}

check_url() {
  local name="$1"
  local url="$2"
  local expect="${3:-}"
  local body
  if ! body="$(curl -fsSL --max-time 10 "$url")"; then
    echo "FAIL ${name}: could not fetch ${url}"
    fail=1
    return
  fi
  if [[ -n "${expect}" ]] && ! grep -q "${expect}" <<<"${body}"; then
    echo "FAIL ${name}: ${url} did not contain '${expect}'"
    fail=1
    return
  fi
  echo "OK  ${name}: ${url}"
}

check_active node_exporter
check_active prometheus
check_active loki
check_active promtail
check_active grafana-server

check_url "Node Exporter metrics" "http://127.0.0.1:9100/metrics" "node_cpu_seconds_total"
check_url "Prometheus ready" "http://127.0.0.1:9090/-/ready"
check_url "Loki ready" "http://127.0.0.1:3100/ready"
check_url "Grafana health" "http://127.0.0.1:3000/api/health" "database"

if python3 - <<'PY'
import json
import sys
import urllib.request

try:
    with urllib.request.urlopen("http://127.0.0.1:9090/api/v1/targets", timeout=10) as resp:
        data = json.load(resp)
except Exception as exc:
    print(f"FAIL Prometheus targets API: {exc}")
    sys.exit(1)

node_up = False
for target in data.get("data", {}).get("activeTargets", []):
    job = target.get("labels", {}).get("job", "")
    health = target.get("health", "")
    print(f"    target job={job} health={health}")
    if job == "node" and health == "up":
        node_up = True

if not node_up:
    print("FAIL Prometheus node target is not UP")
    sys.exit(1)

print("OK  Prometheus node target is UP")
PY
then
  :
else
  fail=1
fi

echo
if [[ "${fail}" -eq 0 ]]; then
  echo "All checks passed."
  echo "Next: capture the README screenshots (Prometheus targets, Grafana dashboard, Loki logs, GitHub Actions)."
  exit 0
fi

echo "One or more checks failed. Inspect: journalctl -u <service> -e"
exit 1
