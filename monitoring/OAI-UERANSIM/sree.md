# 🚀 5G Network Telemetry, Observability & Kepler Energy Monitoring Operations Guide

> **Author**: Sree  
> **Environment**: Linux Ubuntu / Kind Kubernetes Cluster (`oai-tutorial`)  
> **Components**: OAI 5G Core (v2.1.0), UERANSIM, Kepler v0.11.3, Prometheus, Grafana 13, Custom Web Telemetry App

---

## 📖 Table of Contents
1. [Overview & Architecture](#1-overview--architecture)
2. [5G Core & RAN Pod Architecture](#2-5g-core--ran-pod-architecture)
3. [Single-Connection Case Switching Manual](#3-single-connection-case-switching-manual)
   - [Case 1: Monolithic 5G gNB](#case-1-monolithic-5g-gnb)
   - [Case 2: CU / DU F1 Split](#case-2-cu--du-f1-split)
   - [Case 3: CU-CP / CU-UP / DU E1-F1 Split](#case-3-cu-cp--cu-up--du-e1-f1-split)
4. [Observability Infrastructure Setup](#4-observability-infrastructure-setup)
   - [Kepler v0.11.3 eBPF Energy Exporter](#kepler-v0113-ebpf-energy-exporter)
   - [Prometheus Monitoring Engine](#prometheus-monitoring-engine)
   - [Grafana Dashboard Provisioning](#grafana-dashboard-provisioning)
5. [Traffic Load Generation & Kepler Energy Testing](#5-traffic-load-generation--kepler-energy-testing)
6. [Operational Commands & Web Access Directory](#6-operational-commands--web-access-directory)

---

## 1. Overview & Architecture

This guide provides complete instructions for deploying an OpenAirInterface (OAI) 5G Standalone Core network integrated with UERANSIM simulators on Kubernetes. It covers telemetry tracking, eBPF energy measurement using **Kepler v0.11.3**, and multi-case functional split switching.

### System Access Points:
| Service | Access URL / Port | Description |
| :--- | :--- | :--- |
| **Grafana Console** | [http://localhost:3000](http://localhost:3000) | Multi-case 5G & Kepler Energy Dashboards |
| **Prometheus UI** | [http://localhost:8080](http://localhost:8080) | Time-series query engine & target status |
| **Kepler Exporter** | [http://localhost:28282](http://localhost:28282) | eBPF Joules and Watts metrics stream |
| **Web Telemetry App** | [http://localhost:8085](http://localhost:8085) | Central dynamic telemetry dashboard console |

---

## 2. 5G Core & RAN Pod Architecture

The 5G architecture consists of 10+ cloud-native microservice pods running in the `oai-tutorial` namespace:

### Core Network Pods:
* **`case1-mysql` / `case3-mysql`**: MySQL database holding 5G subscriber data & profiles.
* **`oai-nrf`**: Network Repository Function for service discovery.
* **`oai-udr`**: Unified Data Repository for profile data.
* **`oai-udm`**: Unified Data Management for subscriber credential processing.
* **`oai-ausf`**: Authentication Server Function for UE authentication.
* **`oai-amf`**: Access & Mobility Management Function handling RAN signaling.
* **`oai-smf`**: Session Management Function for PDU session management.
* **`oai-upf`**: User Plane Function routing packet data between gNB and traffic server.

### RAN & Simulation Pods:
* **`oai-gnb`** (Case 1): Monolithic gNodeB base station (combining CU & DU).
* **`oai-cu` & `oai-du`** (Case 2): 2-way Split gNodeB connected over F1 interface.
* **`oai-cu-cp`, `oai-cu-up` & `oai-du`** (Case 3): 3-way Split gNodeB connected over E1 & F1 interfaces.
* **`oai-nr-ue`**: UERANSIM 5G User Equipment simulator.
* **`oai-traffic-server`**: iPerf3 target server for user-plane throughput testing.

---

## 3. Single-Connection Case Switching Manual

> ⚠️ **CRITICAL RULE**: Only **ONE** 5G network case (Case 1, Case 2, or Case 3) must be active and connected at any given time. Always uninstall the currently running case and wait for all pods in `oai-tutorial` to terminate before deploying the next case.

---

### Case 1: Monolithic 5G gNB

In Case 1, the gNodeB operates as a single monolithic unit (`oai-gnb`) handling both Central Unit (CU) and Distributed Unit (DU) responsibilities.

#### Step C1.1: Clean Previous Connection (Ensure 1 active case only)
```bash
# Uninstall any running cases
helm uninstall case2 -n oai-tutorial 2>/dev/null || true
helm uninstall case3 -n oai-tutorial 2>/dev/null || true
helm uninstall case1 -n oai-tutorial 2>/dev/null || true

# Verify namespace cleanup
kubectl get pods -n oai-tutorial
```

#### Step C1.2: Deploy Case 1 Helm Chart
```bash
cd /home/snsrl/deplo/charts/e2e_scenarios/case1
helm dependency update
helm install case1 . -n oai-tutorial
```

#### Step C1.3: Verify Case 1 Pod Readiness
```bash
kubectl get pods -n oai-tutorial -w
```
*Expected Pods*: `case1-mysql`, `oai-nrf`, `oai-udr`, `oai-udm`, `oai-ausf`, `oai-amf`, `oai-smf`, `oai-upf`, `oai-gnb` (2/2 Ready), `oai-nr-ue`, `oai-traffic-server`.

---

### Case 2: CU / DU F1 Split

In Case 2, the gNodeB is split into a Central Unit (`oai-cu`) and a Distributed Unit (`oai-du`) communicating over the 3GPP F1 interface.

#### Step C2.1: Clean Previous Connection
```bash
helm uninstall case1 -n oai-tutorial 2>/dev/null || true
helm uninstall case3 -n oai-tutorial 2>/dev/null || true
helm uninstall case2 -n oai-tutorial 2>/dev/null || true

# Verify namespace cleanup
kubectl get pods -n oai-tutorial
```

#### Step C2.2: Deploy Case 2 Helm Chart
```bash
cd /home/snsrl/deplo/charts/e2e_scenarios/case2
helm dependency update
helm install case2 . -n oai-tutorial
```

#### Step C2.3: Verify Case 2 Pod Readiness
```bash
kubectl get pods -n oai-tutorial -w
```
*Expected Pods*: `case2-mysql`, `oai-nrf`, `oai-udr`, `oai-udm`, `oai-ausf`, `oai-amf`, `oai-smf`, `oai-upf`, `oai-cu`, `oai-du`, `oai-nr-ue`, `oai-traffic-server`.

---

### Case 3: CU-CP / CU-UP / DU E1-F1 Split

In Case 3, the gNodeB is disaggregated into 3 separate entities: Central Unit Control Plane (`oai-cu-cp`), Central Unit User Plane (`oai-cu-up`), and Distributed Unit (`oai-du`) connected via E1 and F1 interfaces.

#### Step C3.1: Clean Previous Connection
```bash
helm uninstall case1 -n oai-tutorial 2>/dev/null || true
helm uninstall case2 -n oai-tutorial 2>/dev/null || true
helm uninstall case3 -n oai-tutorial 2>/dev/null || true

# Verify namespace cleanup
kubectl get pods -n oai-tutorial
```

#### Step C3.2: Deploy Case 3 Helm Chart
```bash
cd /home/snsrl/deplo/charts/e2e_scenarios/case3
helm dependency update
helm install case3 . -n oai-tutorial
```

#### Step C3.3: Verify Case 3 Pod Readiness
```bash
kubectl get pods -n oai-tutorial -w
```
*Expected Pods*: `case3-mysql`, `oai-nrf`, `oai-udr`, `oai-udm`, `oai-ausf`, `oai-amf`, `oai-smf`, `oai-upf`, `oai-cu-cp`, `oai-cu-up`, `oai-du`, `oai-nr-ue`, `oai-traffic-server`.

---

## 4. Observability Infrastructure Setup

### Kepler v0.11.3 eBPF Energy Exporter

Kepler (Kubernetes Efficient Power Level Exporter) utilizes eBPF probe programs to calculate real-time container CPU, RAM, and system power consumption in Joules and Watts.

#### Step K.1: Download & Install Kepler Release v0.11.3
```bash
# Download official Helm Chart package
curl -sL https://github.com/sustainable-computing-io/kepler/releases/download/v0.11.3/kepler-helm-0.11.3.tgz -o /tmp/kepler-helm-0.11.3.tgz

# Install with apiserver podInformer mode for Kind compatibility
helm install kepler /tmp/kepler-helm-0.11.3.tgz \
  --namespace kepler \
  --create-namespace \
  --set config.kube.podInformer.mode=apiserver
```

#### Step K.2: Verify Kepler DaemonSet & Live Metrics
```bash
# Check Pod status in kepler namespace
kubectl get pods,ds,svc -n kepler

# Test live metrics output from container on port 28282
KEPLER_POD=$(kubectl get pods -n kepler -l app.kubernetes.io/name=kepler -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n kepler $KEPLER_POD -- curl -s http://localhost:28282/metrics | grep kepler_container_cpu_joules_total | head -n 10
```

---

### Prometheus Monitoring Engine

Prometheus scrapers ingest time-series data from `node-exporter`, `kube-state-metrics`, and `kepler`.

#### Step P.1: Update Prometheus Scrape Configuration
Edit `/home/snsrl/grafa/monitor-linux-prometheus-grafana/OAI-UERANSIM/monitoring/prometheus/config-map.yaml` to include the `kepler` target:

```yaml
      - job_name: 'kepler'
        static_configs:
          - targets: ['kepler.kepler.svc.cluster.local:28282']
```

#### Step P.2: Apply Configuration & Restart Prometheus
```bash
kubectl apply -f monitoring/prometheus/config-map.yaml
kubectl rollout restart deployment/prometheus-deployment -n monitoring
```

---

### Grafana Dashboard Provisioning

Grafana automatically provisions dashboards stored inside Kubernetes `ConfigMaps` mounted to `/etc/grafana/provisioning/dashboards/custom`.

#### Step G.1: Dashboard Files Structure
* **Case 1 Dashboard**: `monitoring/grafana/monolithic-5g-gnb-dashboard.json`
* **Case 2 Dashboard**: `monitoring/grafana/case2-cu-du-split-dashboard.json`
* **Case 3 Dashboard**: `monitoring/grafana/case3-e1-f1-split-dashboard.json`
* **K8s Pod Dashboard**: `Kubernetes Pods monitoring via Prometheus.json`

#### Step G.2: Generate ConfigMap & Rollout Restart Grafana
```bash
# Run provider script to update ConfigMaps
python3 /home/snsrl/.gemini/antigravity/brain/d109c8f4-a60c-4ed2-b30c-6ce4466712fe/scratch/generate_all_4_dashboards_provider.py

# Apply ConfigMaps & restart Grafana
kubectl apply -f monitoring/grafana/grafana-dashboard-provider.yaml
kubectl rollout restart deployment/grafana -n monitoring
```

---

## 5. Traffic Load Generation & Kepler Energy Testing

To observe live CPU, throughput, and Kepler Joule/Watt energy spikes, run an **iPerf3 bandwidth load test** through the 5G user-plane.

### Step T.1: Run 50 Mbps Traffic Load Test
```bash
# Find Traffic Server IP inside the cluster
TRAFFIC_IP=$(kubectl get pods -n oai-tutorial -o wide | grep traffic | awk '{print $6}')

# Execute 50 Mbps load test for 30 seconds from UE pod
UE_POD=$(kubectl get pods -n oai-tutorial -l app.kubernetes.io/name=oai-nr-ue -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n oai-tutorial $UE_POD -c nr-ue -- iperf3 -c $TRAFFIC_IP -t 30 -b 50M
```

### Step T.2: Verify Kepler Power Spikes in Grafana / CLI
```bash
kubectl exec -n kepler $(kubectl get pods -n kepler -l app.kubernetes.io/name=kepler -o jsonpath='{.items[0].metadata.name}') -- curl -s http://localhost:28282/metrics | grep 'kepler_container_cpu_joules_total{' | grep -E '(gnb|du|nr-ue|upf)'
```

#### Observed Power Benchmark (50 Mbps Load):
* **`du` / `gnb` Power**: Spikes from `72 Joules` to **`417+ Joules`** (**+480% increase**).
* **`nr-ue` Power**: Spikes from `49 Joules` to **`325+ Joules`** (**+560% increase**).

---

## 6. Operational Commands & Web Access Directory

### Port-Forwarding Recovery Commands (Run if machine reboots):
```bash
# Grafana Port Forward (Port 3000)
nohup kubectl port-forward -n monitoring svc/grafana 3000:3000 --address 0.0.0.0 > /tmp/grafana_pf.log 2>&1 &

# Prometheus Port Forward (Port 8080)
nohup kubectl port-forward -n monitoring svc/prometheus-service 8080:8080 --address 0.0.0.0 > /tmp/prometheus_pf.log 2>&1 &

# Web Telemetry App Server (Port 8085)
cd /home/snsrl/grafa/monitor-linux-prometheus-grafana/OAI-UERANSIM/dashboard-app
nohup python3 -m http.server 8085 > /tmp/webapp.log 2>&1 &
```

---
*Created by Sree for 5G Kubernetes Telemetry & Energy Monitoring Operations.*
