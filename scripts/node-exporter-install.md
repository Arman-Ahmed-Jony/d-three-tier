# Prometheus Node Exporter — Ubuntu EC2

Prometheus **Node Exporter** collects hardware and OS-level metrics from a Linux machine and exposes them through an HTTP endpoint.

By default, Node Exporter runs on:

```text
http://<EC2-IP>:9100/metrics
```

---

## 1. Download Node Exporter

Download and extract Node Exporter:

```bash
wget https://github.com/prometheus/node_exporter/releases/download/v1.12.1/node_exporter-1.12.1.linux-amd64.tar.gz

tar -xvf node_exporter-1.12.1.linux-amd64.tar.gz
```

Copy the binary to `/usr/local/bin`:

```bash
sudo cp node_exporter-1.12.1.linux-amd64/node_exporter /usr/local/bin/
```

Verify the installation:

```bash
node_exporter --version
```

---

## 2. Create a Dedicated User

It is recommended to run Node Exporter using a dedicated system user instead of `root`.

```bash
sudo useradd --no-create-home --shell /bin/false node_exporter
```

---

## 3. Create a systemd Service

Create the service file:

```bash
sudo nano /etc/systemd/system/node_exporter.service
```

Add:

```ini
[Unit]
Description=Prometheus Node Exporter
Documentation=https://github.com/prometheus/node_exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --web.listen-address=0.0.0.0:9100
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Save and exit.

---

## 4. Enable and Start Node Exporter

Reload systemd:

```bash
sudo systemctl daemon-reload
```

Enable Node Exporter to start automatically after a reboot:

```bash
sudo systemctl enable node_exporter
```

Start the service:

```bash
sudo systemctl start node_exporter
```

Check the service status:

```bash
sudo systemctl status node_exporter
```

You should see:

```text
Active: active (running)
```

---

## 5. Verify Node Exporter

Check that Node Exporter is listening on port `9100`:

```bash
sudo ss -lntp | grep 9100
```

You can also test it locally:

```bash
curl http://localhost:9100/metrics
```

If everything is working, you will see Prometheus metrics such as:

```text
# HELP node_cpu_seconds_total Seconds the CPUs spent in each mode.
# TYPE node_cpu_seconds_total counter
node_cpu_seconds_total{cpu="0",mode="idle"} ...
```

---

## 6. Access Metrics from a Browser

Node Exporter exposes metrics on port **9100**.

```text
http://<EC2-PUBLIC-IP>:9100/metrics
```

For example:

```text
http://18.123.45.67:9100/metrics
```

### AWS Security Group

If you want to access the metrics from your local machine, add an inbound rule to the EC2 Security Group:

```text
Type:        Custom TCP
Protocol:    TCP
Port:        9100
Source:      My IP
```

For a production environment, avoid exposing port `9100` to:

```text
0.0.0.0/0
```

Instead, allow access only from your **Prometheus server's Security Group or private IP**.

---

## 7. Useful Commands

### Check status

```bash
sudo systemctl status node_exporter
```

### Start

```bash
sudo systemctl start node_exporter
```

### Stop

```bash
sudo systemctl stop node_exporter
```

### Restart

```bash
sudo systemctl restart node_exporter
```

### Enable on boot

```bash
sudo systemctl enable node_exporter
```

### View logs

```bash
sudo journalctl -u node_exporter -f
```

---

## Architecture

Node Exporter itself does **not store metrics**. It exposes metrics for Prometheus to collect.

```text
┌───────────────────────┐
│       Ubuntu EC2      │
│                       │
│  CPU                  │
│  Memory               │
│  Disk                 │
│  Network              │
│  Filesystem           │
│         │             │
│         ▼             │
│   Node Exporter       │
│       :9100           │
└──────────┬────────────┘
           │
           │ /metrics
           ▼
      ┌────────────┐
      │ Prometheus │
      │    :9090   │
      └─────┬──────┘
            │
            ▼
       ┌──────────┐
       │ Grafana  │
       │   :3000  │
       └──────────┘
```

The flow is:

```text
Ubuntu EC2
    ↓
Node Exporter
    ↓
Prometheus
    ↓
Grafana
```

Node Exporter provides the machine metrics, Prometheus collects and stores them, and Grafana visualizes them.
