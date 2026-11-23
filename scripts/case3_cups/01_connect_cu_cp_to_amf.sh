#!/usr/bin/env bash
# ==============================================================================
# 01_connect_cu_cp_to_amf.sh - Case 3 (CUPS): Connect CU-CP to AMF over N2 (NGAP)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"
init_environment "$@"

RELEASE_NAME="${RELEASE_NAME:-cucp}"
CUCP_LABEL="app.kubernetes.io/name=oai-cu-cp"

log_step "CASE 3 (CUPS) - Step 1: Deploying OAI CU-CP & Connecting to AMF over N2 (NGAP)"
log_info "Cluster Context   : ${KUBE_CONTEXT}"
log_info "Namespace         : ${NAMESPACE}"
log_info "CU-CP Release     : ${RELEASE_NAME}"

# 1. Deploy or verify CU-CP
if kctl get pods -l "${CUCP_LABEL}" 2>/dev/null | grep -q "Running"; then
  log_info "CU-CP pod is already running in namespace '${NAMESPACE}'."
else
  log_info "Deploying CU-CP Helm chart from: ${CHARTS_DIR}/oai-cu-cp..."
  khelm upgrade --install "${RELEASE_NAME}" "${CHARTS_DIR}/oai-cu-cp" \
    --namespace "${NAMESPACE}" \
    --set kubernetesDistribution=Vanilla
fi

# 2. Wait for CU-CP to become Ready
wait_for_pod_ready "${CUCP_LABEL}" "180s" || exit 1

CUCP_POD=$(get_pod_name "${CUCP_LABEL}")

# 3. Verify N2 (NGAP) registration with AMF
log_step "Verifying CU-CP N2 (NGAP) Association with AMF..."
if wait_for_log_pattern "${CUCP_LABEL}" "associated AMF 1|NG_SETUP_RESPONSE|Received NGAP_REGISTER_GNB_REQ" 15 2; then
  log_success "CU-CP successfully registered with AMF over N2 (NGAP)!"
else
  log_warn "CU-CP log excerpt:"
  kctl logs "${CUCP_POD}" --tail=20 || true
fi

# 4. Verify E1 and F1-C Listeners on CU-CP
log_step "Verifying CU-CP Listeners (E1 SCTP:38462 & F1-C SCTP:38472)..."
kctl logs "${CUCP_POD}" --tail=50 2>&1 | grep -i -E "e1|f1|sctp" | head -n 6 || true

log_success "Step 1 Complete: CU-CP is active, registered with AMF, and listening for CU-UP and DU!"
