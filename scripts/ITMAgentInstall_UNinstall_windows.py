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
# ITMAgentInstall_windows.py    :   Uninstall All ITM agents, and INSTALL new thereafter
#
# 2024-02-27    version V1.0    :   Initial release ( Benny Skov/Denmark/IBM )
#
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
#
#   .\ITMAgentInstall_windows.py -nodename kmdwinitm001 -ccode kmn -shore nearshore -envir classic
#
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
# if getattr(sys, 'frozen', False):
#     workdir = os.path.dirname(sys.executable) # needed for getting the current dir where the exe file is placed
# else:
#     workdir = os.path.dirname(os.path.abspath(__file__))
workdir     = os.path.dirname(os.path.abspath(__file__))
workdir     = workdir.replace('\\','/').strip()
workdir     = workdir.split('/')[0:-1]
workdir     = "/".join(workdir)
nodename    = socket.gethostname().lower()
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
#
# Functions
#
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_help_error
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_help_error():
    print(" ")
    print(" ")
    print(" use: -?             for this help message")
    print(" use: -nodename      [optional] nodename on which you want the itm agent to be installed. Default is nodename set as hostname ")
    print(" use: -ccode         Customer Code - to be prefixed at the ITM agent name")
    print(" use: -shore         onshore or nearshore")
    print(" use: -envir         The RTEMS environtment must be either (paas|classic|fmo|energinet|infrastructure)")
    print(" use: -primary       [optional] primary RTEMS hostIP. if you know beforehand, then use -primary 84.255.124.200")
    print(" use: -secondary     [optional] secondary RTEMS hostIP. if you know beforehand, then use -secondary 84.255.124.201")
    print(" use: -f             [optional] ForceUninstall to also remove subagents is present on server")
    print(" use: -p             [optional] this will only do the select, and do a port check. and create a csv file")
    print(" use: -u             [optional] this will UNINSTALL and cleanup to remove IP for kyndryl")
    print(" use: -d             [optional] set services to disabled after stop")
    print(" use: -version       [optional] displays this script version")
    print(" ")
    print(" ")
    print("\t\t\texample:")
    print(" ")
    print('\t\t\t ITMAgentInstall_windows.cmd -nodename kmdwinitm001 -ccode kmn -shore nearshore -envir . -f')
    print('\t\t\t ITMAgentInstall_windows.cmd -nodename kmdwinitm001 -ccode kmn -shore nearshore -envir classic -f')
    print('\t\t\t ITMAgentInstall_windows.cmd -nodename kmdwinitm001 -ccode kmn -primary 84.255.124.200 -secondary 84.255.124.201 -f')
    print('\t\t\t ITMAgentInstall_windows.cmd -nodename kmdwinitm001 -p      ( ping only. )')
    print('\t\t\t ITMAgentInstall_windows.cmd -nodename kmdwinitm001 -u      ( uninstall only. )')
    print('\t\t\t ITMAgentInstall_windows.cmd -nodename kmdwinitm001 -u -d   ( set all services disabled. and uninstall )')
    print(" ")
    print(" ")
    exit()
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
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
# f_check_port
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_check_port(host,port,debug):
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(1)  # Adjust timeout as needed
            s.connect((host, port))
        return True
    except Exception as e:
        # if debug:
        #     logging.info(f"Error\t={e}")
        return False
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_read_csv_and_ping
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_read_csv_and_ping(frtems,rtemsPreselected,primary,secondary,rtemsFiltered,envir,shore,debug):

    Hash_rtemsCi = {}

    rtems = pd.read_csv(frtems, delimiter=";", encoding='utf-8')
    rtems = rtems.astype(str)
    rtems = rtems.map(lambda x: x.strip() if isinstance(x, str) else x)
    for i, row in rtems.iterrows():
        rtemsCi = str(row["rtemsCi"].strip().lower())
        rtemsIP = str(row["rtemsIP"].strip().lower())
        rtemsPairs = row["rtemsPairs"].strip().lower()
        rtemsPairs = str(rtemsPairs)
        rtemsPrimSec = str(row["rtemsPrimSec"].strip().lower())
        rtemsPrimSec = str(row["rtemsPrimSec"].strip().lower())
        rtemsTier = str(row["rtemsTier"].strip().lower())
        rtemsEnvir = str(row["rtemsEnvir"].strip().lower())
        rtemsShore = str(row["rtemsShore"].strip().lower())

        if rtemsPreselected:
            if not ( (re.search(f"{rtemsIP}", primary, re.IGNORECASE)) or (re.search(f"{rtemsIP}", secondary, re.IGNORECASE))):
                envir = rtemsEnvir
                shore = rtemsShore
                continue

        if rtemsFiltered:
            if (re.search('Emptying', rtemsTier, re.IGNORECASE)): continue
            if not (re.search(f"{shore}", rtemsShore, re.IGNORECASE)): continue
            if not (re.search(f"{envir}", rtemsEnvir, re.IGNORECASE)): continue

        host = rtemsIP
        port = 3660
        if f_check_port(host,port,debug):
            text = f"Port {port} is open on {host}."
            Hash_rtemsCi[rtemsIP] = f"True;{nodename};{ip_address};{subnet_mask};{network_address};{broadcast_address};{dns_servers};{rtemsCi};{rtemsIP};{rtemsPairs};{rtemsPrimSec};{rtemsTier};{rtemsEnvir};{rtemsShore}"
        else:
            text = f"Port {port} is closed on {host}."
        # if debug:
        #     logging.info(f"rtemsCi: {text}")

    return Hash_rtemsCi
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# write all pings
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_write_pings(Hash_rtemsCi,pingfile,debug):
    with open(pingfile, 'w') as file:
        value = "status;nodename;ip_address;subnet_mask;network_address;broadcast_address;dns_servers;rtemsCi;rtemsIP;rtemsPairs;rtemsPrimSec;rtemsTier;rtemsEnvir;rtemsShore"
        file.write(f"{value}\n")
        for key, value in Hash_rtemsCi.items():
            file.write(f"{value}\n")
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_get_network_info
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_get_network_info(ip_address,debug):
    try:
        # Get the network details
        network = ipaddress.ip_network(ip_address, strict=False)
        subnet_mask = network.netmask
        network_address = network.network_address
        broadcast_address = network.broadcast_address

        # Get default gateway (assuming it's reachable)
        gateway_ip = str(network.network_address + 1)  # Change if default gateway IP is different
        gateway_reachable = f_check_port(gateway_ip, 80,debug)  # Assuming HTTP port for gateway check

        if gateway_reachable:
            default_gateway = gateway_ip
        else:
            default_gateway = "Unknown (not reachable)"

        # Get DNS servers
        result = dns.resolver.Resolver(ip_address, 'PTR')
        dns_servers = str(result.nameservers)

        return {
            "ip_address": ip_address,
            "subnet_mask": str(subnet_mask),
            "network_address": str(network_address),
            "broadcast_address": str(broadcast_address),
            "default_gateway": default_gateway,
            "dns_servers": dns_servers
        }
    except Exception as e:
        return {"Error": str(e)}
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_zip_archive
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_zip_archive(zip_path, archive_path,debug):
    try:
        if os.path.isfile(zip_path):
            os.remove(zip_path)
        if os.path.isdir(archive_path):
            with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
                    for root, dirs, files in os.walk(archive_path):
                        for file in files:
                            zipf.write(os.path.join(root, file), os.path.relpath(os.path.join(root, file), archive_path))
            if debug:
                logging.info(f"The earlier GSMA files in {archive_path} has been zipped to {zip_path}, to be restored after reinstall")
        else:
            if debug:
                logging.info(f"There were no earlier GSMA files in {archive_path} ")
        return False
    except Exception as e:
        if debug:
            logging.info(f"Error\t={e}")
        return False
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_zip_extract
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_zip_extract(zip_path, extract_path,debug):
    try:
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            for entry in zip_ref.infolist():
                target_path = os.path.join(extract_path, entry.filename)
                if os.path.exists(target_path):
                    os.remove(target_path)  # Remove existing file
                zip_ref.extract(entry, path=extract_path)
        if debug:
            logging.info(f"# ========> GSMA files in {zip_path} has been restored/extracted to {extract_path}")
    except Exception as e:
        if debug:
            logging.info(f"Error\t={e}")
        return False
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_cmdexec
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_cmdexec(cmdexec,debug):
    # cmdexec = f"{cmdexec} 2>&1"
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
# stop agents if any is active
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_stopItmServices(DisableAllServices,debug):
    RC = 0
    result = ""
    c = wmi.WMI()
    query = f"SELECT * FROM Win32_Service where DisplayName like '%Monitoring Agent for%'"
    services = c.query(query)
    # if debug: logging.info("{:30s} - {}".format("services",f"{services}"))

    if len(services) == 0:
        result = "no ITM services found. There is no ITM agent installed"
        if debug: logging.info(result)
        RC = 12
    else:
        if DisableAllServices:
            for service in services:
                serviceName = service.Name
                serviceState = service.State
                serviceType = service.StartMode
                cmdexec = f"{pwsh} \"Set-Service -Name {serviceName} -StartupType Disabled\""
                result, RC = f_cmdexec(cmdexec,debug)
                if debug: logging.info("{:30s} - {}".format("result",f"{result}"))

        for service in services:
            serviceName = service.Name
            serviceState = service.State
            serviceType = service.StartMode
            if debug: logging.info("{:30s} - {}".format("serviceName",serviceName))
            if debug: logging.info("{:30s} - {}".format("serviceState",serviceState))
            if debug: logging.info("{:30s} - {}".format("serviceType",serviceType))
            cmdexec = f"{pwsh} \"Stop-Service -Name {serviceName} -Force -ErrorAction SilentlyContinue\""
            result, RC = f_cmdexec(cmdexec,debug)
            if debug: logging.info("{:30s} - {}".format("result",f"{result}"))

    return result, RC
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# start agents
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_startItmServices(debug):
    RC = 0
    result = ""
    if debug:
        logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
        logging.info(f"#  start agents")
        logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")

    c = wmi.WMI()
    query = f"SELECT * FROM Win32_Service where DisplayName like '%Monitoring Agent for%'"
    services = c.query(query)
    # if debug: logging.info("{:30s} - {}".format("services",f"{services}"))

    if len(services) == 0:
        result = "no ITM services found. There is no ITM agent installed"
        if debug: logging.info(result)
        RC = 12
    else:
        for service in services:
            serviceName = service.Name
            serviceState = service.State
            serviceType = service.StartMode
            if debug: logging.info("{:30s} - {}".format("serviceName",serviceName))
            if debug: logging.info("{:30s} - {}".format("serviceState",serviceState))
            if debug: logging.info("{:30s} - {}".format("serviceType",serviceType))
            if re.search(f"KNTCMA_Primary", serviceName, re.IGNORECASE):
                cmdexec = f"{pwsh} \"Set-Service -Name {serviceName} -StartupType Automatic\""
            else:
                cmdexec = f"{pwsh} \"Set-Service -Name {serviceName} -StartupType Manual\""
            result, RC = f_cmdexec(cmdexec,debug)

            cmdexec = f"{pwsh} \"Start-Service -Name {serviceName} -ErrorAction SilentlyContinue\""
            result, RC = f_cmdexec(cmdexec,debug)
            if debug: logging.info("{:30s} - {}".format("result",f"{result}"))
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
logfile     = f_set_debug_logging(debug)
f_set_priority()
platformnode= platform.node().lower()
OSsystem    = platform.system()
OSrelease   = platform.release()
OSversion   = platform.version()
ip_address  = socket.gethostbyname(nodename)
network_info= f_get_network_info(ip_address,debug)
# for key, value in network_info.items():
#     print(f"{key}: {value}")
ip_address          = str(network_info["ip_address"])
subnet_mask         = str(network_info["subnet_mask"])
network_address     = str(network_info["network_address"])
broadcast_address   = str(network_info["broadcast_address"])
default_gateway     = str(network_info["default_gateway"])
dns_servers         = str(network_info["dns_servers"])
Install             = False
ForceUninstall      = False
Pingonly            = False
Uninstall     = False
DisableAllServices  = False
cleaupTemp          = False
ccode               = ""
shore               = ""
envir               = ""
primary             = ""
secondary           = ""
rtemsPreselected    = False
rtemsFiltered       = False
pwsh                = "powershell -ExecutionPolicy bypass -NoProfile -NonInteractive -InputFormat none -c "
# ----------------------------------------------------------------------------------------------------------------------------
#
# settings for ITM6 agent uninstall
#
# ----------------------------------------------------------------------------------------------------------------------------
project             = "HSM-TOOLS"
UninstName          = 'ITMRmvAll.exe'
DisplayName         = 'monitoring Agent'
ServiceName         = '^k.*'
CommandLine         = '^C:\\IBM.ITM\\.*\\K*'
UninstPath          = f"{workdir}/bin/{UninstName}"
UninstCmdexec       = ("start", "/WAIT", "/MIN", f"{UninstPath}", "-batchrmvall", "-removegskit")
step                = 0
RegistryKeys = (
    'HKLM:/SOFTWARE/Candle'
    'HKLM:/SOFTWARE/Wow6432Node/Candle',
    'HKLM:/SYSTEM/CurrentControlSet/Services/Candle',
    'HKLM:/SYSTEM/CurrentControlSet/Services/IBM/ITM'
)
# RemoveDirs = (
#     "C:/Windows/Temp",
#     "C:/Temp/scanner_logs",
#     "C:/Temp/jre",
#     "C:/Temp/report",
#     "C:/Temp/exclude_config.txt",
#     "C:/Temp/Get-Win-Disks-and-Partitions.ps1",infrastructure
#     "C:/Temp/log4j2-scanner-2.6.5.jar",
#     "C:/salt",
#     "${scriptBin}"
# )
RemoveDirs = (
    "C:/Temp"
)
# ----------------------------------------------------------------------------------------------------------------------------
# display vars
# ----------------------------------------------------------------------------------------------------------------------------
# $text = "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"; Logline -logstring $text -step $step
# text = f'begin:             {now}' if debug: logging.info(f'{now}')
# $text = "psvers:            " + $psvers; Logline -logstring $text -stexttep $step
# $text = "hostname:          " + $hostname; Logline -logstring $text -step $step
# $text = "hostIp:            " + $hostIp; Logline -logstring $text -step $step
# $text = "scriptName:        " + $scriptName; Logline -logstring $text -step $step
# $text = "scriptPath:        " + $scriptPath; Logline -logstring $text -step $step
# $text = "scriptDir:         " + $scriptDir; Logline -logstring $text -step $step
# $text = "logfile:           " + $logfile; Logline -logstring $text -step $step
# $text = "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"; Logline -logstring $text -step $step
# $text = "UninstName:        " + $UninstName; Logline -logstring $text -step $step
# $text = "DisplayName:       " + $DisplayName; Logline -logstring $text -step $step
# $text = "ServiceName:       " + $ServiceName; Logline -logstring $text -step $step
# $text = "CommandLine:       " + $CommandLine; Logline -logstring $text -step $step
# $text = "UninstPath:        " + $UninstPath; Logline -logstring $text -step $step
# $text = "UninstCmdexec:     " + $UninstCmdexec; Logline -logstring $text -step $step
# $text = "DisableAllServices:    " + $DisableAllServices; Logline -logstring $text -step $step
# foreach ( $key in $RegistryKeys ) {
#     $text = "registry key to be removed: " + $key; Logline -logstring $text -step $step
# }
# foreach ( $dir in $RemoveDirs ) {
#     $text = "directory to be removed: " + $dir; Logline -logstring $text -step $step
# }
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
print("Begin  {:65s} - {}".format(scriptName,now))
if debug:
    logging.info(f"# Begin -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ")
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# set environtment
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if debug:
    logging.info(f"set environtment ----------------------------------------------------------------------------------------------------------------------------------------------------------")
paths = os.environ.get("Path", "").split(";")
logging.info(f"paths beginning= {paths}")

clean_paths = []
# Iterate through the existing paths
for p in paths:
    if (re.search(f"PortablePython", p, re.IGNORECASE)): continue
    if (re.search(f"{project}", p, re.IGNORECASE)): continue
    clean_paths.append(p)

clean_paths = ";".join(clean_paths)
os.environ["Path"] = clean_paths
os.environ["Path"] = f"{workdir}/bin;{workdir}/scripts/PortablePython/;{workdir}/scripts/PortablePython/Scripts/;" + clean_paths
# ----------------------------
# No need to set path. Path is set in the CMD file. if set from here it will be added to whole environtment.
# ----------------------------
# os.environ["Path"] = f"{workdir}/;C:/IBM/ITM/;{workdir}/PortablePython/;{workdir}/PortablePython/Scripts/;" + clean_paths
# os.environ['ICCRTE_DIR']  = "C:/IBM/ITM/GSK8_x64"
# os.environ['KEYFILE_DIR'] = "C:/IBM/ITM/keyfiles"
# os.environ['CANDLE_HOME'] = "C:/IBM/ITM"
# os.environ['LIBPATH'] = "C:/IBM/ITM/InstallITM;C:/IBM/ITM/TMAITM6"
# for name, value in os.environ.items():
#     if debug:
#         logging.info("{:30s} - {}".format(name,value))
# paths = os.environ.get("PATH", "").split(";")
# for p in paths:
#     if debug:
#         p = p.strip()
#         if len(p) > 0: logging.info(p)

# ----------------------------------------------------------------------------------------------------------------------------------------------------------
#  pass args
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
argnum = 1
if debug:
    logging.info(f"args retrieved: {len(sys.argv)}")
    logging.info(f"args: {sys.argv}")
if len(sys.argv) > 1:
    if bool(re.search(r'^(-h|-?|--?|--help)$', sys.argv[1], re.IGNORECASE)): f_help_error()
    for i, arg in enumerate(sys.argv):
        checkArg = str(arg.strip())
        if re.search(r'\-nodename$',    checkArg, re.IGNORECASE): Install = True;  argnum = i; argnum += 1; nodename = sys.argv[argnum]
        if re.search(r'\-ccode$',       checkArg, re.IGNORECASE): Install = True;  argnum = i; argnum += 1; ccode = sys.argv[argnum]
        if re.search(r'\-shore$',       checkArg, re.IGNORECASE): Install = True;  argnum = i; argnum += 1; shore = sys.argv[argnum]
        if re.search(r'\-envir$',       checkArg, re.IGNORECASE): Install = True;  argnum = i; argnum += 1; envir = sys.argv[argnum]
        if re.search(r'\-primary$',     checkArg, re.IGNORECASE): Install = True;  argnum = i; argnum += 1; primary = sys.argv[argnum]
        if re.search(r'\-secondary$',   checkArg, re.IGNORECASE): Install = True;  argnum = i; argnum += 1; secondary = sys.argv[argnum]
        if re.search(r'\-f$',           checkArg, re.IGNORECASE): ForceUninstall = True
        if re.search(r'\-p$',           checkArg, re.IGNORECASE): Install = False; Pingonly = True
        if re.search(r'\-u$',           checkArg, re.IGNORECASE): Install = False; Uninstall = True
        if re.search(r'\-d$',           checkArg, re.IGNORECASE): Install = False; DisableAllServices = True
        if re.search(r'\-version$',     checkArg, re.IGNORECASE): print(version);exit()
        if len(sys.argv) >= 1:
            pass
        else:
            f_help_error()
else:
    f_help_error()

if not Pingonly and not Uninstall:
    if len(nodename) == 0: f_help_error()
    if len(ccode) == 0: f_help_error()
    if len(shore) == 0: f_help_error()
    if len(envir) == 0: f_help_error()
if ccode == "None": ccode = "kmn"
if shore == "None": shore = "nearshore"
if envir == "None": envir = "."
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# check rtems.csv
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
frtems = f"{workdir}/ITMConfig/rtems.csv"
if not os.path.isfile(frtems):
    print(f"{frtems} file not found")
    exit()
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# check pingfile
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
pingfile = f"{workdir}/scripts/{scriptName}_pingfile.log"
if os.path.isfile(pingfile):
    os.remove(pingfile)
Path(pingfile).touch()
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# FOR TESTING
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# shore = "nearshore"
# ccode = "kmn"
# envir = "cmo classic"
# primary = "10.149.1.5" # closed on kmdwinitm001
# primary = "84.255.124.200"
# secondary = "10.149.1.6" # closed on kmdwinitm001
# secondary = "84.255.124.201"
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
#
# Begin
#
# Install
#
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if Install:

    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    # check/refill args
    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    if len(nodename) == 0:
        nodename = platformnode
        nodename = nodename.lower()

    if len(primary) > 0 and len(secondary) > 0:
        rtemsPreselected = True
        shore = ""
        envir = ""
        if debug:
            logging.info(f"envir and shore is set to empty, primary and secondary is preselected:")

        if len(ccode) == 0:
            if debug:
                text = f"\n\n\t-ccode must be given"
                logging.info(text)
                print(f"{text}")
            f_help_error()
    else:
        if Pingonly:
            pass
        else:
            if len(ccode) == 0:
                if debug:
                    text = f"\n\n\t-ccode must be given"
                    logging.info(text)
                    print(f"{text}")
                f_help_error()

            if len(shore) == 0:
                if debug:
                    text = f"\n\n\t-shore must be given"
                    logging.info(text)
                    print(f"{text}")
                f_help_error()

            if len(envir) == 0:
                if debug:
                    text = f"\n\n\t-envir must be given"
                    logging.info(text)
                    print(f"{text}")
                f_help_error()

            if not re.search(r'(paas|classic|fmo|energinet|infrastructure|.)', envir, re.IGNORECASE):
                if debug:
                    text = f"\n\n\t-envir {envir} must be either (paas|classic|fmo|energinet|infrastructure)"
                    logging.info(text)
                    print(f"{text}")
                f_help_error()
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# always display all vars
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if debug:
    logging.info("{:30s} - {}".format("scriptName",scriptName))
    logging.info("{:30s} - {}".format("workdir",workdir))
    logging.info("{:30s} - {}".format("logfile",logfile))
    logging.info("{:30s} - {}".format("pingfile",pingfile))
    logging.info("{:30s} - {}".format("Install",Install))
    logging.info("{:30s} - {}".format("ForceUninstall",ForceUninstall))
    logging.info("{:30s} - {}".format("Pingonly",Pingonly))
    logging.info("{:30s} - {}".format("Uninstall",Uninstall))
    logging.info("{:30s} - {}".format("DisableAllServices",DisableAllServices))
    logging.info("{:30s} - {}".format("cleaupTemp",cleaupTemp))
    logging.info("{:30s} - {}".format("project",project))
    logging.info("{:30s} - {}".format("UninstName",UninstName))
    logging.info("{:30s} - {}".format("DisplayName",DisplayName))
    logging.info("{:30s} - {}".format("ServiceName",ServiceName))
    logging.info("{:30s} - {}".format("UninstPath",UninstPath))
    logging.info("{:30s} - {}".format("CommandLine",CommandLine))
    logging.info("{:30s} - {}".format("UninstCmdexec",UninstCmdexec))
    logging.info("{:30s} - {}".format("rtemsPreselected",rtemsPreselected))
    logging.info("{:30s} - {}".format("rtemsFiltered",rtemsFiltered))
    logging.info("{:30s} - {}".format("platformnode",platformnode))
    logging.info("{:30s} - {}".format("OSsystem",OSsystem))
    logging.info("{:30s} - {}".format("OSrelease",OSrelease))
    logging.info("{:30s} - {}".format("OSversion",OSversion))
    logging.info("{:30s} - {}".format("nodename",nodename))
    logging.info("{:30s} - {}".format("ip_address",ip_address))
    logging.info("{:30s} - {}".format("subnet_mask",subnet_mask))
    logging.info("{:30s} - {}".format("network_address",network_address))
    logging.info("{:30s} - {}".format("broadcast_address",broadcast_address))
    logging.info("{:30s} - {}".format("default_gateway",default_gateway))
    logging.info("{:30s} - {}".format("dns_servers",dns_servers))
    logging.info("{:30s} - {}".format("ccode",ccode))
    logging.info("{:30s} - {}".format("shore",shore))
    logging.info("{:30s} - {}".format("envir",envir))
    logging.info("{:30s} - {}".format("primary",primary))
    logging.info("{:30s} - {}".format("secondary",secondary))
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# If Pingonly
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if Pingonly:
    if debug:
        logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
        logging.info(f"#  Pingonly  ")
        logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")

    Hash_rtemsCi = f_read_csv_and_ping(frtems,rtemsPreselected,primary,secondary,rtemsFiltered,envir,shore,debug)
    f_write_pings(Hash_rtemsCi,pingfile,debug)
    RC = 0
    f_end(RC, debug) #NOTE
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# Ping & port check
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
else:
    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    # Ports check
    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    if debug:
        logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
        logging.info(f"# Ping & port check")
        logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")

    if rtemsPreselected:
        rtemsFiltered = False
    else:
        rtemsFiltered = True

    Hash_rtemsCi = {}
    Hash_rtemsCi = f_read_csv_and_ping(frtems,rtemsPreselected,primary,secondary,rtemsFiltered,envir,shore,debug)
    f_write_pings(Hash_rtemsCi,pingfile,debug)
    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    # have we found all the predefined requested
    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    if rtemsPreselected or len(Hash_rtemsCi) >= 2:
        if debug:
            logging.info(f"for envir {envir}, {len(Hash_rtemsCi)} RTEMS have been selected or both predefined RTEMS {primary}/{secondary} is matched, and their ports are opened")
    else:
        Hash_rtemsCi = {}
        if debug:
            logging.info(f"predefined RTEMS {primary}/{secondary} is NOT found or their ports are not Opened")
    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    # There is no ports opened for any of the RTEMS in the selected envir or predefined. We will now try all RTEMS
    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    if len(Hash_rtemsCi) == 0:
        if debug:
            logging.warning(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
            logging.warning(f"#  There is no ports opened for any of the RTEMS in the selected {envir} on {shore} or on the selected predefined. We will now try all RTEMS")
            logging.warning(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")

        Hash_rtemsCi = {}
        rtemsPreselected    = False
        rtemsFiltered       = False
        Hash_rtemsCi = f_read_csv_and_ping(frtems,rtemsPreselected,primary,secondary,rtemsFiltered,envir,shore,debug)
        f_write_pings(Hash_rtemsCi,pingfile,debug)

    if len(Hash_rtemsCi) == 0:
        RC = 12
        if debug:
            logging.warning(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
            logging.warning(f"#  There is no ports opened for any of the RTEMS.")
            logging.warning(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
            print(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
            print(f"#  There is no ports opened for any of the RTEMS.")
            print(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")

        f_end(RC, debug) #NOTE

    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    # match the found in pairs
    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    if debug:
        logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
        logging.info(f"#  match the found in pairs  ")
        logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")

    if len(Hash_rtemsCi) > 0:

        apair_found = False

        for top_rtemsIP in Hash_rtemsCi:

            if apair_found: break

            status,nodename,ip_address,subnet_mask,network_address,broadcast_address,dns_servers,rtemsCi,rtemsIP,rtemsPairs,rtemsPrimSec,rtemsTier,rtemsEnvir,rtemsShore = Hash_rtemsCi[top_rtemsIP].split(";")
            if debug:
                logging.info(f"check rtemsPairs={rtemsPairs}")
            counter = 0
            check_pairs = Hash_rtemsCi

            for low_key in check_pairs:
                if re.search(f";{rtemsPairs};", check_pairs[low_key], re.IGNORECASE):
                    if debug: logging.info(f"Found '{rtemsPairs}' in value: {check_pairs[low_key]}")
                    if re.search(f";primary;", check_pairs[low_key], re.IGNORECASE):
                        primary = check_pairs[low_key].split(";")[8]
                    if re.search(f";secondary;", check_pairs[low_key], re.IGNORECASE):
                        secondary = check_pairs[low_key].split(";")[8]
                    pairSelected = rtemsPairs
                    counter += 1
                    if counter >= 2:
                        apair_found = True
                        break
    if debug:
        logging.info(f"nodename={nodename} primary IP {primary} pair {pairSelected} port is open")
        logging.info(f"nodename={nodename} secondary IP {secondary} pair {pairSelected} port is open")

    if len(primary) > 0 and len(secondary) > 0:
        var1 = primary
        var2 = secondary
        selected_var = random.choice([var1, var2])
        unselected_var = var1 if selected_var == var2 else var2

        CT_CMSLIST = f"IP.SPIPE:{selected_var};IP.SPIPE:{unselected_var}"
        if debug:
            logging.info(f"CT_CMSLIST is set to={CT_CMSLIST}")
    else:
        if debug:
            text=f"primary or secondary ip is missing. script is unable to create CT_CMSLIST. ending"
            print(f"{text}")
            logging.info(text)
    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    #
    #
    # check if there is more than OS, and GSMA running. exit if, unless -f is given
    #
    #
    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    if debug:
        logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
        logging.info(f"#  check if there is more than OS, and GSMA running. exit if, unless -f is given ")
        logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")

    c = wmi.WMI()
    services_cnt = 0
    query = f"SELECT * FROM Win32_Service where DisplayName like '%Monitoring Agent for%'"
    services = c.query(query)
    for service in services:
        text= "Service: {:60s} {:30s} {}".format(service.DisplayName,service.Name,service.State);logging.info(text)
        services_cnt += 1
        # print(services_cnt)

    if services_cnt > 5:
        text= f"there are running {services_cnt} ITM agents. More than OS and GSMA ITM agents";logging.error(text);print(f"{text}")
        if ForceUninstall:
            text= f"force ForceUninstall is set to {ForceUninstall}, so we continue to reinstall OS & GSMA ITM agents";logging.warning(text);print(f"{text}")
        else:
            text= f"force ForceUninstall is set to {ForceUninstall}, so we are exiting. To force a reinstall you have to set -f as argument";logging.error(text);print(f"{text}")
            RC = 12
            f_end(RC, debug) #NOTE
    else:
        text= f"there are running {services_cnt} ITM agents as expected for only OS & GSMA";logging.info(text)

    if debug:
        logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
        logging.info(f"#  zip and save original config & scripts, to be restored after reinstall  ")
        logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
    # ----------------------------------------
    # cleanup config & make a new zip file
    # ----------------------------------------
    zip_path = f"{workdir}/smitoolConfigZIP.zip"
    archive_path = "C:/IBM/ITM/smitools/config/"
    f_zip_archive(zip_path, archive_path,debug)
    # ----------------------------------------
    # cleanup scripts & make a new zip file
    # ----------------------------------------
    zip_path = f"{workdir}/smitoolScriptZIP.zip"
    archive_path = "C:/IBM/ITM/smitools/scripts/"
    f_zip_archive(zip_path, archive_path,debug)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# Stop Services & disable services & Uninstall & cleanup & check if everything is gone due to intelectual property of kyndryl
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if Uninstall or ForceUninstall:

    if debug:
        logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
        logging.info(f"#  stop agents if any is active ")
        logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")

    result, RC = f_stopItmServices(DisableAllServices,debug)
    if result is None: result = ''
    if RC is None: RC = 0
    if (re.search("no ITM services found", str(result), re.IGNORECASE)):
        if debug:
            logging.warning(f"No ITM Agent to uninstall, continues to next step")
    else:
        logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
        logging.info(f"#  START Uninstall & cleanup  ")
        logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")

        result, RC = f_cmdexec(UninstCmdexec,debug)
        if debug:
            logging.info(f"f_cmdexec rc: {RC}")
            logging.info(f"f_cmdexec result: {result}")
            for line in result:
                line = line.strip()
                logging.info(line)
        # ----------------------------------------------------------------------------------------------------------------------------------------------------------
        # loop to wait before it is done
        # ----------------------------------------------------------------------------------------------------------------------------------------------------------
        time.sleep(30)
        process_name = "ITMRmvAll.exe"
        timeout=600
        if f_check_process_running(process_name,debug):
            if f_wait_for_process_completion(process_name,timeout,debug):
                text = f"Process {process_name} completed successfully."
                if debug: logging.info(f"{text}")
            else:
                text = f"Process {process_name} did not complete within 10 minutes."
                if debug: logging.info(f"{text}")
        else:
            text = f"Process {process_name} is not running. Uninstall completed"
            if debug: logging.info(f"{text}")
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# Install
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if Install:

    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    # unzip Install image
    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
    logging.info(f"#  unzip Install image  ")
    logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
    zipSource       = f'{workdir}/repository/ITM_win_6307SP14-349-1KMD.zip'
    zipOldExtract   = f'{workdir}/scripts/ITM_win_6307SP14-349-1KMD/'
    zipTarget       = f'{workdir}/scripts/'

    # Remove earlier extraction if it exists
    if os.path.isdir(zipOldExtract):
        shutil.rmtree(zipOldExtract)
        if debug:
            text = f"Old extraction directory removed: {zipOldExtract}"; logging.info(text)
    # Ensure the target directory exists
    if not os.path.exists(zipTarget):
        os.makedirs(zipTarget)

    if os.path.isfile(zipSource):
        if debug:
            text = f"{zipSource} file found.";logging.info(text)
        try:
            with zipfile.ZipFile(zipSource, 'r') as zip_ref:
                zip_ref.extractall(zipTarget)
            if os.path.isdir(zipTarget):
                logging.info(f"Zipfile {zipSource} successfully extracted to {zipTarget}")
            else:
                logging.error(f"Extraction failed: Target directory {zipTarget} not created")
        except zipfile.BadZipFile:
            logging.error(f"Bad zip file: {zipSource}")
        except PermissionError:
            logging.error(f"Permission denied: Unable to write to {zipTarget}")
        except Exception as e:
            logging.error(f"Unexpected error during extraction: {e}")
    else:
        if debug:
            text = f"zipfile {zipSource} missing";logging.error(text)
        RC = 12
        f_end(RC, debug) #NOTE

    if debug:
        logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
        logging.info(f"#  Install agents  ")
        logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")

    cmdexec = f"{zipTarget}/ITM_win_6307SP14-349-1KMD/ITM_win/instTEMA_win.cmd {ccode} {primary} {secondary} 2>&1"
    result, RC = f_cmdexec(cmdexec,debug)
    if debug:
        logging.info(f"f_cmdexec rc: {RC}")
        logging.info(f"f_cmdexec result: {result}")
        for line in result:
            line = line.strip()
            logging.info(line)
    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    # stop agents if any is active for restore smitoolConfigZIP
    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    result, RC = f_stopItmServices(DisableAllServices,debug)
    if result is None: result = ''
    if RC is None: RC = 0
    if (re.search("no ITM services found", str(result), re.IGNORECASE)):
        if debug:
            logging.error(f"No ITM Agent found after install!")
        RC = 0
        f_end(RC, debug) #NOTE
    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    # restore smitoolConfigZIP.zip & smitoolScriptZIP, after reinstall.
    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    if debug:
        logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
        logging.info(f"# restore smitoolConfigZIP.zip & smitoolScriptZIP, after reinstall.  ")
        logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
    # ----------------------------------------
    # extract config
    # ----------------------------------------
    zip_path = f"{workdir}/smitoolConfigZIP.zip"
    extract_path = "C:/IBM/ITM/smitools/config"
    f_zip_extract(zip_path, extract_path,debug)
    # ----------------------------------------
    # extract scripts
    # ----------------------------------------
    zip_path = f"{workdir}/smitoolScriptZIP.zip"
    extract_path = "C:/IBM/ITM/smitools/scripts"
    f_zip_extract(zip_path, extract_path,debug)
    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    # start OS & GSMA agents
    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    if debug:
        logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
        logging.info(f"#  start OS & GSMA agents  ")
        logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")

    result, RC = f_startItmServices(debug)
    if result is None: result = ''
    if RC is None: RC = 0
    if (re.search("no ITM services found", str(result), re.IGNORECASE)):
        if debug:
            logging.error(f"No ITM Agent found after install!")
    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    # is services running
    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    c = wmi.WMI()
    query = f"SELECT * FROM Win32_Service where DisplayName like '%Monitoring Agent for%'"
    services = c.query(query)
    for service in services:
        serviceName = service.Name
        serviceState = service.State
        serviceType = service.StartMode
        text= f"'{serviceName}' '{serviceState}' '{serviceType}'"
        if debug: logging.info(text)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# cleaupTemp
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if cleaupTemp:
    files = ['smitoolConfigZIP.zip','smitoolScriptZIP.zip','ITM_win_6307SP14-349-1KMD.zip','rtems.csv','ITMRmvAll.exe','ITMRmvAll.log','PortablePython.zip']
    try:
        for file in files:
            file = f'{workdir}/{file}'
            if os.path.isfile(file):
                os.remove(file)
            if debug:
                text = 'zipfile is removed '+ str(file);logging.info(text)
    except Exception as e:
        if debug:
            text = f'file {str(file)} is NOT removed. Error: {str(e)}';logging.warning(text)
    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    # cleanup dir
    # ----------------------------------------------------------------------------------------------------------------------------------------------------------
    try:
        dirlist = ['ITM_win_6307SP14-349-1KMD','PortablePython']
        for dirname in dirlist:
            dirname = f"{workdir}/{dirname}"
            if os.path.isdir(dirname):
                shutil.rmtree(dirname)
                if debug:
                    text = 'extracted zip dir is removed '+ str(dirname);logging.info(text)
    except Exception as e:
        if debug:
            text = f'extracted zip dir {str(file)} is NOT removed. Error: {str(e)}';logging.warning(text)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# show environtment after Install de-Install
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# if debug:
    # logging.info(f"show path ----------------------------------------------------------------------------------------------------------------------------------------------------------")
    # for name, value in os.environ.items():
    #     if debug:
    #         logging.info("{:30s} - {}".format(name,value))

    # paths = os.environ.get("PATH", "").split(";")
    # for p in paths:
    #     if debug:
    #         p = p.strip()
    #         if len(p) > 0: logging.info(p)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# THE END
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
f_end(RC, debug)