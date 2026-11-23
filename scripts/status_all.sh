#!/usr/bin/env bash
# ==============================================================================
# status_all.sh - Overall Status Check for 5G Core, RAN, and GTP Tunnels
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
init_environment "$@"

echo -e "${BOLD}${CYAN}"
echo "========================================================================"
echo "          OAI 5G SYSTEM STATUS (CORE, RAN & GTP DATA PLANE)             "
echo "========================================================================"
echo -e "${NC}"
echo -e "Context   : ${BOLD}${KUBE_CONTEXT}${NC}"
echo -e "Namespace : ${BOLD}${NAMESPACE}${NC}"
echo ""

log_step "1. 5G Core Network Functions"
kctl get pods -l "app.kubernetes.io/name in (oai-amf, oai-smf, oai-upf, oai-nrf, oai-udm, oai-udr, oai-ausf, basic-mysql, case1-mysql)" -o wide 2>/dev/null || true

log_step "2. 5G RAN Components"
kctl get pods -l "app.kubernetes.io/name in (oai-gnb, oai-cu, oai-du, oai-cu-cp, oai-cu-up, oai-nr-ue)" -o wide 2>/dev/null || true

log_step "3. UE Tunnel & GTP Data Plane Inspection"
UE_POD=$(get_pod_name "app.kubernetes.io/name=oai-nr-ue")
if [[ -n "${UE_POD}" ]]; then
  echo -e "UE Pod: ${BOLD}${UE_POD}${NC}"
  UE_IP=$(kctl exec "${UE_POD}" -c nr-ue -- ip -4 addr show dev oaitun_ue1 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)
  if [[ -n "${UE_IP}" ]]; then
    log_success "UE interface 'oaitun_ue1' IP: ${UE_IP} (GTP-U session active)"
    log_info "Pinging UPF gateway (12.1.1.1)..."
    kctl exec "${UE_POD}" -c nr-ue -- ping -c 2 -W 2 -I oaitun_ue1 12.1.1.1 2>/dev/null && \
      log_success "Ping to UPF via GTP tunnel: SUCCESS (Round-trip OK)" || \
      log_warn "Ping to UPF had packet loss."
  else
    log_warn "UE pod is present but 'oaitun_ue1' interface does not have an IP yet."
  fi
else
  log_info "No active UE pod found in namespace '${NAMESPACE}'."
fi

log_step "4. Helm Releases Summary"
khelm list 2>/dev/null || true
echo ""
