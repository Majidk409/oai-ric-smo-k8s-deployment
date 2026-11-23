#!/usr/bin/env bash
# ==============================================================================
# 05_connect_ue_and_gtp_tunnel.sh - Case 3 (CUPS): Connect UE & Verify End-to-End CUPS GTP Tunnel
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"
init_environment "$@"

RELEASE_NAME="${RELEASE_NAME:-nrue}"
UE_LABEL="app.kubernetes.io/name=oai-nr-ue"
DU_LABEL="app.kubernetes.io/name=oai-du"
CUCP_LABEL="app.kubernetes.io/name=oai-cu-cp"
CUUP_LABEL="app.kubernetes.io/name=oai-cu-up"

log_step "CASE 3 (CUPS) - Step 5: Connecting UE & Verifying Full CUPS GTP Tunnel to UPF"
log_info "Cluster Context   : ${KUBE_CONTEXT}"
log_info "Namespace         : ${NAMESPACE}"

# 1. Ensure DU is running first
if ! kctl get pods -l "${DU_LABEL}" 2>/dev/null | grep -q "Running"; then
  log_error "DU is not running. Please run previous setup scripts (01-04) first."
  exit 1
fi

DU_POD=$(get_pod_name "${DU_LABEL}")
DU_IP=$(kctl get pod "${DU_POD}" -o jsonpath='{.status.podIP}')
log_info "Target DU RFSimulator IP: ${DU_IP}"

# 2. Deploy or restart UE
if kctl get pods -l "${UE_LABEL}" 2>/dev/null | grep -q "Running"; then
  log_info "UE pod is already present. Restarting UE to re-trigger PDU session and E1 Bearer context..."
  kctl rollout restart deployment/"${RELEASE_NAME}" 2>/dev/null || kctl delete pod -l "${UE_LABEL}" 2>/dev/null
else
  log_info "Deploying NR-UE Helm chart from: ${CHARTS_DIR}/oai-nr-ue (rfSimServer=${DU_IP})..."
  khelm upgrade --install "${RELEASE_NAME}" "${CHARTS_DIR}/oai-nr-ue" \
    --namespace "${NAMESPACE}" \
    --set kubernetesDistribution=Vanilla \
    --set config.rfSimServer="${DU_IP}"
fi

# 3. Wait for UE pod Ready
wait_for_pod_ready "${UE_LABEL}" "180s" || exit 1

UE_POD=$(get_pod_name "${UE_LABEL}")

# 4. Verify RRC & E1 Bearer Context Setup
log_step "Verifying RRC Connection and E1 Bearer Setup..."
if wait_for_log_pattern "${UE_LABEL}" "RRCSetupComplete|PDU SESSION ESTABLISHMENT ACCEPT|associated" 15 3; then
  log_success "UE RRC connection and registration established!"
fi

# 5. Verify CUPS GTP Tunnel to UPF via ICMP Ping
log_step "Verifying End-to-End CUPS User Plane (UE <==> DU <==F1-U==> CU-UP <==N3 GTP==> UPF)..."
sleep 2

if verify_ue_gtp_ping "${UE_LABEL}" "12.1.1.1" 4; then
  log_success "Case 3 Complete: Full CUPS architecture verified with active GTP tunnels to UPF!"
else
  log_warn "Ping directly to 12.1.1.1 had packet loss. Checking UE interface status..."
  kctl exec "${UE_POD}" -c nr-ue -- ip addr show || true
fi
