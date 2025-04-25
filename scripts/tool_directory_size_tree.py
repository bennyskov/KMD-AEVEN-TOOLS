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
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
import warnings
import re
import yaml
import argparse
import psutil
from pathlib import Path
import heapq
import humanize
warnings.filterwarnings('ignore', 'This pattern is interpreted as a regular expression, and has match groups.')
global debug
debug = bool
debug = True
# ---------------------------------------------------------------------------------------------------------------------------------------
#
#   Directory Size Tree Tool - Scan drives and create directory size tree visualization
#
# ---------------------------------------------------------------------------------------------------------------------------------------
# Changelog:
#
# 2025-01-05    version V1.0    :   Initial release ( Benny.Skov@kyndryl.com )
# 2025-04-25    version V1.1    :   Added directory size tree functionality
#
# ---------------------------------------------------------------------------------------------------------------------------------------
# Description:
#   This script scans drives or specific directories and creates a visual tree representation of disk space usage.
#   It also reports the top largest directories and files to help identify space hogs.
#
# ---------------------------------------------------------------------------------------------------------------------------------------
# Usage Examples:
#
#   # Scan all drives with default depth (3)
#   python tool_directory_size_tree.py
#
#   # Scan specific path with depth 4
#   python tool_directory_size_tree.py -p "C:\Users" -d 4
#
#   # Scan all drives with depth 2 and show top 10 items
#   python tool_directory_size_tree.py -d 2 -t 10
#
#   # Enable debug logging
#   python tool_directory_size_tree.py --debug
#
# ---------------------------------------------------------------------------------------------------------------------------------------
# Parameters:
#
#   -p, --path    : Path to scan (if not provided, scan all drives)
#   -d, --depth   : Maximum depth for directory tree (default: 3)
#   -t, --top     : Number of top items to display (default: 5)
#   --debug       : Enable debug logging
#
# ---------------------------------------------------------------------------------------------------------------------------------------
# Output:
#   1. Console output with directory tree and top files/directories
#   2. JSON report saved to output directory
#
# ---------------------------------------------------------------------------------------------------------------------------------------

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
def f_set_logging(logfile,debug):
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
    f_log(f'Logging initialized. Writing to file',f'{logfile}',debug)

#endregion
#region f_dump_and_write
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# f_dump_and_write(result,stepName,debug)
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def f_dump_and_write(result,stepName, jsondir):
    job_json_file = f'{jsondir}/{stepName}.json'
    result_dumps = json.dumps(result, indent=5)
    # f_log(f'result_dumps',f'{result_dumps}',debug)
    fhandle = open(job_json_file, 'w', encoding='utf-8')
    fhandle.write(f"{result_dumps}")
    fhandle.close()
#endregion
#region f_end
def f_end(RC, debug):
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

#region get_drive_size
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# Get drive size and used space for all drives
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def get_drives():
    """Get all available drives on the system"""
    drives = []

    try:
        if platform.system() == 'Windows':
            # Get Windows drives
            for drive in psutil.disk_partitions(all=False):
                if drive.fstype and 'cdrom' not in drive.opts.lower():
                    drives.append(drive.mountpoint)
        else:
            # For Linux/Unix/MacOS
            for part in psutil.disk_partitions(all=False):
                if part.fstype and not part.mountpoint.startswith('/dev'):
                    drives.append(part.mountpoint)
    except Exception as e:
        f_log('Error getting drives', str(e), debug, 'ERROR')

    return drives
#endregion

#region scan_directory
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# Scan directory recursively and calculate sizes
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def scan_directory(path, max_depth=3, current_depth=0, file_sizes=None, dir_sizes=None):
    """
    Scan directory recursively and calculate sizes

    Args:
        path: Directory path to scan
        max_depth: Maximum depth to scan (default: 3)
        current_depth: Current scan depth
        file_sizes: Dictionary to store file sizes
        dir_sizes: Dictionary to store directory sizes

    Returns:
        total_size: Total size of the directory in bytes
    """
    if file_sizes is None:
        file_sizes = {}

    if dir_sizes is None:
        dir_sizes = {}

    # Print progress indicator
    if current_depth == 0:
        f_log(f"Scanning", f"{path}", debug, 'INFO')

    total_size = 0

    try:
        # Get directory content
        try:
            dir_content = list(os.scandir(path))
        except (PermissionError, OSError) as e:
            f_log(f"Permission denied: {path}", str(e), debug, 'DEBUG')
            # Store empty size for this directory and return
            dir_sizes[path] = 0
            return 0

        # Process all files first
        for entry in dir_content:
            if entry.is_file(follow_symlinks=False):
                try:
                    file_size = entry.stat(follow_symlinks=False).st_size
                    total_size += file_size
                    file_path = os.path.join(path, entry.name)
                    file_sizes[file_path] = file_size
                except (PermissionError, OSError):
                    # Silently ignore permission errors for individual files
                    pass

        # Then process subdirectories if not at max depth
        if current_depth < max_depth:
            for entry in dir_content:
                if entry.is_dir(follow_symlinks=False):
                    try:
                        subdir_path = entry.path
                        subdir_size = scan_directory(
                            subdir_path,
                            max_depth,
                            current_depth + 1,
                            file_sizes,
                            dir_sizes
                        )
                        total_size += subdir_size
                        dir_sizes[subdir_path] = subdir_size
                    except (PermissionError, OSError):
                        # Silently ignore permission errors when recursing
                        dir_sizes[entry.path] = 0

    except Exception as e:
        f_log(f"Error scanning directory {path}", str(e), debug, 'DEBUG')
        # Still store this path with zero size
        dir_sizes[path] = 0
        return 0

    # Store the total size for this directory
    dir_sizes[path] = total_size

    return total_size
#endregion

#region print_directory_tree
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# Print directory tree with sizes
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def print_directory_tree(path, dir_sizes, max_depth=3, current_depth=0):
    """
    Print directory tree with sizes

    Args:
        path: Directory path to print
        dir_sizes: Dictionary of directory sizes
        max_depth: Maximum depth to print
        current_depth: Current depth
    """
    if current_depth > max_depth:
        return

    # Calculate indentation
    indent = "│   " * current_depth

    # Get size for current directory
    size = dir_sizes.get(path, 0)
    human_size = humanize.naturalsize(size, binary=True)

    # Print current directory with size
    if current_depth == 0:
        f_log(f"Directory Tree", "", debug, 'INFO')
        # Use a bold effect for the root directory if possible
        print(f"\033[1m{path}\033[0m [{human_size}]")
    else:
        connector = "├── " if current_depth > 0 else ""
        if size > 1073741824:  # Highlight directories larger than 1GB
            print(f"{indent}{connector}\033[1;32m{os.path.basename(path)}\033[0m [{human_size}]")
        elif size > 104857600:  # Highlight directories larger than 100MB
            print(f"{indent}{connector}\033[0;32m{os.path.basename(path)}\033[0m [{human_size}]")
        else:
            print(f"{indent}{connector}{os.path.basename(path)} [{human_size}]")

    try:
        # Get subdirectories
        try:
            entries = list(os.scandir(path))
            # Get subdirectories
            subdirs = []
            for entry in entries:
                if entry.is_dir(follow_symlinks=False) and entry.path in dir_sizes:
                    subdirs.append((entry.path, dir_sizes[entry.path]))

            # Sort subdirectories by size (largest first)
            subdirs.sort(key=lambda x: x[1], reverse=True)

            # Print subdirectories
            for i, (subdir_path, _) in enumerate(subdirs):
                # Skip if we've reached max depth
                if current_depth + 1 > max_depth:
                    if i == 0 and subdirs:
                        next_indent = "│   " * current_depth
                        print(f"{next_indent}├── \033[0;36m...\033[0m")
                    break

                last_item = (i == len(subdirs) - 1)

                # Recursively print subdirectory tree
                print_directory_tree(subdir_path, dir_sizes, max_depth, current_depth + 1)

        except (PermissionError, OSError):
            next_indent = "│   " * current_depth
            print(f"{next_indent}├── \033[0;31m[ACCESS DENIED]\033[0m")

    except Exception as e:
        next_indent = "│   " * current_depth
        print(f"{next_indent}├── \033[0;31m[ERROR: {type(e).__name__}]\033[0m")
#endregion

#region print_top_items
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# Print top directories and files by size
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def print_top_items(dir_sizes, file_sizes, top_count=5):
    """
    Print top directories and files by size

    Args:
        dir_sizes: Dictionary of directory sizes
        file_sizes: Dictionary of file sizes
        top_count: Number of top items to print
    """
    f_log(f"Top {top_count} Largest Directories", "", debug, 'INFO')

    # Get top directories
    top_dirs = heapq.nlargest(top_count, dir_sizes.items(), key=lambda x: x[1])

    print("\n" + "=" * 80)
    print(f"TOP {top_count} LARGEST DIRECTORIES:")
    print("=" * 80)
    for i, (dir_path, size) in enumerate(top_dirs, 1):
        print(f"{i}. {dir_path}")
        print(f"   Size: {humanize.naturalsize(size, binary=True)}")

    # Get top files
    top_files = heapq.nlargest(top_count, file_sizes.items(), key=lambda x: x[1])

    print("\n" + "=" * 80)
    print(f"TOP {top_count} LARGEST FILES:")
    print("=" * 80)
    for i, (file_path, size) in enumerate(top_files, 1):
        print(f"{i}. {file_path}")
        print(f"   Size: {humanize.naturalsize(size, binary=True)}")
#endregion

#region generate_report
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# Generate disk space usage report
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
def generate_report(scan_path=None, max_depth=3, top_count=5):
    """
    Generate disk space usage report

    Args:
        scan_path: Path to scan (if None, scan all drives)
        max_depth: Maximum depth for directory tree
        top_count: Number of top items to display
    """
    f_log(f"Generating disk space report", "", debug, 'INFO')

    # Dictionary to store file and directory sizes
    file_sizes = {}
    dir_sizes = {}

    # Get drives to scan
    if scan_path:
        drives_to_scan = [scan_path]
    else:
        drives_to_scan = get_drives()
        f_log(f"Detected drives", f"{drives_to_scan}", debug, 'INFO')

    # Scan each drive
    for drive in drives_to_scan:
        try:
            f_log(f"Scanning drive", f"{drive}", debug, 'INFO')
            scan_directory(drive, max_depth, 0, file_sizes, dir_sizes)
        except Exception as e:
            f_log(f"Error scanning drive {drive}", str(e), debug, 'ERROR')

    # Print directory tree for each drive
    for drive in drives_to_scan:
        try:
            print("\n" + "=" * 80)
            print(f"DIRECTORY TREE FOR {drive} (MAX DEPTH: {max_depth})")
            print("=" * 80)
            print_directory_tree(drive, dir_sizes, max_depth)
        except Exception as e:
            f_log(f"Error printing directory tree for {drive}", str(e), debug, 'ERROR')

    # Print top directories and files
    print_top_items(dir_sizes, file_sizes, top_count)

    # Save results to JSON
    results = {
        "scan_time": datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        "max_depth": max_depth,
        "top_directories": [{"path": d, "size": s} for d, s in heapq.nlargest(top_count, dir_sizes.items(), key=lambda x: x[1])],
        "top_files": [{"path": f, "size": s} for f, s in heapq.nlargest(top_count, file_sizes.items(), key=lambda x: x[1])]
    }

    f_dump_and_write(results, "disk_space_report", jsondir)
    f_log(f"Report saved to", f"{jsondir}/disk_space_report.json", debug, 'INFO')
#endregion

#region main
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
# Main function
# ----------------------------------------------------------------------------------------------------------------------------------------------------------
if __name__ == "__main__":
    global logfile, scriptname
    global now, Logdate_long, jsondir, logdir
    nodename            = socket.gethostname().lower()
    CONTINUE            = True
    RC                  = 0
    scriptname          = sys.argv[0]
    scriptname          = scriptname.replace('\\','/').strip()
    scriptname          = scriptname.split('/')[-1]
    scriptname          = scriptname.split('.')[0]
    start               = time.time()
    now                 = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    Logdate_long        = datetime.now().strftime('%Y-%m-%d_%H-%M-%S_%f')
    project             = 'KMD-AEVEN-TOOLS'
    logdir              = f'D:/scripts/GIT/{project}/logs'
    jsondir             = f'D:/scripts/GIT/{project}/output'
    logfile             = f'{logdir}/{scriptname}_{Logdate_long}.log'

    # Create directories if they don't exist
    for directory in [logdir, jsondir]:
        if not os.path.exists(directory):
            os.makedirs(directory)

    if os.path.isfile(logfile): os.remove(logfile)
    f_set_logging(logfile, debug)

    # Parse command line arguments
    parser = argparse.ArgumentParser(description="Directory Size Tree - Scan drives and create directory size tree visualization")
    parser.add_argument("-p", "--path", help="Path to scan (if not provided, scan all drives)", default=None)
    parser.add_argument("-d", "--depth", help="Maximum depth for directory tree (default: 3)", type=int, default=3)
    parser.add_argument("-t", "--top", help="Number of top items to display (default: 5)", type=int, default=5)
    parser.add_argument("--debug", help="Enable debug logging", action="store_true")

    args = parser.parse_args()

    # Set debug based on command line argument
    if args.debug:
        debug = True
        f_log("Debug logging enabled", "", debug, 'INFO')

    # Log script start
    stepName = 'begin'
    f_log(f'{stepName}','',debug)
    f_log(f'nodename',f'{nodename}',debug)
    f_log(f'logdir',f'{logdir}',debug)
    f_log(f'logfile',f'{logfile}',debug)
    f_log(f'jsondir',f'{jsondir}',debug)
    f_log(f'scriptname',f'{scriptname}',debug)
    f_log(f'scan path',f'{args.path if args.path else "All drives"}',debug)
    f_log(f'max depth',f'{args.depth}',debug)
    f_log(f'top count',f'{args.top}',debug)
    f_log(f'debug',f'{debug}',debug)

    # Generate report
    if CONTINUE:
        stepName = 'disk_space_scan'
        f_log(f'{stepName}','',debug)

        try:
            # Check if humanize package is installed
            try:
                import humanize
            except ImportError:
                f_log("Installing required package: humanize", "", debug, 'INFO')
                subprocess.check_call([sys.executable, "-m", "pip", "install", "humanize"])
                import humanize

            generate_report(args.path, args.depth, args.top)
            f_log("Disk space scan completed successfully", "", debug, 'INFO')
        except Exception as e:
            f_log("Error during disk space scan", str(e), debug, 'ERROR')
            RC = 1

    # End script
    f_end(RC, debug)
#endregion