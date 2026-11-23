#!/usr/bin/env bash
# ==============================================================================
# common.sh - Shared utility library for OAI 5G RAN and Core test scripts
# ==============================================================================

set -o pipefail

# --- Color Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- Logging Helpers ---
log_info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()    { echo -e "\n${BOLD}${BLUE}==> $*${NC}"; }

# --- Cluster Context and Namespace Initialization ---
init_environment() {
  # Auto-detect default context if not specified
  if [[ -z "${KUBE_CONTEXT}" ]]; then
    if kubectl config get-contexts -o name 2>/dev/null | grep -q "^kind-oai-tutorial$"; then
      KUBE_CONTEXT="kind-oai-tutorial"
    else
      KUBE_CONTEXT="$(kubectl config current-context 2>/dev/null || echo 'kubernetes-admin@kubernetes')"
    fi
  fi

  NAMESPACE="${NAMESPACE:-oai-tutorial}"
  CHARTS_DIR="${CHARTS_DIR:-/home/snsrl/deplo/charts/oai-5g-ran}"

  # Parse CLI arguments if passed: -c <context> -n <namespace>
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c|--context)
        KUBE_CONTEXT="$2"
        shift 2
        ;;
      -n|--namespace)
        NAMESPACE="$2"
        shift 2
        ;;
      -h|--help)
        echo "Usage: $0 [-c <kube_context>] [-n <namespace>]"
        exit 0
        ;;
      *)
        shift
        ;;
    esac
  done

  # Verify cluster connectivity
  if ! kubectl --context "${KUBE_CONTEXT}" get namespace "${NAMESPACE}" >/dev/null 2>&1; then
    log_warn "Namespace '${NAMESPACE}' not found in context '${KUBE_CONTEXT}' or cluster unreachable."
  fi
}

# Run kubectl in target context and namespace
kctl() {
  kubectl --context "${KUBE_CONTEXT}" -n "${NAMESPACE}" "$@"
}

# Run helm in target context and namespace
khelm() {
  helm --kube-context "${KUBE_CONTEXT}" -n "${NAMESPACE}" "$@"
}

# Wait for a pod matching a label selector to be Ready
wait_for_pod_ready() {
  local label="$1"
  local timeout="${2:-180s}"
  log_info "Waiting up to ${timeout} for pod with label '${label}' to become Ready..."

  if kctl wait --for=condition=ready pod -l "${label}" --timeout="${timeout}" >/dev/null 2>&1; then
    local pod_name
    pod_name=$(kctl get pods -l "${label}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    log_success "Pod '${pod_name}' is Ready."
    return 0
  else
    log_error "Timeout reached waiting for pod with label '${label}'."
    kctl get pods -l "${label}" 2>/dev/null
    return 1
  fi
}

# Wait for a specific string pattern in pod logs
wait_for_log_pattern() {
  local label="$1"
  local pattern="$2"
  local max_retries="${3:-15}"
  local sleep_sec="${4:-2}"
  local pod_name

  pod_name=$(kctl get pods -l "${label}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  if [[ -z "${pod_name}" ]]; then
    log_error "No pod found matching label '${label}'."
    return 1
  fi

  log_info "Checking logs of '${pod_name}' for pattern: '${pattern}'..."
  local count=1
  while [[ ${count} -le ${max_retries} ]]; do
    if kctl logs "${pod_name}" --tail=100 2>&1 | grep -E -q "${pattern}"; then
      log_success "Found pattern in '${pod_name}' logs: '${pattern}'"
      return 0
    fi
    sleep "${sleep_sec}"
    ((count++))
  done

  log_error "Pattern '${pattern}' not found in logs after ${max_retries} attempts."
  return 1
}

# Get first pod name for a given label
get_pod_name() {
  local label="$1"
  kctl get pods -l "${label}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null
}

# Ping target from UE pod through GTP-U tunnel interface (oaitun_ue1)
verify_ue_gtp_ping() {
  local ue_label="${1:-app.kubernetes.io/name=oai-nr-ue}"
  local target_ip="${2:-12.1.1.1}"
  local count="${3:-4}"
  local pod_name

  pod_name=$(get_pod_name "${ue_label}")
  if [[ -z "${pod_name}" ]]; then
    log_error "UE pod not found."
    return 1
  fi

  log_info "Verifying UE interface 'oaitun_ue1' on pod '${pod_name}'..."
  local ue_ip
  ue_ip=$(kctl exec "${pod_name}" -c nr-ue -- ip -4 addr show dev oaitun_ue1 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)

  if [[ -n "${ue_ip}" ]]; then
    log_success "UE has acquired IP address: ${ue_ip} on interface oaitun_ue1 (GTP tunnel active)"
  else
    log_warn "Interface 'oaitun_ue1' does not have an IPv4 address yet. Checking ifconfig..."
    kctl exec "${pod_name}" -c nr-ue -- ifconfig 2>/dev/null || true
  fi

  log_info "Sending ${count} ICMP echo requests through GTP tunnel to UPF (${target_ip})..."
  if kctl exec "${pod_name}" -c nr-ue -- ping -I oaitun_ue1 -c "${count}" -W 2 "${target_ip}"; then
    log_success "GTP tunnel verified! Traffic successfully flowed UE -> RAN -> UPF."
    return 0
  else
    log_error "Ping through GTP tunnel to ${target_ip} failed or timed out."
    return 1
  fi
}
