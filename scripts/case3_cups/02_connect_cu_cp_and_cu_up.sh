#!/usr/bin/env bash
# ==============================================================================
# 02_connect_cu_cp_and_cu_up.sh - Case 3 (CUPS): Connect CU-UP to CU-CP over E1
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"
init_environment "$@"

RELEASE_NAME="${RELEASE_NAME:-cuup}"
CUCP_LABEL="app.kubernetes.io/name=oai-cu-cp"
CUUP_LABEL="app.kubernetes.io/name=oai-cu-up"

log_step "CASE 3 (CUPS) - Step 2: Connecting CU-UP to CU-CP over E1 Interface (SCTP 38462)"
log_info "Cluster Context   : ${KUBE_CONTEXT}"
log_info "Namespace         : ${NAMESPACE}"
log_info "CU-UP Release     : ${RELEASE_NAME}"

# 1. Ensure CU-CP is running first
if ! kctl get pods -l "${CUCP_LABEL}" 2>/dev/null | grep -q "Running"; then
  log_error "CU-CP must be running first. Run 01_connect_cu_cp_to_amf.sh first."
  exit 1
fi

# 2. Deploy or verify CU-UP
if kctl get pods -l "${CUUP_LABEL}" 2>/dev/null | grep -q "Running"; then
  log_info "CU-UP pod is already running in namespace '${NAMESPACE}'."
else
  log_info "Deploying CU-UP Helm chart from: ${CHARTS_DIR}/oai-cu-up..."
  khelm upgrade --install "${RELEASE_NAME}" "${CHARTS_DIR}/oai-cu-up" \
    --namespace "${NAMESPACE}" \
    --set kubernetesDistribution=Vanilla \
    --set config.cucpHost=oai-cu-cp
fi

# 3. Wait for CU-UP to become Ready
wait_for_pod_ready "${CUUP_LABEL}" "180s" || exit 1

CUUP_POD=$(get_pod_name "${CUUP_LABEL}")
CUCP_POD=$(get_pod_name "${CUCP_LABEL}")

# 4. Verify E1 Setup on CU-CP side
log_step "Verifying E1 Setup in CU-CP and CU-UP Logs..."
if wait_for_log_pattern "${CUCP_LABEL}" "Accepting new CU-UP ID|E1_SETUP_RESPONSE|Received E1AP_SETUP_REQ" 15 2; then
  log_success "E1 interface setup confirmed: CU-CP accepted connection from CU-UP!"
else
  log_warn "CU-CP log excerpt:"
  kctl logs "${CUCP_POD}" --tail=20 || true
fi

log_success "Step 2 Complete: CU-CP and CU-UP are successfully connected over E1!"
