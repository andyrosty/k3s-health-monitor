#!/usr/bin/env bash

f() {
  "${FLUX_CMD[@]}" "$@"
}

check_flux_kustomizations() {
  local not_ready

  if ! f get kustomizations >/dev/null 2>&1; then
    fail "Flux kustomizations check failed. Flux may not be installed or kubeconfig is unavailable."
    return
  fi

  not_ready="$(f get kustomizations --no-header 2>/dev/null | awk '$4 != "True" {print}')"

  if [ -z "$not_ready" ]; then
    pass "Flux kustomizations Ready"
  else
    fail "Flux kustomizations not Ready:"
    echo "$not_ready" | sed 's/^/       /'
  fi
}

check_flux_helmreleases() {
  local not_ready

  if ! f get helmreleases -A >/dev/null 2>&1; then
    warn "Flux HelmRelease check failed or no HelmReleases found"
    return
  fi

  not_ready="$(f get helmreleases -A --no-header 2>/dev/null | awk '$5 != "True" {print}')"

  if [ -z "$not_ready" ]; then
    pass "Flux HelmReleases Ready"
  else
    fail "Flux HelmReleases not Ready:"
    echo "$not_ready" | sed 's/^/       /'
  fi
}

check_flux_sources() {
  local not_ready

  if ! f get sources git -A >/dev/null 2>&1; then
    warn "Flux Git source check failed"
    return
  fi

  not_ready="$(f get sources git -A --no-header 2>/dev/null | awk '$5 != "True" {print}')"

  if [ -z "$not_ready" ]; then
    pass "Flux Git sources Ready"
  else
    fail "Flux Git sources not Ready:"
    echo "$not_ready" | sed 's/^/       /'
  fi
}

check_flux_helmrepositories() {
  local not_ready

  if ! f get sources helm -A >/dev/null 2>&1; then
    warn "Flux HelmRepository check failed or no HelmRepositories found"
    return
  fi

  not_ready="$(f get sources helm -A --no-header 2>/dev/null | awk '$5 != "True" {print}')"

  if [ -z "$not_ready" ]; then
    pass "Flux HelmRepositories Ready"
  else
    fail "Flux HelmRepositories not Ready:"
    echo "$not_ready" | sed 's/^/       /'
  fi
}
