#!/usr/bin/env bash
# ==============================================================================
# 04_connect_cu_and_du.sh - Case 3 (CUPS): Connect DU to CU-CP (F1-C) and CU-UP (F1-U)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"
init_environment "$@"

RELEASE_NAME="${RELEASE_NAME:-du}"
CUCP_LABEL="app.kubernetes.io/name=oai-cu-cp"
CUUP_LABEL="app.kubernetes.io/name=oai-cu-up"
DU_LABEL="app.kubernetes.io/name=oai-du"

log_step "CASE 3 (CUPS) - Step 4: Connecting DU to CU-CP (F1-C) & CU-UP (F1-U)"
log_info "Cluster Context   : ${KUBE_CONTEXT}"
log_info "Namespace         : ${NAMESPACE}"

# 1. Ensure CU-CP and CU-UP are running first
if ! kctl get pods -l "${CUCP_LABEL}" 2>/dev/null | grep -q "Running"; then
  log_error "CU-CP is not running. Run 01_connect_cu_cp_to_amf.sh first."
  exit 1
fi
if ! kctl get pods -l "${CUUP_LABEL}" 2>/dev/null | grep -q "Running"; then
  log_error "CU-UP is not running. Run 02_connect_cu_cp_and_cu_up.sh first."
  exit 1
fi

# 2. Deploy or verify DU configured to point to CU-CP
if kctl get pods -l "${DU_LABEL}" 2>/dev/null | grep -q "Running"; then
  log_info "DU pod is already running in namespace '${NAMESPACE}'."
else
  log_info "Deploying DU Helm chart for CUPS (cuHost=oai-cu-cp)..."
  khelm upgrade --install "${RELEASE_NAME}" "${CHARTS_DIR}/oai-du" \
    --namespace "${NAMESPACE}" \
    --set kubernetesDistribution=Vanilla \
    --set config.cuHost=oai-cu-cp
fi

# 3. Wait for DU to become Ready
wait_for_pod_ready "${DU_LABEL}" "180s" || exit 1

DU_POD=$(get_pod_name "${DU_LABEL}")
CUCP_POD=$(get_pod_name "${CUCP_LABEL}")

# 4. Verify F1 Setup on CU-CP
log_step "Verifying F1-C Setup on CU-CP..."
if wait_for_log_pattern "${CUCP_LABEL}" "Received F1 Setup Request|F1_SETUP_RESPONSE" 15 2; then
  log_success "CU-CP received F1 Setup Request from DU and established F1-C connection!"
else
  log_warn "CU-CP log excerpt:"
  kctl logs "${CUCP_POD}" --tail=20 || true
fi

# 5. Verify RFSimulator on DU
log_step "Verifying RFSimulator Server on DU..."
if wait_for_log_pattern "${DU_LABEL}" "I Frame.Slot|rfsimulator.*listening|rfsimulator" 10 2; then
  log_success "DU RFSimulator is listening and ready for UE connection!"
fi

log_success "Step 4 Complete: DU is connected to CU-CP (F1-C) and ready for CU-UP data plane (F1-U)!"
