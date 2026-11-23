#!/usr/bin/env python3
"""qsafe-testbed energy xApp (Near-RT RIC).

- A1: receives policy type 20008 energy_saving {cell_id, max_prb_ratio} from the A1 mediator
  (RMR 20010) and enforces it on the DU with E2SM-RC style 2 action 6 (slice PRB quota).
  Replies with RMR 20011. Deleting the policy restores 100 %.
- KPM: subscribes to the DU (style 4, S-NSSAI 222/123) and serves the latest KPIs as JSON on
  :8095/kpm, so the rApps on the Non-RT RIC can read QoS (via the a1proxy nginx, /kpm).
"""
import argparse, json, signal, threading, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from lib.xAppBase import xAppBase
from ricxappframe.xapp_frame import rmr
from ricxappframe.e2ap.asn1 import IndicationMsg

A1_POLICY_REQ, A1_POLICY_RESP, POLICY_TYPE = 20010, 20011, 20008
active = {}  # policy_instance_id -> cap; several energy rApps may hold policies on the cell
state = {"max_prb_ratio": 100, "policy_instance_id": None, "kpm": {}, "kpm_time": None, "history": []}


class Api(BaseHTTPRequestHandler):
    def do_GET(self):
        body = json.dumps({k: state[k] for k in ("max_prb_ratio", "policy_instance_id", "kpm", "kpm_time")}
                          if self.path.startswith("/kpm") else state["history"][-50:]).encode()
        self.send_response(200); self.send_header("Content-Type", "application/json"); self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


class EnergyXapp(xAppBase):
    def enforce(self, ratio):
        ratio = max(1, min(100, int(ratio)))
        self.e2sm_rc.control_slice_level_prb_quota(self.node, 0, min_prb_ratio=0, max_prb_ratio=ratio,
                                                   dedicated_prb_ratio=100, ack_request=1)
        state["max_prb_ratio"] = ratio
        print(f"[energy-xapp] E2 RC control -> {self.node}: DL max PRB ratio {ratio}%", flush=True)

    def handle_a1(self, raw):
        req = json.loads(raw)
        op, pid = req.get("operation"), req.get("policy_instance_id")
        if isinstance(req.get("payload"), str):  # the A1 mediator forwards the policy body as a JSON string
            req["payload"] = json.loads(req["payload"] or "{}")
        status = "OK"
        try:
            # the cell runs with the most restrictive cap among all active policies
            if op in ("CREATE", "UPDATE"):
                active[pid] = int(req["payload"]["max_prb_ratio"])
            elif op == "DELETE":
                active.pop(pid, None)
                status = "DELETED"
            self.enforce(min(active.values(), default=100))
            state["policy_instance_id"] = min(active, key=active.get) if active else None
        except Exception as e:
            print(f"[energy-xapp] A1 policy {pid} failed: {e}", flush=True)
            status = "ERROR"
        state["history"].append({"time": time.time(), "op": op, "policy": pid, "payload": req.get("payload"),
                                 "status": status})
        print(f"[energy-xapp] A1 {op} {pid} {req.get('payload')} -> {status}", flush=True)
        resp = {"policy_type_id": int(req.get("policy_type_id", POLICY_TYPE)), "policy_instance_id": pid,
                "handler_id": "qsafe_energy_xapp", "status": status}
        self.rmr_send(self.node, json.dumps(resp).encode(), A1_POLICY_RESP)

    def kpm_cb(self, agent, sub, hdr, msg):
        meas = self.e2sm_kpm.extract_meas_data(msg)
        kpm = {}
        for ue, d in meas.get("ueMeasData", {}).items():
            for name, vals in d["measData"].items():
                kpm.setdefault(name, 0)
                kpm[name] += sum(vals) if isinstance(vals, list) else vals
        state["kpm"], state["kpm_time"] = kpm, time.time()

    def _run(self):
        # Same loop as xAppBase, plus A1 policy requests.
        while self.running:
            try:
                sbuf = rmr.rmr_torcv_msg(self.rmr_client, None, 100)
                summary = rmr.message_summary(sbuf)
            except Exception:
                continue
            if summary[rmr.RMR_MS_MSG_STATE] == 0 and summary["message type"] == A1_POLICY_REQ:
                self.handle_a1(rmr.get_payload(sbuf))
                rmr.rmr_free_msg(sbuf)
                continue
            if summary[rmr.RMR_MS_MSG_STATE] == 0 and summary["message type"] == 12050:
                ind = IndicationMsg(); ind.decode(rmr.get_payload(sbuf))
                # Only one subscription (KPM); xAppBase's ID mapping can race with subscribe(), so don't rely on it.
                h, m = self.e2sm_kpm.unpack_ric_indication(ind)
                self.kpm_cb(summary["meid"].decode(), summary["subscription id"], h, m)
            rmr.rmr_free_msg(sbuf)

    @xAppBase.start_function
    def start(self, node, metrics):
        self.node = node
        self.enforce(100)  # start from a known state; PMS re-sends active policies on resync
        conds = [{'testCondInfo': {'testType': ('sNSSAI', 'true'), 'testExpr': 'equal',
                                   'testValue': ('valueOctS', bytes([222, 0x00, 0x00, 0x7B]))}}]
        self.e2sm_kpm.subscribe_report_service_style_4(node, 1000, conds, metrics, 1000, self.kpm_cb)
        while self.running:
            time.sleep(1)


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument("--e2_node_id", default='gnbd_208_095_00000e00_e00')
    p.add_argument("--kpm_ran_func_id", type=int, default=2)
    p.add_argument("--rc_ran_func_id", type=int, default=3)
    p.add_argument("--api_port", type=int, default=8095)
    a = p.parse_args()
    x = EnergyXapp('', 8090, 4560)
    x.e2sm_kpm.set_ran_func_id(a.kpm_ran_func_id)
    x.e2sm_rc.set_ran_func_id(a.rc_ran_func_id)
    threading.Thread(target=ThreadingHTTPServer(("0.0.0.0", a.api_port), Api).serve_forever, daemon=True).start()
    for s in (signal.SIGINT, signal.SIGTERM, signal.SIGQUIT):
        signal.signal(s, x.signal_handler)
    x.start(a.e2_node_id, ["DRB.UEThpDl", "DRB.UEThpUl", "RRU.PrbTotDl"])
