#!/usr/bin/env bash

check_ingress_service() {
  local svc_type
  local external_ip

  if ! k get svc "$INGRESS_SERVICE" -n "$INGRESS_NAMESPACE" >/dev/null 2>&1; then
    fail "Ingress service $INGRESS_NAMESPACE/$INGRESS_SERVICE not found"
    return
  fi

  svc_type="$(k get svc "$INGRESS_SERVICE" -n "$INGRESS_NAMESPACE" -o jsonpath='{.spec.type}' 2>/dev/null)"
  external_ip="$(k get svc "$INGRESS_SERVICE" -n "$INGRESS_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)"

  if [ "$svc_type" != "LoadBalancer" ]; then
    fail "Ingress service is type $svc_type, expected LoadBalancer"
    return
  fi

  if [ -z "$external_ip" ]; then
    fail "Ingress LoadBalancer has no external IP"
    return
  fi

  if [ "$external_ip" = "$EXPECTED_INGRESS_IP" ]; then
    pass "Ingress LoadBalancer IP is $external_ip"
  else
    warn "Ingress LoadBalancer IP is $external_ip, expected $EXPECTED_INGRESS_IP"
  fi
}

check_url() {
  local name="$1"
  local url="$2"
  local expected_codes="$3"
  local code

  if [ -z "$url" ]; then
    warn "$name URL not configured"
    return
  fi

  code="$(curl -k -L -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" || true)"

  if echo "$expected_codes" | grep -qw "$code"; then
    pass "$name URL reachable: $url returned HTTP $code"
  else
    fail "$name URL check failed: $url returned HTTP $code, expected one of [$expected_codes]"
  fi
}

check_external_urls() {
  check_url "Homepage" "$HOMEPAGE_URL" "200 302 403"
  check_url "Grafana" "$GRAFANA_URL" "200 302 403"
  check_url "Jellyfin" "$JELLYFIN_URL" "200 302 401 403"
  check_url "qBittorrent" "$QBITTORRENT_URL" "200 302 401 403"
  check_url "Smoke test" "$SMOKE_TEST_URL" "200"
  check_url "Keycloak" "$KEYCLOAK_URL" "200 302"
  check_url "Rocket.Chat" "$ROCKETCHAT_URL" "200 302 401 403"
}
