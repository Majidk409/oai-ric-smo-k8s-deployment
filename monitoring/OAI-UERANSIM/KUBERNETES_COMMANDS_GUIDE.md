# Complete Kubernetes, 5G OAI Cases & Grafana/Prometheus Operations Guide

This guide contains all Kubernetes, Helm, Prometheus, and Grafana commands required to operate the **OpenAirInterface (OAI) 5G Core Network**, switch between **gNB Functional Split Cases (Case 1, Case 2, Case 3)**, and maintain the **Prometheus & Grafana Observability Suite**.

---

## Table of Contents
1. [Cluster Health & Diagnostics](#1-cluster-health--diagnostics)
2. [5G RAN & Core Functional Split Cases](#2-5g-ran--core-functional-split-cases)
   - [Checking Current Active Case](#checking-current-active-case)
   - [Switching Cases (Uninstalling & Installing)](#switching-cases-uninstalling--installing)
   - [Case 1: Monolithic gNB](#case-1-monolithic-gnb)
   - [Case 2: CU / DU Split (F1 Interface)](#case-2-cu--du-split-f1-interface)
   - [Case 3: CU-CP / CU-UP / DU Split (E1/F1 Interfaces)](#case-3-cu-cp--cu-up--du-split-e1f1-interfaces)
3. [UERANSIM Simulator Operations](#3-ueransim-simulator-operations)
4. [Prometheus & Kube-State-Metrics Setup](#4-prometheus--kube-state-metrics-setup)
5. [Grafana Setup & Dashboard Provisioning](#5-grafana-setup--dashboard-provisioning)
6. [Port Forwarding & Web Consoles Access](#6-port-forwarding--web-consoles-access)
7. [Traffic Generation & Load Testing (iPerf3)](#7-traffic-generation--load-testing-iperf3)

---

## 1. Cluster Health & Diagnostics

Check nodes status:
```bash
kubectl get nodes
```

View all running pods across namespaces:
```bash
kubectl get pods -A
```

Check 5G network pods in `oai-tutorial` namespace:
```bash
kubectl get pods -n oai-tutorial -o wide
```

Check monitoring infrastructure pods:
```bash
kubectl get pods -n monitoring
```

View pod logs for troubleshooting:
```bash
# Example for AMF pod
kubectl logs -n oai-tutorial -l app.kubernetes.io/name=oai-amf --tail=100 -f

# Example for UPF pod
kubectl logs -n oai-tutorial -l app.kubernetes.io/name=oai-upf --tail=100 -f
```

---

## 2. 5G RAN & Core Functional Split Cases

### Checking Current Active Case
```bash
helm ls -A
```

---

### Switching Cases (Uninstalling & Installing)

Before deploying a new Case, uninstall the currently active Case:
```bash
# Uninstall Case 3 (or currently active release)
helm uninstall case3 -n oai-tutorial

# Uninstall Case 2 if running
helm uninstall case2 -n oai-tutorial

# Uninstall Case 1 if running
helm uninstall case1 -n oai-tutorial
```

---

### Case 1: Monolithic gNB
* **Architecture**: Single `oai-gnb` pod + 5G Core Network + `oai-nr-ue`.
* **Chart Location**: `/home/snsrl/deplo/charts/e2e_scenarios/case1`

Deploy Case 1:
```bash
cd /home/snsrl/deplo/charts/e2e_scenarios/case1
helm dependency update
helm install case1 . -n oai-tutorial
```

Verify deployment:
```bash
kubectl get pods -n oai-tutorial
```

---

### Case 2: CU / DU Split (F1 Interface)
* **Architecture**: Disaggregated `oai-cu` + `oai-du` pods + 5G Core Network + `oai-nr-ue`.
* **Chart Location**: `/home/snsrl/deplo/charts/e2e_scenarios/case2`

Deploy Case 2:
```bash
cd /home/snsrl/deplo/charts/e2e_scenarios/case2
helm dependency update
helm install case2 . -n oai-tutorial
```

Verify deployment:
```bash
kubectl get pods -n oai-tutorial
```

---

### Case 3: CU-CP / CU-UP / DU Split (E1/F1 Interfaces)
* **Architecture**: 3-way split `oai-cu-cp` + `oai-cu-up` + `oai-du` pods + 5G Core Network + `oai-nr-ue`.
* **Chart Location**: `/home/snsrl/deplo/charts/e2e_scenarios/case3`

Deploy Case 3:
```bash
cd /home/snsrl/deplo/charts/e2e_scenarios/case3
helm dependency update
helm install case3 . -n oai-tutorial
```

Verify deployment:
```bash
kubectl get pods -n oai-tutorial
```

---

## 3. UERANSIM Simulator Operations

Deploy UERANSIM gNB:
```bash
cd /home/snsrl/grafa/monitor-linux-prometheus-grafana/OAI-UERANSIM/OAI+UERANSIM
helm install ueransim-gnb ueransim-5g-ran/ueransim-gnb/ -n oai
```

Deploy UERANSIM UEs (Single or Multiple):
```bash
# Single UE
helm install ueransim-ue1 ueransim-5g-ran/ueransim-ue1/ -n oai

# Multiple UEs (e.g., 5 UEs)
helm install ueransim-gnb ueransim-5g-ran/ueransim-gnb/ -n oai \
  --set ues.enabled=true \
  --set ues.count=5
```

Verify Ping from UE pod:
```bash
UE_POD=$(kubectl get pods -n oai -l app=ueransim-ue -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it -n oai $UE_POD -- ping -c 4 -I uesimtun0 google.com
```

---

## 4. Prometheus & Kube-State-Metrics Setup

1. Create `monitoring` namespace:
```bash
kubectl create namespace monitoring
```

2. Deploy Prometheus RBAC, ConfigMap, Deployment & Service:
```bash
cd /home/snsrl/grafa/monitor-linux-prometheus-grafana/OAI-UERANSIM/monitoring/prometheus
kubectl apply -f clusterRole.yaml
kubectl apply -f config-map.yaml
kubectl apply -f prometheus-deployment.yaml
kubectl apply -f prometheus-service.yaml -n monitoring
```

3. Deploy Kube-State-Metrics:
```bash
cd /home/snsrl/grafa/monitor-linux-prometheus-grafana/OAI-UERANSIM/monitoring
kubectl apply -f kube-state-metrics-configs/
```

Verify Prometheus status:
```bash
kubectl get pods,svc -n monitoring
```

---

## 5. Grafana Setup & Dashboard Provisioning

1. Deploy Grafana Datasource & Dashboard Provisioner ConfigMaps:
```bash
cd /home/snsrl/grafa/monitor-linux-prometheus-grafana/OAI-UERANSIM/monitoring/grafana
kubectl apply -f grafana-datasource-config.yaml
kubectl apply -f grafana-dashboard-provider.yaml
```

2. Deploy Grafana Workload & Service:
```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

3. Restart Grafana to pick up new dashboards:
```bash
kubectl rollout restart deployment/grafana -n monitoring
kubectl rollout status deployment/grafana -n monitoring
```

---

## 6. Port Forwarding & Web Consoles Access

### Grafana UI Port Forwarding (Port 3000)
Run in background:
```bash
nohup kubectl port-forward -n monitoring svc/grafana 3000:3000 --address 0.0.0.0 > /tmp/grafana_pf.log 2>&1 &
```
* **URL**: [http://localhost:3000](http://localhost:3000)
* **Username**: `admin`
* **Password**: `admin`

---

### Prometheus Server Port Forwarding (Port 8080)
Run in background:
```bash
nohup kubectl port-forward -n monitoring svc/prometheus-service 8080:8080 --address 0.0.0.0 > /tmp/prometheus_pf.log 2>&1 &
```
* **URL**: [http://localhost:8080](http://localhost:8080)

---

### 5G Telemetry & Web Dashboard App (Port 8085)
Run in background:
```bash
nohup python3 -m http.server 8085 --directory /home/snsrl/grafa/monitor-linux-prometheus-grafana/OAI-UERANSIM/dashboard-app > /tmp/dashboard_app.log 2>&1 &
```
* **URL**: [http://localhost:8085](http://localhost:8085)

---

## 7. Traffic Generation & Load Testing (iPerf3)

1. Deploy iPerf3 Server Pod:
```bash
kubectl run iperf3 --image=maitaba/iperf3:latest -n oai
```

2. Execute iPerf3 Automated Load Test:
```bash
cd /home/snsrl/grafa/monitor-linux-prometheus-grafana/OAI-UERANSIM/OAI+UERANSIM
chmod +x run_iperf3_tests.sh run_load.sh
./run_iperf3_tests.sh 60
```
