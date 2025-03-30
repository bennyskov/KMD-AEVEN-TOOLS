import json
import sys, os
import requests
import re
import time
import socket
from sys import exit
from datetime import datetime
from datetime import timedelta
from requests.auth import HTTPBasicAuth
from pathlib import Path
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
# ---------------------------------------------------------------------------------------------------------------------------------------
#
#
#                                                                             dddddddd
#   kkkkkkkk                                                                  d::::::d                                        lllllll
#   k::::::k                                                                  d::::::d                                        l:::::l
#   k::::::k                                                                  d::::::d                                        l:::::l
#   k::::::k                                                                  d:::::d                                         l:::::l
#   k:::::k    kkkkkkkyyyyyyy           yyyyyyynnnn  nnnnnnnn        ddddddddd:::::drrrrr   rrrrrrrrryyyyyyy           yyyyyyyl::::l
#   k:::::k   k:::::k  y:::::y         y:::::y n:::nn::::::::nn    dd::::::::::::::dr::::rrr:::::::::ry:::::y         y:::::y l::::l
#   k:::::k  k:::::k    y:::::y       y:::::y  n::::::::::::::nn  d::::::::::::::::dr:::::::::::::::::ry:::::y       y:::::y  l::::l
#   k:::::k k:::::k      y:::::y     y:::::y   nn:::::::::::::::nd:::::::ddddd:::::drr::::::rrrrr::::::ry:::::y     y:::::y   l::::l
#   k::::::k:::::k        y:::::y   y:::::y      n:::::nnnn:::::nd::::::d    d:::::d r:::::r     r:::::r y:::::y   y:::::y    l::::l
#   k:::::::::::k          y:::::y y:::::y       n::::n    n::::nd:::::d     d:::::d r:::::r     rrrrrrr  y:::::y y:::::y     l::::l
#   k:::::::::::k           y:::::y:::::y        n::::n    n::::nd:::::d     d:::::d r:::::r               y:::::y:::::y      l::::l
#   k::::::k:::::k           y:::::::::y         n::::n    n::::nd:::::d     d:::::d r:::::r                y:::::::::y       l::::l
#   k::::::k k:::::k           y:::::::y          n::::n    n::::nd::::::ddddd::::::ddr:::::r                 y:::::::y       l::::::l
#   k::::::k  k:::::k           y:::::y           n::::n    n::::n d:::::::::::::::::dr:::::r                  y:::::y        l::::::l
#   k::::::k   k:::::k         y:::::y            n::::n    n::::n  d:::::::::ddd::::dr:::::r                 y:::::y         l::::::l
#   kkkkkkkk    kkkkkkk       y:::::y             nnnnnn    nnnnnn   ddddddddd   dddddrrrrrrr                y:::::y          llllllll
#                            y:::::y                                                                        y:::::y
#                           y:::::y                                                                        y:::::y
#                          y:::::y                                                                        y:::::y
#                         y:::::y                                                                        y:::::y
#                        yyyyyyy                                                                        yyyyyyy
#
#
# ---------------------------------------------------------------------------------------------------------------------------------------
# Changelog
#
# set_maintenance_mode.py  :   shortened version for ansible
#
# ---------------------------------------------------------------------------------------------------------------------------------------
# vars to login to bluecare and default if no input is added
# ---------------------------------------------------------------------------------------------------------------------------------------
debug       = bool
debug       = True
def f_log(key,value,debug):
    if debug: text = "{:30}: {:}".format(f'{key}',f'{value}'); print(text)
start       = time.time()
now         = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
exechost    = socket.gethostname().lower()
f_log(f'exechost',f'{exechost}',debug)
argvnull    = sys.argv[0]
scriptNamepy= argvnull.split('\\')[-1]
scriptName  = scriptNamepy.split(".")[0]
user        = 'y9gb84'
pw          = 'andersine1313#'
hostIP      = '84.255.92.69'
port        = '9443'
auth        =  HTTPBasicAuth(user,pw)
bcurl       = f'https://{hostIP}:{port}/Portal/services/rest/cis/v1/'
nodename    = 'kmdwinitm001'
desc        = "Server put in maintenancce mode by system"
change      = "CHG00000000"
endact      = "2"
eventTypeName=""
from_time   = "now"
until_time  = "1440"
monsol      = ""
instanceId  = ""
# ---------------------------------------------------------------------------------------------------------------------------------------
# parse and check input
# ---------------------------------------------------------------------------------------------------------------------------------------
argnum = 1
if len(sys.argv) > 1:
    for i, arg in enumerate(sys.argv):
        checkArg = str(arg.strip())
        if re.match("\-nodename$", checkArg, re.IGNORECASE): argnum = i; argnum += 1; nodename = sys.argv[argnum]
        if re.match("\-desc$", checkArg, re.IGNORECASE): argnum = i; argnum += 1; desc = sys.argv[argnum]
        if re.match("\-change$", checkArg, re.IGNORECASE): argnum = i; argnum += 1; change = sys.argv[argnum]
        if re.match("\-from_time$", checkArg, re.IGNORECASE): argnum = i; argnum += 1; from_time = sys.argv[argnum]
        if re.match("\-until_time$", checkArg, re.IGNORECASE): argnum = i; argnum += 1; until_time = sys.argv[argnum]
        if re.match("\-monsol$", checkArg, re.IGNORECASE): argnum = i; argnum += 1; monsol = sys.argv[argnum]
        if re.match("\-user$", checkArg, re.IGNORECASE): argnum = i; argnum += 1; user = sys.argv[argnum]
        if re.match("\-pw$", checkArg, re.IGNORECASE): argnum = i; argnum += 1; pw = sys.argv[argnum]
# ---------------------------------------------------------------------------------------------------------------------------------------
if len(nodename) == 0 or nodename is None:
    f_log(f'nodename is empty',f'{nodename}',debug)
    exit(12)
f_log(f'sys.argv',f'{sys.argv}',debug)
# ---------------------------------------------------------------------------------------------------------------------------------------
# note the cacf server is one  hour behind!!!!
# vaidate from_time time
# format = yyyy-MM-dd HH:mm
# ---------------------------------------------------------------------------------------------------------------------------------------
if bool(re.match(r'now', from_time, re.IGNORECASE)):
    current_time = datetime.now()
    added_time = current_time + timedelta(minutes=65)
    from_time = str(added_time.strftime('%Y-%m-%d %H:%M'))
else:
    if bool(re.match(r'\b\d{4}-\d{2}-\d{2} \d{2}:\d{2}$', from_time, re.IGNORECASE)):
        from_time = datetime.strptime(from_time,'%Y-%m-%d %H:%M')
        from_date = from_time.strftime('%Y-%m-%d %H:%M')
        from_time = str(from_time.strftime('%Y-%m-%d %H:%M'))
    else:
        f_log(f'from_time format is wrong   ',f'{from_time}',debug)
        f_log(f'from_time type',f'{str(type(from_time))}',debug)
        f_log(f'from_time     ',f'{from_time}',debug)
# ---------------------------------------------------------------------------------------------------------------------------------------
# vaidate until_time time
# format = yyyy-MM-dd HH:mm
# ---------------------------------------------------------------------------------------------------------------------------------------
if bool(re.match(r'^\d+$', until_time, re.IGNORECASE)):
    current_time = datetime.now()
    until_time = int(until_time)+65
    until_time = current_time + timedelta(minutes=until_time)
    until_time = str(until_time.strftime('%Y-%m-%d %H:%M'))
else:
    if bool(re.match(r'\b\d{4}-\d{2}-\d{2} \d{2}:\d{2}$', until_time, re.IGNORECASE)):
        until_time = datetime.strptime(until_time,'%Y-%m-%d %H:%M')
        until_date = until_time.strftime('%Y-%m-%d %H:%M')
        until_time = str(until_time.strftime('%Y-%m-%d %H:%M'))
    else:
        f_log(f'until_time format is wrong   ',f'{until_time}',debug)
        f_log(f'until_time type',f'{str(type(until_time))}',debug)
        f_log(f'until_time     ',f'{until_time}',debug)
# ---------------------------------------------------------------------------------------------------------------------------------------
# get all bluecare nodenames to select bcNodeName with ccode
# ---------------------------------------------------------------------------------------------------------------------------------------
apifunc         = "nodes"
url             = f'{bcurl}{apifunc}'
f_log(f'url',f'\n{url}',debug)
headers         = { "accept": "application/json","content-type": "application/json"}
response        = requests.get(url, headers=headers, auth=auth, verify=False)
result_decoded  = response.content.decode('utf-8')
result_loaded   = json.loads(result_decoded)
result_dumps    = json.dumps(result_loaded, indent=5)
# f_log(f'result_dumps',f'\n{result_dumps}',debug)
for id in result_loaded:
    if 'name' in id:
        bcItmKey = str(id['name'])
        bcItmKey = bcItmKey.strip()
        if bool(re.search(r'^(HUB_|REMOTE_)', bcItmKey, re.IGNORECASE)): continue
        if bcItmKey.count('.') > 0: continue
        if bcItmKey.count('_') != 1: continue
        bcCI = bcItmKey.split("_")[1]
        if bool(re.search(r'^[a-zA-Z0-9]{32}$', bcCI, re.IGNORECASE)): continue
        if bool(re.search(f'{nodename}',bcItmKey, re.IGNORECASE)):
            bcNodeName = bcItmKey
            f_log(f'bcNodeName',f'{bcNodeName}',debug)
# ---------------------------------------------------------------------------------------------------------------------------------------
# build body
# ---------------------------------------------------------------------------------------------------------------------------------------
body = {}
body['id'] = '' # empty first time
body['changeNumber'] = change
body['description'] = desc
body['endAction'] = '2'
body['eventTypeName'] = ''
body['from'] = from_time
body['until'] = until_time
body['instanceId'] = ''
body['monitoringSolutionName'] = monsol
body['nodeName'] = bcNodeName
bodyjson = json.dumps(body, indent=5)
f_log(f'bodyjson',f'\n{bodyjson}',debug)
# ---------------------------------------------------------------------------------------------------------------------------------------
# set in maintenance mode
# ---------------------------------------------------------------------------------------------------------------------------------------
try:
    apifunc     = "maintenanceschedules"
    url         = f'{bcurl}{apifunc}'
    headers     = { "accept": "application/json","content-type": "application/json"}
    response    = requests.post(url, headers=headers, auth=auth, verify=False, data=bodyjson) # post method
    response.raise_for_status()
    status_code = response.status_code
    f_log(f'status_code',f'{status_code}',debug)
    if status_code == 201:
        result_decoded  = response.content.decode('utf-8')
        result_loaded   = json.loads(result_decoded)
        result_dumps    = json.dumps(result_loaded, indent=5)
        f_log(f'result_dumps',f'\n{result_dumps}',debug)
        maintenance_id = result_loaded['id']
        print(maintenance_id)
        RC = 0
    else:
        raise Exception(f'status_code {status_code} : {url} failed')
except Exception as e:
    f_log(f'response',f'{response}',debug)
    f_log(f'error',f'{e}',debug)
    result_decoded  = response.content.decode('utf-8')
    f_log(f'result_decoded',f'{result_decoded}',debug)
    result_loaded   = json.loads(result_decoded)
    f_log(f'result_loaded',f'{result_loaded}',debug)
    result_dumps    = json.dumps(result_loaded, indent=5)
    f_log(f'result_dumps',f'\n{result_dumps}',debug)
    RC = 12

exit(RC)