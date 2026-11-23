#!/usr/bin/env bash
# ==============================================================================
# run_case1.sh - Case 1: Monolithic gNB Full Workflow Runner
# ==============================================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"
init_environment "$@"

echo -e "${BOLD}${GREEN}"
echo "========================================================================"
echo "    STARTING OAI CASE 1: MONOLITHIC gNB (N2 NGAP + N3 GTP-U TUNNEL)     "
echo "========================================================================"
echo -e "${NC}"

# Step 1: Connect gNB to UPF & AMF
"${SCRIPT_DIR}/01_connect_gnb_to_upf.sh" "$@"

# Step 2: Connect UE to gNB & verify GTP tunnel
"${SCRIPT_DIR}/02_connect_ue_to_gnb_and_gtp.sh" "$@"

echo -e "\n${BOLD}${GREEN}========================================================================${NC}"
echo -e "${BOLD}${GREEN}  CASE 1 WORKFLOW COMPLETED SUCCESSFULLY!                              ${NC}"
echo -e "${BOLD}${GREEN}========================================================================${NC}"
