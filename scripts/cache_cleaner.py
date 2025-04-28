#!/usr/bin/env python
# filepath: d:\scripts\GIT\KMD-AEVEN-TOOLS\scripts\cache_cleaner.py
import os
import sys
import shutil
import platform
import argparse
from datetime import datetime
import logging
from pathlib import Path

# Set up logging
def setup_logging(debug=False):
    log_level = logging.DEBUG if debug else logging.INFO
    logging.basicConfig(
        level=log_level,
        format="%(asctime)s - %(levelname)s - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )
    return logging.getLogger()

def get_cache_paths(username=None):
    """Get the default VS Code Insiders cache paths based on platform and username"""
    system = platform.system()
    paths = []

    if system == "Windows":
        # If username is provided, use it; otherwise use the current user
        if not username:
            username = os.environ.get("USERNAME")

        cached_data_path = Path(f"C:\\Users\\{username}\\AppData\\Roaming\\Code - Insiders\\CachedData")
        cache_data_path = Path(f"C:\\Users\\{username}\\AppData\\Roaming\\Code - Insiders\\Cache\\Cache_Data")

        paths.append(cached_data_path)
        paths.append(cache_data_path)

    elif system == "Darwin":  # macOS
        if not username:
            username = os.environ.get("USER")

        cached_data_path = Path(f"/Users/{username}/Library/Application Support/Code - Insiders/CachedData")
        cache_data_path = Path(f"/Users/{username}/Library/Application Support/Code - Insiders/Cache/Cache_Data")

        paths.append(cached_data_path)
        paths.append(cache_data_path)

    elif system == "Linux":
        if not username:
            username = os.environ.get("USER")

        cached_data_path = Path(f"/home/{username}/.config/Code - Insiders/CachedData")
        cache_data_path = Path(f"/home/{username}/.config/Code - Insiders/Cache/Cache_Data")

        paths.append(cached_data_path)
        paths.append(cache_data_path)

    return paths

def clear_cache(paths, logger, dry_run=False):
    """Delete files in the specified paths"""
    total_size = 0
    total_files = 0
    stats = {}
    has_errors = False

    for path in paths:
        if not path.exists():
            logger.warning(f"Path does not exist: {path}")
            continue

        logger.info(f"Processing directory: {path}")
        dir_size = 0
        dir_files = 0
        dir_errors = 0

        try:
            # Count files first (for both dry run and actual deletion)
            for item in path.glob("**/*"):
                if item.is_file():
                    try:
                        dir_size += item.stat().st_size
                        dir_files += 1
                    except PermissionError:
                        logger.warning(f"Permission denied when accessing: {item}")
                        dir_errors += 1
                    except Exception as e:
                        logger.warning(f"Error accessing {item}: {e}")
                        dir_errors += 1

            # Delete files if not in dry run mode
            if not dry_run:
                # Delete files and folders inside but keep the directory
                for item in path.iterdir():
                    try:
                        if item.is_file():
                            item.unlink(missing_ok=True)
                        elif item.is_dir():
                            shutil.rmtree(item, ignore_errors=True)
                    except PermissionError:
                        logger.warning(f"Permission denied when deleting: {item}")
                        dir_errors += 1
                    except Exception as e:
                        logger.warning(f"Error deleting {item}: {e}")
                        dir_errors += 1

                if dir_errors > 0:
                    has_errors = True
                logger.info(f"Cleared {dir_files} files ({dir_size / (1024 * 1024):.2f} MB) from {path} with {dir_errors} errors")
            else:
                logger.info(f"[DRY RUN] Would clear {dir_files} files ({dir_size / (1024 * 1024):.2f} MB) from {path}")

            total_size += dir_size
            total_files += dir_files
            stats[str(path)] = {
                "files": dir_files,
                "size_mb": dir_size / (1024 * 1024),
                "errors": dir_errors
            }

        except Exception as e:
            has_errors = True
            logger.error(f"Error processing {path}: {e}")

    action = "Would clear" if dry_run else "Cleared"
    logger.info(f"{action} a total of {total_files} files ({total_size / (1024 * 1024):.2f} MB)")
    return stats, has_errors

def main():
    parser = argparse.ArgumentParser(description="VS Code Insiders Cache Cleaner")
    parser.add_argument("-u", "--username", help="Specify the username for cache paths")
    parser.add_argument("-p", "--paths", nargs="+", help="Custom paths to clear")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be deleted without deleting")
    parser.add_argument("--debug", action="store_true", help="Enable debug logging")
    parser.add_argument("--force", action="store_true", help="Return success (0) even if some files could not be deleted")
    args = parser.parse_args()

    logger = setup_logging(args.debug)
    logger.info(f"VS Code Insiders Cache Cleaner started at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    if args.paths:
        paths = [Path(p) for p in args.paths]
        logger.info(f"Using custom paths: {', '.join(str(p) for p in paths)}")
    else:
        paths = get_cache_paths(args.username)
        logger.info(f"Using default VS Code Insiders cache paths for {args.username or 'current user'}")

    # Log the paths that will be cleared
    for path in paths:
        logger.info(f"Target path: {path}")

    stats, has_errors = clear_cache(paths, logger, args.dry_run)

    logger.info("Cache cleaning completed")

    # Return appropriate exit code
    if has_errors and not args.force:
        logger.warning("Some files could not be deleted. Use --force to ignore these errors.")
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main())
