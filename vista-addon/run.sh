#!/usr/bin/env bash
# VistA EHR Server - Home Assistant add-on entrypoint.
# Every step below is idempotent and runs on EVERY boot, so a recreated container
# (add-on rebuild/update) restores the VAAES nursing content, note titles, dialog links,
# CP Flowsheets access and client-version override without manual work.

echo "============================================"
echo " VistA EHR Server - Home Assistant Add-on"
echo "============================================"

# Keep the database (g) and journals (j) in the add-on's persistent /data. Supervisor recreates the
# container from the image on every start, so without this every restart reset VistA to the image.
# Seeded from the image on first boot, or whenever vehu.dat is missing (e.g. restored from a backup,
# which excludes the database files).
PERSIST=/data/vista
if [ ! -f "$PERSIST/g/vehu.dat" ]; then
    echo "Seeding persistent VistA database into $PERSIST (first boot)..."
    rm -rf "$PERSIST" && mkdir -p "$PERSIST.tmp"
    cp -a /home/vehu/g /home/vehu/j "$PERSIST.tmp/" && mv "$PERSIST.tmp" "$PERSIST" || { echo "Seeding FAILED"; rm -rf "$PERSIST.tmp"; }
fi
if [ -f "$PERSIST/g/vehu.dat" ]; then
    for d in g j; do
        [ -L "/home/vehu/$d" ] || { rm -rf "/home/vehu/$d" && ln -s "$PERSIST/$d" "/home/vehu/$d"; }
    done
    echo "VistA database: $PERSIST (persistent)"
fi

echo "Patching XUSRB.m/XUS1.m (login) and GMTSOBJ.m (health summary temp path)..."
python3 /patch_xusrb.py 2>&1 || echo "patch_xusrb failed"
python3 /patch_gmtsobj.py 2>&1 || echo "patch_gmtsobj failed"

# Drop stale compiled objects for every routine we ship or patch so YottaDB recompiles from .m
for r in PXRMEXIC PXRMEXIU PXRMEXU4 GMTSOBJ XUSRB XUS1 prdimport vaaesfix setupnote linkdlg fixdlgauth mdclio cpfsver mhadll nbmcpset listusers; do
    rm -f /home/vehu/r/r2.02_x86_64/$r.o /home/vehu/s/r2.02_x86_64/$r.o /home/vehu/p/r2.02_x86_64/$r.o 2>/dev/null
done
chown vehu:vehu /home/vehu/r/*.m 2>/dev/null

# Docker sends SIGTERM to this script (PID 1), not to start.sh; shut VistA down cleanly ourselves.
shutdown_vista() {
    echo "Stopping VistA..."
    /etc/init.d/vehuvista stop
    [ -f /etc/init.d/vehuvista-ydbgui ] && /etc/init.d/vehuvista-ydbgui stop
    exit 0
}
trap shutdown_vista TERM INT

# Start VistA (original image entrypoint) in the background
if [ -f /home/vehu/bin/start.sh ]; then
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

# Run an M routine as vehu with the VistA environment, stdin closed (no interactive prompts)
mrun() {
    su - vehu -c "source /home/vehu/etc/env && cd /home/vehu && mumps -run $1" < /dev/null 2>&1
}

echo "Waiting for VistA to start..."
READY=0
for i in $(seq 1 90); do
    if su - vehu -c 'source /home/vehu/etc/env && mumps -run %XCMD "W 1" 2>/dev/null' | grep -q "1"; then
        echo "VistA is ready after $((i*2))s"
        READY=1
        break
    fi
    sleep 2
done
if [ "$READY" = "1" ]; then
    sleep 20   # let the listener, TaskMan and journaling settle before bulk installs

    echo ""
    echo "============================================"
    echo " VAAES reminder dialogs (install if missing)"
    echo "============================================"
    for attempt in 1 2 3; do
        OUT=$(mrun vaaesfix)
        echo "$OUT" | grep -v '^\s*$' | tail -8
        if echo "$OUT" | grep -q "VAAES DIALOGS OK"; then break; fi
        echo "Attempt $attempt did not complete; retrying in 30s..."
        sleep 30
    done

    echo ""
    echo "============================================"
    echo " Note titles, dialog links, dialog authorization"
    echo "============================================"
    mrun setupnote  | grep -v '^\s*$'
    mrun linkdlg    | grep -v '^\s*$' | grep -v GETLINK
    mrun fixdlgauth | grep -v '^\s*$' | grep -E "Dialog|REMDLGOK|Total"

    echo ""
    echo "============================================"
    echo " CP Flowsheets: MD CLIO menu option + client version override"
    echo "============================================"
    mrun mdclio  | grep -v '^\s*$'
    mrun cpfsver | grep -v '^\s*$'

    echo ""
    echo "============================================"
    echo " MHA instruments (Morse Fall Scale, Braden Scale): DLL name parameter"
    echo "============================================"
    mrun mhadll | grep -v '^\s*$'
    echo "Boot provisioning complete."
else
    echo "VistA did not start within 180s - skipping provisioning (will run on next boot)."
fi

# Keep the container alive with VistA
if [ "$VISTA_PID" -gt 0 ] 2>/dev/null; then
    wait $VISTA_PID
else
    while true; do sleep 30; done
fi
