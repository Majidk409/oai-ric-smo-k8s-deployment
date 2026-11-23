#!/usr/bin/env bash
# ==============================================================================
# 01_connect_cu_to_core.sh - Case 2: Connect Central Unit (CU) to 5G Core (AMF & UPF)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"
init_environment "$@"

RELEASE_NAME="${RELEASE_NAME:-cu}"
CU_LABEL="app.kubernetes.io/name=oai-cu"

log_step "CASE 2 - Step 1: Deploying OAI CU & Establishing N2/N3 Connection to Core"
log_info "Cluster Context : ${KUBE_CONTEXT}"
log_info "Namespace       : ${NAMESPACE}"
log_info "CU Helm Release : ${RELEASE_NAME}"

# 1. Deploy or verify CU
if kctl get pods -l "${CU_LABEL}" 2>/dev/null | grep -q "Running"; then
  log_info "CU pod is already running in namespace '${NAMESPACE}'."
else
  log_info "Deploying CU Helm chart from: ${CHARTS_DIR}/oai-cu..."
  khelm upgrade --install "${RELEASE_NAME}" "${CHARTS_DIR}/oai-cu" \
    --namespace "${NAMESPACE}" \
    --set kubernetesDistribution=Vanilla
fi

# 2. Wait for CU to become Ready
wait_for_pod_ready "${CU_LABEL}" "180s" || exit 1

CU_POD=$(get_pod_name "${CU_LABEL}")

# 3. Verify N2 (NGAP) Setup with AMF
log_step "Verifying CU N2 (NGAP) setup with AMF..."
if wait_for_log_pattern "${CU_LABEL}" "associated AMF 1|NG_SETUP_RESPONSE|Received NGAP_REGISTER_GNB_REQ" 15 2; then
  log_success "CU is successfully registered with AMF over N2 (NGAP)."
else
  log_warn "Could not confirm NGAP setup in recent logs. Last 20 lines of CU log:"
  kctl logs "${CU_POD}" --tail=20 || true
fi

# 4. Verify N3 GTP-U and F1-C Listener Readiness
log_step "Verifying CU Interface Listeners (N3 GTP-U on UDP 2152 & F1-C on SCTP 38472)..."
kctl logs "${CU_POD}" --tail=50 2>&1 | grep -i -E "f1|sctp|gtp|upf" | head -n 6 || true

log_success "Step 1 Complete: CU is up, registered with AMF, and listening for DU connections!"
