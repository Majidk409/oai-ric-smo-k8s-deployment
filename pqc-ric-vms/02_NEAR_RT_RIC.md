# 2. Near-RT RIC on ric-nearrt (10.230.4.43): O-RAN SC L release

Everything here runs **inside the VM** (`ssh snsrl@10.230.4.43`). It includes every fix that was
needed on the real install (marked **FIX**).

## 2.1 Kubernetes 1.28 + Helm 3.14

```bash
git clone -b l-release https://github.com/o-ran-sc/ric-plt-ric-dep.git ~/ric-dep
cd ~/ric-dep/bin
sudo ./install_k8s_and_helm.sh 2>&1 | tee ~/install_k8s.log      # 5–10 min; use tmux
```

These messages in the log are harmless:
- `modprobe: FATAL: Module nf_conntrack_ipv4/ipv6/proto_sctp not found`: built into newer kernels.
- `Version '0.7.5-00' for 'kubernetes-cni' was not found`: it installs 1.2.0 instead.
- the `pause:3.8` warning.

**FIX: kubectl for your user.** The installer writes `KUBECONFIG=/root/.kube/config` into
`/etc/environment`:

```bash
mkdir -p ~/.kube
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
echo 'export KUBECONFIG=$HOME/.kube/config' >> ~/.bashrc && export KUBECONFIG=$HOME/.kube/config
kubectl get pods -A                          # ~8 pods, all Running
```

**FIX: storage label.** The installer looks for a node role "master", which Kubernetes 1.28 calls
"control-plane", so its labelling step fails:

```bash
kubectl label --overwrite nodes $(hostname) local-storage=enable
```

## 2.2 Common Helm templates

**FIX: ChartMuseum.** Without it, the script loops on `servecm not yet running`:

```bash
cd ~ && curl -LO https://get.helm.sh/chartmuseum-v0.15.0-linux-amd64.tar.gz
tar xzf chartmuseum-v0.15.0-linux-amd64.tar.gz && sudo mv linux-amd64/chartmuseum /usr/local/bin/
cd ~/ric-dep/bin
sudo ./install_common_templates_to_helm.sh   # with sudo: the install below also runs as root
sudo helm repo list                          # local  http://127.0.0.1:8879/charts
```

## 2.3 Recipe and install

```bash
cp ~/ric-dep/RECIPE_EXAMPLE/example_recipe_oran_l_release.yaml ~/ric-recipe.yaml
sed -i 's/ricip: "10.0.0.1"/ricip: "10.230.4.43"/; s/auxip: "10.0.0.1"/auxip: "10.230.4.43"/' ~/ric-recipe.yaml
cd ~/ric-dep/bin
sudo ./install -f ~/ric-recipe.yaml          # 5–15 min; use tmux
kubectl get pods -n ricplt -w                # 13 pods Running
```

The pods are: a1mediator, alarmmanager, appmgr, e2mgr, e2term-alpha, o1mediator, rtmgr, submgr,
vespamgr, dbaas, kong, and the prometheus server and alertmanager. A few early restarts (e.g.
rtmgr) are normal.

## 2.4 Make E2 and A1 reachable from the lab

**FIX: E2 on the standard port.** The chart exposes E2 only as NodePort 32222. This also opens
36422 on the VM's IP:

```bash
kubectl patch svc service-ricplt-e2term-sctp-alpha -n ricplt -p '{"spec":{"externalIPs":["10.230.4.43"]}}'
kubectl get svc -n ricplt service-ricplt-e2term-sctp-alpha      # EXTERNAL-IP 10.230.4.43, 36422:32222/SCTP
```

**FIX: A1 through Kong.** The ingresses have no class, so Kong ignores them, and the a1mediator
path prefix must also be stripped:

```bash
for i in a1mediator appmgr e2mgr; do
  kubectl patch ingress ingress-ricplt-$i -n ricplt --type merge -p '{"spec":{"ingressClassName":"kong"}}'
done
kubectl annotate ingress ingress-ricplt-a1mediator -n ricplt konghq.com/strip-path=true --overwrite
curl -s http://10.230.4.43:32080/a1mediator/A1-P/v2/healthcheck -o /dev/null -w "A1 via Kong: HTTP %{http_code}\n"   # 200
curl -s http://10.230.4.43:32080/a1mediator/A1-P/v2/policytypes; echo                                                # []
```

Kong's log keeps saying `waiting for addresses to be provisioned for publish service ... kong-proxy`.
That is expected: `kong-proxy` is a LoadBalancer service with no cloud load balancer behind it, and
routing works through NodePort 32080 anyway.

**These patches live in Kubernetes,** so they survive reboots. Running `./uninstall` + `./install`
resets them, so apply 2.4 again after a reinstall.

## Result

| Interface | Address |
|---|---|
| **E2** | `10.230.4.43:36422` (SCTP); NodePort `32222` also works |
| **A1** | `http://10.230.4.43:32080/a1mediator/A1-P/v2/...` |

## Troubleshooting

| Problem | Command |
|---|---|
| A pod is not Running | `kubectl describe pod -n ricplt <pod>` (look at Events) |
| See a pod's log | `kubectl logs -n ricplt <pod>` |
| ErrImagePull | `bash ~/portal_login.sh`, then `kubectl delete pod -n ricplt <pod>` |
| Clean reinstall | `cd ~/ric-dep/bin && sudo ./uninstall`, then 2.3 and 2.4 |
