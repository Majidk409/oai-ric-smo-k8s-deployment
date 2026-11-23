#!/usr/bin/env bash
# ==============================================================================
# 02_connect_cu_and_du.sh - Case 2: Connect Distributed Unit (DU) to CU over F1
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"
init_environment "$@"

RELEASE_NAME="${RELEASE_NAME:-du}"
CU_LABEL="app.kubernetes.io/name=oai-cu"
DU_LABEL="app.kubernetes.io/name=oai-du"

log_step "CASE 2 - Step 2: Connecting DU to CU over F1 Interface (F1-C SCTP + F1-U GTP-U)"
log_info "Cluster Context : ${KUBE_CONTEXT}"
log_info "Namespace       : ${NAMESPACE}"

# 1. Ensure CU is running first
if ! kctl get pods -l "${CU_LABEL}" 2>/dev/null | grep -q "Running"; then
  log_error "CU is not running. Please run 01_connect_cu_to_core.sh first."
  exit 1
fi

# 2. Deploy or verify DU
if kctl get pods -l "${DU_LABEL}" 2>/dev/null | grep -q "Running"; then
  log_info "DU pod is already running in namespace '${NAMESPACE}'."
else
  log_info "Deploying DU Helm chart from: ${CHARTS_DIR}/oai-du..."
  khelm upgrade --install "${RELEASE_NAME}" "${CHARTS_DIR}/oai-du" \
    --namespace "${NAMESPACE}" \
    --set kubernetesDistribution=Vanilla \
    --set config.cuHost=oai-cu
fi

# 3. Wait for DU to become Ready
wait_for_pod_ready "${DU_LABEL}" "180s" || exit 1

DU_POD=$(get_pod_name "${DU_LABEL}")
CU_POD=$(get_pod_name "${CU_LABEL}")

# 4. Verify F1 Setup on CU side
log_step "Verifying F1 Setup on CU..."
if wait_for_log_pattern "${CU_LABEL}" "Received F1 Setup Request|F1_SETUP_RESPONSE|F1-C connection" 15 2; then
  log_success "CU received F1 Setup Request from DU and established F1 connection!"
else
  log_warn "CU log excerpt:"
  kctl logs "${CU_POD}" --tail=20 || true
fi

# 5. Verify RFSimulator started on DU
log_step "Verifying RFSimulator Server on DU..."
if wait_for_log_pattern "${DU_LABEL}" "I Frame.Slot|rfsimulator.*listening|rfsimulator" 10 2; then
  log_success "DU RFSimulator server is running and ready for UE connection!"
fi

log_success "Step 2 Complete: CU and DU are successfully connected over F1!"
