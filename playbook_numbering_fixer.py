#!/usr/bin/env python3
"""
Ansible Playbook Numbering Fixer

This script automatically renumbers plays and tasks in Ansible playbooks
according to the specified convention from the project directive.

Features:
- Fixes numbering of plays and tasks in all playbooks
- Generates a report of changes made
- Preserves formatting and comments
- Handles both single-file and batch processing

Usage:
    python playbook_numbering_fixer.py [--dry-run] [--verbose] [path/to/playbook.yml]
"""

import argparse
import os
import re
import sys
from pathlib import Path
import yaml

# ANSI color codes for terminal output
class Colors:
    RESET = '\033[0m'
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'

def colorize(text, color):
    """Add color to terminal text."""
    return f"{color}{text}{Colors.RESET}"

def parse_arguments():
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description='Fix Ansible playbook numbering.')
    parser.add_argument('path', nargs='?', default='.',
                        help='Path to YAML file or directory (default: current directory)')
    parser.add_argument('--dry-run', action='store_true',
                        help='Show changes without modifying files')
    parser.add_argument('--verbose', action='store_true',
                        help='Show detailed information about each change')
    return parser.parse_args()

def is_ansible_playbook(file_path):
    """Check if a file appears to be an Ansible playbook."""
    if not (file_path.endswith('.yml') or file_path.endswith('.yaml')):
        return False

    # Check if the file is in the archive directory
    if 'archive' in Path(file_path).parts:
        return False

    # Read the first few lines to see if it looks like a playbook
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read(4096)  # Read first 4KB
            # Look for common playbook indicators
            return ('hosts:' in content or
                    'tasks:' in content or
                    '- name:' in content)
    except Exception:
        return False

def find_playbook_files(path):
    """Find all Ansible playbook files in the specified path."""
    path = Path(path)
    if path.is_file():
        return [path] if is_ansible_playbook(path) else []

    playbooks = []
    for root, _, files in os.walk(path):
        for file in files:
            file_path = Path(root) / file
            if is_ansible_playbook(file_path):
                playbooks.append(file_path)
    return playbooks

def parse_playbook(file_path):
    """
    Parse an Ansible playbook and extract its structure with detailed position information.
    Returns a structure that can be used for precise text replacement.
    """
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    lines = content.splitlines()
    result = {
        'file_path': file_path,
        'content': content,
        'lines': lines,
        'plays': []
    }

    # Find top-level plays and their tasks
    play_pattern = re.compile(r'^- name:\s*[\'"](.+?)[\'"]')
    play_index = -1
    task_index = -1
    in_tasks_section = False

    for line_number, line in enumerate(lines):
        line_stripped = line.strip()
        indent = len(line) - len(line.lstrip())

        # Skip comments and empty lines
        if not line_stripped or line_stripped.startswith('#'):
            continue

        # Check for a new top-level play
        if indent == 0 and line_stripped.startswith('- name:'):
            play_match = play_pattern.match(line_stripped)
            if play_match:
                play_name = play_match.group(1)
                play_index += 1
                task_index = -1
                in_tasks_section = False

                result['plays'].append({
                    'name': play_name,
                    'line_number': line_number,
                    'line': line,
                    'tasks': [],
                    'tasks_section_line': None
                })

        # Check for the tasks section
        elif line_stripped == 'tasks:':
            if play_index >= 0:
                result['plays'][play_index]['tasks_section_line'] = line_number
                in_tasks_section = True

        # Check for tasks within the tasks section
        elif in_tasks_section and line_stripped.startswith('- name:'):
            task_match = play_pattern.match(line_stripped)
            if task_match and play_index >= 0:
                task_name = task_match.group(1)
                task_index += 1

                # Determine if it's an include_role task
                is_include_role = False
                # Look ahead for include_role
                for i in range(line_number + 1, min(line_number + 5, len(lines))):
                    if 'include_role:' in lines[i]:
                        is_include_role = True
                        break

                result['plays'][play_index]['tasks'].append({
                    'name': task_name,
                    'line_number': line_number,
                    'line': line,
                    'indent': indent,
                    'is_include_role': is_include_role
                })

    return result

def fix_numbering(playbook):
    """
    Fix the numbering of plays and tasks in a playbook.
    Returns a list of changes to be made.
    """
    changes = []

    # Start with play numbering
    play_number = 1
    play_letter = 'A'

    for play_index, play in enumerate(playbook['plays']):
        # Extract current play name and check format
        current_play_name = play['name']
        current_line = play['line']

        # Parse the current play name to extract description
        play_name_match = re.match(r'^\d+\.[A-Z]\s+-\s+(.+)$', current_play_name)
        play_desc = play_name_match.group(1) if play_name_match else current_play_name

        # Create the correctly numbered play name
        new_play_name = f"{play_number}.{play_letter} - {play_desc}"

        # Check if the name needs changing
        if new_play_name != current_play_name:
            # Create the replacement line
            quote_char = current_line[current_line.find(current_play_name) - 1]  # ' or "
            new_line = current_line.replace(
                f"name: {quote_char}{current_play_name}{quote_char}",
                f"name: {quote_char}{new_play_name}{quote_char}"
            )

            changes.append({
                'line_number': play['line_number'],
                'old_line': current_line,
                'new_line': new_line,
                'old_name': current_play_name,
                'new_name': new_play_name,
                'type': 'play'
            })

        # Now process tasks within this play
        task_number = 0
        last_base_task_number = -1
        subtask_letter = 'a'

        for task_index, task in enumerate(play['tasks']):
            current_task_name = task['name']
            current_line = task['line']

            # Skip include_role tasks if needed, but still check their prefix
            if task['is_include_role']:
                # Ensure it has the correct play prefix, but keep its task number
                task_name_match = re.match(r'^\d+\.[A-Z]\.(\d{2})([a-z]?)\s+-\s+(.+)$', current_task_name)
                if task_name_match:
                    task_num, task_subletter, task_desc = task_name_match.groups()

                    # Only fix the play prefix part, keep the task numbers
                    new_task_name = f"{play_number}.{play_letter}.{task_num}{task_subletter or ''} - {task_desc}"

                    if new_task_name != current_task_name:
                        quote_char = current_line[current_line.find(current_task_name) - 1]
                        new_line = current_line.replace(
                            f"name: {quote_char}{current_task_name}{quote_char}",
                            f"name: {quote_char}{new_task_name}{quote_char}"
                        )

                        changes.append({
                            'line_number': task['line_number'],
                            'old_line': current_line,
                            'new_line': new_line,
                            'old_name': current_task_name,
                            'new_name': new_task_name,
                            'type': 'task'
                        })
                continue

            # Check if this is a subtask (has same base number as previous)
            task_name_match = re.match(r'^\d+\.[A-Z]\.(\d{2})([a-z]?)\s+-\s+(.+)$', current_task_name)
            is_subtask = False

            if task_name_match:
                task_num_str, task_subletter, task_desc = task_name_match.groups()
                task_num = int(task_num_str)

                # If this has the same number as the previous task, it's a subtask
                if task_num == last_base_task_number and task_subletter:
                    is_subtask = True
                    subtask_letter = task_subletter
            else:
                # If not matching the expected format, extract description directly
                task_desc = current_task_name

            if is_subtask:
                # For subtasks, keep the same base number but ensure proper lettering
                new_task_name = f"{play_number}.{play_letter}.{last_base_task_number:02d}{subtask_letter} - {task_desc}"
                # Next subtask would use next letter
                subtask_letter = chr(ord(subtask_letter) + 1)
            else:
                # Regular task - use the next number in sequence
                new_task_name = f"{play_number}.{play_letter}.{task_number:02d} - {task_desc}"
                last_base_task_number = task_number
                task_number += 1
                subtask_letter = 'a'  # Reset subtask lettering

            # Check if the name needs changing
            if new_task_name != current_task_name:
                quote_char = current_line[current_line.find(current_task_name) - 1]
                new_line = current_line.replace(
                    f"name: {quote_char}{current_task_name}{quote_char}",
                    f"name: {quote_char}{new_task_name}{quote_char}"
                )

                changes.append({
                    'line_number': task['line_number'],
                    'old_line': current_line,
                    'new_line': new_line,
                    'old_name': current_task_name,
                    'new_name': new_task_name,
                    'type': 'task'
                })

        # Increment for next play
        play_number += 1
        play_letter = chr(ord(play_letter) + 1)

    return changes

def apply_changes(playbook, changes):
    """Apply the changes to the playbook content."""
    lines = playbook['lines'].copy()

    # Sort changes by line number in reverse order to avoid messing up line numbers
    changes.sort(key=lambda x: x['line_number'], reverse=True)

    for change in changes:
        lines[change['line_number']] = change['new_line']

    return '\n'.join(lines)

def write_fixed_playbook(file_path, content):
    """Write the fixed content back to the playbook file."""
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

def report_changes(playbook, changes, args):
    """Report changes to be made to the playbook."""
    file_path = playbook['file_path']

    if not changes:
        if args.verbose:
            print(colorize(f"✓ {file_path}: No numbering changes needed", Colors.GREEN))
        return

    play_changes = [c for c in changes if c['type'] == 'play']
    task_changes = [c for c in changes if c['type'] == 'task']

    print(colorize(f"⚠ {file_path}: {len(play_changes)} play(s) and {len(task_changes)} task(s) need renumbering",
                  Colors.YELLOW))

    if args.verbose:
        for change in changes:
            line_number = change['line_number'] + 1  # 1-based line number for display
            change_type = "Play" if change['type'] == 'play' else "Task"

            print(f"  Line {line_number} ({change_type}):")
            print(f"    {colorize('Old:', Colors.RED)} {change['old_name']}")
            print(f"    {colorize('New:', Colors.GREEN)} {change['new_name']}")
            print()

def main():
    args = parse_arguments()
    path = args.path

    # Find all playbook files
    playbook_files = find_playbook_files(path)

    if not playbook_files:
        print(colorize(f"No Ansible playbook files found in {path}", Colors.YELLOW))
        return 1

    # Process each playbook
    total_changes = 0
    fixed_files = 0

    for file_path in playbook_files:
        try:
            # Parse playbook and find numbering issues
            playbook = parse_playbook(file_path)
            changes = fix_numbering(playbook)
            total_changes += len(changes)

            # Report changes
            report_changes(playbook, changes, args)

            # Apply changes if not in dry run mode
            if changes and not args.dry_run:
                fixed_content = apply_changes(playbook, changes)
                write_fixed_playbook(file_path, fixed_content)
                fixed_files += 1
                print(colorize(f"✓ Fixed {len(changes)} numbering issues in {file_path}", Colors.GREEN))
        except Exception as e:
            print(colorize(f"❌ Error processing {file_path}: {str(e)}", Colors.RED))

    # Summary
    if total_changes > 0:
        print(colorize(f"\nFound {total_changes} numbering issues in {len(playbook_files)} playbooks",
                      Colors.YELLOW))
        if not args.dry_run:
            print(colorize(f"Fixed {fixed_files} playbooks", Colors.GREEN))
        else:
            print(colorize("Dry run mode - no files were modified", Colors.CYAN))
            print(colorize("Run without --dry-run to apply fixes", Colors.YELLOW))
    else:
        print(colorize(f"\nAll {len(playbook_files)} playbooks follow the numbering convention", Colors.GREEN))

    return 0 if total_changes == 0 or (not args.dry_run) else 1

if __name__ == "__main__":
    sys.exit(main())
