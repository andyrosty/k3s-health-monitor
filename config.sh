#!/usr/bin/env bash
# Where kubectl commands should run from
K3S_CONTROL_HOST="andrew@192.168.50.147"

# Run kubectl remotely through the control node
KUBECTL_CMD=(ssh "$K3S_CONTROL_HOST" sudo k3s kubectl)
FLUX_CMD=(ssh "$K3S_CONTROL_HOST" sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml flux)

# Cluster identity
CLUSTER_NAME="homelab-k3s"
EXPECTED_NODE_COUNT=3

# Network
INGRESS_NAMESPACE="nginx-ingress"
INGRESS_SERVICE="ingress-nginx-controller"
EXPECTED_INGRESS_IP="192.168.50.240"

# kube-prometheus-stack creates these control-plane metric Services without
# endpoint objects; Prometheus discovers their targets separately.
SERVICE_ENDPOINT_EXCLUSIONS=(
  "kube-system/kube-prometheus-stack-kube-controller-manager"
  "kube-system/kube-prometheus-stack-kube-etcd"
  "kube-system/kube-prometheus-stack-kube-proxy"
  "kube-system/kube-prometheus-stack-kube-scheduler"
)

# NAS / NFS
NAS_SERVER="192.168.50.227"
NAS_DOWNLOADS_PATH="/downloads"
NAS_MEDIA_PATH="/media"

QBITTORRENT_DOWNLOADS_PVC="qbittorrent-downloads"
JELLYFIN_MEDIA_PVC="jellyfin-media"

# Apps
HOMEPAGE_NAMESPACE="homepage"
HOMEPAGE_DEPLOYMENT="homepage"
HOMEPAGE_URL="https://homepage.dev-andrew.com"

GRAFANA_NAMESPACE="monitoring"
GRAFANA_DEPLOYMENT="kube-prometheus-stack-grafana"
GRAFANA_URL="https://grafana.dev-andrew.com"

JELLYFIN_NAMESPACE="jellyfin"
JELLYFIN_DEPLOYMENT="jellyfin"
JELLYFIN_URL="https://jellyfin.dev-andrew.com"

QBITTORRENT_NAMESPACE="qbittorrent"
QBITTORRENT_DEPLOYMENT="qbittorrent"
QBITTORRENT_CONTAINER="qbittorrent"
GLUETUN_CONTAINER="gluetun"
QBITTORRENT_URL="https://qbittorrent.dev-andrew.com"

QBITTORRENT_OAUTH2_PROXY_DEPLOYMENT="qbittorrent-oauth2-proxy"

SMOKE_TEST_NAMESPACE="smoke-test"
SMOKE_TEST_DEPLOYMENT="nginx-smoke-test"
SMOKE_TEST_URL="http://smoke-test.dev-andrew.com"

STORAGE_TEST_NAMESPACE="storage-test"
STORAGE_TEST_DEPLOYMENT="storage-test"
STORAGE_TEST_PVC="storage-test-data"

CLOUDFLARED_NAMESPACE="cloudflare"
CLOUDFLARED_DEPLOYMENT="cloudflared"
CLOUDFLARED_LOG_LOOKBACK="15m"

KEYCLOAK_NAMESPACE="keycloak"
KEYCLOAK_DEPLOYMENT="keycloak"
KEYCLOAK_POSTGRES_DEPLOYMENT="keycloak-postgres"
KEYCLOAK_URL="https://keycloak.dev-andrew.com"

ROCKETCHAT_NAMESPACE="rocketchat"
ROCKETCHAT_HELMRELEASE="rocketchat"
ROCKETCHAT_DEPLOYMENT="rocketchat-rocketchat"
ROCKETCHAT_MONGODB_STATEFULSET="rocketchat-mongodb"
ROCKETCHAT_NATS_STATEFULSET="rocketchat-nats"
ROCKETCHAT_URL="https://rocketchat.dev-andrew.com"

# Health thresholds
GLUETUN_LOG_LOOKBACK="10m"
PUBLIC_IP_CHECK_URL="https://api.ipify.org"
