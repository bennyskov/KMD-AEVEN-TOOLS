import sys, os, re, socket, platform, json, yaml, ast
import requests
from requests.auth import HTTPBasicAuth
import subprocess
import logging
import logging.config
import inspect
from subprocess import Popen, PIPE, CalledProcessError
from datetime import datetime
from sys import exit
from awxkit import *
from awxkit.api.pages import Api
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
import warnings
import re
warnings.filterwarnings('ignore', 'This pattern is interpreted as a regular expression, and has match groups.')
# ---------------------------------------------------------------------------------------------------------------------------------------
#
#
#                                                                             dddddddd
#   kkkkkkkk                                                                  d::::::d                                        lllllll
#   k::::::k                                                                  d::::::d                                        l:::::l
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
# 2025-01-05    version V1.0    :   Initial release ( Benny.Skov@kyndryl.com )
#
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
#  init
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
#region
#
# #NOTE delete of these nodes in inventories.
#
nodenames       = ['udv19bfs01, udv19db2aws01, udv19avs01, udv19elk02, udv19cis01, udv19tdm03, udv19bfs02, udv19tdm02, udv19tdg01, udv19elk01, udv19tools, udv19gws01, udv19app01, udv19elk03, kmddbs2136']
nodenames       = ['kmdwinitm001']
#
debug           = bool
debug           = True
useRestAPI      = False #    True: REST API or False: awx
hostname        = socket.gethostname().lower()
RC              = 0
result          = {}
twtok           = ''
cred_ids        = []
cred_names      = []
payload         = []
sys_argv        = sys.argv
scriptname      = sys.argv[0]
scriptname      = scriptname.replace('\\','/').strip()
scriptname      = scriptname.split('/')[-1]
scriptname      = scriptname.split('.')[0]
now             = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
Logdate_long    = datetime.now().strftime('%Y-%m-%d_%H-%M-%S_%f')
project         = 'KMD-AEVEN-TOOLS'
jsondir         = f'D:/scripts/GIT/{project}/backup_inventory'
logdir          = f'D:/scripts/GIT/{project}/logs'
if not os.path.isdir(f'{jsondir}'): os.mkdir(f'{jsondir}')
if not os.path.isdir(f'{logdir}'): os.mkdir(f'{logdir}')
logfile         = f'{logdir}/{scriptname}_{Logdate_long}.log'
tower_host      = 'https://ansible-tower-web-svc-tower.apps.kmdcacf001.adminkmd.local'
tower_url       = f'{tower_host}/api/v2/'
twusr           = 'functional_id_001'
twpwd           = 'm9AHKuXYa*MeZZWLsHqB' # se i 1password
#endregion
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# awx config settingss. awx is reading these
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
#region
os.environ['TOWER_HOST']        = f'{tower_host}'
os.environ['TOWER_USERNAME']    = f'{twusr}'
os.environ['TOWER_PASSWORD']    = f'{twpwd}'
os.environ['TOWER_VERIFY_SSL']  = 'False'
#endregion
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# functions begin
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_dump_and_write(result,useRestAPI,stepName,jsondir,debug):
    if debug:
        if useRestAPI:
            job_json_file = f'{jsondir}/{stepName}_useRestAPI.json'
        else:
            job_json_file = f'{jsondir}/{stepName}_useAwxAPI.json'
        result_dumps = json.dumps(result, indent=5)
        # f_log(f'result_dumps',f'{result_dumps}',debug)
        fhandle = open(job_json_file, 'w', encoding='utf-8')
        fhandle.write(f"{result_dumps}")
        fhandle.close()
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_log
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_log(key,value,debug):
    if debug: text = "{:30}: {:}".format(f'{key}',f'{value}'); logging.info(text)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_set_logging
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_set_logging(debug):
    logging_schema = {
        'version': 1,
        'formatters': {
            'standard': {
                'class': 'logging.Formatter',
                "format": "%(asctime)s\t%(levelname)s\t%(filename)s\t%(message)s",
                'datefmt': '%Y %b %d %H:%M:%S'
            }
        },
        'handlers': {
            'console': {
                'class': 'logging.StreamHandler',
                'formatter': 'standard',
                'level': 'INFO',
                'stream': 'ext://sys.stdout'
            },
            'file': {
                'class': 'logging.FileHandler',
                'formatter': 'standard',
                'level': 'INFO',
                'filename': logfile,
                'mode': 'w'
            }
        },
        'loggers': {
            '__main__': {
                'handlers': ['console', 'file'],
                'level': 'INFO',
                'propagate': False
            }
        },
        'root': {
            'level': 'INFO',
            'handlers': ['console', 'file'],
        }
    }
    logging.config.dictConfig(logging_schema)
    logging.info(f'Logging to file: {logfile}')
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# load_data
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def load_data(string):
    string = str(string)
    if not string or string.isspace():
        return ""

    # First try to parse as JSON which is the most likely format from AWX CLI
    try:
        obj = json.loads(string)
        return obj
    except json.JSONDecodeError:
        pass

    # Try to parse as Python literal (dict, list, etc.)
    try:
        obj = ast.literal_eval(string)
        if isinstance(obj, (tuple, list, dict)):
            return obj
        else:
            # Return the string as is if it's a valid literal but not a collection
            return string
    except (ValueError, SyntaxError):
        pass

    # Try to parse as YAML
    try:
        obj = yaml.safe_load(string)
        return obj
    except yaml.YAMLError:
        pass

    # If all parsing fails, return the original string
    return string
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_requests
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_requests(request='',twusr='',twpwd='', payload='', debug=False):
    try:
        tower_url               = f'https://ansible-tower-web-svc-tower.apps.kmdcacf001.adminkmd.local/api/v2/'
        url                     = f'{tower_url}{request}'
        f_log(f'url',f'{url}',debug)
        RC                      = 0
        if len(payload) == 0:
            response                = requests.get(url, auth=(twusr, twpwd), verify=False, timeout=1440)
        else:
            response                = requests.post(url, auth=(twusr, twpwd), json=payload, verify=False, timeout=1440)
        response.raise_for_status()
        if response.status_code == 200 or response.status_code == 201:
            result_decoded  = response.content.decode('utf-8')
            result_loaded   = load_data(result_decoded)
            result_dumps    = json.dumps(result_loaded, indent=5)
            result          = json.loads(result_dumps)
            # f_log(f'result type',f'{type(result)}',debug)
            # f_log(f'result_dumps',f'\n{result_dumps}',debug)

    except Exception as e:
        if debug:
            f_log(f'request',f'{request}',debug)
            f_log(f'error',f'{e}',debug)
            f_log(f'RC',f'{RC}',debug)
            f_log(f'result type',f'{type(result)}',debug)
            f_log(f'result',f'{result}',debug)
            RC = 12
    finally:
        return result, RC
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_cmdexec
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_cmdexec(cmdexec='',debug=False):
    try:
        f_log(f'cmdexec',f'{cmdexec}',debug)
        cmdexec_result = subprocess.run(cmdexec, capture_output=True, text=True)
        RC = cmdexec_result.returncode
        # f_log(f'cmdexec_result type',f'{type(cmdexec_result)}',debug)
        # f_log(f'cmdexec_result     ',f'{cmdexec_result}',debug)
        if RC > 0:
            raise Exception('f_cmdexec failed')
        else:
            result = load_data(cmdexec_result.stdout)
            if len(result) == 0:
                raise Exception(f'result cannot be read. invalid syntax from input {result}',debug)
    except Exception as e:
        if debug:
            f_log(f'cmdexec',f'{cmdexec}',debug)
            f_log(f'error',f'{e}',debug)
            f_log(f'RC',f'{RC}',debug)
            f_log(f'result type',f'{type(cmdexec_result.stdout)}',debug)
            f_log(f'result stdout',f'{cmdexec_result.stdout}',debug)
            f_log(f'result stderr',f'{cmdexec_result.stderr}',debug)
            RC = 12
    finally:
        return result, RC
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# Begin
#-----------------------------------------------------------------------------------------------------------------------------------------------------------
#region
f_set_logging(debug)
f_log(f'Begin','---------------------------------------------------------------------------------------------------------------------------------------------',debug)
#endregion
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# login
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if not useRestAPI:
    stepName = 'login'
    # First check if we can access AWX with current credentials/token
    cmdexec = ['awx', 'me', '--conf.format', 'yaml', '--conf.insecure']
    try:
        result, RC = f_cmdexec(cmdexec, debug)
        if RC == 0 and 'username' in result:
            f_log('AWX Auth Status', 'Already logged in', debug)
            twtok = os.environ.get('TOWER_OAUTH_TOKEN', '')
            f_log('Current token', f'{twtok[:10]}...' if twtok else 'None', debug)
        else:
            raise Exception("Not authenticated")
    except Exception as e:
        f_log('AWX Auth Status', f'Login required: {str(e)}', debug)

        # Perform login to get new token
        cmdexec = f'awx login --conf.host {tower_host} --conf.username {twusr} --conf.password {twpwd} --conf.insecure --conf.format yaml'
        result, RC = f_cmdexec(cmdexec, debug)

        if RC == 0 and 'token' in result:
            twtok = result['token']
            os.environ['TOWER_OAUTH_TOKEN'] = twtok
            f_log('New token obtained', f'{twtok[:10]}...', debug)

            # Configure AWX client to use the token
            cmdexec = ['awx', 'config', 'oauth_token', f'{twtok}']
            result, RC = f_cmdexec(cmdexec, debug)
            f_log('token config', f'{result}', debug)

            cmdexec = ['awx', 'config', 'use_token', 'True']
            result, RC = f_cmdexec(cmdexec, debug)
            f_log('token usage config', f'{result}', debug)
        else:
            f_log('Login failed', f'RC: {RC}, Result: {result}', debug)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# Get all inventories
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
try:
    stepName = 'export_inventories'
    f_log(f'{stepName}','---------------------------------------------------------------------------------------------------------------------------------------------',debug)
    if useRestAPI:
        request = f'inventories/'
        result,RC = f_requests(request,twusr,twpwd,payload,debug)
    else:
        # cmdexec = ['awx', 'export', '--inventories']
        cmdexec = ['awx', 'inventory', 'list', '--format', 'json']
        result,RC = f_cmdexec(cmdexec,debug)
        # f_log(f'result', f'{result}', debug)

    if RC > 0: raise Exception(f'step {stepName} failed')
    f_dump_and_write(result,useRestAPI,stepName,jsondir,debug)

    all_inventories = result['results']
    inventories_to_export = []
    for inv in all_inventories:
        inv_id = inv['id']
        inv_name = inv['name']
        if inv_name.startswith(('eng_i', 'kmn_i', 'kmw_i')) and re.search(r'inventory$', inv_name):
            f_log(f'inventory', f'{inv_name} (ID: {inv_id})', debug)
            inventories_to_export.append(inv_id)
        else:
            pass
            # f_log(f'skip name', f'{inv_name} (ID: {inv_id})', debug)
except Exception as e:
    if debug: logging.error(e)
    RC = 12
    exit(RC)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# export all inventories with eng_ , or kmn_ , kmw_
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
try:
    stepName = 'export_inventories'
    f_log(f'{stepName}','---------------------------------------------------------------------------------------------------------------------------------------------',debug)
    for inv_id in inventories_to_export:
        if useRestAPI:
            request = f'inventories/{inv_id}/'
            result,RC = f_requests(request,twusr,twpwd,payload,debug)
        else:
            cmdexec = ['awx', 'export', '--inventory', str(inv_id)]
            result,RC = f_cmdexec(cmdexec,debug)
            # f_log(f'result', f'{result}', debug)

        if RC > 0: raise Exception(f'step {stepName} failed')
        f_dump_and_write(result,useRestAPI,stepName,jsondir,debug)
except Exception as e:
    if debug: logging.error(e)
    RC = 12
    exit(RC)
f_log(f'END','---------------------------------------------------------------------------------------------------------------------------------------------',debug)