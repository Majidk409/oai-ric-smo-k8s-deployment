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

## 3.4 FIX: make the policy service speak O-RAN SC A1 (needed for policy types and policies)

**Symptom:**
- The policy service shows `ric-nearrt` as `AVAILABLE`, but `policytype_ids` stays `[]`.
- After a type exists, the RIC flips to `UNAVAILABLE`.
- Its log says `StdA1ClientVersion2 - Unexpected response for policy type ...
  JSONObject["policySchema"] not found`.

**Cause:** the policy service probes RICs as "O-RAN standard A1-P v2" first, and that probe
succeeds. But O-RAN SC's A1 mediator returns policy types in its own format (`create_schema`). The
policy service's O-RAN SC client (`OscA1Client`) understands that format, but it calls the old
path style `/a1-p/...`, while the L-release A1 mediator only serves `/A1-P/v2/...`.

**Fix, part 1: an extra Kong route on ric-nearrt** (`config/a1osc-route.yaml`), mapping
`/a1osc/a1-p/*` to `/A1-P/v2/*`:

```bash
# on ric-nearrt
kubectl apply -f a1osc-route.yaml
curl -s http://10.230.4.43:32080/a1osc/a1-p/policytypes; echo      # same list as /a1mediator/A1-P/v2/policytypes
```

**Fix, part 2: point the policy service at it, with the O-RAN SC client.** This uses its
configuration API, so no redeploy is needed:

```bash
# on ric-smo; the file is config/pms-application_configuration.json
PMS=$(kubectl get svc -n nonrtric policymanagementservice -o jsonpath='{.spec.clusterIP}')
curl -s -X PUT http://$PMS:8081/a1-policy/v2/configuration -H "Content-Type: application/json" \
     --data @pms-application_configuration.json -w "HTTP %{http_code}\n"             # 200
```

The `ric-nearrt` entry now reads:

```json
{"name": "ric-nearrt", "baseUrl": "http://10.230.4.43:32080/a1osc",
 "customAdapterClass": "org.onap.ccsdk.oran.a1policymanagementservice.clients.OscA1Client",
 "managedElementIds": ["oai-gnb"]}
```

## 3.5 Proof: a real policy over A1 (verified 2026-11-25)

```bash
# ric-nearrt: create a policy type (normally an xApp does this)
curl -s -X PUT http://10.230.4.43:32080/a1mediator/A1-P/v2/policytypes/20008 -H "Content-Type: application/json" \
  -d '{"name":"demo_threshold","description":"A1 demo","policy_type_id":20008,"create_schema":{"$schema":"http://json-schema.org/draft-07/schema#","type":"object","properties":{"threshold":{"type":"integer","default":0}},"additionalProperties":false}}'

# ric-smo: the type appears in the Non-RT RIC, then send a policy
curl -s "http://$PMS:8081/a1-policy/v2/policy-types?ric_id=ric-nearrt"                    # {"policytype_ids":["20008"]}
curl -s -X PUT http://$PMS:8081/a1-policy/v2/services -H "Content-Type: application/json" \
  -d '{"service_id":"demo","keep_alive_interval_seconds":0,"callback_url":""}'             # 201
curl -s -X PUT http://$PMS:8081/a1-policy/v2/policies -H "Content-Type: application/json" \
  -d '{"ric_id":"ric-nearrt","policy_id":"demo-pol-1","service_id":"demo","policytype_id":"20008","policy_data":{"threshold":5}}'   # 201

# ric-nearrt: the policy arrived over A1
curl -s http://10.230.4.43:32080/a1mediator/A1-P/v2/policytypes/20008/policies                 # ["demo-pol-1"]
curl -s http://10.230.4.43:32080/a1mediator/A1-P/v2/policytypes/20008/policies/demo-pol-1      # {"threshold":5}
```

The status `NOT_ENFORCED` is expected until an xApp handles policy type 20008.
