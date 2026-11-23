# OAI 5G on Kubernetes + O-RAN Near-RT RIC + SMO: deployment files of the RIC machine (10.230.4.28)

This is a copy of the deployment material found on the lab's RIC/SMO machine (Ubuntu 22.04, 22
threads, 62 GB) on 2026-11-23. It covers OAI 5G core and RAN on Kubernetes (kind + Helm), the
monitoring stack, the O-RAN SC Near-RT RIC and the O-RAN SC SMO OAM.

| Folder | What it is | Taken from (.28) |
|---|---|---|
| `helm-charts/oai-5g-core/` | OAI 5G core Helm charts (AMF, SMF, UPF, NRF, UDM, UDR, AUSF, PCF, NSSF, LMF, MySQL, IMS; `oai-5g-basic` / `-mini` / `-advance` umbrella charts) | `~/deplo/charts` |
| `helm-charts/oai-5g-ran/` | OAI RAN Helm charts: gNB, CU, CU-CP, CU-UP, DU, DU/gNB with 7.2 fronthaul (`*-fhi-72`), NR-UE, FlexRIC | `~/deplo/charts` |
| `helm-charts/e2e_scenarios/case1..3` | End-to-end scenarios: case 1 monolithic gNB, case 2 F1 split (CU + DU), case 3 CU-CP / CU-UP / DU split | `~/deplo/charts` |
| `helm-charts/desktop-variants/` | Locally edited copies of case 1 and case 2 | `~/Desktop/case1`, `~/Desktop/case2` |
| `scripts/` | Automation for the three cases on the cluster: deploy, connect, verify GTP-U, clean up (see `scripts/README.md`) | `~/scripts` |
| `monitoring/` | Prometheus + Grafana (docker-compose), Kubernetes monitoring manifests (Prometheus, kube-state-metrics), OAI core + UERANSIM charts | `~/grafa/monitor-linux-prometheus-grafana` |
| `near-rt-ric/qsafe-ric/` | **O-RAN SC Near-RT RIC (i-release), Docker Compose** (srsRAN packaging), with the A1 mediator + A1 proxy, KPM monitor and energy xApps, and run logs. See its `README.md` | `~/qsafe-ric` |
| `smo-oam/` | **O-RAN SC SMO OAM**: Docker Compose (`solution/`: NETCONF controller, VES collector, Kafka, O-DU O1 and O-RU M-plane simulators) and Kubernetes (`solution_k8s/`). Upstream it/oam at `bfdfa32` (2025-12-01) plus local changes | `~/smo/oam` |
| `guides/` | Step-by-step guides (mini PC setup, kind cluster, observability, the 3 split cases, AI/ML co-location) and the run scripts used with them | `~/*.md`, `~/*_script.sh` |

## Not included

- **The OAI source tree** (`~/icdcn`, 2.2 GB), **UERANSIM source**, and the older RIC copy
  `~/oran-sc-ric`. These are upstream projects; clone them from their own repos.
- **The kubeconfig** (`~/.kube/config`): it holds cluster credentials.

## Notes on credentials in these files

Apart from the lab-generated test keys below, all of them are **public defaults** of the upstream
projects:
- MySQL `linux` / `test` (OAI);
- SMO `.env` passwords (O-RAN SC defaults);
- the self-signed demo certificates tracked in upstream it/oam;
- the lab-generated test CA and client keys for the simulated O-DU ↔ SMO TLS link
  (`smo-oam/solution/o1-ofhmp-interfaces/base/docker/conf/*.key`). They are included on purpose, so
  the setup runs as it is. Regenerate them with the `openssl` configs in the same folder for anything
  beyond the lab;
- the simulated subscribers with PLMN 001/01 and OAI's default keys.

Change them before any deployment outside the lab.

## Status when copied (2026-11-23)

- **The kind cluster `oai-tutorial` (Kubernetes v1.30)** was present, but its API server did not
  answer. No live cluster state is included, only the files.
- **The Near-RT RIC and SMO containers were stopped.** The qsafe-ric README records the last
  working run (2026-09-28): E2 + KPM from an OAI gNB, and A1 policies to an energy xApp.
