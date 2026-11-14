#!/usr/bin/env python3
"""Fix VistA RPC Broker login undefined variable errors.

Patches specific functions that use undefined Kernel environment vars:
1. XUSRB.m INHIB1 - uses XQVOL
2. XUSRB.m INHIB2 - uses XUVOL
3. XUS1.m LOG - uses XUENV, XUVOL, XUDEV, XUCI
"""
import glob
import os

def find_routine(name):
    for pattern in [f'/home/vehu/r/{name}.m', f'/home/vehu/r/{name.upper()}.m']:
        matches = glob.glob(pattern)
        if matches:
            return matches[0]
    for root, dirs, files in os.walk('/home/vehu/r'):
        for f in files:
            if f.upper() == f'{name.upper()}.M':
                return os.path.join(root, f)
    return None

def remove_object(name):
    for root, dirs, files in os.walk('/home/vehu'):
        for f in files:
            if f.upper() == f'{name.upper()}.O':
                path = os.path.join(root, f)
                os.remove(path)
                print(f"  Removed {path}")

# ========================================
# Patch XUSRB.m - INHIB1 (XQVOL) and INHIB2 (XUVOL)
# ========================================
print("=== Patching XUSRB.m ===")
xusrb = find_routine('XUSRB')
if xusrb:
    print(f"Found: {xusrb}")
    with open(xusrb, 'r') as f:
        lines = f.readlines()
    new_lines = []
    count = 0
    for i, line in enumerate(lines):
        new_lines.append(line)
        if line.strip().startswith('INHIB1()') and (i+1 >= len(lines) or 'D(XQVOL)' not in lines[i+1]):
            new_lines.append(' S:\'$D(XQVOL) XQVOL="ROU"\n')
            count += 1
            print(f"  Fixed INHIB1 at line {i+1}")
        if line.strip().startswith('INHIB2()') and (i+1 >= len(lines) or 'D(XUVOL)' not in lines[i+1]):
            new_lines.append(' S:\'$D(XUVOL) XUVOL=""\n')
            count += 1
            print(f"  Fixed INHIB2 at line {i+1}")
    if count:
        with open(xusrb, 'w') as f:
            f.writelines(new_lines)
        remove_object('XUSRB')
        print(f"  Patched {count} locations")
    else:
        print("  Already patched")
else:
    print("ERROR: XUSRB.m not found!")

# ========================================
# Patch XUS1.m - LOG function uses XUENV, XUVOL, XUDEV, XUCI
# ========================================
print("\n=== Patching XUS1.m ===")
xus1 = find_routine('XUS1')
if xus1:
    print(f"Found: {xus1}")
    with open(xus1, 'r') as f:
        lines = f.readlines()

    # Find the LOG label (it's "LOG ;" or "LOG;", NOT "LOG(")
    new_lines = []
    count = 0
    for i, line in enumerate(lines):
        new_lines.append(line)
        # Match "LOG" at start of line followed by space or semicolon
        stripped = line.rstrip()
        if (stripped == 'LOG' or stripped.startswith('LOG ') or stripped.startswith('LOG;')):
            if i+1 < len(lines) and 'D(XUENV)' not in lines[i+1] and 'D(XUVOL)' not in lines[i+1]:
                # Insert defaults for all vars used in LOG+3
                fix = ' S:\'$D(XUENV) XUENV="" S:\'$D(XUVOL) XUVOL="" S:\'$D(XUDEV) XUDEV="" S:\'$D(XUCI) XUCI=""\n'
                new_lines.append(fix)
                count += 1
                print(f"  Fixed LOG at line {i+1}: {stripped}")

    if count:
        with open(xus1, 'w') as f:
            f.writelines(new_lines)
        remove_object('XUS1')
        print(f"  Patched {count} locations")
    else:
        print("  Already patched or not found")
        # Debug: show what labels exist
        for i, line in enumerate(lines):
            if line.startswith('LOG'):
                print(f"  Found label at {i+1}: {line.rstrip()}")
else:
    print("ERROR: XUS1.m not found!")

print("\n=== All patches complete ===")
