# 3. Non-RT RIC on ric-smo (10.230.4.44): O-RAN SC L release

Everything here runs **inside the VM** (`ssh snsrl@10.230.4.44`).

## 3.1 Kubernetes 1.28 + Helm 3.14

Exactly as in [02_NEAR_RT_RIC.md](02_NEAR_RT_RIC.md) §2.1: clone `ric-dep` (l-release), run
`sudo ./install_k8s_and_helm.sh`, then apply the kubectl and storage-label fixes. Skip 2.2–2.4.

## 3.2 Minimal Non-RT RIC

| Part | Installed | Why |
|---|---|---|
| A1 Policy Management Service (PMS) | ✅ | sends A1 policies to the Near-RT RIC |
| Information Coordinator Service (ICS) | ✅ | data/job registry |
| Control panel + gateway | ✅ | web GUI, NodePort 30091 |
| A1 simulators | ✅ | test targets |
| A1 controller, Kong, CAPIF, service manager, DMaaP adapter, rApp manager, DME participant, RAN PM | ❌ | heavy or not needed yet (the rApp manager needs ONAP ACM) |

```bash
sudo apt-get install -y lsof                                  # the deploy script needs it
git clone -b l-release https://github.com/o-ran-sc/it-dep.git ~/it-dep
```

**Point the PMS at our Near-RT RIC** (see `config/pms-application_configuration.json`):

```bash
cp pms-application_configuration.json \
   ~/it-dep/nonrtric/helm/policymanagementservice/resources/data/application_configuration.json
```

It contains two RICs:
- `ric-nearrt` → `http://10.230.4.43:32080/a1mediator`;
- `ric-sim` → `http://a1-sim-osc-0.a1-sim:8085`.

**Recipe with only the parts above:**

```bash
cp ~/it-dep/nonrtric/RECIPE_EXAMPLE/example_recipe.yaml ~/nonrtric-recipe.yaml
for k in installA1controller installKong installDmaapadapterservice installCapifcore installServicemanager installrAppmanager installDmeParticipant installRanpm; do
  sed -i -E "s/^(  $k:).*/\1 false/" ~/nonrtric-recipe.yaml
done
grep -E "^  install" ~/nonrtric-recipe.yaml
```

Five switches should be `true`: Pms, A1simulator, Controlpanel, Informationservice and
Nonrtricgateway.

**Deploy:**

```bash
cd ~/it-dep/bin
sudo -E ./deploy-nonrtric -f ~/nonrtric-recipe.yaml 2>&1 | tee ~/deploy-nonrtric.log   # use tmux
kubectl get pods -n nonrtric -w
```

You should end with 10 pods, all `1/1 Running`: 6 × a1-sim, controlpanel, informationservice-0,
nonrtricgateway and policymanagementservice-0. The PMS stays `0/1` for about 2 minutes first.

## 3.3 Proof: A1 across the network

```bash
PMS=$(kubectl get svc -n nonrtric policymanagementservice -o jsonpath='{.spec.clusterIP}')
curl -s http://$PMS:8081/a1-policy/v2/rics | python3 -m json.tool
```

The output must show `"ric_id": "ric-nearrt"` with `"state": "AVAILABLE"`. That means the Non-RT RIC
(10.230.4.44) reaches the Near-RT RIC (10.230.4.43) over A1. `policytype_ids` stays `[]` until an
xApp registers a policy type.

**Control panel:** http://10.230.4.44:30091

**Start over:** `cd ~/it-dep/bin && sudo -E ./undeploy-nonrtric`, then deploy again.
