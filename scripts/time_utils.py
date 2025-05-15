"""
Time utilities module to avoid time module shadowing issues.
"""
import time as _time  # Import with underscore to avoid namespace pollution

def time():
    """Get current time in seconds since epoch."""
    return _time.time()

def sleep(seconds):
    """Sleep for the specified number of seconds."""
    _time.sleep(seconds)
