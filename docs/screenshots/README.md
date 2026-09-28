# Required assignment screenshots

Capture these **after** `sudo bash scripts/install-all.sh` and `sudo bash scripts/verify.sh` succeed. Use an SSH tunnel if the VM is remote. Do not include passwords in the images.

Save files in this folder with **exactly** these names (referenced from the root README):

| File | What to capture |
|------|-----------------|
| `prometheus-targets.png` | Prometheus **Status → Targets** (or `/targets`). Job `node` / Node Exporter is **UP**. |
| `prometheus-query.png` | Prometheus Graph. Query e.g. `node_cpu_seconds_total` and execute. |
| `node-exporter-metrics.png` | Browser at `http://127.0.0.1:9100/metrics` showing `node_cpu_seconds_total`, memory, filesystem, network metrics. |
| `grafana-prometheus-datasource.png` | Grafana **Connections → Data sources → Prometheus**. Status: successfully connected / Save & test OK. |
| `grafana-dashboard.png` | Dashboard **Node Overview** with CPU, Memory, Disk, and Network panels. |
| `grafana-loki-datasource.png` | Grafana Loki datasource. Save & test OK. |
| `grafana-loki-logs.png` | Grafana **Explore**, datasource Loki, query `{job="systemd-journal"}` with log lines. |
| `gha-runner-online.png` | GitHub **Settings → Actions → Runners**. Self-hosted runner **Online**. |
| `gha-workflow-success.png` | A green **Client CI** run whose steps include **Build**, **Test**, and **Upload artifact**. |
| `gha-artifact.png` | The run’s **Artifacts** section showing `todo-client-build`. |

Suggested Grafana login URL: http://127.0.0.1:3000 (change the default admin password on the server).
