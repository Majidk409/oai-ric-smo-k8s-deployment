#!/usr/bin/env python3
"""qsafe-testbed: send one E2SM-RC style 2 action 6 (slice-level PRB quota) control, then exit."""
import argparse, signal, time, os
from lib.xAppBase import xAppBase

class RcCtrl(xAppBase):
    @xAppBase.start_function
    def start(self, e2_node_id, max_ratio):
        print(f"RC control -> {e2_node_id}: max_prb_ratio={max_ratio}", flush=True)
        self.e2sm_rc.control_slice_level_prb_quota(e2_node_id, 0, min_prb_ratio=0,
                                                   max_prb_ratio=max_ratio, dedicated_prb_ratio=100, ack_request=1)
        time.sleep(2)
        import os; os._exit(0)

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument("--e2_node_id", default='gnbd_208_095_00000e00_e00')
    p.add_argument("--ran_func_id", type=int, default=3)
    p.add_argument("--max_prb_ratio", type=int, required=True)
    p.add_argument("--http_server_port", type=int, default=8091)
    p.add_argument("--rmr_port", type=int, default=4561)
    a = p.parse_args()
    x = RcCtrl('', a.http_server_port, a.rmr_port)
    x.e2sm_rc.set_ran_func_id(a.ran_func_id)
    signal.signal(signal.SIGINT, x.signal_handler); signal.signal(signal.SIGTERM, x.signal_handler)
    x.start(a.e2_node_id, a.max_prb_ratio)
