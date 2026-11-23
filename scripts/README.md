# OAI 5G RAN & Core Automation Scripts

Automated scripts for deploying, connecting, and verifying OpenAirInterface (OAI) 5G RAN components and user-plane GTP-U tunnels across all 3GPP split architectures.

---

## Directory Structure

```text
/home/snsrl/scripts/
├── common.sh                 # Shared library: auto-detects cluster context, namespace, log helpers
├── status_all.sh             # Master diagnostic checking Core, RAN, UE GTP tunnel & Helm releases
│
├── case1_monolithic/         # CASE 1: Monolithic gNodeB (SA RFsim)
│   ├── 01_connect_gnb_to_upf.sh          # Connects gNB to AMF (N2 NGAP) & UPF (N3 GTP-U)
│   ├── 02_connect_ue_to_gnb_and_gtp.sh   # Connects UE and verifies end-to-end GTP tunnel
│   ├── run_case1.sh                      # Master runner executing all Case 1 steps
│   └── cleanup_case1.sh                  # Teardown script for Case 1 RAN
│
├── case2_f1_split/           # CASE 2: F1 Split (Central Unit + Distributed Unit)
│   ├── 01_connect_cu_to_core.sh          # Connects CU to AMF (N2 NGAP) and UPF (N3 GTP)
│   ├── 02_connect_cu_and_du.sh           # Connects DU to CU over F1 (F1-C SCTP + F1-U GTP-U)
│   ├── 03_connect_du_to_upf.sh           # Verifies DU <-> CU <-> UPF data plane path
│   ├── 04_connect_ue_to_cu_and_gtp.sh    # Connects UE to DU/CU & verifies GTP tunnel to UPF
│   ├── run_case2.sh                      # Master runner executing all Case 2 steps
│   └── cleanup_case2.sh                  # Teardown script for Case 2 RAN
│
└── case3_cups/               # CASE 3: Control & User Plane Separation (CU-CP + CU-UP + DU)
    ├── 01_connect_cu_cp_to_amf.sh        # Connects CU-CP to AMF (N2 NGAP)
    ├── 02_connect_cu_cp_and_cu_up.sh     # Connects CU-UP to CU-CP over E1 interface (SCTP 38462)
    ├── 03_connect_cu_up_to_upf.sh        # Verifies CU-UP to UPF N3 GTP-U interface
    ├── 04_connect_cu_and_du.sh           # Connects DU to CU-CP (F1-C) and CU-UP (F1-U)
    ├── 05_connect_ue_and_gtp_tunnel.sh   # Connects UE & verifies end-to-end CUPS GTP tunnel
    ├── run_case3.sh                      # Master runner executing all Case 3 steps
    └── cleanup_case3.sh                  # Teardown script for Case 3 RAN
```

---

## Usage Guide

### General Flags
All scripts support the following optional parameters (or environment variables):
* `-c, --context <context>`: Target Kubernetes cluster context (default: auto-detected, prioritizes `kind-oai-tutorial`)
* `-n, --namespace <namespace>`: Target namespace (default: `oai-tutorial`)
* `-h, --help`: Displays usage help

### Diagnostic Check
To inspect the live status of all 5G Core, RAN, and UE GTP tunnel sessions at any time:
```bash
/home/snsrl/scripts/status_all.sh
```

---

### Executing Case 1 (Monolithic gNB)
```bash
# Option A: Run all steps automatically
/home/snsrl/scripts/case1_monolithic/run_case1.sh

# Option B: Run step-by-step
/home/snsrl/scripts/case1_monolithic/01_connect_gnb_to_upf.sh
/home/snsrl/scripts/case1_monolithic/02_connect_ue_to_gnb_and_gtp.sh

# Cleanup when done
/home/snsrl/scripts/case1_monolithic/cleanup_case1.sh
```

---

### Executing Case 2 (F1 Split: CU + DU)
```bash
# Option A: Run all steps automatically
/home/snsrl/scripts/case2_f1_split/run_case2.sh

# Option B: Run step-by-step
/home/snsrl/scripts/case2_f1_split/01_connect_cu_to_core.sh
/home/snsrl/scripts/case2_f1_split/02_connect_cu_and_du.sh
/home/snsrl/scripts/case2_f1_split/03_connect_du_to_upf.sh
/home/snsrl/scripts/case2_f1_split/04_connect_ue_to_cu_and_gtp.sh

# Cleanup when done
/home/snsrl/scripts/case2_f1_split/cleanup_case2.sh
```

---

### Executing Case 3 (CUPS: CU-CP + CU-UP + DU)
```bash
# Option A: Run all steps automatically
/home/snsrl/scripts/case3_cups/run_case3.sh

# Option B: Run step-by-step
/home/snsrl/scripts/case3_cups/01_connect_cu_cp_to_amf.sh
/home/snsrl/scripts/case3_cups/02_connect_cu_cp_and_cu_up.sh
/home/snsrl/scripts/case3_cups/03_connect_cu_up_to_upf.sh
/home/snsrl/scripts/case3_cups/04_connect_cu_and_du.sh
/home/snsrl/scripts/case3_cups/05_connect_ue_and_gtp_tunnel.sh

# Cleanup when done
/home/snsrl/scripts/case3_cups/cleanup_case3.sh
```
