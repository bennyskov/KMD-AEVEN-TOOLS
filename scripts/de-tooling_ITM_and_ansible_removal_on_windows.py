# -*- coding: utf-8 -*-
import json
import pandas as pd
import sys, os
import re
import time
import logging
import logging.config
import shutil
import psutil
import random
import platform
import ipaddress
import socket
import wmi
import dns
from dns import resolver
import zipfile36 as zipfile
import subprocess
from subprocess import Popen, PIPE, CalledProcessError
from datetime import datetime
from datetime import timedelta
from sys import exit
from pathlib import Path
from pprint import pprint
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
import warnings
warnings.filterwarnings('ignore', category=SyntaxWarning)
# Specifically ignore dns module escape sequence warnings
warnings.filterwarnings('ignore', r'.*SyntaxWarning.*invalid escape sequence.*')
warnings.filterwarnings('ignore', r'.*token.is_identifier.*')
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# INIT logging
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
version     = "version KMD V1.2"
debug       = bool
debug       = True
RC          = 0
start       = time.time()
now         = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
scriptName  = sys.argv[0]
scriptName  = scriptName.replace('\\','/').strip()
scriptName  = scriptName.split('/')[-1]
scriptName  = scriptName.split(".")[0]
if getattr(sys, 'frozen', False):
    workdir = os.path.dirname(sys.executable) # needed for getting the current dir where the exe file is placed
else:
    workdir = os.path.dirname(os.path.abspath(__file__))
workdir     = os.path.dirname(os.path.abspath(__file__))
workdir     = workdir.replace('\\','/').strip()
workdir     = workdir.split('/')[0:-1]
workdir     = "/".join(workdir)
nodename    = socket.gethostname().lower()
leftover    = f"{workdir}/scripts/{scriptName}_leftoverfile.log"
if os.path.isfile(leftover):
    os.remove(leftover)
Path(leftover).touch()
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
#
# Functions
#
# f_set_debug_logging
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_set_debug_logging(debug):
    if debug:
        logfile = f"{workdir}/scripts/{scriptName}_debugfile.log"
        if os.path.isfile(logfile):
            os.remove(logfile)
        Path(logfile).touch()
        logging_schema = {
            "version": 1,
            "formatters": {
                "standard": {
                    "class": "logging.Formatter",
                    "format": "%(asctime)s\t%(levelname)s\t%(filename)s\t%(message)s",
                    "datefmt": "%Y %b %d %H:%M:%S"
                }
            },
            "handlers": {
                "console": {
                    "class": "logging.StreamHandler",
                    "formatter": "standard",
                    "level": "INFO",
                    "stream": "ext://sys.stdout"
                },
                "file": {
                    "class": "logging.handlers.RotatingFileHandler",
                    "formatter": "standard",
                    "level": "INFO",
                    "filename": logfile,
                    "mode": "a",
                    "encoding": "utf-8",
                    # "maxBytes": 500000,
                    # "backupCount": 4
                }
            },
            "loggers" : {
                "__main__": {  # if __name__ == "__main__"
                    "handlers": ["console", "file"],
                    "level": "INFO",
                    "propagate": False
                }
            },
            "root" : {
                "level": "INFO",
                "handlers": ["file"]
            }
        }
        logging.config.dictConfig(logging_schema)
        return logfile
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_set_priority
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_set_priority():
    os_used = sys.platform
    process = psutil.Process(os.getpid())  # Set highest priority for the python script for the CPU
    if os_used == "win32":  # Windows (either 32-bit or 64-bit)
        process.nice(psutil.HIGH_PRIORITY_CLASS)
        # process.nice(psutil.REALTIME_PRIORITY_CLASS)
        # process.nice(psutil.HIGH_PRIORITY_CLASS)
        # process.nice(psutil.ABOVE_NORMAL_PRIORITY_CLASS)
        # process.nice(psutil.NORMAL_PRIORITY_CLASS)
        # process.nice(psutil.BELOW_NORMAL_PRIORITY_CLASS)
    elif os_used == "linux":  # linux
        process.nice(psutil.IOPRIO_HIGH)
    else:  # MAC OS X or other
        process.nice(20)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# write all leftovers
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_write_pings(leftover_List,leftover,debug):
    with open(leftover, 'w') as file:
        value = "status;nodename;ip_address;subnet_mask;network_address;broadcast_address;dns_servers;rtemsCi;rtemsIP;rtemsPairs;rtemsPrimSec;rtemsTier;rtemsEnvir;rtemsShore"
        file.write(f"{value}\n")
        for line in leftover_List:
            file.write(f"{line}\n")
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_cmdexec
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_cmdexec(cmdexec,debug):
    cmdexec = f"{cmdexec} 2>&1"
    if debug: logging.info(f"cmdexec='{cmdexec}'")
    try:
        p = subprocess.Popen(cmdexec, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, encoding="ISO-8859-1")
        result=p.stdout.readlines()
        rc = p.returncode
        # if debug:
        #     logging.info(f"f_cmdexec result: {result}")
        #     logging.info(f"f_cmdexec rc: {RC}")

    except subprocess.CalledProcessError:
        if debug:
            logging.warning(f"Error starting service '{service}'.")
            logging.info(f"f_cmdexec result: {result}")
            logging.info(f"f_cmdexec rc: {RC}")

    except UnicodeDecodeError:
        if debug:
            logging.info(f"\n*Output has invalid (non utf-8) characters! Invalid output\n")
            logging.info(f"f_cmdexec result: {result}")
            logging.info(f"f_cmdexec rc: {RC}")

    return result, RC
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_check_process_running
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_check_process_running(process_name,debug):
    try:
        # Check if the process is running
        result = subprocess.run(["tasklist", "/FI", f"IMAGENAME eq {process_name}"], capture_output=True, text=True)
        if debug:
            logging.info(f"result={result}")
        if process_name in result.stdout:
            return True
        else:
            return False
    except Exception as e:
        text = f"Error checking process: {e}"
        if debug:
            logging.info(f"{text}")
        return False
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_wait_for_process_completion
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_wait_for_process_completion(process_name,timeout,debug):
    start_time = time.time()
    while f_check_process_running(process_name,debug):
        if time.time() - start_time > timeout:
            text = f"Process {process_name} did not complete within {timeout} seconds."
            if debug:
                logging.info(f"{text}")
            return False
        time.sleep(1)
    return True
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_close_locked_handle
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_close_locked_handle(path=None,blockedFilePath=None,depth=0,debug=True):
    # handleCmd = f"{workdir}/handle "f'{blockedFilePath}'" -accepteula -nobanner"
    # handleRegex = "pid:\s*(\d+).*?type:\s*File\s*([0-9A-F]+):"
    # if (handleRegex.Success):
    #     processId = handleRegex.Groups[1].Value.Trim()
    #     handleId = handleRegex.Groups[2].Value.Trim()
    #     cmdexec = f"{workdir}/handle -c {handleId} -y -p {processId} -accepteula -nobanner"
    # # f_close_locked_handle(path,blockedFilePath,depth)
    return path,blockedFilePath,depth
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_check_if_process_hangs
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_kill_if_process_hangs(process_name,debug):
    try:
        # Check if the process is running
        result = subprocess.run(["tasklist", "/FI", f"IMAGENAME eq {process_name}"], capture_output=True, text=True)
        if debug:
            logging.info(f"result={result}")
        if process_name in result.stdout:
            result = subprocess.run([f"{workdir}/bin/psKill", "-t", f"{process_name}","-accepteula","-nobanner"], capture_output=True, text=True)

            result = subprocess.run(["tasklist", "/FI", f"IMAGENAME eq {process_name}"], capture_output=True, text=True)
            if debug:
                logging.info(f"result={result}")
            if process_name in result.stdout:
                if debug:
                    logging.warning(f"result={result}")
                return False
            else:
                return True

    except Exception as e:
        text = f"Error checking process: {e}"
        if debug:
            logging.info(f"{text}")
        return False
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_end
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_end(RC, debug):
    end = time.time()
    hours, rem = divmod(end-start, 3600)
    minutes, seconds = divmod(rem, 60)
    endPrint = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    text = "End of {:65s} - {} - {:0>2}:{:0>2}:{:05.2f}".format(scriptName,endPrint,int(hours),int(minutes),seconds)
    if debug:
        logging.info(f"{text}")
    print(f"{text}")
    exit(RC)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
#
#
# INIT
#
#
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
logfile             = f_set_debug_logging(debug)
f_set_priority()
platformnode        = platform.node().lower()
OSsystem            = platform.system()
OSrelease           = platform.release()
OSversion           = platform.version()
Uninstall           = False
pwsh                = "powershell -ExecutionPolicy bypass -NoProfile -NonInteractive -InputFormat none -c "
# ----------------------------------------------------------------------------------------------------------------------------
#
# settings for ITM6 agent uninstall
#
# ----------------------------------------------------------------------------------------------------------------------------
project             = "KMD-AEVEN-TOOLS"
UninstName          = 'ITMRmvAll.exe'
DisplayName         = 'monitoring Agent'
ServiceName         = '^k.*'
CommandLine         = '^C:\\IBM.ITM\\.*\\K*'
UninstPath          = f"{workdir}/bin/{UninstName}"
UninstAnsible       = ("C:/PROGRA~1/ansible/GTS/ILMT/uninstall.bat")
step                = 0
# RegistryKeys = (
#     'HKLM:/SOFTWARE/Candle',
#     'HKLM:/SOFTWARE/Wow6432Node/Candle',
#     'HKLM:/SYSTEM/CurrentControlSet/Services/Candle',
#     'HKLM:/SYSTEM/CurrentControlSet/Services/IBM/ITM'
# )
removeList = (
    "C:/Windows/Temp/KMD-AEVEN-TOOLS/",
    "C:/Windows/Temp/IBM Tivoli Monitoring*",
    "C:/Windows/Temp/instTEMA_nt*",
    "C:/Windows/Temp/ITM6*",
    "C:/Windows/Temp/k06_reconfig*",
    "C:/Windows/Temp/knt_reconfig*",
    "C:/Windows/Temp/kinconfg_*",
    "C:/Windows/Temp/silconfig*",
    "C:/Windows/Temp/silent.txt*",
    "C:/Temp/scanner_logs",
    "C:/Temp/jre",
    "C:/Temp/report",
    "C:/Temp/exclude_config.txt",
    "C:/Temp/Get-Win-Disks-and-Partitions.ps1",
    "C:/Temp/log4j2-scanner-2.6.5.jar"
)
# @fsList_orig = ("/var/opt/ansible",
#         "/var/opt/ansible_workdir",
#         "/etc/ansible",
#         "/root/.ansible_async",
#         "/tmp/gts-ansible",
#         "/etc/opt/bigfix",
#         "/var/tmp/ilmt",
#         "/var/tmp/aicbackup/ilmt",
#         "/var/db/sudo/lectured/ansible",
#         "/etc/opt/Bigfix",
#         "/etc/BESClient",
#         "/tmp/*BESClient*",
#         "/root/.ansible",
#         "/var/opt/ansible*",
#         "/var/log/ansible*",
#         "/_opt_IBM_ITM_i",
#         "/usr/bin/ansibl*"
#         );
# @fsList = ("/etc/opt/bigfix",
#         "/var/tmp/ilmt",
#         "/var/tmp/aicbackup/ilmt",
#         "/etc/opt/Bigfix",
#         "/etc/BESClient",
#         "/tmp/*BESClient*",
#         "/_opt_IBM_ITM_i",
#         );

# @cacfUsers = ("kmduxat1",
#         "kmduxat2",
#         "kmnuxat1",
#         "kmnuxat2",
#         "kmwuxat1",
#         "kmwuxat2",
#         "ug2uxat1",
#         "ug2uxat2",
#         "yl5uxat1",
#         "yl5uxat2");
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# display all vars
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if debug:
    logging.info("{:30s} - {}".format("leftover",leftover))
    logging.info("{:30s} - {}".format("Uninstall",Uninstall))
    logging.info("{:30s} - {}".format("UninstAnsible",UninstAnsible))

logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
logging.info(f"#  START Uninstall & cleanup  ")
logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
result, RC = f_cmdexec(UninstAnsible,debug)
if debug:
    logging.info(f"f_cmdexec rc: {RC}")
    logging.info(f"f_cmdexec result: {result}")
    for line in result:
        line = line.strip()
        logging.info(line)

# cmdexec = f"{pwsh} \"Stop-Service -Name {serviceName} -Force -ErrorAction SilentlyContinue\""
# result, RC = f_cmdexec(cmdexec,debug)
# if debug: logging.info("{:30s} - {}".format("result",f"{result}"))

# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# cleanup dir
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
try:
    removeFiles = (
    "C:/Windows/Temp/IBM.*Tivoli.*Monitoring.*",
    "C:/Windows/Temp/instTEMA_nt.*",
    "C:/Windows/Temp/ITM6.*",
    "C:/Windows/Temp/k06_reconfig.*",
    "C:/Windows/Temp/knt_reconfig.*",
    "C:/Windows/Temp/kinconfg_.*",
    "C:/Windows/Temp/silconfig.*",
    "C:/Windows/Temp/silent.txt.*",
    "C:/Temp/scanner_logs.*",
    "C:/Temp/exclude_config.txt",
    "C:/Temp/Get-Win-Disks-and-Partitions.ps1",
    "C:/Temp/log4j2-scanner-2.6.5.jar"
    )
    removeDirs = (
    "C:/ansible_workdir/",
    "C:/ProgramData/BigFix/",
    "C:/ProgramData/ansible/",
    "C:/ProgramData/ilmt/",
    "C:/PROGRA~1/BigFix/",
    "C:/PROGRA~1/ansible/",
    "C:/PROGRA~1/ilmt/",
    "C:/Windows/Temp/KMD-AEVEN-TOOLS/",
    "C:/Temp/jre/",
    "C:/Temp/report/",
    )

    for directory in removeDirs:
        if os.path.isdir(directory):
            shutil.rmtree(directory)
            if debug:
                logging.info("{:30s} - {}".format("dir is removed", directory))

    for filename in removeFiles:
        if os.path.isfile(filename):
            os.remove(filename)
            if debug:
                logging.info("{:30s} - {}".format("file is removed", filename))

except Exception as e:
    if debug:
        text = f'file/dir is NOT removed. Error: {str(e)}';logging.warning(text)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# THE END
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
f_end(RC, debug)