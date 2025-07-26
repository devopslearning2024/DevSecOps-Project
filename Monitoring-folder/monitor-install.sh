#!/bin/bash
# Installing Prometheus
sudo useradd --system --no-create-home --shell /bin/false prometheus
wget https://github.com/prometheus/prometheus/releases/download/v2.47.1/prometheus-2.47.1.linux-amd64.tar.gz
tar -xvf prometheus-2.47.1.linux-amd64.tar.gz
cd prometheus-2.47.1.linux-amd64/
sudo mkdir -p /data /etc/prometheus
sudo mv prometheus promtool /usr/local/bin/
sudo mv consoles/ console_libraries/ /etc/prometheus/
sudo mv prometheus.yml /etc/prometheus/prometheus.yml
sudo chown -R prometheus:prometheus /etc/prometheus/ /data/
sudo nano /etc/systemd/system/prometheus.service

SERVICE_FILE="/etc/systemd/system/prometheus.service"

# Create the systemd unit file for Prometheus
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target
StartLimitIntervalSec=500
StartLimitBurst=5

[Service]
User=prometheus
Group=prometheus
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=/data \\
  --web.console.templates=/etc/prometheus/consoles \\
  --web.console.libraries=/etc/prometheus/console_libraries \\
  --web.listen-address=0.0.0.0:9090 \\
  --web.enable-lifecycle

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable/start Prometheus
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus

# Check status
sudo systemctl status prometheus

#Installing Node Exporter
sudo useradd --system --no-create-home --shell /bin/false node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
tar -xvf node_exporter-1.6.1.linux-amd64.tar.gz
sudo mv node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter*

SERVICE_FILE1="/etc/systemd/system/node_exporter.service"

# Create the systemd unit file for Node Exporter
sudo tee "$SERVICE_FILE1" > /dev/null <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target
StartLimitIntervalSec=500
StartLimitBurst=5

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/node_exporter --collector.logind

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable/start node_exporter
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter

# Check status
sudo systemctl status node_exporter

PROM_FILE="/etc/prometheus/prometheus.yml"

# Backup existing file
sudo cp "$PROM_FILE" "${PROM_FILE}.bak.$(date +%F-%T)"

# Write Prometheus configuration
sudo tee "$PROM_FILE" > /dev/null <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'jenkins'
    metrics_path: '/prometheus'
    static_configs:
      - targets: ['localhost:8080']
EOF

# Restart Prometheus to apply changes
sudo systemctl restart prometheus

#Check the validity of the configuration file:
promtool check config /etc/prometheus/prometheus.yml
curl -X POST http://localhost:9090/-/reload


# Installing Grafana
sudo apt-get update
sudo apt-get install -y apt-transport-https software-properties-common

#Add the GPG Key
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -

#Add Grafana Repository
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list

#Update and Install Grafana
sudo apt-get update
sudo apt-get -y install grafana

#Enable and Start Grafana Service
sudo systemctl enable grafana-server
sudo systemctl start grafana-server