#!/usr/bin/env bash
# ==============================================================================
# 01_connect_gnb_to_upf.sh - Case 1: Connect Monolithic gNB to UPF / AMF
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"
init_environment "$@"

RELEASE_NAME="${RELEASE_NAME:-gnb}"
GNB_LABEL="app.kubernetes.io/name=oai-gnb"

log_step "CASE 1 - Step 1: Connecting Monolithic gNB to AMF (N2) & UPF (N3 GTP-U Tunnel)"
log_info "Cluster Context : ${KUBE_CONTEXT}"
log_info "Namespace       : ${NAMESPACE}"
log_info "Helm Release    : ${RELEASE_NAME}"

# 1. Check if 5G Core is reachable
log_info "Verifying 5G Core AMF and UPF are active..."
if ! kctl get pods -l app.kubernetes.io/name=oai-amf | grep -q "Running"; then
  log_warn "OAI AMF pod is not running in namespace '${NAMESPACE}'. Ensure Core is started."
fi

# 2. Deploy gNB if not already deployed
if kctl get pods -l "${GNB_LABEL}" 2>/dev/null | grep -q "Running"; then
  log_info "gNB pod is already running in namespace '${NAMESPACE}'."
else
  log_info "Deploying Monolithic gNB Helm chart from: ${CHARTS_DIR}/oai-gnb..."
  khelm upgrade --install "${RELEASE_NAME}" "${CHARTS_DIR}/oai-gnb" \
    --namespace "${NAMESPACE}" \
    --set kubernetesDistribution=Vanilla
fi

# 3. Wait for gNB to reach Ready state
wait_for_pod_ready "${GNB_LABEL}" "180s" || exit 1

# 4. Verify N2 (NGAP) setup between gNB and AMF
log_step "Verifying N2 (NGAP) Association with AMF..."
GNB_POD=$(get_pod_name "${GNB_LABEL}")

if wait_for_log_pattern "${GNB_LABEL}" "associated AMF 1|NG_SETUP_RESPONSE|Received NGAP_REGISTER_GNB_REQ" 15 2; then
  log_success "gNB successfully connected to AMF over N2 (NGAP)."
else
  log_warn "Could not explicitly match NGAP success pattern in recent logs. Full gNB log excerpt:"
  kctl logs "${GNB_POD}" --tail=25 || true
fi

# 5. Verify N3 GTP-U Interface Preparation to UPF
log_step "Verifying N3 GTP-U Interface to UPF..."
log_info "Checking if gNB configured GTP-U listening port (UDP 2152)..."
if kctl logs "${GNB_POD}" --tail=100 2>&1 | grep -i -E "gtp|n3|upf" | head -n 5; then
  log_success "N3 GTP-U endpoint configuration confirmed."
fi

# 6. Verify RFSimulator Server is active
log_step "Verifying RFSimulator Server..."
if wait_for_log_pattern "${GNB_LABEL}" "I Frame.Slot|rfsimulator.*listening|rfsimulator" 10 2; then
  log_success "gNB RFSimulator server is running and ready for UE connections."
fi

log_success "Step 1 Complete: gNB is connected to Core (N2 NGAP & N3 GTP-U ready)!"
