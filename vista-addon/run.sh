#!/usr/bin/env bash

echo "============================================"
echo " VistA EHR Server - Home Assistant Add-on"
echo "============================================"

# Fix XQVOL/XUVOL/XUENV undefined errors in XUSRB/XUS1 before starting VistA
echo "Patching XUSRB.m and XUS1.m to fix login bugs..."
python3 /patch_xusrb.py 2>&1 || python /patch_xusrb.py 2>&1 || echo "Python patch failed"

# Fix GMTSOBJ temp file path to use /tmp/ instead of $$PWD^%ZISH (prevents IONOTOPEN crash)
echo "Patching GMTSOBJ.m to fix Health Summary temp file path..."
python3 /patch_gmtsobj.py 2>&1 || python /patch_gmtsobj.py 2>&1 || echo "GMTSOBJ patch failed"

# Remove compiled .o files for our patched routines so YottaDB recompiles from .m
echo "Removing stale .o files for patched routines..."
rm -f /home/vehu/r/r2.02_x86_64/PXRMEXIC.o \
      /home/vehu/r/r2.02_x86_64/PXRMEXIU.o \
      /home/vehu/r/r2.02_x86_64/PXRMEXU4.o \
      /home/vehu/r/r2.02_x86_64/GMTSOBJ.o \
      /home/vehu/s/r2.02_x86_64/PXRMEXIC.o \
      /home/vehu/s/r2.02_x86_64/PXRMEXIU.o \
      /home/vehu/s/r2.02_x86_64/PXRMEXU4.o \
      /home/vehu/s/r2.02_x86_64/GMTSOBJ.o \
      /home/vehu/p/r2.02_x86_64/PXRMEXIC.o \
      /home/vehu/p/r2.02_x86_64/PXRMEXIU.o \
      /home/vehu/p/r2.02_x86_64/PXRMEXU4.o \
      /home/vehu/p/r2.02_x86_64/GMTSOBJ.o 2>/dev/null
echo "Done."

# Find and run the original entrypoint (starts VistA, sshd, xinetd, etc.)
if [ -f /home/vehu/bin/start.sh ]; then
    # Start VistA in background so we can import PRD files after it's ready
    /home/vehu/bin/start.sh "$@" &
    VISTA_PID=$!
elif [ -f /entrypoint.sh ]; then
    /entrypoint.sh "$@" &
    VISTA_PID=$!
elif [ -f /home/vehu/entrypoint.sh ]; then
    /home/vehu/entrypoint.sh "$@" &
    VISTA_PID=$!
else
    echo "Could not find original entrypoint"
    /usr/sbin/sshd 2>/dev/null
    /usr/sbin/xinetd 2>/dev/null
    VISTA_PID=0
fi

# Helper: wait for VistA MUMPS to be ready
wait_for_vista() {
    echo "Waiting for VistA to start..."
    for i in $(seq 1 60); do
        if su - vehu -c 'source /home/vehu/etc/env && mumps -run %XCMD "W 1" 2>/dev/null' | grep -q "1"; then
            echo "VistA is ready after ${i}s"
            return 0
        fi
        sleep 2
    done
    echo "VistA did not start within 120s"
    return 1
}

# Import VAAES PRD files on first boot (only if not already done)
IMPORT_FLAG="/home/vehu/g/.prd_imported"
if [ -d /prd-files ] && [ "$(ls -A /prd-files/*.PRD 2>/dev/null)" ] && [ ! -f "$IMPORT_FLAG" ]; then
    echo ""
    echo "============================================"
    echo " Importing VAAES PRD files (first boot)..."
    echo "============================================"
    wait_for_vista
    sleep 5

    echo "Running PRD import via MUMPS prdimport routine..."
    if su - vehu -c 'source /home/vehu/etc/env && mumps -run %XCMD "D ALL^prdimport(\"/prd-files/\")"' 2>&1; then
        echo "MUMPS PRD import succeeded."
        touch "$IMPORT_FLAG"
    else
        echo "MUMPS PRD import returned non-zero, trying Python fallback..."
        if python3 /import_prd.py 2>&1; then
            echo "Python PRD import succeeded."
            touch "$IMPORT_FLAG"
        else
            echo "PRD import FAILED - will retry on next restart."
        fi
    fi
    echo "PRD import complete."
fi

# Always run TIU title setup and dialog linking (idempotent - safe to run every boot)
# This ensures VAAES nursing assessment titles exist and are linked to reminder dialogs
SETUP_FLAG="/home/vehu/g/.tiu_setup_done"
if [ -f /home/vehu/r/setupnote.m ] && [ -f /home/vehu/r/linkdlg.m ]; then
    # Only wait for VistA if we didn't already wait above
    if [ -f "$IMPORT_FLAG" ] || wait_for_vista; then
        sleep 2
        echo ""
        echo "============================================"
        echo " Setting up VAAES TIU note titles..."
        echo "============================================"
        su - vehu -c 'source /home/vehu/etc/env && mumps -run setupnote' 2>&1
        echo ""
        echo "============================================"
        echo " Linking VAAES titles to reminder dialogs..."
        echo "============================================"
        su - vehu -c 'source /home/vehu/etc/env && mumps -run linkdlg' 2>&1
        echo ""
        echo "============================================"
        echo " Authorizing VAAES reminder dialogs..."
        echo "============================================"
        su - vehu -c 'source /home/vehu/etc/env && mumps -run fixdlgauth' 2>&1
        touch "$SETUP_FLAG"
        echo "TIU setup complete."
    fi
fi

# Wait for VistA to keep running
if [ "$VISTA_PID" -gt 0 ] 2>/dev/null; then
    wait $VISTA_PID
else
    while true; do sleep 30; done
fi
