
#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Native Ubuntu Observability Stack
# Prometheus + Grafana + Loki + Grafana Alloy
# No Docker
# Target: Ubuntu 24.04 LTS, amd64 or arm64
# ============================================================

if [[ "${EUID}" -ne 0 ]]; then
    echo "Run with: sudo bash $0"
    exit 1
fi

if [[ ! -f /etc/os-release ]]; then
    echo "Cannot identify the operating system."
    exit 1
fi

. /etc/os-release

if [[ "${ID}" != "ubuntu" ]]; then
    echo "This script supports Ubuntu only."
    exit 1
fi

ARCH="$(dpkg --print-architecture)"

case "$ARCH" in
    amd64) PROM_ARCH="linux-amd64"; LOKI_ARCH="amd64" ;;
    arm64) PROM_ARCH="linux-arm64"; LOKI_ARCH="arm64" ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "=== Installing prerequisites ==="

apt-get update
apt-get install -y \
    ca-certificates curl gnupg jq unzip tar

# ------------------------------------------------------------
# 1. Configure Grafana's official APT repository
# ------------------------------------------------------------

echo "=== Configuring Grafana repository ==="

install -d -m 0755 /etc/apt/keyrings

curl -fsSL https://apt.grafana.com/gpg.key \
    -o /tmp/grafana.gpg.key

gpg --dearmor --yes \
    -o /etc/apt/keyrings/grafana.gpg \
    /tmp/grafana.gpg.key

chmod 0644 /etc/apt/keyrings/grafana.gpg

cat > /etc/apt/sources.list.d/grafana.list <<'EOF'
deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main
EOF

apt-get update

# Install Grafana and Alloy from the official repository.
apt-get install -y grafana alloy

# ------------------------------------------------------------
# 2. Install Prometheus
# ------------------------------------------------------------

echo "=== Installing Prometheus ==="

PROM_VERSION="$(
    curl -fsSL \
      https://api.github.com/repos/prometheus/prometheus/releases/latest |
      jq -er '.tag_name | ltrimstr("v")'
)"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

curl -fL \
    "https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.${PROM_ARCH}.tar.gz" \
    -o "$TMP_DIR/prometheus.tar.gz"

tar -xzf "$TMP_DIR/prometheus.tar.gz" -C "$TMP_DIR"

id prometheus >/dev/null 2>&1 ||
    useradd --system --no-create-home \
      --shell /usr/sbin/nologin prometheus

install -d -o prometheus -g prometheus -m 0750 \
    /etc/prometheus /var/lib/prometheus

PROM_DIR="$TMP_DIR/prometheus-${PROM_VERSION}.${PROM_ARCH}"

install -o root -g root -m 0755 \
    "$PROM_DIR/prometheus" /usr/local/bin/prometheus

install -o root -g root -m 0755 \
    "$PROM_DIR/promtool" /usr/local/bin/promtool

cat > /etc/prometheus/prometheus.yml <<'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ['127.0.0.1:9090']
EOF

chown root:prometheus /etc/prometheus/prometheus.yml
chmod 0640 /etc/prometheus/prometheus.yml

cat > /etc/systemd/system/prometheus.service <<'EOF'
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --storage.tsdb.retention.time=15d \
  --web.listen-address=127.0.0.1:9090 \
  --web.enable-remote-write-receiver

Restart=on-failure
RestartSec=5s
NoNewPrivileges=true
ProtectHome=true
ProtectSystem=full
ReadWritePaths=/var/lib/prometheus

[Install]
WantedBy=multi-user.target
EOF

# ------------------------------------------------------------
# 3. Install Loki
# ------------------------------------------------------------

echo "=== Installing Loki ==="

LOKI_VERSION="$(
    curl -fsSL \
      https://api.github.com/repos/grafana/loki/releases/latest |
      jq -er '.tag_name | ltrimstr("v")'
)"

curl -fL \
    "https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/loki-linux-${LOKI_ARCH}.zip" \
    -o "$TMP_DIR/loki.zip"

unzip -oq "$TMP_DIR/loki.zip" -d "$TMP_DIR/loki"

install -o root -g root -m 0755 \
    "$TMP_DIR/loki/loki-linux-${LOKI_ARCH}" \
    /usr/local/bin/loki

id loki >/dev/null 2>&1 ||
    useradd --system --no-create-home \
      --shell /usr/sbin/nologin loki

install -d -o loki -g loki -m 0750 \
    /etc/loki /var/lib/loki

cat > /etc/loki/config.yml <<'EOF'
auth_enabled: false

server:
  http_listen_address: 127.0.0.1
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /var/lib/loki
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory
  storage:
    filesystem:
      chunks_directory: /var/lib/loki/chunks
      rules_directory: /var/lib/loki/rules

schema_config:
  configs:
    - from: 2024-04-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

limits_config:
  retention_period: 168h

compactor:
  working_directory: /var/lib/loki/compactor
  retention_enabled: true
  delete_request_store: filesystem
EOF

chown root:loki /etc/loki/config.yml
chmod 0640 /etc/loki/config.yml

cat > /etc/systemd/system/loki.service <<'EOF'
[Unit]
Description=Loki Log Aggregation
Wants=network-online.target
After=network-online.target

[Service]
User=loki
Group=loki
Type=simple
ExecStart=/usr/local/bin/loki -config.file=/etc/loki/config.yml
Restart=on-failure
RestartSec=5s
NoNewPrivileges=true
ProtectHome=true
ProtectSystem=full
ReadWritePaths=/var/lib/loki

[Install]
WantedBy=multi-user.target
EOF

# ------------------------------------------------------------
# 4. Configure Grafana datasource provisioning
# ------------------------------------------------------------

echo "=== Configuring Grafana datasources ==="

install -d -o root -g grafana -m 0750 \
    /etc/grafana/provisioning/datasources

cat > /etc/grafana/provisioning/datasources/observability.yml <<'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    uid: prometheus
    type: prometheus
    access: proxy
    url: http://127.0.0.1:9090
    isDefault: true
    editable: true

  - name: Loki
    uid: loki
    type: loki
    access: proxy
    url: http://127.0.0.1:3100
    editable: true
EOF

# IMPORTANT: Grafana must be able to read this file.
chown root:grafana \
    /etc/grafana/provisioning/datasources/observability.yml
chmod 0640 \
    /etc/grafana/provisioning/datasources/observability.yml

# ------------------------------------------------------------
# 5. Configure Grafana Alloy
# ------------------------------------------------------------

echo "=== Configuring Grafana Alloy ==="

# Allow Alloy to read standard Ubuntu system logs.
usermod -aG adm alloy

cat > /etc/alloy/config.alloy <<'EOF'
prometheus.exporter.unix "local" {}

prometheus.scrape "local" {
  targets    = prometheus.exporter.unix.local.targets
  forward_to = [prometheus.remote_write.local.receiver]
}

prometheus.remote_write "local" {
  endpoint {
    url = "http://127.0.0.1:9090/api/v1/write"
  }
}

loki.write "local" {
  endpoint {
    url = "http://127.0.0.1:3100/loki/api/v1/push"
  }
}

local.file_match "system_logs" {
  path_targets = [
    {
      "__path__" = "/var/log/*.log",
      "job"      = "system",
      "host"     = constants.hostname,
    },
  ]
}

loki.source.file "system_logs" {
  targets    = local.file_match.system_logs.targets
  forward_to = [loki.write.local.receiver]
}
EOF

chown root:alloy /etc/alloy/config.alloy
chmod 0640 /etc/alloy/config.alloy

# ------------------------------------------------------------
# 6. Start services
# ------------------------------------------------------------

echo "=== Enabling and restarting services ==="

systemctl daemon-reload

systemctl enable prometheus loki grafana-server alloy

systemctl restart prometheus
systemctl restart loki

# Give backend services a moment to initialize.
sleep 3

systemctl restart alloy
systemctl restart grafana-server

echo
echo "=== Installation finished ==="
echo
echo "Checking service status..."

for SERVICE in prometheus loki alloy grafana-server; do
    if systemctl is-active --quiet "$SERVICE"; then
        echo "[OK] $SERVICE is running"
    else
        echo "[ERROR] $SERVICE is not running"
        systemctl --no-pager --full status "$SERVICE" || true
    fi
done

echo
echo "=== Local endpoints ==="
echo "Grafana:    http://127.0.0.1:3000"
echo "Prometheus: http://127.0.0.1:9090"
echo "Loki:       http://127.0.0.1:3100"
echo
echo "Only Grafana should normally be opened from your browser."
echo "Restrict EC2 Security Group TCP 3000 to your own IP."
echo
echo "Check Grafana with:"
echo "  curl -I http://127.0.0.1:3000"
echo
echo "Check logs with:"
echo "  sudo journalctl -u grafana-server -n 50 --no-pager"