# VistA EHR Server

Runs FOIA VistA with the VEHU training database (worldvista/vehu) plus the VAAES nursing
reminder dialogs. Everything the boot script provisions is idempotent and re-runs on every
start, so an add-on rebuild or update self-heals without manual steps:

- Imports and installs the VAAES PRD bundles (shift assessment, IV insert/maintain, skin assessment)
- Creates the CPRS note titles and links them to the reminder dialogs
- Authorizes the dialogs for TIU templates
- Grants the `MD CLIO` option (CP Flowsheets) to the demo users
- Sets the required CP Flowsheets client version to the public 1.0.63.2 build
- Sets `YS MHA_A DLL NAME` to `YS_MHA_A_XE10.dll` so Morse Fall Scale / Braden Scale open from the dialogs
- Patches XUSRB/XUS1 (login) and GMTSOBJ (health summary temp path)

The database and journals live in the add-on's persistent `/data/vista` (seeded from the image on
first boot), so restarts, rebuilds and updates keep your data. They are excluded from HA backups;
restoring a backup re-seeds a fresh database and re-provisions it.

## Clients (Windows)

- **CPRS**: use the WorldVistA build matching the VEHU image (the pinned 202609 image needs 1.33.214.5):
  `https://code.worldvista.org/files/clients/OSEHRA_VistA/CPRS/`
  Shortcut target: `CPRSChart.exe s=<HA IP> p=9430`
- **CP Flowsheets**: public build 1.0.63.2 (`MD_1_63_scrubbed.zip` on the FOIA mirror). The VA
  build uses the VA broker cipher; patch its 20-row cipher table to the FOIA table (same one
  embedded in the WorldVistA CPRS build) or it reports "Not a valid ACCESS CODE/VERIFY CODE pair".
  Shortcut target: `CPFlowsheets.exe s=<HA IP> p=9430`

## Demo logins (VEHU)

| User            | Access   | Verify    |
|-----------------|----------|-----------|
| PROGRAMMER,ONE  | PRO1234  | PRO1234!! |
| TDNURSE,ONE     | 1TDNURSE | BDNURSE1! |
| PROVIDER,VERO   | CAS123   | CAS123..  |
| VEHU,TEN        | 10VEHU   | QXYG~011  |

Electronic signature for all: `123456`. Full list is shown on the sign-on screen.

## VAAES shift assessment in CPRS

Notes tab, New Note, type `VAAES` in the title box and pick
**VAAES ACUTE INPT NSG SHIFT ASSESSMENT**. The reminder dialog opens on selection.

## Ports

- **9430**: RPC Broker (CPRS, CP Flowsheets)
- **2222**: SSH into the VistA container (`vehu`/`vehu`)
- **8001**: VistA web interface
- **8089**: YottaDB GUI

## Optional: NursingBooster MCP bridge

`mumps -run nbmcpset` (as `vehu`, not run at boot) creates the `NB MCP BRIDGE` broker context
option and COM object and assigns them to TDNURSE,ONE.
