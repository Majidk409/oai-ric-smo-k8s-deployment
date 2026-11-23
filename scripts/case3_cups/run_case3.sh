#!/usr/bin/env bash
# ==============================================================================
# run_case3.sh - Case 3: CUPS (CU-CP + CU-UP + DU + UE) Full Workflow Runner
# ==============================================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"
init_environment "$@"

echo -e "${BOLD}${GREEN}"
echo "========================================================================"
echo "    STARTING OAI CASE 3: CUPS (CU-CP + CU-UP + DU + GTP TUNNEL)         "
echo "========================================================================"
echo -e "${NC}"

# Step 1: Connect CU-CP to AMF (N2 NGAP)
"${SCRIPT_DIR}/01_connect_cu_cp_to_amf.sh" "$@"

# Step 2: Connect CU-UP to CU-CP over E1
"${SCRIPT_DIR}/02_connect_cu_cp_and_cu_up.sh" "$@"

# Step 3: Verify CU-UP to UPF N3 GTP interface
"${SCRIPT_DIR}/03_connect_cu_up_to_upf.sh" "$@"

# Step 4: Connect DU to CU-CP and CU-UP
"${SCRIPT_DIR}/04_connect_cu_and_du.sh" "$@"

# Step 5: Connect UE and verify end-to-end CUPS GTP tunnel
"${SCRIPT_DIR}/05_connect_ue_and_gtp_tunnel.sh" "$@"

echo -e "\n${BOLD}${GREEN}========================================================================${NC}"
echo -e "${BOLD}${GREEN}  CASE 3 (CUPS) WORKFLOW COMPLETED SUCCESSFULLY!                       ${NC}"
echo -e "${BOLD}${GREEN}========================================================================${NC}"
