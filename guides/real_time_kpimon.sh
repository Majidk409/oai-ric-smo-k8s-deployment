#!/bin/bash

cd /home/snsrl/oran-sc-ric/xApps/python

# Run docker-compose exec but pipe its output to stdout
docker-compose exec -T -e PYTHONUNBUFFERED=1 python_xapp_runner ./kpm_mon_xapp_v2_test1.py --metrics=DRB.UEThpDl,DRB.UEThpUl --kpm_report_style=5 2>&1
