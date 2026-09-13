#!/usr/bin/env bash
set -u
set -o pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$BASE_DIR/config.sh"
source "$BASE_DIR/lib/output.sh"
source "$BASE_DIR/lib/kubernetes.sh"
source "$BASE_DIR/lib/flux.sh"
source "$BASE_DIR/lib/ingress.sh"
source "$BASE_DIR/lib/storage.sh"
source "$BASE_DIR/lib/apps.sh"

banner
echo "K3S HEALTH CHECK REPORT"
echo "Cluster: $CLUSTER_NAME"
echo "Time: $(date)"
echo

section "Cluster"
check_kubectl
check_nodes
check_namespaces
check_node_pressure
check_unhealthy_pods
check_pod_restarts
check_pvcs
check_deployments
check_statefulsets
check_daemonsets
check_service_endpoints

section "Flux"
check_flux_kustomizations
check_flux_helmreleases
check_flux_sources
check_flux_helmrepositories

section "Ingress"
check_ingress_service
check_ingresses
check_external_urls
check_certificates

section "Storage"
check_qbittorrent_downloads
check_jellyfin_media

section "Applications"
check_homepage
check_grafana
check_smoke_test
check_storage_test
check_cloudflared
check_keycloak
check_rocketchat
check_jellyfin
check_qbittorrent
check_gluetun

section "VPN"
check_qbittorrent_vpn_ip

summary
