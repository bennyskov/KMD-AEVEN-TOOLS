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
from awxkit import *
from awxkit.api.pages import Api
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
import warnings
import re
warnings.filterwarnings('ignore', 'This pattern is interpreted as a regular expression, and has match groups.')
global debug
debug = bool
debug = True
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
# f_dump_and_write(result,useRestAPI,stepName,debug)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_dump_and_write(result,useRestAPI,stepName,debug):
    if useRestAPI:
        job_json_file = f'{jsondir}/{stepName}_useRestAPI.json'
    else:
        job_json_file = f'{jsondir}/{stepName}_useAwxAPI.json'

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
        str(hostname),  # Convert hostname to string explicitly
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
#endregion
#region f_requests
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
            response            = requests.get(url, auth=(twusr, twpwd), verify=False, timeout=1440)
        else:
            response            = requests.post(url, auth=(twusr, twpwd), json=payload, verify=False, timeout=1440)
        response.raise_for_status()
        if response.status_code == 200 or response.status_code == 201:
            result_decoded      = response.content.decode('utf-8')
            result_loaded       = f_load_data(result_decoded)
            result_dumps        = json.dumps(result_loaded, indent=5)
            result              = json.loads(result_dumps)
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
        # f_log(f'cmdexec_result type',f'{type(cmdexec_result)}',debug)
        # f_log(f'cmdexec_result     ',f'{cmdexec_result}',debug)
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
            f_log(f'result type',f'{type(cmdexec_result.stdout)}',debug)
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
    if debug: logging.info('use: python get_cred_for_host.py -t {{ launch_template_name }} -n {{ hostname }} -s {{ change }} -u {{ twusr }} -p {{ twpwd }}')
    exit(12)
#endregion
#region read_input_sys_argv
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# end functions
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# global launch_template_name, isRunningLocally, hostname,sys_argv, twusr, twpwd, tower_host, tower_url
tower_host          = 'https://ansible-tower-web-svc-tower.apps.kmdcacf001.adminkmd.local'
tower_url           = f'{tower_host}/api/v2/'
hostname            = socket.gethostname().lower()
sys_argv            = sys.argv
isRunningLocally    = False
useRestAPI          = True
if re.search(r".*kmdwinitm001.*", hostname, re.IGNORECASE): isRunningLocally = True
if re.search(r"^automation-job.*", hostname, re.IGNORECASE): isRunningLocally = False
if isRunningLocally:
    change              = "CHG000000"
    twusr               = 'functional_id_001'
    twpwd               = 'm9AHKuXYa*MeZZWLsHqB' # se i 1password
    launch_template_name= 'kmn_jobtemplate_de-tooling_disable_SCCM_windows'
    # launch_template_name= 'kmn_jobtemplate_de-tooling_REinstall_ITM_windows' # not part of kmn_jobtemplate_de-tooling_begin
    # launch_template_name= 'kmn_jobtemplate_de-tooling_cleanup_CACF_ansible'
    # launch_template_name= 'kmn_jobtemplate_de-tooling_servercheck_windows'
    # launch_template_name= 'kmn_jobtemplate_de-tooling_set_maintenancemode'
    # launch_template_name= 'kmn_jobtemplate_de-tooling_UNinstall_ITM_windows'
    # launch_template_name= 'kmn_jobtemplate_de-tooling_UNinstall_ITM_linux'
    sys_argv            = ['d:/scripts/GIT/KMD-AEVEN-TOOLS/scripts/get_credentials_and_launch_template.py', '-t', f'{launch_template_name}', '-n', f'{hostname}', '-s', f'{change}', '-u', f'{twusr}', '-p', f'{twpwd}']
    argnum              = 11
if len(sys_argv) > 1:
    if bool(re.search(r'^(-h|-?|--?|--help)$', sys_argv[1], re.IGNORECASE)): f_help_error()
    if len(sys_argv) < 4: f_help_error()
    else:
        for i, arg in enumerate(sys_argv):
            checkArg = str(arg.strip())
            if re.search(r'-n$', checkArg, re.IGNORECASE): argnum = i; argnum += 1; hostname = sys_argv[argnum].lower()
            if re.search(r'-s$', checkArg, re.IGNORECASE): argnum = i; argnum += 1; change = sys_argv[argnum]
            if re.search(r'-t$', checkArg, re.IGNORECASE): argnum = i; argnum += 1; launch_template_name = sys_argv[argnum]
else:
    f_help_error()
#endregion
#region init}
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
#  init
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
global hostnames, project
global logfile, scriptname, payload
global now, Logdate_long, jsondir, logdir
global cred_names, credential_ids, credential_names, template_id, CONTINUE, RC

# hostnames           = ['udv19bfs01, udv19db2aws01, udv19avs01, udv19elk02, udv19cis01, udv19tdm03, udv19bfs02, udv19tdm02, udv19tdg01, udv19elk01, udv19tools, udv19gws01, udv19app01, udv19elk03, kmddbs2136']
hostnames           = ['udv19bfs01']
cred_names          = []
credential_ids      = []
credential_names    = []
template_id         = []
payload             = []
CONTINUE            = True
RC                  = 0
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
f_log(f'isRunningLocally',f'{isRunningLocally}',debug)
f_log(f'useRestAPI',f'{useRestAPI}',debug)
f_log(f'hostname',f'{hostname}',debug)
f_log(f'change',f'{change}',debug)
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
#region awx_login
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# awx config settingss. awx is reading these
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if CONTINUE:
    if not useRestAPI:
        stepName = 'awx_login'
        f_log(f'{stepName}','',debug)
        os.environ['TOWER_HOST']        = f'{tower_host}'
        os.environ['TOWER_USERNAME']    = f'{twusr}'
        os.environ['TOWER_PASSWORD']    = f'{twpwd}'
        os.environ['TOWER_VERIFY_SSL']  = 'False'
        os.environ['TOWER_FORMAT']      = 'json'

        try:
            cmdexec = ['awx', 'me', '--conf.format', 'yaml', '--conf.insecure']
            result, RC = f_cmdexec(cmdexec, debug)
            result = result['results'][0]
            # f_log('me', f'{result}', debug)
            # f_log('RC', f'{RC}', debug)
            if isRunningLocally: f_dump_and_write(result,useRestAPI,stepName,debug)
            if RC == 0 and f'username' in result:
                f_log('AWX Auth Status', 'Already logged in', debug)
                twtok = os.environ.get('TOWER_OAUTH_TOKEN', '')
                f_log('Current token', f'{twtok[:10]}...' if twtok else 'None', debug)
            else:
                raise Exception("Not authenticated"); f_end(RC)
        except Exception as e:
            f_log('AWX Auth Status', f'Login required: {str(e)}', debug)

            # Perform login to get new token
            cmdexec = ['awx', 'login',
                        '--conf.host', tower_host,
                        '--conf.username', twusr,
                        '--conf.password', twpwd,
                        '--conf.insecure',
                        '--conf.format', 'yaml']

            result, RC = f_cmdexec(cmdexec, debug)

            if RC == 0 and 'token' in result:
                twtok = result['token']
                os.environ['TOWER_OAUTH_TOKEN'] = twtok
                f_log('New token obtained', f'{twtok[:10]}...', debug)

                # Configure AWX client to use the token
                cmdexec = ['awx', 'config', 'oauth_token', f'{twtok}']
                result, RC = f_cmdexec(cmdexec, debug)
                # f_log('token config', f'{result}', debug)

                cmdexec = ['awx', 'config', 'use_token', 'True']
                result, RC = f_cmdexec(cmdexec, debug)
                # f_log('token usage config', f'{result}', debug)

                # Verify login was successful
                cmdexec = ['awx', 'me', '--conf.format', 'yaml', '--conf.insecure']
                result, RC = f_cmdexec(cmdexec, debug)
                result = result['results'][0]
                if RC == 0 and 'username' in result:
                    f_log('AWX Auth Verification', 'Successfully authenticated', debug)
                else:
                    f_log('AWX Auth Verification', 'Authentication still failing after login attempt', debug)
            else:
                f_log('Login failed', f'RC: {RC}, Result: {result}', debug)
                raise Exception("Failed to authenticate with AWX"); f_end(RC)
#endregion
#region awx_hostname
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# get_hostname
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if CONTINUE:
    try:
        inv_name = None
        stepName = 'awx_hostname'
        f_log(f'{stepName}','',debug)
        acceptedInv = ['kmn_inventory','kmw_inventory','eng_inventory','enw_inventory']
        hostnames = [f'{hostname.upper()}',f'{hostname.lower()}']
        for hostname in hostnames:
            hostname = hostname.strip()
            if useRestAPI:
                request = f'hosts/?name={hostname}'
                result,RC = f_requests(request,twusr,twpwd,payload,debug)
            else:
                cmdexec = ['awx', 'host', 'list', '--name', f'{hostname}']
                result,RC = f_cmdexec(cmdexec,debug)
            if RC > 0: continue
            if isRunningLocally: f_dump_and_write(result,useRestAPI,stepName,debug)
            datalist = []
            datalist = result['results']
            for row in datalist:
                checkName = row['summary_fields']['inventory']['name']
                if checkName in acceptedInv:
                    inv_name     = row['summary_fields']['inventory']['name']
                    inv_id       = row['summary_fields']['inventory']['id']
                    host_id     = row['id']
                    hostname    = row['name']
                else:
                    continue

        f_log(f'inv_id',f'{inv_id}',debug)
        f_log(f'inv_name',f'{inv_name}',debug)
        f_log(f'host_id',f'{host_id}',debug)
        f_log(f'hostname',f'{hostname}',debug)

    except Exception as e:
        if debug: logging.error(e)
        RC = 12
        f_end(RC)
#endregion
#region awx_allGroupsWithHost
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# awx_allGroupsWithHost
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if CONTINUE:
    try:
        stepName = 'awx_allGroupsWithHost'
        f_log(f'{stepName}','',debug)
        if useRestAPI:
            request = f'hosts/{host_id}/all_groups/?page_size=all'
            result,RC = f_requests(request,twusr,twpwd,payload,debug)
        else:
            cmdexec = ['awx','groups','list','--host',f'{host_id}','--all-pages']
            # cmdexec = ['awx','host','get',f'{host_id}','--query','all_groups','--all-pages']
            result,RC = f_cmdexec(cmdexec,debug)

        if RC > 0: raise Exception(f'step {stepName} failed'); f_end(RC)
        if isRunningLocally: f_dump_and_write(result,useRestAPI,stepName,debug)

        if useRestAPI:
            allGroupsWithHost = result['results']                               # REST way
        else:
            allGroupsWithHost = result['summary_fields']['groups']['results']   # AWX way
        allGroups_names = []
        if isinstance(allGroupsWithHost, (list)):
            for index, group in enumerate(allGroupsWithHost):
                for key, value in group.items():
                    if key == 'name': allGroups_names.append(value)
        unique_group_list = list(set(allGroups_names))
        f_log(f'unique_group_list',f'{unique_group_list}',debug)
    except Exception as e:
        if debug: logging.error(e)
        f_log(f'exception:',f'{e}',debug)

        RC = 12
        f_end(RC)
#endregion
#region avx_credNameFromGroup
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# avx_credNameFromGroup
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if CONTINUE:
    try:
        stepName = 'avx_credNameFromGroup'
        f_log(f'{stepName}','',debug)
        for grp_cred in unique_group_list:
            if useRestAPI:
                request = f'groups/?name={grp_cred}'
                result,RC = f_requests(request,twusr,twpwd,payload,debug)
            else:
                cmdexec = ['awx', 'group', 'list', '--name', f'{grp_cred}', '--all-pages']
                result,RC = f_cmdexec(cmdexec,debug)
            if RC > 0: raise Exception(f'step {stepName} failed'); f_end(RC)
            if isRunningLocally: f_dump_and_write(result,useRestAPI,stepName,debug)
            grp_cred_count = result['count']
            if grp_cred_count <= 1:
                raise Exception(f'step get credNameFromGroup by {grp_cred}: Requested job_template {launch_template_name} is not found'); f_end(RC)
            else:
                result = result['results']
                if isinstance(result, (list)):
                    for index, group_element in enumerate(result):
                        for key, value in group_element.items():
                            if key == 'variables':
                                data = f_load_data(value)
                                if isinstance(data, (dict)):
                                    for variables_key, variables_value in data.items():
                                        if isinstance(variables_value, (str)):
                                            if bool(re.search('_cred', variables_key, re.IGNORECASE)) or bool(re.search('_cred', variables_value, re.IGNORECASE)):
                                                f_log(f'{variables_key}',f'{variables_value}',debug)
                                                cred_names.append(variables_value)
            unique_cred_name_list = list(set(cred_names))
            f_log(f'unique_cred_name_list',f'{unique_cred_name_list}',debug)
    except Exception as e:
        if debug: logging.error(e)
        RC = 12
        f_end(RC)
#endregion
#region awx_credential_ids
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# awx_credential_ids
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if CONTINUE:
    try:
        stepName = 'awx_credential_ids'
        f_log(f'{stepName}','',debug)
        credential_ids = []
        credential_names = []
        for cred_name in unique_cred_name_list:
            if useRestAPI:
                request = f'credentials/?name={cred_name}'
                result,RC = f_requests(request,twusr,twpwd,payload,debug)
            else:
                cmdexec = ['awx', 'credential', 'list', '--name', f'{cred_name}', '--all-pages']
                result,RC = f_cmdexec(cmdexec,debug)

            if RC > 0: raise Exception(f'step {stepName} failed'); f_end(RC)
            if isRunningLocally: f_dump_and_write(result,useRestAPI,stepName,debug)

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
                credential_ids.append(credential_id)
                credential_names.append(credential_name)
        # ----------------------------------------------------------------------------------------------------------------------------------------------------------
        # added to be able to use depot
        # ----------------------------------------------------------------------------------------------------------------------------------------------------------
        kmn_cred_tower_and_sfs = 33
        credential_names.append('kmn_cred_tower_and_sfs')
        credential_ids.append(33)
        # ----------------------------------------------------------------------------------------------------------------------------------------------------------
        unique_credential_names = list(set(credential_names))
        f_log(f'unique_credential_names',f'{unique_credential_names}',debug)
        unique_credential_ids = list(set(credential_ids))
        f_log(f'unique_credential_ids',f'{unique_credential_ids}',debug)
    except Exception as e:
        if debug: logging.error(e)
        RC = 12
        f_end(RC)
#endregion
#region get_jobTemplateByName
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# get_jobTemplateByName
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
try:
    stepName = 'get_jobTemplateByName'
    f_log(f'{stepName}','---------------------------------------------------------------------------------------------------------------------------------------------',debug)
    if useRestAPI:
        request = f'job_templates/?name={launch_template_name}'
        result,RC = f_requests(request,twusr,twpwd,payload,debug)
    else:
        cmdexec = ['awx', 'job_templates', 'list', '--name', f'{launch_template_name}']
        result,RC = f_cmdexec(cmdexec,debug)

    if RC > 0: raise Exception(f'step {stepName} failed')
    if isRunningLocally: f_dump_and_write(result,useRestAPI,stepName,debug)
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
if CONTINUE:
    try:
        stepName = 'launch_job_template'
        f_log(f'{stepName}','',debug)
        credential_ids = ','.join(map(str, unique_credential_ids))
        f_log(f'unique_credential_ids',f'{unique_credential_ids}',debug)
        if useRestAPI:
            payload = {
                "inventory": inv_id,
                "credentials": unique_credential_ids,
                "extra_vars": {
                    "nodename": hostname,
                    "change": change
                }
            }
            request = f'job_templates/{template_id}/launch/'
            f_log(f'request',f'{request}',debug)
            result,RC = f_requests(request,twusr,twpwd,payload,debug)
            jobid = result['id']
            f_log(f'jobid',f'{jobid}',debug)
        else:
            job_template    = f'--name {launch_template_name} '
            credential      = f'--credentials {credential_ids} '
            inventory       = f'--inventory {inv_id} '
            extra_vars = {
                'hostname': f'{hostname}',
                'change': f'{change}',
            }
            extra_vars  = f'--extra_vars \"{extra_vars}\"'
            cmdexec = f"awx job_templates launch {launch_template_name} {credential} {inventory} {extra_vars}"
            f_log(f'cmdexec',f'{cmdexec}',debug)
            result,RC = f_cmdexec(cmdexec,debug)
            jobid = result['id']
            f_log(f'jobid',f'{jobid}',debug)

        if RC > 0: raise Exception(f'step {stepName} failed'); f_end(RC)
        if isRunningLocally:
            f_dump_and_write(result,useRestAPI,stepName,debug)
    except Exception as e:
        if debug: logging.error(e)
        RC = 12
        f_end(RC)

f_end(RC)
#endregionq