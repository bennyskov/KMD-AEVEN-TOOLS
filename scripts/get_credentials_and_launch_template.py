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
twusr           = '' # coming from testing or from parsed args within playbook
twpwd           = '' # coming from testing or from parsed args within playbook
debug           = bool
debug           = True
useRestAPI      = False #    True: REST API or False: awx
TESTING         = False
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if TESTING:
    print(f'TESTING={TESTING}')
    print(f'useRestAPI={useRestAPI}')
    twusr               = 'functional_id_001'
    twpwd               = 'm9AHKuXYa*MeZZWLsHqB' # se i 1password
    req_hostname        = 'dfkdbs302d                 '
    req_servicenow_id   = 'CHG0000ZZZ'
    # launch_template_name= 'eng_jobtemplate_decom_start'
    launch_template_name= 'kmn_windows_remote_aeven_SA_redirect'
    sys_argv            = ['d:/scripts/GIT/eng_automation_other/scripts/scripts/get_credentials_and_launch_template.py.py', '-t', f'{launch_template_name}', '-n', f'{req_hostname}', '-s', f'{req_servicenow_id}', '-u', f'{twusr}', '-p', f'{twpwd}']
    print(f'sys_argv={sys_argv}')
    argnum              = 11
sys_argv        = sys.argv
scriptname      = sys.argv[0]
scriptname      = scriptname.replace('\\','/').strip()
scriptname      = scriptname.split('/')[-1]
scriptname      = scriptname.split('.')[0]
hostname        = socket.gethostname().lower()
RC              = 0
cred_ids        = []
cred_names      = []
payload         = []
now             = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
tower_host      = 'https://ansible-tower-web-svc-tower.apps.kmdcacf001.adminkmd.local'
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# awx config settingss. awx is reading these
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
os.environ['TOWER_HOST']        = f'{tower_host}'
os.environ['TOWER_USERNAME']    = f'{twusr}'
os.environ['TOWER_PASSWORD']    = f'{twpwd}'
os.environ['TOWER_VERIFY_SSL']  = 'False'
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# functions begin
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_dump_and_write(result,useRestAPI,stepName,debug):
    if debug:
        if useRestAPI:
            job_json_file = f'D:/scripts/GIT/eng_automation_other/archive/json_files/{stepName}_useRestAPI.json'
        else:
            job_json_file = f'D:/scripts/GIT/eng_automation_other/archive/json_files/{stepName}_useAwxAPI.json'

        result_dumps = json.dumps(result, indent=5)
        f_log(f'result_dumps',f'{result_dumps}',debug)

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
def f_set_logging():
    # now = datetime.now().strftime('%Y %b %d %H:%M:%S')
    # text = "{:25} {:20} {:8} {:30} {}".format(now,'%(levelname)s','%(filename)s','%(message)s')
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
            }
        },
        'loggers' : {
            '__main__': {
                'handlers': ['console'],
                'level': 'INFO',
                'propagate': False
            }
        },
        'root' : {
            'level': 'INFO',
            'handlers': ['console'],
        }
    }
    logging.config.dictConfig(logging_schema)
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
            response                = requests.get(url, auth=(twusr, twpwd), verify=False, imeout=300)
        else:
            response                = requests.post(url, auth=(twusr, twpwd), json=payload, verify=False, imeout=300)
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
        f_log(f'cmdexec_result type',f'{type(cmdexec_result)}',debug)
        f_log(f'cmdexec_result     ',f'{cmdexec_result}',debug)
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
def f_help_error():
    if debug: logging.info('use: python get_cred_for_host.py -t {{ launch_template_name }} -n {{ req_hostname }} -s {{ req_servicenow_id }} -u {{ twusr }} -p {{ twpwd }}')
    exit(12)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# end functions
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# Begin
#----------------------------------------------------------------------------------------------------------------------------------------------------------
f_set_logging()
f_log(f'Begin','---------------------------------------------------------------------------------------------------------------------------------------------',debug)
f_log(f'sys_argv',f'{sys_argv}',debug)
if not TESTING:
    if len(sys_argv) > 1:
        if bool(re.search(r'^(-h|-?|--?|--help)$', sys_argv[1], re.IGNORECASE)): f_help_error()
        if len(sys_argv) < 4: f_help_error()
        else:
            for i, arg in enumerate(sys_argv):
                checkArg = str(arg.strip())
                if re.search(r'-n$', checkArg, re.IGNORECASE): argnum = i; argnum += 1; req_hostname = sys_argv[argnum].lower()
                if re.search(r'-s$', checkArg, re.IGNORECASE): argnum = i; argnum += 1; req_servicenow_id = sys_argv[argnum]
                if re.search(r'-t$', checkArg, re.IGNORECASE): argnum = i; argnum += 1; launch_template_name = sys_argv[argnum]
    else:
        f_help_error()
#----------------------------------------------------------------------------------------------------------------------------------------------------------
f_log(f'req_hostname',f'{req_hostname}',debug)
f_log(f'req_servicenow_id',f'{req_servicenow_id}',debug)
f_log(f'launch_template_name',f'{launch_template_name}',debug)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# get_hostname
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
stepName = 'get_hostname'
f_log(f'{stepName}','---------------------------------------------------------------------------------------------------------------------------------------------',debug)
try:
    chosen = ''
    hostnames = [f'{req_hostname.upper()}',f'{req_hostname.lower()}']
    for req_hostname in hostnames:
        req_hostname = req_hostname.strip()
        if useRestAPI:
            request = f'hosts/?name={req_hostname}'
            result,RC = f_requests(request,twusr,twpwd,payload,debug)
        else:
            cmdexec = ['awx', 'host', 'list', '--name', f'{req_hostname}']
            result,RC = f_cmdexec(cmdexec,debug)

        if RC > 0: raise Exception(f'step {stepName} failed')
        if TESTING: f_dump_and_write(result,useRestAPI,stepName,debug)

        if result['count'] > 0:
            chosen = req_hostname

    if chosen == '':
        raise Exception(f'Hostname {req_hostname} not found')
    else:
        req_hostname = chosen

    f_log(f'req_hostname',f'{req_hostname}',debug)

except Exception as e:
    if debug: logging.error(e)
    RC = 12
    exit(RC)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# get_jobTemplateByName
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
stepName = 'get_jobTemplateByName'
f_log(f'{stepName}','---------------------------------------------------------------------------------------------------------------------------------------------',debug)
try:
    if useRestAPI:
        request = f'job_templates/?name={launch_template_name}'
        result,RC = f_requests(request,twusr,twpwd,payload,debug)
    else:
        cmdexec = ['awx', 'job_templates', 'list', '--name', f'{launch_template_name}']
        result,RC = f_cmdexec(cmdexec,debug)

    if RC > 0: raise Exception(f'step {stepName} failed')
    if TESTING: f_dump_and_write(result,useRestAPI,stepName,debug)

    template_count = result['count']
    if template_count != 1:
        raise Exception(f'step get jobTemplateByName by launch_template_name: Requested job_template {launch_template_name} is not found')
    else:
        result                  = result['results'][0]
        template_id             = result['id']
        launch_template_name       = result['name']
        template_org_name       = result['summary_fields']['organization']['name']
        template_org_id         = result['summary_fields']['organization']['id']
        template_inv_name       = result['summary_fields']['inventory']['name']
        template_inv_id         = result['summary_fields']['inventory']['id']
        template_link_to_cred   = result['related']['credentials']
        template_cred           = result['summary_fields']['credentials']
        f_log(f'template_id',f'{template_id}',debug)
        f_log(f'launch_template_name',f'{launch_template_name}',debug)
        f_log(f'template_org_name',f'{template_org_name}',debug)
        f_log(f'template_org_id',f'{template_org_id}',debug)
        f_log(f'template_inv_name',f'{template_inv_name}',debug)
        f_log(f'template_inv_id',f'{template_inv_id}',debug)
        f_log(f'template_link_to_cred',f'{template_link_to_cred}',debug)
        f_log(f'type template_cred',f'{type(template_cred)}',debug)
        # f_log(f'dump template_cred',f'\n{json.template_inv_id(template_cred, indent=4)}',debug)
        if isinstance(template_cred, (list)):
            for index, cred in enumerate(template_cred):
                for key, value in cred.items():
                    if key == 'id': cred_ids.append(value)
                    if key == 'name': cred_names.append(value)
        for index, item in enumerate(cred_ids):
            f_log(f'cred_ids {index}',f'{item}',debug)
        for index, item in enumerate(cred_names):
            f_log(f'cred_names {index}',f'{item}',debug)
except Exception as e:
    if debug: logging.error(e)
    RC = 12
    exit(RC)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# get_jobTemplatesById
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
stepName = 'get_jobTemplatesById'
f_log(f'{stepName}','---------------------------------------------------------------------------------------------------------------------------------------------',debug)
try:
    if useRestAPI:
        request = f'job_templates/{template_id}'
        result,RC = f_requests(request,twusr,twpwd,payload,debug)
    else:
        cmdexec = ['awx', 'job_template', 'get', f'{template_id}']
        result,RC = f_cmdexec(cmdexec,debug)

    if RC > 0: raise Exception(f'step {stepName} failed')
    if TESTING: f_dump_and_write(result,useRestAPI,stepName,debug)

except Exception as e:
    if debug: logging.error(e)
    RC = 12
    exit(RC)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# get_inventoryByName
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
stepName = 'get_inventoryByName'
f_log(f'{stepName}','---------------------------------------------------------------------------------------------------------------------------------------------',debug)
try:
    if useRestAPI:
        request = f'inventories/?name={template_inv_name}'
        result,RC = f_requests(request,twusr,twpwd,payload,debug)
    else:
        cmdexec = ['awx', 'inventory', 'list', '--name', f'{template_inv_name}']
        result,RC = f_cmdexec(cmdexec,debug)

    if RC > 0: raise Exception(f'step {stepName} failed')
    if TESTING: f_dump_and_write(result,useRestAPI,stepName,debug)

    inv_count = result['count']
    if inv_count == 0:
        raise Exception(f'step get_inventoryByName {template_inv_name} is not found')
    else:
        template_inv_id         = result['results'][0]['id']
        template_inv_name       = result['results'][0]['name']
        template_inv_variables  = result['results'][0]['variables']

        result_loaded           = load_data(template_inv_variables)
        inv_cred_name           = result_loaded.get('cyberark_credential')
        cred_names.append(inv_cred_name)

        f_log(f'template_inv_id',f'{template_inv_id}',debug)
        f_log(f'template_inv_name',f'{template_inv_name}',debug)
        f_log(f'inv_cred_name',f'{inv_cred_name}',debug)

    for index, item in enumerate(cred_names):
        f_log(f'cred_names {index}',f'{item}',debug)

except Exception as e:
    if debug: logging.error(e)
    RC = 12
    exit(RC)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# get_allHostsByInvName
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
stepName = 'get_allHostsByInvName'
f_log(f'{stepName}','---------------------------------------------------------------------------------------------------------------------------------------------',debug)
try:
    if useRestAPI:
        request = f'hosts/?inventory={template_inv_id}'
        result,RC = f_requests(request,twusr,twpwd,payload,debug)
    else:
        cmdexec = ['awx', 'host', 'list', '--inventory', f'{template_inv_id}', '--all-pages']
        result,RC = f_cmdexec(cmdexec,debug)

    if RC > 0: raise Exception(f'step {stepName} failed')
    if TESTING: f_dump_and_write(result,useRestAPI,stepName,debug)

except Exception as e:
    if debug: logging.error(e)
    RC = 12
    exit(RC)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# get_singleHostGetGroups
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
stepName = 'get_singleHostGetGroups'
f_log(f'{stepName}','---------------------------------------------------------------------------------------------------------------------------------------------',debug)
try:
    allGroups_names = []
    if useRestAPI:
        request = f'hosts/?name={req_hostname}&inventory={template_inv_id}'
        result,RC = f_requests(request,twusr,twpwd,payload,debug)
    else:
        cmdexec = ['awx', 'host', 'list', '--name', f'{req_hostname}', '--inventory', f'{template_inv_id}', '--all-pages']
        result,RC = f_cmdexec(cmdexec,debug)

    if RC > 0: raise Exception(f'step {stepName} failed')
    if TESTING: f_dump_and_write(result,useRestAPI,stepName,debug)

    singleHostGetGroups_count = result['count']
    if singleHostGetGroups_count != 1:
         raise Exception(f'step get singleHostGetGroups failed. count={singleHostGetGroups_count}. Is host {req_hostname} part of inventory {template_inv_id} / {template_inv_name} ')
    else:
        result = result['results'][0]
        host_id = result['id']
        singleHostGetGroups_names = result['summary_fields']['groups']['results']
        f_log(f'singleHostGetGroups_names',f'{singleHostGetGroups_names}',debug)
        if isinstance(singleHostGetGroups_names, (list)):
            for index, group in enumerate(singleHostGetGroups_names):
                for key, value in group.items():
                    if key == 'name': allGroups_names.append(value)
        for index, item in enumerate(allGroups_names):
            f_log(f'allGroups_names {index}',f'{item}',debug)
except Exception as e:
    if debug: logging.error(e)
    RC = 12
    exit(RC)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# get_allGroupsWithHost
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
stepName = 'get_allGroupsWithHost'
f_log(f'{stepName}','---------------------------------------------------------------------------------------------------------------------------------------------',debug)
try:
    if useRestAPI:
        request = f'hosts/{host_id}/all_groups'
        result,RC = f_requests(request,twusr,twpwd,payload,debug)
    else:
        cmdexec = ['awx','host','get',f'{host_id}','--query','all_groups','--all-pages']
        result,RC = f_cmdexec(cmdexec,debug)

    if RC > 0: raise Exception(f'step {stepName} failed')
    if TESTING: f_dump_and_write(result,useRestAPI,stepName,debug)

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
    RC = 12
    exit(RC)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# get_credNameFromGroup
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
stepName = 'get_credNameFromGroup'
f_log(f'{stepName}','---------------------------------------------------------------------------------------------------------------------------------------------',debug)
try:
    for grp_cred in unique_group_list:
        if useRestAPI:
            request = f'groups/?name={grp_cred}'
            result,RC = f_requests(request,twusr,twpwd,payload,debug)
        else:
            cmdexec = ['awx', 'group', 'list', '--name', f'{grp_cred}', '--all-pages']
            result,RC = f_cmdexec(cmdexec,debug)

        if RC > 0: raise Exception(f'step {stepName} failed')
        if TESTING: f_dump_and_write(result,useRestAPI,stepName,debug)

        grp_cred_count = result['count']
        if grp_cred_count <= 1:
            raise Exception(f'step get credNameFromGroup by {grp_cred}: Requested job_template {launch_template_name} is not found')
        else:
            result = result['results']
            if isinstance(result, (list)):
                for index, group_element in enumerate(result):
                    for key, value in group_element.items():
                        if key == 'variables':
                            data = load_data(value)
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
    exit(RC)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# get_credential_ids
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
stepName = 'get_credential_ids'
f_log(f'{stepName}','---------------------------------------------------------------------------------------------------------------------------------------------',debug)
try:
    credential_ids = []
    credential_names = []
    for cred_name in unique_cred_name_list:
        if useRestAPI:
            request = f'credentials/?name={cred_name}'
            result,RC = f_requests(request,twusr,twpwd,payload,debug)
        else:
            cmdexec = ['awx', 'credential', 'list', '--name', f'{cred_name}', '--all-pages']
            result,RC = f_cmdexec(cmdexec,debug)

        if RC > 0: raise Exception(f'step {stepName} failed')
        if TESTING: f_dump_and_write(result,useRestAPI,stepName,debug)

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
    exit(RC)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# launch_job_template
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
stepName = 'launch_job_template'
f_log(f'{stepName}','---------------------------------------------------------------------------------------------------------------------------------------------',debug)
try:
    credential_ids = ','.join(map(str, unique_credential_ids))

    job_template    = f'--name {launch_template_name} '
    credential      = f'--credentials {credential_ids} '
    inventory       = f'--inventory {template_inv_id} '
    extra_vars = {
        'req_hostname': f'{req_hostname}',
        'req_servicenow_id': f'{req_servicenow_id}',
    }
    extra_vars  = f'--extra_vars \"{extra_vars}\"'

    if useRestAPI:
        request = f'job_templates/{template_id}/launch/'
        f_log(f'request',f'{request}',debug)
        result,RC = f_requests(request,twusr,twpwd,payload,debug)
    else:
        cmdexec = f"awx job_templates launch {launch_template_name} {credential} {inventory} {extra_vars}"
        f_log(f'cmdexec',f'{cmdexec}',debug)
        result,RC = f_cmdexec(cmdexec,debug)

    if RC > 0: raise Exception(f'step {stepName} failed')
    if TESTING: f_dump_and_write(result,useRestAPI,stepName,debug)

except Exception as e:
    if debug: logging.error(e)
    RC = 12
    exit(RC)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
f_log(f'END','---------------------------------------------------------------------------------------------------------------------------------------------',debug)
print(f'{unique_credential_ids}')