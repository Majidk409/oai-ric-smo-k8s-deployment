#!/usr/bin/env bash
# ==============================================================================
# run_case2.sh - Case 2: F1 Split (CU + DU) Full Workflow Runner
# ==============================================================================

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"
init_environment "$@"

echo -e "${BOLD}${GREEN}"
echo "========================================================================"
echo "    STARTING OAI CASE 2: F1 SPLIT RAN (CU + DU + GTP TUNNEL TO UPF)     "
echo "========================================================================"
echo -e "${NC}"

# Step 1: Connect CU to Core (AMF & UPF)
"${SCRIPT_DIR}/01_connect_cu_to_core.sh" "$@"

# Step 2: Connect DU to CU over F1
"${SCRIPT_DIR}/02_connect_cu_and_du.sh" "$@"

# Step 3: Verify DU to UPF data plane path
"${SCRIPT_DIR}/03_connect_du_to_upf.sh" "$@"

# Step 4: Connect UE to DU/CU and test end-to-end GTP tunnel
"${SCRIPT_DIR}/04_connect_ue_to_cu_and_gtp.sh" "$@"

echo -e "\n${BOLD}${GREEN}========================================================================${NC}"
echo -e "${BOLD}${GREEN}  CASE 2 WORKFLOW COMPLETED SUCCESSFULLY!                              ${NC}"
echo -e "${BOLD}${GREEN}========================================================================${NC}"
