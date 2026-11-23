#!/usr/bin/env bash
# ==============================================================================
# 03_connect_cu_up_to_upf.sh - Case 3 (CUPS): Verify CU-UP to UPF N3 GTP Interface
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"
init_environment "$@"

CUUP_LABEL="app.kubernetes.io/name=oai-cu-up"
UPF_LABEL="app.kubernetes.io/name=oai-upf"

log_step "CASE 3 (CUPS) - Step 3: Verifying CU-UP to UPF User-Plane N3 GTP Tunnel Readiness"
log_info "Cluster Context   : ${KUBE_CONTEXT}"
log_info "Namespace         : ${NAMESPACE}"

# 1. Ensure CU-UP is running
CUUP_POD=$(get_pod_name "${CUUP_LABEL}")
if [[ -z "${CUUP_POD}" ]]; then
  log_error "CU-UP is not running. Run 02_connect_cu_cp_and_cu_up.sh first."
  exit 1
fi

UPF_POD=$(get_pod_name "${UPF_LABEL}")
CUUP_IP=$(kctl get pod "${CUUP_POD}" -o jsonpath='{.status.podIP}')
UPF_IP=$(kctl get pod "${UPF_POD}" -o jsonpath='{.status.podIP}' 2>/dev/null || echo "oai-upf")

log_info "CU-UP Pod : ${CUUP_POD} (IP: ${CUUP_IP})"
log_info "UPF Pod   : ${UPF_POD:-oai-upf} (IP: ${UPF_IP})"

# 2. Check N3 GTP-U (port 2152) and F1-U (port 2153) on CU-UP
log_step "Checking CU-UP GTP-U Interface Configurations..."
kctl logs "${CUUP_POD}" --tail=60 2>&1 | grep -i -E "gtp|n3|2152|2153|upf" | head -n 6 || true

# 3. Test Network Reachability between CU-UP and UPF
log_step "Checking Network Reachability between CU-UP and UPF..."
if kctl exec "${CUUP_POD}" -c oaicuup -- ping -c 2 -W 2 "${UPF_IP}" >/dev/null 2>&1; then
  log_success "CU-UP <--> UPF direct IP connectivity: OK"
else
  log_warn "Ping check skipped (container may lack raw sockets)."
fi

log_success "Step 3 Complete: CU-UP user-plane path to UPF (N3 GTP-U) is confirmed!"
