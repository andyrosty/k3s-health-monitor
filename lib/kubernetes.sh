#!/usr/bin/env bash

k() {
  "${KUBECTL_CMD[@]}" "$@"
}

check_kubectl() {
  if k version --client >/dev/null 2>&1 && k cluster-info >/dev/null 2>&1; then
    pass "Kubernetes API reachable through $K3S_CONTROL_HOST"
  else
    fail "Kubernetes API not reachable $K3_CONTROL_HOST. Check kubeconfig or k3s service."
  fi
}

check_nodes() {
  local total
  local ready

  total="$(k get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')"
  ready="$(k get nodes --no-headers 2>/dev/null | awk '$2 == "Ready" {count++} END {print count+0}')"

  if [ "$total" -eq 0 ]; then
    fail "No Kubernetes nodes found"
    return
  fi

  if [ "$ready" -eq "$EXPECTED_NODE_COUNT" ]; then
    pass "Nodes Ready: $ready/$EXPECTED_NODE_COUNT"
  elif [ "$ready" -eq "$total" ]; then
    warn "All discovered nodes are Ready, but expected $EXPECTED_NODE_COUNT and found $total"
  else
    fail "Nodes Ready: $ready/$total. Run: k get nodes -o wide"
  fi
}

check_namespaces() {
  local unhealthy

  unhealthy="$(k get namespaces --no-headers 2>/dev/null | awk '$2 != "Active" {print}')"

  if [ -z "$unhealthy" ]; then
    pass "All namespaces are Active"
  else
    fail "Namespaces not Active:"
    echo "$unhealthy" | sed 's/^/       /'
  fi
}

check_node_pressure() {
  local pressure

  pressure="$(k get nodes -o jsonpath='{range .items[*]}{.metadata.name}{" "}{range .status.conditions[*]}{.type}{"="}{.status}{" "}{end}{"\n"}{end}' 2>/dev/null \
    | grep -E 'MemoryPressure=True|DiskPressure=True|PIDPressure=True|NetworkUnavailable=True' || true)"

  if [ -z "$pressure" ]; then
    pass "No node pressure detected"
  else
    fail "Node pressure detected:"
    echo "$pressure" | sed 's/^/       /'
  fi
}

check_unhealthy_pods() {
  local bad_pods

  bad_pods="$(k get pods -A --no-headers 2>/dev/null \
    | awk '$4 ~ /CrashLoopBackOff|Error|ImagePullBackOff|ErrImagePull|CreateContainerConfigError|CreateContainerError|Pending|Unknown|Failed/ {print}')"

  if [ -z "$bad_pods" ]; then
    pass "No unhealthy pods detected"
  else
    fail "Unhealthy pods found:"
    echo "$bad_pods" | sed 's/^/       /'
  fi
}

check_pod_restarts() {
  local restarted

  restarted="$(k get pods -A --no-headers 2>/dev/null \
    | awk '$5+0 > 3 {print}')"

  if [ -z "$restarted" ]; then
    pass "No pods with high restart count"
  else
    warn "Pods with more than 3 restarts:"
    echo "$restarted" | sed 's/^/       /'
  fi
}

check_pvcs() {
  local bad_pvcs

  bad_pvcs="$(k get pvc -A --no-headers 2>/dev/null \
    | awk '$3 != "Bound" {print}')"

  if [ -z "$bad_pvcs" ]; then
    pass "All PVCs are Bound"
  else
    fail "PVCs not Bound:"
    echo "$bad_pvcs" | sed 's/^/       /'
  fi
}

check_deployments() {
  local bad_deployments

  bad_deployments="$(k get deployments -A --no-headers 2>/dev/null \
    | awk '
      {
        split($3, ready, "/")
        if (ready[1] != ready[2]) {
          print
        }
      }
    ')"

  if [ -z "$bad_deployments" ]; then
    pass "All deployments are Ready"
  else
    fail "Deployments not fully Ready:"
    echo "$bad_deployments" | sed 's/^/       /'
  fi
}

check_statefulsets() {
  local bad_statefulsets

  bad_statefulsets="$(k get statefulsets -A --no-headers 2>/dev/null | awk '
    {
      split($3, ready, "/")
      if (ready[1] != ready[2]) {
        print
      }
    }
  ')"

  if [ -z "$bad_statefulsets" ]; then
    pass "All StatefulSets are Ready"
  else
    fail "StatefulSets not fully Ready:"
    echo "$bad_statefulsets" | sed 's/^/       /'
  fi
}

check_daemonsets() {
  local bad_daemonsets

  bad_daemonsets="$(k get daemonsets -A --no-headers 2>/dev/null | awk '$3 != $5 {print}')"

  if [ -z "$bad_daemonsets" ]; then
    pass "All DaemonSets are Ready"
  else
    fail "DaemonSets not fully Ready:"
    echo "$bad_daemonsets" | sed 's/^/       /'
  fi
}

check_service_endpoints() {
  local services_without_endpoints
  local exclusions

  exclusions="$(printf '%s\n' "${SERVICE_ENDPOINT_EXCLUSIONS[@]}")"

  services_without_endpoints="$(k get endpoints -A --no-headers 2>/dev/null \
    | awk '$3 == "<none>" {print $1 "/" $2 "\t" $0}' \
    | grep -F -v -f <(printf '%s\n' "$exclusions") || true)"

  if [ -z "$services_without_endpoints" ]; then
    pass "All Services have ready endpoints"
  else
    fail "Services without ready endpoints:"
    echo "$services_without_endpoints" | sed 's/^/       /'
  fi
}

check_certificates() {
  local not_ready

  if ! k get certificates -A >/dev/null 2>&1; then
    warn "Certificate check unavailable; cert-manager may not be installed"
    return
  fi

  not_ready="$(k get certificates -A --no-headers 2>/dev/null | awk '$3 != "True" {print}')"

  if [ -z "$not_ready" ]; then
    pass "All TLS certificates are Ready"
  else
    fail "TLS certificates not Ready:"
    echo "$not_ready" | sed 's/^/       /'
  fi
}

check_ingresses() {
  local without_address

  without_address="$(k get ingress -A --no-headers 2>/dev/null | awk '$5 == "" || $5 == "<none>" {print}')"

  if [ -z "$without_address" ]; then
    pass "All Ingresses have an address"
  else
    fail "Ingresses without an address:"
    echo "$without_address" | sed 's/^/       /'
  fi
}
