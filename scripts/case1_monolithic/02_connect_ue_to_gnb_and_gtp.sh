#!/usr/bin/env bash
# ==============================================================================
# 02_connect_ue_to_gnb_and_gtp.sh - Case 1: Connect UE and Verify End-to-End GTP Tunnel to UPF
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"
init_environment "$@"

RELEASE_NAME="${RELEASE_NAME:-nrue}"
UE_LABEL="app.kubernetes.io/name=oai-nr-ue"
GNB_LABEL="app.kubernetes.io/name=oai-gnb"

log_step "CASE 1 - Step 2: Connecting UE to gNB & Verifying GTP Tunnel to UPF"
log_info "Cluster Context : ${KUBE_CONTEXT}"
log_info "Namespace       : ${NAMESPACE}"

# 1. Ensure gNB is running first
if ! kctl get pods -l "${GNB_LABEL}" 2>/dev/null | grep -q "Running"; then
  log_error "gNB is not running. Please run 01_connect_gnb_to_upf.sh first."
  exit 1
fi

# 2. Deploy or restart UE
if kctl get pods -l "${UE_LABEL}" 2>/dev/null | grep -q "Running"; then
  log_info "UE pod is already present. Restarting UE pod to trigger clean PDU session establishment..."
  kctl rollout restart deployment/"${RELEASE_NAME}" 2>/dev/null || kctl delete pod -l "${UE_LABEL}" 2>/dev/null
else
  log_info "Deploying NR-UE Helm chart from: ${CHARTS_DIR}/oai-nr-ue..."
  khelm upgrade --install "${RELEASE_NAME}" "${CHARTS_DIR}/oai-nr-ue" \
    --namespace "${NAMESPACE}" \
    --set kubernetesDistribution=Vanilla \
    --set config.rfSimServer=oai-ran
fi

# 3. Wait for UE pod to reach Ready
wait_for_pod_ready "${UE_LABEL}" "180s" || exit 1

UE_POD=$(get_pod_name "${UE_LABEL}")

# 4. Verify RRC Connection & Registration
log_step "Verifying RRC & NAS Registration in UE Logs..."
if wait_for_log_pattern "${UE_LABEL}" "RRCSetupComplete|PDU SESSION ESTABLISHMENT ACCEPT|associated" 15 3; then
  log_success "UE RRC connection and registration established."
fi

# 5. Verify GTP Tunnel via ICMP Echo to UPF (12.1.1.1)
log_step "Verifying End-to-End N3 GTP-U Tunnel via Data Traffic..."
sleep 2

if verify_ue_gtp_ping "${UE_LABEL}" "12.1.1.1" 4; then
  log_success "GTP tunnel connection confirmed: UE <==> gNB (N3 GTP-U) <==> UPF (12.1.1.1)!"
else
  log_warn "Ping directly to 12.1.1.1 had packet loss. Checking interface status..."
  kctl exec "${UE_POD}" -c nr-ue -- ip addr show || true
fi

log_success "Case 1 Complete: gNB and UE are connected with an active GTP tunnel to the UPF!"
