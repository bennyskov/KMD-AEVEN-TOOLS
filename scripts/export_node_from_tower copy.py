import sys, os, re, socket, platform, json, yaml, ast
import requests
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
debug           = bool
debug           = True
useRestAPI      = False #    True: REST API or False: awx
hostname        = socket.gethostname().lower()
sys_argv        = sys.argv
scriptname      = sys.argv[0]
scriptname      = scriptname.replace('\\','/').strip()
scriptname      = scriptname.split('/')[-1]
scriptname      = scriptname.split('.')[0]
RC              = 0
cred_ids        = []
cred_names      = []
payload         = []
now             = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
tower_host      = 'https://ansible-tower-web-svc-tower.apps.kmdcacf001.adminkmd.local'
twusr           = 'functional_id_001'
twpwd           = 'm9AHKuXYa*MeZZWLsHqB' # se i 1password
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# awx config settingss. awx is reading these
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
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
    Logdate_long = datetime.now().strftime('%Y-%m-%d_%H-%M-%S_%f')
    logfile = f'D:/scripts/GIT/{project}/archive/logs/export_node_from_tower_{Logdate_long}.log'
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
    try:
        obj = ast.literal_eval(string)
        if isinstance(obj, (tuple, list, dict)):
            return obj
        else:
            return None
    except (ValueError, SyntaxError):
        try:
            obj = json.loads(string)
            if isinstance(obj, dict):
                return obj
        except json.JSONDecodeError:
            pass
        try:
            obj = yaml.safe_load(string)
            if isinstance(obj, dict):
                return obj
        except yaml.YAMLError:
            pass
        if isinstance(string, str):
            return string
        return None
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
# f_help_error
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_help_error():
    if debug: logging.info('use: python get_cred_for_host.py -t {{ launch_template_name }} -n {{ nodename }} -s {{ change }} -u {{ twusr }} -p {{ twpwd }}')
    exit(12)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# end functions
# -----
# Begin
#----------------------------------------------------------------------------------------------------------------------------------------------------------
#region
project = 'KMD-AEVEN-TOOLS'
jsondir  = f'D:/scripts/GIT/{project}/backup_inventory'
if not os.path.isdir(f'{jsondir}'): os.mkdir(f'{jsondir}')

# nodename    = ['udv19bfs01, udv19db2aws01, udv19avs01, udv19elk02, udv19cis01, udv19tdm03, udv19bfs02, udv19tdm02, udv19tdg01, udv19elk01, udv19tools, udv19gws01, udv19app01, udv19elk03, kmddbs2136']
nodenames   = ['kmdwinitm001']

f_set_logging(debug)
f_log(f'Begin','---------------------------------------------------------------------------------------------------------------------------------------------',debug)

cmdexec = f'awx login --conf.host {tower_host} --conf.username {twusr} --conf.password {twpwd} --conf.insecure --conf.format yaml'
result,RC = f_cmdexec(cmdexec,debug)
f_dump_and_write(result,useRestAPI,'begin',jsondir,debug)
twtok = result['token']

for nodename in nodenames:

    jsondir = f'{jsondir}/{nodename}'
    if not os.path.isdir(f'{jsondir}'): os.mkdir(f'{jsondir}')
    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    # get_nodename
    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    try:
        stepName = 'get_nodename'
        f_log(f'{stepName}','---------------------------------------------------------------------------------------------------------------------------------------------',debug)
# re.search('_cred', variables_key, re.IGNORECASE)
        found_nodename = ''
        capsnames = [f'{nodename.upper()}',f'{nodename.lower()}']
        for capsname in capsnames:
            capsname = capsname.strip()
            f_log(f'capsname',f'{capsname}',debug)
            if useRestAPI:
                request = f'hosts/?name={capsname}'
                result,RC = f_requests(request,twusr,twpwd,payload,debug)
            else:
                cmdexec = ['awx', 'host', 'list', '--name', f'{capsname}']
                result,RC = f_cmdexec(cmdexec,debug)

            if RC > 0: raise Exception(f'step {stepName} failed')

            if result['count'] > 0:
                result = result['results'][0]
                f_dump_and_write(result,useRestAPI,stepName,jsondir,debug)
                getnode_inv_id      = result['summary_fields']['inventory']['id']
                getnode_inv_name    = result['summary_fields']['inventory']['name']
                found_nodename      = result['name']
                f_log(f'getnode_inv_id',f'{getnode_inv_id}',debug)
                f_log(f'getnode_inv_name',f'{getnode_inv_name}',debug)
                f_log(f'found_nodename',f'{found_nodename}',debug)

            else:
                f_log(f'nodename {nodename} not found',"",debug)

    except Exception as e:
        if debug: logging.error(e)
        RC = 12
        exit(RC)

    # # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    # # get_inventoryByName
    # # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    # try:
    #     stepName = 'get_inventoryByName'
    #     f_log(f'{stepName}','---------------------------------------------------------------------------------------------------------------------------------------------',debug)
    #     if useRestAPI:
    #         request = f'inventories/?name={template_inv_name}'
    #         result,RC = f_requests(request,twusr,twpwd,payload,debug)
    #     else:
    #         cmdexec = ['awx', 'inventory', 'list', '--name', f'{template_inv_name}']
    #         result,RC = f_cmdexec(cmdexec,debug)

    #     if RC > 0: raise Exception(f'step {stepName} failed')
    #     f_dump_and_write(result,useRestAPI,stepName,jsondir,debug)

    #     inv_count = result['count']
    #     if inv_count == 0:
    #         raise Exception(f'step get_inventoryByName {template_inv_name} is not found')
    #     else:
    #         template_inv_id         = result['results'][0]['id']
    #         template_inv_name       = result['results'][0]['name']
    #         template_inv_variables  = result['results'][0]['variables']

    #         result_loaded           = load_data(template_inv_variables)
    #         inv_cred_name           = result_loaded.get('cyberark_credential')
    #         cred_names.append(inv_cred_name)

    #         f_log(f'template_inv_id',f'{template_inv_id}',debug)
    #         f_log(f'template_inv_name',f'{template_inv_name}',debug)
    #         f_log(f'inv_cred_name',f'{inv_cred_name}',debug)

    #     for index, item in enumerate(cred_names):
    #         f_log(f'cred_names {index}',f'{item}',debug)
    # except Exception as e:
    #     if debug: logging.error(e)
    #     RC = 12
    #     exit(RC)
    # # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    # # get_allHostsByInvName
    # # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    # try:
    #     stepName = 'get_allHostsByInvName'
    #     f_log(f'{stepName}','---------------------------------------------------------------------------------------------------------------------------------------------',debug)
    #     if useRestAPI:
    #         request = f'hosts/?inventory={template_inv_id}'
    #         result,RC = f_requests(request,twusr,twpwd,payload,debug)
    #     else:
    #         cmdexec = ['awx', 'host', 'list', '--inventory', f'{template_inv_id}', '--all-pages']
    #         result,RC = f_cmdexec(cmdexec,debug)

    #     if RC > 0: raise Exception(f'step {stepName} failed')
    #     f_dump_and_write(result,useRestAPI,stepName,jsondir,debug)

    # except Exception as e:
    #     if debug: logging.error(e)
    #     RC = 12
    #     exit(RC)
    # # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    # # get_singleHostGetGroups
    # #
    # # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    # try:
    #     stepName = 'get_singleHostGetGroups'
    #     f_log(f'{stepName}','---------------------------------------------------------------------------------------------------------------------------------------------',debug)
    #     allGroups_names = []
    #     if useRestAPI:
    #         request = f'hosts/?name={nodename}&inventory={template_inv_id}'
    #         result,RC = f_requests(request,twusr,twpwd,payload,debug)
    #     else:
    #         cmdexec = ['awx', 'host', 'list', '--name', f'{nodename}', '--inventory', f'{template_inv_id}', '--all-pages']
    #         result,RC = f_cmdexec(cmdexec,debug)

    #     if RC > 0: raise Exception(f'step {stepName} failed')
    #     f_dump_and_write(result,useRestAPI,stepName,jsondir,debug)

    # except Exception as e:
    #     if debug: logging.error(e)
    #     RC = 12
    #     exit(RC)
    # # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    # # get_allGroupsWithHost
    # # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    # try:
    #     stepName = 'get_allGroupsWithHost'
    #     f_log(f'{stepName}','---------------------------------------------------------------------------------------------------------------------------------------------',debug)
    #     if useRestAPI:
    #         request = f'hosts/{host_id}/all_groups'
    #         result,RC = f_requests(request,twusr,twpwd,payload,debug)
    #     else:
    #         cmdexec = ['awx','host','get',f'{host_id}','--query','all_groups','--all-pages']
    #         result,RC = f_cmdexec(cmdexec,debug)

    #     if RC > 0: raise Exception(f'step {stepName} failed')
    #     f_dump_and_write(result,useRestAPI,stepName,jsondir,debug)

    # except Exception as e:
    #     if debug: logging.error(e)
    #     RC = 12
    #     exit(RC)
    # # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    # # get_credNameFromGroup
    # # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    # try:
    #     stepName = 'get_credNameFromGroup'
    #     f_log(f'{stepName}','---------------------------------------------------------------------------------------------------------------------------------------------',debug)
    #     for grp_cred in unique_group_list:
    #         if useRestAPI:
    #             request = f'groups/?name={grp_cred}'
    #             result,RC = f_requests(request,twusr,twpwd,payload,debug)
    #         else:
    #             cmdexec = ['awx', 'group', 'list', '--name', f'{grp_cred}', '--all-pages']
    #             result,RC = f_cmdexec(cmdexec,debug)

    #         if RC > 0: raise Exception(f'step {stepName} failed')
    #         f_dump_and_write(result,useRestAPI,stepName,jsondir,debug)

    # except Exception as e:
    #     if debug: logging.error(e)
    #     RC = 12
    #     exit(RC)
    # # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    # # get_credential_ids
    # # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    # try:
    #     stepName = 'get_credential_ids'
    #     f_log(f'{stepName}','---------------------------------------------------------------------------------------------------------------------------------------------',debug)
    #     credential_ids = []
    #     credential_names = []
    #     for cred_name in unique_cred_name_list:
    #         if useRestAPI:
    #             request = f'credentials/?name={cred_name}'
    #             result,RC = f_requests(request,twusr,twpwd,payload,debug)
    #         else:
    #             cmdexec = ['awx', 'credential', 'list', '--name', f'{cred_name}', '--all-pages']
    #             result,RC = f_cmdexec(cmdexec,debug)

    #         if RC > 0: raise Exception(f'step {stepName} failed')
    #         f_dump_and_write(result,useRestAPI,stepName,jsondir,debug)

    #         credential_count = result['count']
    #         if credential_count == 0:
    #             if debug: text = "{:25}: {:}".format(f'credential_name: {cred_name}',f'is not found!'); logging.warning(text)
    #         else:
    #             result = result['results']
    #             credential_id = result[0]['id']
    #             credential_name = result[0]['name']
    #             f_log(f'cred_name',f'{cred_name}',debug)
    #             f_log(f'credential_name',f'{credential_name}',debug)
    #             f_log(f'credential_id',f'{credential_id}',debug)
    #             credential_ids.append(credential_id)
    #             credential_names.append(credential_name)

    # except Exception as e:
    #     if debug: logging.error(e)
    #     RC = 12
    #     exit(RC)

f_log(f'END','---------------------------------------------------------------------------------------------------------------------------------------------',debug)