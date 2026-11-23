# qsafe-ric on the Near-RT machine (10.230.4.28)

O-RAN SC Near-RT RIC (i-release, srsRAN docker version) in ~/qsafe-ric/oran-sc-ric,
compose project "qsafe-ric", subnet 10.0.3.0/24 (the old RIC on 10.0.2.0/24 is untouched;
its stopped containers were renamed *_old). E2 port 36421/sctp published on the host.
Start/stop:  cd ~/qsafe-ric/oran-sc-ric && docker-compose up -d   /   docker-compose down

Leftover containers stopped (not removed): identity, gateway, dhcp-server, oai-tutorial-control-plane
(list in logs/containers-running-before.txt; restart with docker start <name>).

SCTP fix: the gNB advertises its docker0 address 172.17.0.1 in the E2 association; this host has the
same docker0 address, so e2term heartbeats to it were answered with ABORT, killing E2. Rule added:
  iptables -I INPUT 1 -s 10.0.3.10/32 -p sctp -m addrtype --dst-type LOCAL -j DROP
Undo:
  sudo iptables -D INPUT -s 10.0.3.10/32 -p sctp -m addrtype --dst-type LOCAL -m comment --comment qsafe-ric -j DROP

KPM: OK with xApps/python/qsafe_kpm_mon.py (report style 4, S-NSSAI 222/123 condition).
  docker exec python_xapp_runner python3 -u ./qsafe_kpm_mon.py --e2_node_id gnbd_208_095_00000e00_e00 --ran_func_id 2 --kpm_report_style 4 --metrics DRB.UEThpDl,DRB.UEThpUl,RRU.PrbTotDl

A1: ric_a1mediator (ric-plt-a1 3.2.2, 10.0.3.16, host port 10000) + ric_a1proxy (nginx, host port 10001, /a1-p/* -> /A1-P/v2/*),
defined in docker-compose.a1.yml; A1 routes 20010-20012 added to ric/configs/routes.rtg.
Start all:  docker-compose -f docker-compose.yml -f docker-compose.a1.yml up -d
Policy type 20008 "energy_saving" {cell_id, max_prb_ratio} created on the mediator.

## Energy xApp (2026-09-28)

`xApps/python/qsafe_energy_xapp.py`, run inside `python_xapp_runner` (RMR port 4560):
`docker exec -d python_xapp_runner sh -c 'python3 -u ./qsafe_energy_xapp.py > /opt/xApps/qsafe_energy_xapp.log 2>&1'`

- A1 policy type 20008 (RMR 20010) -> E2SM-RC style 2 action 6 control to the DU `gnbd_208_095_00000e00_e00`
  (RC ran func 3), reply RMR 20011. DELETE restores 100 %. At start it sets 100 %.
- KPM style 4 subscription (DRB.UEThpDl/Ul, RRU.PrbTotDl) -> served on :8095, published through the
  a1proxy: `http://10.230.4.28:10001/kpm` and `/history` (added to `ric/configs/a1proxy/default.conf`).
- `qsafe_rc_ctrl.py --max_prb_ratio N`: one-shot RC control for manual tests.
- Note: the A1 mediator panics if the 20011 reply has `policy_type_id` as a string (must be a number).
