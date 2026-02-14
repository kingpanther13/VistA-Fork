#!/usr/bin/env python3
"""Patch GMTSOBJ.m to use /tmp/ for temp files instead of $$PWD^%ZISH.

Fixes IONOTOPEN crash in GMTS1 when the RPC broker process's current
working directory is not writable by the vehu user.
"""
import os
import sys

ROUTINE = "/home/vehu/r/GMTSOBJ.m"
OLD = 'GMTSPATH=$$PWD^%ZISH'
NEW = 'GMTSPATH="/tmp/"'

# Also delete stale compiled .o so YottaDB recompiles from patched .m
OBJ_DIRS = [
    "/home/vehu/r/r2.02_x86_64",
    "/home/vehu/s/r2.02_x86_64",
    "/home/vehu/p/r2.02_x86_64",
]

def main():
    # Delete stale .o files
    for d in OBJ_DIRS:
        o_file = os.path.join(d, "GMTSOBJ.o")
        if os.path.exists(o_file):
            os.remove(o_file)
            print("Deleted " + o_file)

    if not os.path.exists(ROUTINE):
        print("GMTSOBJ.m not found at " + ROUTINE)
        return 1

    with open(ROUTINE, "r") as f:
        content = f.read()

    if NEW in content:
        print("GMTSOBJ.m already patched.")
        return 0

    if OLD not in content:
        print("WARNING: Pattern not found in GMTSOBJ.m: " + OLD)
        return 1

    content = content.replace(OLD, NEW)
    with open(ROUTINE, "w") as f:
        f.write(content)

    print("Patched GMTSOBJ.m: " + OLD + " -> " + NEW)
    return 0

if __name__ == "__main__":
    sys.exit(main() or 0)
