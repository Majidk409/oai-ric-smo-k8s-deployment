# 🔬 RnD: Kepler v0.11.3 Energy Telemetry & 5G Case Switching Manual

> **CRITICAL RULE**: Only **ONE** 5G network case (Case 1, Case 2, or Case 3) must be active and connected at any given time. Always uninstall the currently running case and ensure all pods are fully terminated before deploying the next case.

---

## 📋 Table of Contents
1. [Kepler v0.11.3 Installation & Verification](#1-kepler-v0113-installation--verification)
2. [Single-Connection Case Switching Rules](#2-single-connection-case-switching-rules)
3. [Case 1: Monolithic 5G gNB (Single Connection)](#case-1-monolithic-5g-gnb-single-connection)
4. [Case 2: CU / DU F1 Split (Single Connection)](#case-2-cu--du-f1-split-single-connection)
5. [Case 3: CU-CP / CU-UP / DU E1-F1 3-Way Split (Single Connection)](#case-3-cu-cp--cu-up--du-e1-f1-3-way-split-single-connection)
6. [Prometheus & Grafana Energy Dashboards Integration](#6-prometheus--grafana-energy-dashboards-integration)

---

## 1. Kepler v0.11.3 Installation & Verification

### Step 1.1: Download & Install Kepler Release v0.11.3 via Helm
```bash
# Download official Kepler v0.11.3 Helm package
curl -sL https://github.com/sustainable-computing-io/kepler/releases/download/v0.11.3/kepler-helm-0.11.3.tgz -o /tmp/kepler-helm-0.11.3.tgz

# Install Kepler into 'kepler' namespace
helm install kepler /tmp/kepler-helm-0.11.3.tgz --namespace kepler --create-namespace
```

### Step 1.2: Verify Kepler DaemonSet & Pod Status
```bash
kubectl get pods,daemonset,service -n kepler
```

### Step 1.3: Verify Kepler Energy Metrics Stream (Port 28282)
```bash
KEPLER_POD=$(kubectl get pods -n kepler -l app.kubernetes.io/name=kepler -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n kepler $KEPLER_POD -- curl -s http://localhost:28282/metrics | grep kepler_container_joules_total | head -n 10
```

---

## 2. Single-Connection Case Switching Rules

To ensure clean performance measurements without metric interference:
1. **Always uninstall active Helm releases in `oai-tutorial` first**.
2. **Wait for pod deletion** using `kubectl get pods -n oai-tutorial`.
3. **Deploy the target case**.

---

## Case 1: Monolithic 5G gNB (Single Connection)

### Step C1.1: Clean previous connection (Ensure 1 active case only)
```bash
helm uninstall case2 -n oai-tutorial 2>/dev/null || true
helm uninstall case3 -n oai-tutorial 2>/dev/null || true
helm uninstall case1 -n oai-tutorial 2>/dev/null || true

# Wait until oai-tutorial namespace has no active pods
kubectl get pods -n oai-tutorial
```

### Step C1.2: Deploy Case 1 (Monolithic gNB + 5G Core)
```bash
cd /home/snsrl/grafa/monitor-linux-prometheus-grafana/OAI-UERANSIM/OAI+UERANSIM/case1
helm dependency update
helm install case1 . -n oai-tutorial
```

### Step C1.3: Verify Single Connection Case 1 Pods
```bash
kubectl get pods -n oai-tutorial -w
```

---

## Case 2: CU / DU F1 Split (Single Connection)

### Step C2.1: Clean previous connection (Ensure 1 active case only)
```bash
helm uninstall case1 -n oai-tutorial 2>/dev/null || true
helm uninstall case3 -n oai-tutorial 2>/dev/null || true
helm uninstall case2 -n oai-tutorial 2>/dev/null || true

# Wait until oai-tutorial namespace has no active pods
kubectl get pods -n oai-tutorial
```

### Step C2.2: Deploy Case 2 (CU / DU F1 Split + 5G Core)
```bash
cd /home/snsrl/grafa/monitor-linux-prometheus-grafana/OAI-UERANSIM/OAI+UERANSIM/case2
helm dependency update
helm install case2 . -n oai-tutorial
```

### Step C2.3: Verify Single Connection Case 2 Pods
```bash
kubectl get pods -n oai-tutorial -w
```

---

## Case 3: CU-CP / CU-UP / DU E1-F1 3-Way Split (Single Connection)

### Step C3.1: Clean previous connection (Ensure 1 active case only)
```bash
helm uninstall case1 -n oai-tutorial 2>/dev/null || true
helm uninstall case2 -n oai-tutorial 2>/dev/null || true
helm uninstall case3 -n oai-tutorial 2>/dev/null || true

# Wait until oai-tutorial namespace has no active pods
kubectl get pods -n oai-tutorial
```

### Step C3.2: Deploy Case 3 (CU-CP, CU-UP, DU + 5G Core)
```bash
cd /home/snsrl/deplo/charts/e2e_scenarios/case3
helm dependency update
helm install case3 . -n oai-tutorial
```

### Step C3.3: Verify Single Connection Case 3 Pods
```bash
kubectl get pods -n oai-tutorial -w
```

---

## 6. Prometheus & Grafana Energy Dashboards Integration

### 6.1 Check Active Grafana Dashboards:
* **Case 1 Monolithic**: [http://localhost:3000/d/monolithic-5g-gnb](http://localhost:3000/d/monolithic-5g-gnb)
* **Case 2 CU-DU Split**: [http://localhost:3000/d/case2-cu-du-split](http://localhost:3000/d/case2-cu-du-split)
* **Case 3 E1-F1 Split**: [http://localhost:3000/d/case3-e1-f1-split](http://localhost:3000/d/case3-e1-f1-split)
* **Web Telemetry App**: [http://localhost:8085](http://localhost:8085)
