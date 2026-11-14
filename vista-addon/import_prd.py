#!/usr/bin/env python3
"""Import VAAES PRD files into VistA using the prdimport MUMPS routine.

This script runs inside the VistA Docker container. It calls the
prdimport.m routine which uses VistA's native Reminder Exchange
infrastructure (PXRMEXHF/PXRMEXSI) to load and install PRD files.

Must run as the vehu user with VistA environment sourced.
"""
import subprocess
import os
import sys
import glob

PRD_DIR = '/prd-files'


def find_prd_files():
    """Find all .PRD files."""
    files = glob.glob(os.path.join(PRD_DIR, '*.PRD'))
    files += glob.glob(os.path.join(PRD_DIR, '*.prd'))
    return sorted(set(files))


def import_all_prd():
    """Import all PRD files using the prdimport MUMPS routine."""
    print("Calling D ALL^prdimport to import all PRD files...")

    # The prdimport routine handles everything:
    # - Finds PRD files in the directory
    # - Loads each into the Exchange File (811.8) using %ZISH and LTMP
    # - Installs all components using INSTALL^PXRMEXSI (silent installer)
    cmd = (
        'source /home/vehu/etc/env && '
        'mumps -run %XCMD \'D ALL^prdimport("/prd-files/")\''
    )

    result = subprocess.run(
        ['bash', '-c', cmd],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        universal_newlines=True, timeout=600,
        cwd='/home/vehu'
    )

    print("STDOUT:", result.stdout)
    if result.stderr:
        print("STDERR:", result.stderr)
    print("Return code: {}".format(result.returncode))

    return result.returncode == 0


def import_single_prd(filepath):
    """Import a single PRD file using the prdimport MUMPS routine."""
    dirpath = os.path.dirname(filepath) + '/'
    filename = os.path.basename(filepath)
    print(f"Importing: {filename} from {dirpath}")

    cmd = (
        'source /home/vehu/etc/env && '
        f'mumps -run %XCMD \'D EN^prdimport("{dirpath}","{filename}")\''
    )

    result = subprocess.run(
        ['bash', '-c', cmd],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        universal_newlines=True, timeout=300,
        cwd='/home/vehu'
    )

    print("STDOUT:", result.stdout)
    if result.stderr:
        print("STDERR:", result.stderr)

    return result.returncode == 0


def main():
    prd_files = find_prd_files()

    if not prd_files:
        print(f"No PRD files found in {PRD_DIR}")
        print("Place .PRD files in /prd-files/ and run again.")
        return

    print(f"Found {len(prd_files)} PRD file(s):")
    for f in prd_files:
        print(f"  {os.path.basename(f)} ({os.path.getsize(f)} bytes)")

    # Use the batch import - it handles all files at once
    success = import_all_prd()

    if not success:
        print("\nBatch import may have had issues. Trying individual files...")
        for filepath in prd_files:
            try:
                ok = import_single_prd(filepath)
                status = "SUCCESS" if ok else "WARNING"
                print(f"  {status}: {os.path.basename(filepath)}")
            except subprocess.TimeoutExpired:
                print(f"  TIMEOUT: {os.path.basename(filepath)}")
            except Exception as e:
                print(f"  ERROR: {os.path.basename(filepath)}: {e}")

    print(f"\n{'='*60}")
    print("PRD import complete.")
    print("Verify in CPRS: Tools > Reminders > Reminder Dialogs")
    print(f"{'='*60}")


if __name__ == '__main__':
    main()
