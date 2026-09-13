# k3s-health-monitor

This project provides a comprehensive health monitoring script for k3s Kubernetes clusters. It automates checks for various cluster components, Flux CD deployments, Ingress services, storage PVCs, and specific applications, providing a consolidated report of their operational status.

## Features

The `healthcheck.sh` script performs the following checks:

### Cluster
- Checks `kubectl` connectivity.
- Verifies node and namespace status.
- Monitors node pressure.
- Identifies unhealthy pods.
- Detects excessive pod restarts.
- Checks Persistent Volume Claims (PVCs).
- Verifies Deployment, StatefulSet, DaemonSet, and Service endpoint readiness.

### Flux CD
- Checks Flux Kustomizations.
- Verifies Flux HelmReleases.
- Monitors Flux Sources.
- Verifies Flux HelmRepositories.

### Ingress
- Checks the Nginx Ingress service.
- Verifies ingress addresses, TLS certificate readiness, and external URLs configured for applications.

### Storage
- Monitors qBittorrent downloads.
- Checks Jellyfin media storage.

### Applications
- Checks the status of Homepage.
- Checks the status of Grafana.
- Checks the smoke test, storage test, and Cloudflared deployments.
- Checks Keycloak and its PostgreSQL deployment.
- Checks the Rocket.Chat HelmRelease.
- Checks the status of Jellyfin.
- Checks the status of qBittorrent.
- Checks the status of Gluetun.

### VPN
- Verifies the public IP address used by qBittorrent through Gluetun.

## Prerequisites

Before running the health check script, ensure you have:

- A running k3s Kubernetes cluster.
- SSH access to your k3s control plane host from where you intend to run this script.
- `kubectl` and `flux` CLIs installed on the k3s control plane host, accessible via `sudo`.

## Configuration

All configuration is managed in `config.sh`. You need to customize this file to match your cluster's setup.

```bash
#!/usr/bin/env bash

# Where kubectl commands should run from
K3S_CONTROL_HOST="your-k3s-control-plane-user@your-k3s-control-plane-ip"

# Run kubectl remotely through the control node
KUBECTL_CMD=(ssh "$K3S_CONTROL_HOST" sudo k3s kubectl)
FLUX_CMD=(ssh "$K3S_CONTROL_HOST" sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml flux)

# Cluster identity
CLUSTER_NAME="your-cluster-name"
EXPECTED_NODE_COUNT=3 # Adjust as per your cluster

# Network
INGRESS_NAMESPACE="nginx-ingress"
INGRESS_SERVICE="ingress-nginx-controller"
EXPECTED_INGRESS_IP="your-ingress-controller-ip"

# NAS / NFS (if applicable)
NAS_SERVER="your-nas-server-ip"
NAS_DOWNLOADS_PATH="/downloads"
NAS_MEDIA_PATH="/media"

QBITTORRENT_DOWNLOADS_PVC="qbittorrent-downloads" # Name of your qbittorrent downloads PVC
JELLYFIN_MEDIA_PVC="jellyfin-media" # Name of your jellyfin media PVC

# Apps (customize URLs and deployment names as needed)
HOMEPAGE_NAMESPACE="homepage"
HOMEPAGE_DEPLOYMENT="homepage"
HOMEPAGE_URL="https://homepage.yourdomain.com"

GRAFANA_NAMESPACE="monitoring"
GRAFANA_DEPLOYMENT="kube-prometheus-stack-grafana"
GRAFANA_URL="https://grafana.yourdomain.com"

JELLYFIN_NAMESPACE="jellyfin"
JELLYFIN_DEPLOYMENT="jellyfin"
JELLYFIN_URL="https://jellyfin.yourdomain.com"

QBITTORRENT_NAMESPACE="qbittorrent"
QBITTORRENT_DEPLOYMENT="qbittorrent"
QBITTORRENT_CONTAINER="qbittorrent"
GLUETUN_CONTAINER="gluetun"
QBITTORRENT_URL="https://qbittorrent.yourdomain.com"

# Health thresholds
GLUETUN_LOG_LOOKBACK="10m" # How far back to look in Gluetun logs for IP check
PUBLIC_IP_CHECK_URL="https://api.ipify.org" # URL to check public IP
```

## Usage


1.  **Edit `config.sh`:**
    Update the variables in `config.sh` with your cluster's specific details.

2.  **Run the health check:**
    ```bash
    ./healthcheck.sh
    ```

## Output

The script will print a detailed report to the console, categorizing checks by component (Cluster, Flux, Ingress, Storage, Applications, VPN). Each check will indicate `[PASS]` or `[FAIL]` along with relevant information or error messages. A summary will be provided at the end.
