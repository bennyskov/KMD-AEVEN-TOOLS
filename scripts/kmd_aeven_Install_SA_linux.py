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
#   .\ITMAgentInstall_windows.py -nodename kmdwinitm001 -ccode kmn -shore nearshore -envir classic
# Functions
#
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_set_debug_logging
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_set_debug_logging(debug):
    if debug: 
        logfile = f"{workdir}/{scriptName}_debugfile.log"
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
        if debug:
            logging.info(f"Error\t={e}")
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
        if debug: 
            logging.info(f"rtemsCi: {text}")

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
        #     logging.info(f"f_cmdexec rc: {rc}")
            
    except subprocess.CalledProcessError:
        if debug:
            logging.warning(f"Error starting service '{service}'.")
            logging.info(f"f_cmdexec result: {result}")
            logging.info(f"f_cmdexec rc: {rc}")

    except UnicodeDecodeError: 
        if debug:
            logging.info(f"\n*Output has invalid (non utf-8) characters! Invalid output\n")
            logging.info(f"f_cmdexec result: {result}")
            logging.info(f"f_cmdexec rc: {rc}")

    return result,rc
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
                logging.info(f"# ========> earlier GSMA files in {archive_path} has been zipped to {zip_path}, to be restored after reinstall")
        else:                    
            if debug: 
                logging.info(f"# ========> there were no earlier GSMA files in {archive_path} ")
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
# stop agents if any is active
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_stopItmServices(debug):
    if debug: 
        logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
        logging.info(f"#  stop agents if any is active ")
        logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")

    c = wmi.WMI()
    query = f"SELECT * FROM Win32_Service where DisplayName like 'Monitoring Agent for%'"
    services = c.query(query)
        
    for service in services:
        serviceName = service.Name
        serviceState = service.State
        serviceType = service.StartMode
        if re.search(f"disabled", serviceType, re.IGNORECASE):
            if re.search(f"KNTCMA_Primary", serviceName, re.IGNORECASE):
                cmdexec = f"{pwsh} \"Set-Service -Name {serviceName} -StartupType Automatic\""
            else:
                cmdexec = f"{pwsh} \"Set-Service -Name {serviceName} -StartupType Manual\""
            result,rc = f_cmdexec(cmdexec,debug) 
            if debug:
                for line in result:
                    line = line.strip()
                    if (re.search(f"HELPMSG", line, re.IGNORECASE)): continue                        
                    if len(line) > 0: logging.info(line)        
        if re.search(f"Running", serviceState, re.IGNORECASE):
            cmdexec = f"net stop {serviceName}"
            result,rc = f_cmdexec(cmdexec,debug) 
            if debug:
                for line in result:
                    line = line.strip()
                    if (re.search(f"HELPMSG", line, re.IGNORECASE)): continue                        
                    if len(line) > 0: logging.info(line)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# start agents 
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_startItmServices(debug):
    if debug: 
        logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
        logging.info(f"#  start agents")
        logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")

    c = wmi.WMI()
    query = f"SELECT * FROM Win32_Service where DisplayName like 'Monitoring Agent for%'"
    services = c.query(query)
        
    for service in services:
        serviceName = service.Name
        serviceState = service.State
        serviceType = service.StartMode
        if re.search(f"disabled", serviceType, re.IGNORECASE):
            if re.search(f"KNTCMA_Primary", serviceName, re.IGNORECASE):
                cmdexec = f"{pwsh} \"Set-Service -Name {serviceName} -StartupType Automatic\""
            else:
                cmdexec = f"{pwsh} \"Set-Service -Name {serviceName} -StartupType Manual\""
            result,rc = f_cmdexec(cmdexec,debug) 
            if debug:
                for line in result:
                    line = line.strip()
                    if (re.search(f"HELPMSG", line, re.IGNORECASE)): continue                        
                    if len(line) > 0: logging.info(line)        
        if re.search(f"Stopped", serviceState, re.IGNORECASE):
            cmdexec = f"net start {serviceName}"
            result,rc = f_cmdexec(cmdexec,debug) 
            if debug:
                for line in result:
                    line = line.strip()
                    if (re.search(f"HELPMSG", line, re.IGNORECASE)): continue                        
                    if len(line) > 0: logging.info(line)                    
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
    print(" use: -f             [optional] Force reinstall, even if other subagents is present on server")    
    print(" use: -p             [optional] this will only do the select, and do a port check. and create a csv file")    
    print(" use: -version       [optional] displays this script version")
    print(" ")
    print(" ")
    print("\t\t\texample:")
    print(" ")
    print('\t\t\tITMAgentInstall_windows.exe -ccode kmn -shore nearshore -envir classic -f')
    print('\t\t\tITMAgentInstall_windows.exe -nodename kmdwinitm001 -ccode kmn -shore nearshore -envir classic -f')
    print('\t\t\tITMAgentInstall_windows.exe -nodename kmdwinitm001 -ccode kmn -primary 84.255.124.200 -secondary 84.255.124.201 -f')
    print('\t\t\tITMAgentInstall_windows.exe -nodename kmdwinitm001 -p     ( ping only. )')
    print(" ")
    print(" ")
    print(f"\t\t\tdebug file is placed:\t{logfile}")
    print(f"\t\t\tResult file is placed:\t{pingfile}")
    print(" ")
    print(" ")
    print(" ")
    exit()
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_end
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_end(debug):
    end = time.time()
    hours, rem = divmod(end-start, 3600)
    minutes, seconds = divmod(rem, 60)
    endPrint = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    text = "End of {:65s} - {} - {:0>2}:{:0>2}:{:05.2f}".format(scriptName,endPrint,int(hours),int(minutes),seconds)
    if debug: 
        logging.info(f"{text}")   
    print(f"{text}")
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# 
# 
# INIT
# 
# 
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
version = "version KMD V0.1"
debug = bool
debug = True
start = time.time()
now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
Logdate = datetime.now().strftime('%Y%m%d_%H%M%S')
Logdate_long = datetime.now().strftime('%Y%m%d_%H%M%S_%f')
argvnull    = sys.argv[0]
scriptName  = sys.argv[0]
scriptName  = scriptName.replace('\\','/').strip()
scriptName  = scriptName.split('/')[-1]
scriptName  = scriptName.split(".")[0]
if getattr(sys, 'frozen', False):
    workdir = os.path.dirname(sys.executable) # needed for getting the current dir where the exe file is placed
else:
    workdir = os.path.dirname(os.path.abspath(__file__))
#   workdir     = os.path.dirname(os.path.realpath(__file__))
workdir     = workdir.replace('\\','/').strip()
nodename    = socket.gethostname().lower()
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
forceInstall        = False
pingonly            = False
rtemsPreselected    = False
pwsh                = "powershell -ExecutionPolicy bypass -NoProfile -NonInteractive -InputFormat none -c "
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
    if (re.search(f"scripttemp_dir", p, re.IGNORECASE)): continue
    clean_paths.append(p)
    
clean_paths = ";".join(clean_paths)
os.environ["Path"] = clean_paths
# ----------------------------
# No need to set path. Path is set in the CMD file. if set from here it will be added to whol environtment.
# ----------------------------
# os.environ["Path"] = f"{workdir}/;C:/IBM/ITM/;{workdir}/PortablePython/;{workdir}/PortablePython/Scripts/;" + clean_paths
# os.environ['ICCRTE_DIR']  = "C:/IBM/ITM/GSK8_x64"    
# os.environ['KEYFILE_DIR'] = "C:/IBM/ITM/keyfiles"
# os.environ['CANDLE_HOME'] = "C:/IBM/ITM"
# os.environ['LIBPATH'] = "C:/IBM/ITM/InstallITM;C:/IBM/ITM/TMAITM6"
# for name, value in os.environ.items():
#     if debug:
#         logging.info("{:30s} - {}".format(name,value))

paths = os.environ.get("PATH", "").split(";")
for p in paths:
    if debug:
        p = p.strip()
        if len(p) > 0: logging.info(p)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# init var
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
ccode = ""
shore = ""
envir = ""
primary = ""
secondary = ""
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# check rtems.csv
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
frtems = f"{workdir}/rtems.csv"
if not os.path.isfile(frtems): 
    print(f"{frtems} file not found")
    exit()
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# check pingfile
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
pingfile = f"{workdir}/{scriptName}_pingfile.log"
if os.path.isfile(pingfile): 
    os.remove(pingfile)
Path(pingfile).touch()
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
        if re.search(r'\-nodename$',    checkArg, re.IGNORECASE): argnum = i; argnum += 1; nodename = sys.argv[argnum]
        if re.search(r'\-ccode$',       checkArg, re.IGNORECASE): argnum = i; argnum += 1; ccode = sys.argv[argnum]
        if re.search(r'\-shore$',       checkArg, re.IGNORECASE): argnum = i; argnum += 1; shore = sys.argv[argnum]
        if re.search(r'\-envir$',       checkArg, re.IGNORECASE): argnum = i; argnum += 1; envir = sys.argv[argnum]
        if re.search(r'\-primary$',     checkArg, re.IGNORECASE): argnum = i; argnum += 1; primary = sys.argv[argnum]
        if re.search(r'\-secondary$',   checkArg, re.IGNORECASE): argnum = i; argnum += 1; secondary = sys.argv[argnum]
        if re.search(r'\-f$',           checkArg, re.IGNORECASE): forceInstall = True
        if re.search(r'\-p$',           checkArg, re.IGNORECASE): pingonly = True
        if re.search(r'\-version$',     checkArg, re.IGNORECASE): print(version);exit()
        if len(sys.argv) >= 1:
            pass
        else:
            f_help_error()
else:
    f_help_error()
    
if len(nodename) == 0: f_help_error()
if len(ccode) == 0: f_help_error()
if len(shore) == 0: f_help_error()
if len(envir) == 0: f_help_error()
if ccode == "None": ccode = "kmn"
if shore == "None": shore = "nearshore"
if envir == "None": envir = "."
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# unzip install image
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
logging.info(f"#  unzip install image  ")
logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
ITM_zipdir  = f'{workdir}/ITM_win_6307SP14-349-1KMD'
ITM_zipfile = f'{ITM_zipdir}.zip'
if os.path.isfile(ITM_zipfile): 
    if debug: 
        text = f"{ITM_zipfile} file is found. properly not run from ansible, then its okay to unzip";logging.info(text) 
        logging.warning(text)

    archive_zipfile = f"{ITM_zipdir}/ITM_win"
    if os.path.isdir(archive_zipfile):
        shutil.rmtree(archive_zipfile)
        if debug: 
            text = 'old zip dir is removed '+ str(archive_zipfile);logging.info(text) 
        with zipfile.ZipFile(ITM_zipfile, 'r') as zip_ref:
            zip_ref.extractall(workdir)

    if os.path.isdir(archive_zipfile):
        if debug: 
            text = f"zipfile {ITM_zipfile} is extracted to {archive_zipfile}";logging.info(text) 
    else:
        if debug: 
            text = f"zipfile {ITM_zipfile} failed to extract to {archive_zipfile}";logging.error(text) 
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
    if pingonly:
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

        if not re.search('(paas|classic|fmo|energinet|infrastructure|\.)', envir, re.IGNORECASE):
            if debug: 
                text = f"\n\n\t-envir {envir} must be either (paas|classic|fmo|energinet|infrastructure)"
                logging.info(text)
                print(f"{text}")    
            f_help_error()


if debug:
    logging.info("{:30s} - {}".format("scriptName",scriptName))
    logging.info("{:30s} - {}".format("workdir",workdir))
    logging.info("{:30s} - {}".format("logfile",logfile))
    logging.info("{:30s} - {}".format("pingfile",pingfile))
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
    logging.info("{:30s} - {}".format("rtemsPreselected",rtemsPreselected))
    logging.info("{:30s} - {}".format("primary",primary))
    logging.info("{:30s} - {}".format("secondary",secondary))
    if pingonly:
        logging.warning("{:30s} - {}".format("pingonly",pingonly))
    else:
        logging.info("{:30s} - {}".format("pingonly",pingonly))
    if forceInstall:
        logging.warning("{:30s} - {}".format("forceInstall",forceInstall))
    else:
        logging.info("{:30s} - {}".format("forceInstall",forceInstall))

# ----------------------------------------------------------------------------------------------------------------------------------------------------------
#
#
# check pingonly
#
#
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if debug: 
    logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
    logging.info(f"#  check pingonly  ")
    logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")

if pingonly:
    text=f"pingonly selected.";logging.info(text)
    print(f"{text}")   
    
    rtemsPreselected    = False
    rtemsFiltered       = False
    Hash_rtemsCi = f_read_csv_and_ping(frtems,rtemsPreselected,primary,secondary,rtemsFiltered,envir,shore,debug)
    f_write_pings(Hash_rtemsCi,pingfile,debug)
    f_end(debug)   
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
#
#
# install
#
#
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# check if there is more than OS, and GSMA running. exit if, unless -f is given
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if debug: 
    logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
    logging.info(f"#  check if there is more than OS, and GSMA running. exit if, unless -f is given ")
    logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")

c = wmi.WMI()
services_cnt = 0
query = f"SELECT * FROM Win32_Service where DisplayName like 'Monitoring Agent for%'"
services = c.query(query)
for service in services:
    text= "Service: {:60s} {:30s} {}".format(service.DisplayName,service.Name,service.State);logging.info(text)
    services_cnt += 1
    # print(services_cnt)

if services_cnt > 5:
    text= f"there are running {services_cnt} ITM agents. More than OS and GSMA ITM agents";logging.error(text);print(f"{text}")
    if forceInstall:
        text= f"force Install is set to {forceInstall}, so we continue to reinstall OS & GSMA ITM agents";logging.warning(text);print(f"{text}")        
    else:
        text= f"force Install is set to {forceInstall}, so we are exiting. To force a reinstall you have to set -f as argument";logging.error(text);print(f"{text}")       
        f_end(debug)
else:
    text= f"there are running {services_cnt} ITM agents as expected for only OS & GSMA";logging.info(text)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# stop agents if any is active
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
f_stopItmServices(debug)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# zip and save original config & scripts, to be restored after reinstall
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
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
# read rtems.csv. First check ports opened for either predefined or by environtment
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if debug: 
    logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
    logging.info(f"# read rtems.csv. First check ports opened for either predefined or by environtment")
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
    if debug: 
        logging.warning(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
        logging.warning(f"#  There is no ports opened for any of the RTEMS.")
        logging.warning(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
        print(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
        print(f"#  There is no ports opened for any of the RTEMS.")
        print(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
    
    f_end(debug)
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
# Uninstall & cleanup
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if debug: 
    logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
    logging.info(f"#  Uninstall & cleanup  ")
    logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")

# cmdexec = f'cmd /K {workdir}/ITMRmvAll.exe -batchrmvall -removegskit'
cmdexec = f'start /WAIT /MIN {workdir}/ITMRmvAll.exe -batchrmvall -removegskit'
result,rc = f_cmdexec(cmdexec,debug) 
if debug:
    logging.info(f"f_cmdexec rc: {rc}")
    logging.info(f"f_cmdexec result: {result}")
    for line in result:
        line = line.strip()
        logging.info(line)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# loop to wait before it is done
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
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
    text = f"Process {process_name} is not running."
    if debug: logging.info(f"{text}")
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
#
# install agents
#
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if debug: 
    logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
    logging.info(f"#  install agents  ")
    logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")

cmdexec = f"{ITM_zipdir}/ITM_win/instTEMA_win.cmd {ccode} {primary} {secondary}"
result,rc = f_cmdexec(cmdexec,debug) 
if debug:
    logging.info(f"f_cmdexec rc: {rc}")
    logging.info(f"f_cmdexec result: {result}")
    for line in result:
        line = line.strip()
        logging.info(line)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# stop agents if any is active
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
f_stopItmServices(debug)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# restore smitoolConfigZIP.zip & smitoolScriptZIP, after reinstall.
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if debug: 
    logging.info(f"# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  ")
    logging.info(f"#  zip and save original config & scripts, to be restored after reinstall  ")
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

f_startItmServices(debug)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# is services running
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
c = wmi.WMI()
query = f"SELECT * FROM Win32_Service where DisplayName like 'Monitoring Agent for%'"
services = c.query(query)
for service in services:
    serviceName = service.Name
    serviceState = service.State
    serviceType = service.StartMode    
    text= f"The service '{serviceName}' has status: '{serviceState}'. Startup Type is: '{serviceType}'"
    if debug: 
        logging.info(text)
        logging.info(str(service))
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# cleanup files
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
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
# set environtment
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if debug: 
    logging.info(f"show environtment ----------------------------------------------------------------------------------------------------------------------------------------------------------")
for name, value in os.environ.items():
    if debug:
        logging.info("{:30s} - {}".format(name,value))

paths = os.environ.get("PATH", "").split(";")
for p in paths:
    if debug:
        p = p.strip()
        if len(p) > 0: logging.info(p)               
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# THE END
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
f_end(debug)