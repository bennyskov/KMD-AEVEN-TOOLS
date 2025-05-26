import sys, os, re, socket, platform, json, yaml, ast
import requests
from requests.auth import HTTPBasicAuth
import subprocess
import logging
import logging.config
import inspect
import time
from datetime import datetime
from datetime import timedelta
from subprocess import Popen, PIPE, CalledProcessError
from datetime import datetime
from sys import exit
# from awxkit import *
# from awxkit.api.pages import Api
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
import warnings
import re
import yaml
warnings.filterwarnings('ignore', 'This pattern is interpreted as a regular expression, and has match groups.')
global debug
debug = bool
debug = True
# ---------------------------------------------------------------------------------------------------------------------------------------
#
#
#                                                                         }    dddddddd
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
#region f_log
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_log
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_log(key, value, debug, level='DEBUG'):
    level = level.upper()
    valid_levels = ['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL']
    if level not in valid_levels:
        level = 'DEBUG'

    text = f"{key:60}: {value}"
    log_method = getattr(logging, level.lower(), logging.debug)
    log_method(text)
#endregion
#region f_set_logging
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_set_logging
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_set_logging(logfile, debug):
    logging_schema = {
        'version': 1,
        'formatters': {
            'standard': {
                'format': "%(asctime)s\t%(levelname)s\t%(filename)s\t%(message)s",
                'datefmt': '%Y %b %d %H:%M:%S'
            }
        },
        'handlers': {
            'console': {
                'class': 'logging.StreamHandler',
                'formatter': 'standard',
                'level': 'DEBUG' if debug else 'INFO',
                'stream': 'ext://sys.stdout'
            },
            'file': {
                'class': 'logging.FileHandler',
                'formatter': 'standard',
                'level': 'DEBUG' if debug else 'INFO',
                'filename': logfile,
                'mode': 'w'
            }
        },
        'root': {
            'level': 'DEBUG' if debug else 'INFO',
            'handlers': ['console', 'file']
        }
    }
    logging.config.dictConfig(logging_schema)
    logging.debug(f"Logging initialized. Writing to file: {logfile}")
#endregion
#region f_dump_and_write
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_dump_and_write(result,stepName,debug)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_dump_and_write(result,stepName,debug):
    job_json_file = f'{jsondir}/{stepName}.json'
    result_dumps = json.dumps(result, indent=5)
    # f_log(f'result_dumps',f'{result_dumps}',debug)
    fhandle = open(job_json_file, 'w', encoding='utf-8')
    fhandle.write(f"{result_dumps}")
    fhandle.close()
#endregion
#region f_end
def f_end(RC):
    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    # THE END
    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    end = time.time()
    hours, rem = divmod(end-start, 3600)
    minutes, seconds = divmod(rem, 60)
    endPrint = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    # Format values explicitly as strings where needed
    text = "{:6} - {} - {} - {} - {:0>2}:{:0>2}:{:05.2f}".format(
        'End of',
        str(nodename),  # Convert nodename to string explicitly
        str(scriptname),  # Convert scriptname to string explicitly
        endPrint,
        int(hours),
        int(minutes),
        seconds
    )
    f_log('finished - elapsed time:', text, debug, level='DEBUG')
    exit(RC)
#endregion
#region f_load_data
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_load_data
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_load_data(string):
    string = str(string)
    if not string or string.isspace():
        return ""

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
#endregion
#region f_requests
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_requests
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_requests(request,twusr,twpwd,payload,debug):
    result = None
    RC = 0
    try:
        tower_url               = f'https://ansible-tower-web-svc-tower.apps.kmdcacf001.adminkmd.local/api/v2/'
        url                     = f'{tower_url}{request}'
        f_log(f'url',f'{url}',debug)

        if payload and isinstance(payload, (dict, list)):
            payload_json = json.dumps(payload, ensure_ascii=False)
            f_log(f'payload_json',f'{payload_json}',debug)
            response = requests.post(url,
                auth=(twusr, twpwd),
                headers={'Content-Type': 'application/json'},
                data=payload_json,
                verify=False,
                timeout=1440
            )
        else:
            response = requests.get(url, auth=(twusr, twpwd), verify=False, timeout=1440)

        # Handle response
        content = response.content.decode('utf-8')

        if response.status_code in [200, 201]:
            result_loaded = f_load_data(content)
            result = result_loaded
        else:
            # Log the error response content for debugging
            f_log(f'request', request, debug)
            f_log(f'response status', f'{response.status_code} {response.reason}', debug)
            f_log(f'response content', content, debug)
            RC = response.status_code
            try:
                result = json.loads(content)
            except:
                result = {'error': content}

    except Exception as e:
        f_log(f'request', request, debug)
        f_log(f'error', str(e), debug)
        RC = 12

    return result, RC
#endregion
#region f_cmdexec
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_cmdexec
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_cmdexec(cmdexec='',debug=False):
    try:
        f_log(f'cmdexec',f'{cmdexec}',debug)
        cmdexec_result = subprocess.run(cmdexec, capture_output=True, text=True)
        RC = cmdexec_result.returncode
        if RC > 0:
            raise Exception('f_cmdexec failed'); f_end(RC)
        else:
            result = f_load_data(cmdexec_result.stdout)
            if len(result) == 0:
                raise Exception(f'result cannot be read. invalid syntax from input {result}',debug); f_end(RC)
    except Exception as e:
        if debug:
            f_log(f'cmdexec',f'{cmdexec}',debug)
            f_log(f'error',f'{e}',debug)
            f_log(f'RC',f'{RC}',debug)
            f_log(f'cmdexec_result',f'{cmdexec_result}',debug)
            f_log(f'result stdout',f'{cmdexec_result.stdout}',debug)
            f_log(f'result stderr',f'{cmdexec_result.stderr}',debug)
            RC = 12
    finally:
        return result, RC
#endregion
#region f_help_error
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_help_error
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_help_error():
    if debug: logging.info('use: python get_cred_for_host.py -t {{ launch_template_name }} -n {{ nodename }} -u {{ twusr }} -p {{ twpwd }} -d')
    exit(12)
#endregion
#region read_input_sys_argv
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# end functions
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
global tower_host, tower_url
global project, checkCaps
global logfile, scriptname, payload, nodename, launch_template_name
global now, Logdate_long, jsondir, logdir
global cred_names, credentials_ids, credential_names, template_id, CONTINUE, RC
global LAUNCH_TEMPLATE

tower_host          = 'https://ansible-tower-web-svc-tower.apps.kmdcacf001.adminkmd.local'
tower_url           = f'{tower_host}/api/v2/'
awx_hostname        = socket.gethostname().lower()
sys_argv            = sys.argv
LAUNCH_TEMPLATE     = False
template_name       = ''
isRunningLocally    = True
if re.search(r".*kmdwinitm001.*", awx_hostname, re.IGNORECASE): isRunningLocally = True
if re.search(r"^automation-job.*", awx_hostname, re.IGNORECASE): isRunningLocally = False
if isRunningLocally and len(sys.argv) <= 3:  # Only use hardcoded values if not provided via command line
    # nodename            = 'dfkapp3019'
    nodename            = 'eboksweb2302'
    twusr               = 'functional_id_001'
    twpwd               = 'm9AHKuXYa*MeZZWLsHqB'
    #
    #
    # launch_template_name= 'kmn_jobtemplate_de-tooling_ITM_and_ansible_removal_on_linux'
    # launch_template_name= 'kmn_jobtemplate_de-tooling_disable_SCCM_windows'
    # launch_template_name= 'kmn_jobtemplate_de-tooling_REinstall_ITM_windows' # not part of kmn_jobtemplate_de-tooling_begin
    # launch_template_name= 'kmn_jobtemplate_de-tooling_cleanup_CACF_linux'
    # launch_template_name= 'kmn_jobtemplate_de-tooling_servercheck_windows'
    # launch_template_name= 'kmn_jobtemplate_de-tooling_set_maintenancemode'
    # launch_template_name= 'kmn_jobtemplate_de-tooling_UNinstall_ITM_windows'
    # launch_template_name= 'kmn_jobtemplate_de-tooling_UNinstall_ITM_linux'
    launch_template_name= 'de-tooling_verify_windows'
    #
    # sys_argv            = ['d:/scripts/GIT/KMD-AEVEN-TOOLS/scripts/launch_and_misc_awx_functions.py', '-t', f'{launch_template_name}', '-n', f'{nodename}', '-u', f'{twusr}', '-p', f'{twpwd}', '-d']
    sys_argv            = ['d:/scripts/GIT/KMD-AEVEN-TOOLS/scripts/launch_and_misc_awx_functions.py', '-t', f'{launch_template_name}', '-n', f'{nodename}']
    argnum              = 11

    # sys_argv            = ['d:/scripts/GIT/KMD-AEVEN-TOOLS/scripts/launch_and_misc_awx_functions.py','-n', f'{nodename}', '--disable']
    # argnum              = 4

if len(sys_argv) > 2:
    if bool(re.search(r'^(-h|-?|--?|--help)$', sys_argv[1], re.IGNORECASE)): f_help_error()
    if len(sys_argv) < 2: f_help_error()
    else:
        for i, arg in enumerate(sys_argv):
            checkArg = str(arg.strip())
            if re.search(r'-n$', checkArg, re.IGNORECASE): argnum = i; argnum += 1; nodename = sys_argv[argnum].lower()
            if re.search(r'-t$', checkArg, re.IGNORECASE): argnum = i; argnum += 1; launch_template_name = sys_argv[argnum]; LAUNCH_TEMPLATE = True
            if re.search(r'-u$', checkArg, re.IGNORECASE): argnum = i; argnum += 1; twusr = sys_argv[argnum]
            if re.search(r'-p$', checkArg, re.IGNORECASE): argnum = i; argnum += 1; twpwd = sys_argv[argnum]
            if re.search(r'-d$', checkArg, re.IGNORECASE): argnum = i; debug = True
else:
    f_help_error()
#endregion
#region init
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
#  init
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# Debug for control flow
f_log(f'template_name', f'{template_name}', debug)
cred_names          = []
credentials_ids     = []
credential_names    = []
template_id         = []
payload             = {}
CONTINUE            = True
RC                  = 0
hostsfound          = False
project             = 'KMD-AEVEN-TOOLS'
scriptname          = sys.argv[0]
scriptname          = scriptname.replace('\\','/').strip()
scriptname          = scriptname.split('/')[-1]
scriptname          = scriptname.split('.')[0]
start               = time.time()
now                 = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
Logdate_long        = datetime.now().strftime('%Y-%m-%d_%H-%M-%S_%f')
jsondir             = f'D:/scripts/GIT/{project}/archive/json_files/'
if not os.path.isdir(f'{jsondir}'): os.mkdir(f'{jsondir}')
logdir              = f'D:/scripts/GIT/{project}/logs'
if not os.path.isdir(f'{logdir}'): os.mkdir(f'{logdir}')
logfile             = f'{logdir}/{scriptname}_{Logdate_long}.log'
if os.path.isfile(logfile): os.remove(logfile)
f_set_logging(logfile,debug)

stepName = 'begin'
f_log(f'{stepName}','',debug)
f_log(f'sys_argv',f'{sys_argv}',debug)
f_log(f'LAUNCH_TEMPLATE',f'{LAUNCH_TEMPLATE}',debug)
f_log(f'template_name',f'{template_name}',debug)
f_log(f'isRunningLocally',f'{isRunningLocally}',debug)
f_log(f'step_hostname',f'{awx_hostname}',debug)
f_log(f'nodename',f'{nodename}',debug)
f_log(f'launch_template_name',f'{launch_template_name}',debug)
f_log(f'twusr',f'{twusr}',debug)
f_log(f'tower_host',f'{tower_host}',debug)
f_log(f'tower_url',f'{tower_url}',debug)
f_log(f'jsondir',f'{jsondir}',debug)
f_log(f'logdir',f'{logdir}',debug)
f_log(f'logfile',f'{logfile}',debug)
f_log(f'scriptname',f'{scriptname}',debug)
f_log(f'project',f'{project}',debug)
f_log(f'debug',f'{debug}',debug)
#endregion
#region get_hostname
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# get_hostname. To be used for all functions
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if CONTINUE:
    try:
        inv_name = None
        stepName = f'step_hostname'
        f_log(f'{stepName}','',debug)
        acceptedInv = ['kmn_inventory','kmw_inventory','eng_inventory','eng_hem']
        checkCaps = [f'{nodename.lower()}',f'{nodename.upper()}']
        for capsOrNot in checkCaps:
            capsOrNot = capsOrNot.strip()

            request = f'hosts/?name={capsOrNot}'
            result,RC = f_requests(request,twusr,twpwd,payload,debug)

            if RC > 0: raise Exception(f'step {stepName} failed'); f_end(RC)
            if result['count'] == 0: continue

            hostsfound = True
            if isRunningLocally: f_dump_and_write(result,stepName,debug)
            host_disIDs = []
            host_disNames = []
            datalist = []
            datalist = result['results']
            for row in datalist:
                checkName           = row['summary_fields']['inventory']['name']
                host_disIDs.append(row['id'])
                host_disNames.append(row['name'] )

                if checkName in acceptedInv:
                    inv_name        = row['summary_fields']['inventory']['name']
                    inventory_id    = row['summary_fields']['inventory']['id']
                    organization_id = row['summary_fields']['inventory']['organization_id']
                    host_id         = row['id']
                    nodename        = row['name']

                else:
                    continue
        if hostsfound:
            f_log(f'inventory_id',f'{inventory_id}',debug)
            f_log(f'inv_name',f'{inv_name}',debug)
            f_log(f'host_id',f'{host_id}',debug)
            f_log(f'nodename',f'{nodename}',debug)
        else:
            raise Exception(f'step {stepName} failed no hosts found'); f_end(RC)

    except Exception as e:
        if debug: logging.error(e)
        RC = 12
        f_end(RC)
#endregion
#region get_allGroupsWithHost
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# get_allGroupsWithHost
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if CONTINUE:
    try:
        stepName = f'step_allGroupsWithHost'
        f_log(f'{stepName}','',debug)

        request = f'hosts/{host_id}/all_groups/?page_size=all'
        result,RC = f_requests(request,twusr,twpwd,payload,debug)

        if RC > 0: raise Exception(f'step {stepName} failed'); f_end(RC)
        if isRunningLocally: f_dump_and_write(result,stepName,debug)
        allGroupsWithHost = result['results']
        cred_names = []
        if isinstance(allGroupsWithHost, (list)):
            for index, group in enumerate(allGroupsWithHost):
                for key, value in group.items():
                    if key == 'variables' and isinstance(value, str) and len(value) > 0:
                        variables_dict = yaml.safe_load(value)
                        if isinstance(variables_dict, dict):
                            os_cred = variables_dict.get('os_credential')
                            jumphost_cred = variables_dict.get('jumphost_credential')

                            if os_cred:
                                f_log(f'Found os_credential', f'{os_cred}', debug)
                                cred_names.append(os_cred)

                            if jumphost_cred:
                                f_log(f'Found jumphost credential', f'{jumphost_cred}', debug)
                                cred_names.append(jumphost_cred)

        unique_cred_name_list = list(set(cred_names))
    except Exception as e:
        if debug: logging.error(e)
        f_log(f'exception:',f'{e}',debug)

        RC = 12
        f_end(RC)
#endregion
#region get_credentials_ids
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# get_credentials_ids
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if CONTINUE:
    try:
        stepName = f'step_credentials_ids'
        f_log(f'{stepName}','',debug)
        credentials_ids = []
        credential_names = []
        for cred_name in unique_cred_name_list:

            request = f'credentials/?name={cred_name}'
            result,RC = f_requests(request,twusr,twpwd,payload,debug)

            if RC > 0: raise Exception(f'step {stepName} failed'); f_end(RC)
            if isRunningLocally: f_dump_and_write(result,stepName,debug)

            credential_count = result['count']
            if credential_count == 0:
                if debug: text = "{:25}: {:}".format(f'credential_name: {cred_name}',f'is not found!'); logging.warning(text)
            else:
                result = result['results']
                credential_id = result[0]['id']
                credential_name = result[0]['name']
                f_log(f'cred_name',f'{cred_name}',debug)
                f_log(f'credential_name',f'{credential_name}',debug)
                f_log(f'credential_id',f'{credential_id}',debug)
                credentials_ids.append(credential_id)
                credential_names.append(credential_name)
        # ----------------------------------------------------------------------------------------------------------------------------------------------------------
        # added to be able to use depot
        # ----------------------------------------------------------------------------------------------------------------------------------------------------------
        if re.search(r"^kmn_.*", inv_name, re.IGNORECASE):
            kmn_cred_tower_and_sfs = 33
            credential_names.append('kmn_cred_tower_and_sfs')

        elif re.search(r"^kmw_.*", inv_name, re.IGNORECASE):
            kmn_cred_tower_and_sfs = 33
            credential_names.append('kmw_cred_tower_and_sfs')

        elif re.search(r"^eng_.*", inv_name, re.IGNORECASE):
            credential_names.append('eng_cred_ansible_tower')
            credentials_ids.append(117)

        # ----------------------------------------------------------------------------------------------------------------------------------------------------------
        unique_credential_names = list(set(credential_names))
        f_log(f'unique_credential_names',f'{unique_credential_names}',debug)
        unique_credentials_ids = list(set(credentials_ids))
        f_log(f'unique_credentials_ids',f'{unique_credentials_ids}',debug)
    except Exception as e:
        if debug: logging.error(e)
        RC = 12
        f_end(RC)
#endregion
#region get_jobTemplateByName
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# get_jobTemplateByName
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if CONTINUE:
    try:
        stepName = f'step_jobTemplateByName'
        f_log(f'{stepName}','---------------------------------------------------------------------------------------------------------------------------------------------',debug)

        request = f'job_templates/?name={launch_template_name}'
        result,RC = f_requests(request,twusr,twpwd,payload,debug)

        if RC > 0: raise Exception(f'step {stepName} failed')
        if isRunningLocally: f_dump_and_write(result,stepName,debug)
        template_count = result['count']
        if template_count != 1:
            raise Exception(f'step get jobTemplateByName by launch_template_name: Requested job_template {launch_template_name} is not found')
        else:
            template_id = result['results'][0]['id']
            f_log(f'template_id',f'{template_id}',debug)

    except Exception as e:
        if debug: logging.error(e)
        RC = 12
        exit(RC)
#endregion
#region launch_job_template
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# launch_job_template
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if CONTINUE and LAUNCH_TEMPLATE:
    try:
        stepName = f'step_launch_job_template'
        f_log(f'{stepName}','',debug)
        f_log(f'credentials_ids',f'{credentials_ids}',debug)
        payload = {
            "organization": organization_id,
            "inventory": inventory_id,
            "credentials": credentials_ids,
            "extra_vars": { "nodename": f"{nodename}" }
        }
        request = f'job_templates/{template_id}/launch/'
        result,RC = f_requests(request,twusr,twpwd,payload,debug)
        f_log(f'result',f'{result}',debug)
        jobid = result['id']
        f_log(f'jobid',f'{jobid}',debug)

        if RC > 0: raise Exception(f'step {stepName} failed'); f_end(RC)
        if isRunningLocally:
            f_dump_and_write(result,stepName,debug)
    except Exception as e:
        if debug: logging.error(e)
        RC = 12
        f_end(RC)
#endregion
print(f'{payload}')
exit(RC)