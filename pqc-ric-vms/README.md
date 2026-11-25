# O-RAN SC Near-RT RIC + Non-RT RIC in two VMs (our deployment, from scratch)

This folder is **our own** from-scratch deployment for the PQC 5G testbed (2026-11-24/25). The rest
of this repository is a copy of other material found on the machine (see the top-level README).

```
.28 (host; other people's work on it stays untouched)
 ├── VM ric-nearrt  10.230.4.43   O-RAN SC Near-RT RIC (L release) on Kubernetes 1.28
 │                                  E2  : 10.230.4.43:36422/sctp  (NodePort 32222 too)
 │                                  A1  : http://10.230.4.43:32080/a1mediator/A1-P/v2/...
 └── VM ric-smo     10.230.4.44   O-RAN SC Non-RT RIC (L release) on Kubernetes 1.28
                                    A1 policy service -> ric-nearrt: AVAILABLE
                                    control panel: http://10.230.4.44:30091
```

| Step | Guide | Result |
|---|---|---|
| 1 | [01_CREATE_VMS.md](01_CREATE_VMS.md) | two Ubuntu 20.04 VMs with lab IPs, campus internet login |
| 2 | [02_NEAR_RT_RIC.md](02_NEAR_RT_RIC.md) | Near-RT RIC running; E2 and A1 reachable from the lab |
| 3 | [03_NON_RT_RIC.md](03_NON_RT_RIC.md) | Non-RT RIC running; A1 to the Near-RT RIC `AVAILABLE` |

**Files:**

| Path | What it is |
|---|---|
| `scripts/mkvm.sh` | creates one VM on the host (macvtap on `enp86s0`, static IP via cloud-init) |
| `scripts/portal_login.sh` | campus internet login for a VM; asks for the credentials and stores nothing |
| `config/ric-recipe-l-release.yaml` | Near-RT RIC recipe (L release, IPs set to 10.230.4.43) |
| `config/nonrtric-recipe.yaml` | Non-RT RIC recipe (minimal set) |
| `config/pms-application_configuration.json` | A1 policy service: our Near-RT RIC + one simulator |

**Status, 2026-11-25:**
- Both VMs survived a reboot, and all pods came back by themselves.
- Checked after the reboot: E2 on the external IP, A1 via Kong `HTTP 200`, the policy service shows
  `ric-nearrt` and `ric-sim` `AVAILABLE`, and the control panel answers `HTTP 200`.

**Next:**
1. An A1 policy demo.
2. E2 from the real OAI DU / CU-CP / CU-UP.
3. SMO OAM (O1).
4. PQC on A1 and E2.
