#!/usr/bin/env bash

check_deployment_ready() {
  local name="$1"
  local namespace="$2"
  local deployment="$3"

  if ! k get deployment "$deployment" -n "$namespace" >/dev/null 2>&1; then
    fail "$name deployment $namespace/$deployment not found"
    return 1
  fi

  local desired
  local available

  desired="$(k get deployment "$deployment" -n "$namespace" -o jsonpath='{.status.replicas}' 2>/dev/null)"
  available="$(k get deployment "$deployment" -n "$namespace" -o jsonpath='{.status.availableReplicas}' 2>/dev/null)"

  desired="${desired:-0}"
  available="${available:-0}"

  if [ "$desired" -gt 0 ] && [ "$available" -eq "$desired" ]; then
    pass "$name deployment Ready: $available/$desired"
    return 0
  else
    fail "$name deployment not Ready: $available/$desired"
    echo "       Run: kubectl get pods -n $namespace"
    return 1
  fi
}

check_statefulset_ready() {
  local name="$1"
  local namespace="$2"
  local statefulset="$3"
  local ready
  local desired

  if ! k get statefulset "$statefulset" -n "$namespace" >/dev/null 2>&1; then
    fail "$name StatefulSet $namespace/$statefulset not found"
    return 1
  fi

  ready="$(k get statefulset "$statefulset" -n "$namespace" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)"
  desired="$(k get statefulset "$statefulset" -n "$namespace" -o jsonpath='{.spec.replicas}' 2>/dev/null)"
  ready="${ready:-0}"
  desired="${desired:-0}"

  if [ "$ready" -eq "$desired" ]; then
    pass "$name StatefulSet Ready: $ready/$desired"
  else
    fail "$name StatefulSet not Ready: $ready/$desired"
    return 1
  fi
}

check_homepage() {
  check_deployment_ready "Homepage" "$HOMEPAGE_NAMESPACE" "$HOMEPAGE_DEPLOYMENT"
}

check_grafana() {
  check_deployment_ready "Grafana" "$GRAFANA_NAMESPACE" "$GRAFANA_DEPLOYMENT"
}

check_jellyfin() {
  check_deployment_ready "Jellyfin" "$JELLYFIN_NAMESPACE" "$JELLYFIN_DEPLOYMENT"
}

check_smoke_test() {
  check_deployment_ready "Smoke test" "$SMOKE_TEST_NAMESPACE" "$SMOKE_TEST_DEPLOYMENT"
}

check_storage_test() {
  check_deployment_ready "Storage test" "$STORAGE_TEST_NAMESPACE" "$STORAGE_TEST_DEPLOYMENT" || return
  check_pvc_bound "$STORAGE_TEST_NAMESPACE" "$STORAGE_TEST_PVC"
}

check_cloudflared() {
  check_deployment_ready "Cloudflared" "$CLOUDFLARED_NAMESPACE" "$CLOUDFLARED_DEPLOYMENT" || return

  if k logs -n "$CLOUDFLARED_NAMESPACE" "deploy/$CLOUDFLARED_DEPLOYMENT" \
    --since="$CLOUDFLARED_LOG_LOOKBACK" 2>/dev/null | grep -q "Registered tunnel connection"; then
    pass "Cloudflared tunnel connected within the last $CLOUDFLARED_LOG_LOOKBACK"
  else
    warn "Cloudflared has no recent tunnel-connection log entry"
  fi
}

check_keycloak() {
  check_deployment_ready "Keycloak" "$KEYCLOAK_NAMESPACE" "$KEYCLOAK_DEPLOYMENT"
  check_deployment_ready "Keycloak PostgreSQL" "$KEYCLOAK_NAMESPACE" "$KEYCLOAK_POSTGRES_DEPLOYMENT"
}

check_helmrelease_ready() {
  local name="$1"
  local namespace="$2"
  local release="$3"
  local ready

  if ! k get helmrelease "$release" -n "$namespace" >/dev/null 2>&1; then
    fail "$name HelmRelease $namespace/$release not found"
    return 1
  fi

  ready="$(f get helmreleases -A --no-header 2>/dev/null \
    | awk -v namespace="$namespace" -v release="$release" \
      '$1 == namespace && $2 == release {print $5}')"
  if [ "$ready" = "True" ]; then
    pass "$name HelmRelease Ready"
  else
    fail "$name HelmRelease not Ready (Ready=${ready:-Unknown})"
    echo "       Run: flux get helmreleases -n $namespace"
    return 1
  fi
}

check_rocketchat() {
  check_helmrelease_ready "Rocket.Chat" "$ROCKETCHAT_NAMESPACE" "$ROCKETCHAT_HELMRELEASE"
  check_deployment_ready "Rocket.Chat" "$ROCKETCHAT_NAMESPACE" "$ROCKETCHAT_DEPLOYMENT"
  check_statefulset_ready "Rocket.Chat MongoDB" "$ROCKETCHAT_NAMESPACE" "$ROCKETCHAT_MONGODB_STATEFULSET"
  check_statefulset_ready "Rocket.Chat NATS" "$ROCKETCHAT_NAMESPACE" "$ROCKETCHAT_NATS_STATEFULSET"
}


check_qbittorrent() {
  check_deployment_ready "qBittorrent" "$QBITTORRENT_NAMESPACE" "$QBITTORRENT_DEPLOYMENT" || return
  check_deployment_ready "qBittorrent OAuth2 Proxy" "$QBITTORRENT_NAMESPACE" "$QBITTORRENT_OAUTH2_PROXY_DEPLOYMENT"

  local pod
  pod="$(k get pod -n "$QBITTORRENT_NAMESPACE" -l app=qbittorrent -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)"

  if [ -z "$pod" ]; then
    fail "qBittorrent pod not found"
    return
  fi

  local container_table
  container_table="$(k get pod "$pod" -n "$QBITTORRENT_NAMESPACE" \
    -o custom-columns=NAME:.status.containerStatuses[*].name,READY:.status.containerStatuses[*].ready \
    --no-headers 2>/dev/null)"

  if [ -z "$container_table" ]; then
    fail "Could not read qBittorrent container statuses from pod $pod"
    echo "       Run: kubectl get pod -n $QBITTORRENT_NAMESPACE $pod -o wide"
    return
  fi

  if echo "$container_table" | grep -q "$QBITTORRENT_CONTAINER" && \
     echo "$container_table" | grep -q "$GLUETUN_CONTAINER" && \
     echo "$container_table" | grep -q "true,true"; then
    pass "qBittorrent containers Ready: $container_table"
  else
    fail "qBittorrent containers not Ready: $container_table"
    echo "       Run: kubectl describe pod -n $QBITTORRENT_NAMESPACE $pod"
  fi

  if k exec -n "$QBITTORRENT_NAMESPACE" "deploy/$QBITTORRENT_DEPLOYMENT" \
    -c "$QBITTORRENT_CONTAINER" -- wget -q --spider --timeout=10 "http://127.0.0.1:8080" >/dev/null 2>&1; then
    pass "qBittorrent Web UI reachable inside pod"
  else
    fail "qBittorrent Web UI not reachable inside pod"
    echo "       qBittorrent container is running, but localhost:8080 did not respond."
  fi
}

check_gluetun() {
  local logs
  local bad_logs

  if ! k logs -n "$QBITTORRENT_NAMESPACE" "deploy/$QBITTORRENT_DEPLOYMENT" \
    -c "$GLUETUN_CONTAINER" --since="$GLUETUN_LOG_LOOKBACK" >/tmp/gluetun-healthcheck.log 2>/dev/null; then
    fail "Could not read Gluetun logs"
    return
  fi

  logs="$(cat /tmp/gluetun-healthcheck.log)"

  bad_logs="$(echo "$logs" | grep -Ei 'restarting VPN because it failed to pass the healthcheck|lookup .* i/o timeout|wireguard connection is not working|operation not permitted' || true)"

  rm -f /tmp/gluetun-healthcheck.log

  if [ -z "$bad_logs" ]; then
    pass "Gluetun logs clean for last $GLUETUN_LOG_LOOKBACK"
  else
    fail "Gluetun VPN health issue detected in last $GLUETUN_LOG_LOOKBACK:"
    echo "$bad_logs" | tail -10 | sed 's/^/       /'
    echo "       Suggested: check Proton endpoint, DNS_ADDRESS, DOT, and WIREGUARD_MTU."
  fi
}

check_qbittorrent_vpn_ip() {
  local qbit_ip
  local control_ip

  qbit_ip="$(k exec -n "$QBITTORRENT_NAMESPACE" "deploy/$QBITTORRENT_DEPLOYMENT" \
    -c "$QBITTORRENT_CONTAINER" -- wget -qO- --timeout=15 "$PUBLIC_IP_CHECK_URL" 2>/dev/null || true)"

  if [ -z "$qbit_ip" ]; then
    fail "Could not get qBittorrent public IP from inside pod"
    echo "       qBittorrent may not have internet access, DNS may be failing, or Gluetun may be blocking traffic."
    return
  fi

  control_ip="$(ssh "$K3S_CONTROL_HOST" "curl -s --max-time 15 $PUBLIC_IP_CHECK_URL" 2>/dev/null || true)"

  if [ -z "$control_ip" ]; then
    warn "Could not get control-node public IP for VPN comparison"
    echo "       qBittorrent public IP from pod: $qbit_ip"
    return
  fi

  if [ "$qbit_ip" = "$control_ip" ]; then
    fail "qBittorrent public IP matches control-node/home IP: $qbit_ip"
    echo "       This suggests qBittorrent may NOT be going through the VPN."
  else
    pass "qBittorrent VPN IP check passed: qBittorrent=$qbit_ip control-node=$control_ip"
  fi
}
