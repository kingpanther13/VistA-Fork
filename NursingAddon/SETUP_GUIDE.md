# CPRS Nursing Addon - Local Setup & Development Guide

A guide for setting up a local CPRS + VistA development environment and building
a nursing-focused automation addon (similar to CPRSBooster but tailored for
nursing workflows like reminder dialogues, note templates, and shift assessments).

---

## Table of Contents

1. [Quick Start: Docker VistA + CPRS](#1-quick-start-docker-vista--cprs)
2. [Understanding the Architecture](#2-understanding-the-architecture)
3. [What Clinical Content You Get (and Don't Get)](#3-what-clinical-content-you-get-and-dont-get)
4. [Importing Nursing Content (Reminder Exchange)](#4-importing-nursing-content-reminder-exchange)
5. [Addon Architecture: How to Automate CPRS Without Getting Flagged](#5-addon-architecture-how-to-automate-cprs-without-getting-flagged)
6. [Approach A: AutoHotkey 2.0 (CPRSBooster Model)](#6-approach-a-autohotkey-20-cprsbooster-model)
7. [Approach B: PowerShell + UI Automation](#7-approach-b-powershell--ui-automation)
8. [Approach C: RPC Broker Direct (Advanced)](#8-approach-c-rpc-broker-direct-advanced)
9. [Nursing Workflows to Automate](#9-nursing-workflows-to-automate)
10. [VA Compliance & TRM Notes](#10-va-compliance--trm-notes)
11. [Resources & References](#11-resources--references)

---

## 1. Quick Start: Docker VistA + CPRS

### Prerequisites

- **Windows machine** (or VM) for CPRS client -- CPRS is a native Win32 Delphi app
- **Docker** on any machine (Linux/Mac/Windows) for the VistA server
- Network connectivity between the two (localhost works if both on same machine)

### Step 1: Start the VistA Server

```powershell
# Pull and run the VEHU (VistA eHealth University) training image
# This comes pre-loaded with synthetic patients and clinical config
docker run -d `
  -p 9430:9430 `
  -p 8001:8001 `
  -p 2222:22 `
  --name vehu `
  worldvista/vehu:latest
```

Alternative images:
```powershell
# WorldVistA EHR (more clinical content, production-like)
docker run -d -p 9430:9430 --name worldvista worldvista/worldvista-ehr:latest

# OSEHRA VistA (minimal, closer to this repo's source)
docker run -d -p 9430:9430 --name osehra osehra/osehravista:latest
```

### Step 2: Get CPRS Client

**Option A** -- Download pre-built:
- WorldVistA releases: https://github.com/WorldVistA/VistA/releases
- OSEHRA CPRS builds: https://code.osehra.org/files/clients/

**Option B** -- Compile from this repo's source (requires Delphi RAD Studio):
- Source is at: `Packages/Order Entry Results Reporting/CPRS/CPRS-Chart/CPRSChart.dpr`
- This is CPRS v1.33.112.1 (patch OR*3.0*629)

### Step 3: Connect CPRS to Your Local VistA

```powershell
# Launch CPRS pointing at your Docker VistA server
.\CPRSChart.exe s=127.0.0.1 p=9430
```

Or create a shortcut with those parameters in the Target field.

### Step 4: Log In

VEHU demo credentials:
| Role     | Access Code | Verify Code |
|----------|-------------|-------------|
| Doctor   | fakedoc1    | 1Doc!@#$    |
| Nurse    | fakenurse1  | 1Nur!@#$    |

After login, select a patient from the list (e.g., "CARTER,DAVID") and a visit
location. You should see the full CPRS GUI with Cover Sheet, Problems, Meds,
Orders, Notes, Consults, Labs, and Reports tabs.

### Step 5: Verify It Works

1. Click the **Notes** tab
2. Click **New Note**
3. Select a note title and location
4. Type some text and save

If that works, your dev environment is ready.

---

## 2. Understanding the Architecture

```
+-------------------+          RPC Broker           +-------------------+
|                   |   (TCP, port 9430 default)    |                   |
|   CPRS Client     | <--------------------------> |   VistA Server     |
|   (Delphi Win32)  |                              |   (M/MUMPS on GT.M|
|                   |                              |    or YottaDB)     |
+-------------------+                              +-------------------+
        |                                                   |
        | Your addon sits HERE                              |
        | (overlay on the client)                           |
        v                                                   |
+-------------------+                              +-------------------+
| Nursing Addon     |                              | Clinical Content  |
| - AutoHotkey, or  |                              | - Reminder Defs   |
| - PowerShell, or  |                              | - TIU Templates   |
| - .NET app        |                              | - Note Titles     |
+-------------------+                              | - Health Factors  |
                                                   +-------------------+
```

**Key insight:** CPRSBooster and your addon operate as an *overlay* on the CPRS
GUI. They don't modify CPRS itself. They simulate keystrokes, clicks, and text
entry to automate repetitive workflows. This is why they don't require IT
installation or CPRS modifications.

The CPRS client communicates with VistA exclusively through **RPCs** (Remote
Procedure Calls) over the **RPC Broker** protocol. Every button click in CPRS
ultimately translates to one or more RPC calls to the M/MUMPS server.

---

## 3. What Clinical Content You Get (and Don't Get)

### Included in Open-Source VistA

| Content | Status | Notes |
|---------|--------|-------|
| Clinical Reminders software (PXRM) | Full | All routines, Reminder Exchange utility |
| TIU framework + Template Editor | Full | Create/edit/import/export templates |
| Base national reminder defs (VA-) | Partial | VA-TOBACCO SCREEN, VA-BMI, etc. |
| Health factors + categories | Base set | From PCE package |
| CPRS GUI with all tabs | Full | Notes, Orders, Reminders, etc. |
| RPC Broker | Full | Client-server communication |

### NOT Included (VA-Internal)

| Content | Why | Workaround |
|---------|-----|------------|
| VAAES nursing dialogues | Distributed as PRD patches internally | Import via Reminder Exchange (see below) |
| Site-specific note templates | Built by local CACs over years | Build your own or import .txml files |
| Order sets | Depend on local formulary/lab catalog | Build locally |
| VISN-specific templates | Regional content | Build locally |
| Most of the 400+ PXRM reminder updates | VA internal distribution | Some available at FOIA mirror |

### The Bottom Line

Your local VistA will feel "empty" compared to your workstation at the VA.
The software is all there but the clinical content that makes CPRS productive
(hundreds of templates, reminder dialogues, quick orders) is site-configured.
For addon development, you only need enough content to test your automation --
you don't need a full VA facility's worth of templates.

---

## 4. Importing Nursing Content (Reminder Exchange)

The VA's **Reminder Exchange** utility lets you import/export clinical reminder
dialogues between VistA instances. This is how the VA distributes national
content -- and how you can load test content into your local dev environment.

### Finding PRD Files

Some national reminder updates (including nursing-related VAAES dialogues) are
mirrored at the FOIA VistA site:
```
https://foia-vista.worldvista.org/Patches_By_Application/PXRM-CLINICAL%20REMINDERS/PRD-Files/
```

### Installing a PRD File

From a VistA terminal session (SSH into your Docker container):

```
# Connect to VistA
docker exec -it vehu bash
# Then: csession cache -U VISTA
# Or for GT.M/YottaDB: mumps -dir

# Navigate to Reminder Exchange
S DUZ=1 D ^XUP
Select OPTION NAME: PXRM REMINDER EXCHANGE

# Load a web-hosted PRD file
Select Action: LWH (Load Web Host File)
Enter URL: [paste the URL to the .prd file]

# Install it
Select Action: IFE (Install Exchange File Entry)
Select Action: IA (Install All Components)
```

### Creating Your Own Test Templates

Easier path for development: just create a few nursing templates directly in
CPRS via the **Template Editor** (Tools > Edit Shared Templates). Build a
simplified version of the dialogues you want to automate:

1. Open CPRS as a provider with template editing access
2. Tools > Edit Shared Templates
3. New Template > Dialog type
4. Add fields: checkboxes, dropdowns, text boxes (mimicking a reminder dialogue)
5. Save and associate with a note title

This gives you realistic test targets for your automation addon without needing
to import full VA content.

---

## 5. Addon Architecture: How to Automate CPRS Without Getting Flagged

### Why CPRSBooster Doesn't Get Flagged

1. **AutoHotkey 2.0.x is "Authorized with Constraints" on the VA TRM** (through
   CY2027, decision date July 30, 2025)
2. It runs from a **centralized VA network share** (not locally installed)
3. It went through **~1 year of national IT/HIMS/Security review**
4. It operates at the **keystroke/UI level** only -- it doesn't touch patient data
   directly, access the database, or intercept network traffic
5. It's listed on the **VA Diffusion Marketplace** (official innovation platform)

### Constraints for AutoHotkey at the VA (Per TRM)

- No credentials stored in macros
- No patient data automation/processing
- Requires supervisor + ISSO approval before use
- Must be scanned for viruses
- Must comply with VA Handbook 6500

### Three Viable Approaches

| Approach | Best For | VA TRM Status |
|----------|----------|---------------|
| **AutoHotkey 2.0** | Text expansion, keystroke macros, simple click automation | Authorized with Constraints |
| **PowerShell + UIAutomation** | More sophisticated control interaction, no install needed | PowerShell is standard on all VA machines |
| **RPC Broker Direct** | Bypassing the GUI entirely, reading/writing clinical data programmatically | Official VA technology |

---

## 6. Approach A: AutoHotkey 2.0 (CPRSBooster Model)

This is the proven path. CPRSBooster uses this exact approach.

### Example: Auto-Fill a Reminder Dialogue

```autohotkey
; NursingAddon.ahk - AutoHotkey v2.0
; Requires: AutoHotkey v2.0+ (VA TRM Authorized)

#Requires AutoHotkey v2.0

; === CONFIGURATION ===
; Hotkey: Ctrl+Shift+N = Fill nursing shift assessment
^+n:: {
    ; Verify we're in a CPRS Reminder Dialogue window
    if !WinActive("ahk_class TfrmRemDlg") {
        ToolTip("Not in a Reminder Dialogue window")
        SetTimer(() => ToolTip(), -2000)
        return
    }

    ; Example: Click through common checkboxes in a shift assessment
    ; These coordinates/control names would need to be mapped to your
    ; specific reminder dialogue layout using Window Spy

    ; Step 1: Find and click "Patient Assessed" checkbox
    ControlClick("TCheckBox1", "A")

    ; Step 2: Set "Level of Consciousness" dropdown to "Alert"
    ControlChooseString("Alert", "TORComboBox1", "A")

    ; Step 3: Set "Pain Level" to "0"
    ControlSetText("0", "TEdit3", "A")

    ; Step 4: Add standard narrative
    ControlSetText("Patient assessed at bedside. Alert and oriented x4. "
        . "No acute distress. Call light within reach. Side rails up x2. "
        . "Fall precautions in place.", "TMemo1", "A")

    ToolTip("Shift assessment filled")
    SetTimer(() => ToolTip(), -2000)
}

; === DOT PHRASES (Text Expansion) ===
; Type .fallrisk and it expands to full fall risk assessment text

:*:.fallrisk:: {
    SendText("Fall Risk Assessment:`n"
        . "Morse Fall Scale Score: ___`n"
        . "History of falling: [ ] Yes [ ] No`n"
        . "Secondary diagnosis: [ ] Yes [ ] No`n"
        . "Ambulatory aid: [ ] None [ ] Crutches/Cane [ ] Furniture`n"
        . "IV/Heparin Lock: [ ] Yes [ ] No`n"
        . "Gait: [ ] Normal [ ] Weak [ ] Impaired`n"
        . "Mental Status: [ ] Oriented to own ability [ ] Forgets limitations`n"
        . "Interventions:`n"
        . "- Fall risk bracelet applied`n"
        . "- Bed in lowest position`n"
        . "- Call light within reach`n"
        . "- Non-skid footwear provided`n"
        . "- Environment assessed for hazards")
}

:*:.vitals:: {
    SendText("Vital Signs:`n"
        . "BP: /  | HR:  | RR:  | Temp:  | SpO2: %`n"
        . "Pain: /10 | Location: | Quality: | Duration:`n"
        . "BMI: | Weight: | Height:")
}

:*:.neuro:: {
    SendText("Neurological Assessment:`n"
        . "LOC: Alert and oriented x [ ]`n"
        . "Pupils: PERRLA / [ ] Abnormal: ___`n"
        . "Speech: [ ] Clear [ ] Slurred [ ] Aphasic`n"
        . "Motor: [ ] Moves all extremities [ ] Weakness: ___`n"
        . "Sensation: [ ] Intact [ ] Deficit: ___`n"
        . "GCS: E__ V__ M__ = __/15")
}

:*:.skinassess:: {
    SendText("Skin/Wound Assessment:`n"
        . "Braden Scale Score: ___`n"
        . "Skin integrity: [ ] Intact [ ] Impaired`n"
        . "Wound location: ___`n"
        . "Wound type: [ ] Pressure injury [ ] Surgical [ ] Other: ___`n"
        . "Stage: [ ] I [ ] II [ ] III [ ] IV [ ] Unstageable [ ] DTI`n"
        . "Size: ___ cm x ___ cm x ___ cm`n"
        . "Wound bed: [ ] Granulation [ ] Slough [ ] Eschar [ ] Mixed`n"
        . "Drainage: [ ] None [ ] Serous [ ] Sanguineous [ ] Purulent`n"
        . "Periwound: [ ] Intact [ ] Macerated [ ] Erythematous`n"
        . "Treatment: ___`n"
        . "Dressing change: [ ] Yes [ ] No")
}

; === QUICK ACTIONS ===
; Ctrl+Shift+S = Quick-sign the current note
^+s:: {
    if !WinActive("ahk_exe CPRSChart.exe") {
        return
    }
    ; Simulate the sign note sequence
    Send("!f")   ; Alt+F for File menu (or Action menu)
    Sleep(200)
    Send("s")    ; Sign
    Sleep(500)
    ; The electronic signature dialog will appear
    ; User still enters their own signature code (we never store credentials)
}
```

### Getting Started with AutoHotkey

1. Install AutoHotkey v2.0 from https://www.autohotkey.com/
2. Use **Window Spy** (included with AHK) to identify CPRS control names and classes
3. The key CPRS window classes to target:
   - `TfrmFrame` -- main CPRS window
   - `TfrmRemDlg` -- reminder dialogue windows
   - `TfrmNotes` -- notes tab
   - `TfrmTemplateEditor` -- template editor
   - `TfrmEncounter` -- encounter form

### Mapping Reminder Dialogue Controls

The hardest part is identifying which controls correspond to which fields in a
reminder dialogue. Use AHK's Window Spy or Microsoft's **Accessibility Insights**:

1. Open CPRS and navigate to a reminder dialogue
2. Run Window Spy (right-click AHK tray icon > Window Spy)
3. Hover over each field to get the control class and HWND
4. Document the control map for each dialogue you want to automate

---

## 7. Approach B: PowerShell + UI Automation

PowerShell is already on every VA workstation. No installation needed.

### Example: Inspect CPRS Controls

```powershell
# NursingAddon.ps1 - PowerShell UI Automation for CPRS
# No external modules required -- uses built-in .NET UI Automation

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

# Find the CPRS window
$root = [System.Windows.Automation.AutomationElement]::RootElement
$cprsCondition = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::NameProperty,
    "CPRS",
    [System.Windows.Automation.PropertyConditionFlags]::IgnoreCase
)

# Find CPRS main window (partial match via TreeWalker)
$walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
$child = $walker.GetFirstChild($root)
$cprsWindow = $null

while ($child -ne $null) {
    if ($child.Current.Name -like "*CPRS*" -or $child.Current.Name -like "*Chart*") {
        $cprsWindow = $child
        break
    }
    $child = $walker.GetNextSibling($child)
}

if ($cprsWindow) {
    Write-Host "Found CPRS window: $($cprsWindow.Current.Name)"

    # List all child controls (useful for mapping)
    $allCondition = [System.Windows.Automation.Condition]::TrueCondition
    $children = $cprsWindow.FindAll(
        [System.Windows.Automation.TreeScope]::Descendants,
        $allCondition
    )

    foreach ($element in $children) {
        $name = $element.Current.Name
        $type = $element.Current.ControlType.ProgrammaticName
        $class = $element.Current.ClassName
        if ($name -and $name.Length -gt 0) {
            Write-Host "$type | Class: $class | Name: $name"
        }
    }
} else {
    Write-Host "CPRS not found. Make sure it's running."
}
```

### Example: Click a Button by Name

```powershell
function Click-CPRSButton {
    param([string]$ButtonName)

    $buttonCondition = New-Object System.Windows.Automation.AndCondition(
        (New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::NameProperty, $ButtonName)),
        (New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
            [System.Windows.Automation.ControlType]::Button))
    )

    $button = $cprsWindow.FindFirst(
        [System.Windows.Automation.TreeScope]::Descendants,
        $buttonCondition
    )

    if ($button) {
        $invokePattern = $button.GetCurrentPattern(
            [System.Windows.Automation.InvokePattern]::Pattern)
        $invokePattern.Invoke()
        Write-Host "Clicked: $ButtonName"
    } else {
        Write-Host "Button '$ButtonName' not found"
    }
}

# Usage
Click-CPRSButton "New Note"
```

### Advantages over AutoHotkey

- No installation required (PowerShell is built-in)
- Uses official Windows Accessibility APIs
- More programmatic control (conditionals, loops, error handling)
- Can read control values, not just click them

### Limitations

- Delphi VCL controls have inconsistent UI Automation support
- Custom-drawn controls (common in CPRS reminder dialogues) may not be accessible
- More verbose than AutoHotkey for simple text expansion

---

## 8. Approach C: RPC Broker Direct (Advanced)

Instead of automating the GUI, talk directly to VistA using the same RPCs that
CPRS uses. This is the most robust approach but requires deeper knowledge.

### How It Works

The RPC Broker provides a DLL (`BrokerLib.dll`) that any Windows application can
use to make authenticated RPC calls to VistA. You can also use raw TCP sockets
to speak the broker protocol.

### Key CPRS RPCs for Nursing Workflows

These are the actual RPCs CPRS calls (from the source code in this repo):

| RPC Name | Purpose | Source File |
|----------|---------|-------------|
| `TIU CREATE RECORD` | Create a new note | `rTIU.pas` |
| `TIU SET RECORD TEXT` | Set note body text | `rTIU.pas` |
| `TIU SIGN RECORD` | Sign a note | `rTIU.pas` |
| `TIU GET RECORD TEXT` | Read note text | `rTIU.pas` |
| `ORQQPX REMINDER DETAIL` | Get reminder detail | `rReminders.pas` |
| `ORQQPX REMINDERS LIST` | List active reminders | `rReminders.pas` |
| `PXRM REMINDER DIALOG` | Get reminder dialogue definition | `rReminders.pas` |
| `PXRM REMINDER CATEGORIES` | Get reminder categories | `rReminders.pas` |
| `ORQQVI VITALS` | Read vitals | `rCore.pas` |
| `GMV ADD VM` | Record vitals | (Vitals package) |
| `ORWPT LIST ALL` | List patients | `rCore.pas` |

### Example: Python RPC Client (For Local Dev Only)

```python
"""
Minimal VistA RPC Broker client for development/testing.
Talks directly to VistA, no CPRS GUI needed.

NOTE: This is for LOCAL DEVELOPMENT against your Docker VistA only.
Do not use on VA production systems without proper authorization.
"""

import socket
import hashlib

class VistARPC:
    def __init__(self, host='127.0.0.1', port=9430):
        self.host = host
        self.port = port
        self.sock = None

    def connect(self):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.connect((self.host, self.port))
        # Send connect handshake
        self._send_raw('[XWB]10304\x0ATCPConnect5001' +
                       '0\x0f0013127.0.0.1\x04\x03\x04')
        return self._receive()

    def login(self, access_code, verify_code):
        # XUS AV CODE expects access;verify encrypted
        av_code = access_code + ';' + verify_code
        # In real implementation, this needs proper encryption
        # For dev, use the Broker's authentication flow
        pass

    def call_rpc(self, rpc_name, params=None):
        """Call a VistA RPC and return the result."""
        # Build RPC packet (simplified)
        # Real implementation needs proper packet framing
        pass

    def _send_raw(self, data):
        self.sock.send(data.encode('utf-8'))

    def _receive(self):
        return self.sock.recv(65536).decode('utf-8', errors='replace')

    def disconnect(self):
        if self.sock:
            self._send_raw('[XWB]10304\x05#BYE#\x04')
            self.sock.close()
```

For a more complete RPC client, see the RPC Broker source at:
`Packages/RPC Broker/BDK/` in this repo.

---

## 9. Nursing Workflows to Automate

Based on CPRSBooster patterns and common nursing pain points, here are the
highest-value automation targets:

### Tier 1: Quick Wins (Text Expansion)

These can be done with simple dot phrases on day one:

| Trigger | Expands To |
|---------|-----------|
| `.shiftassess` | Full shift assessment template (neuro, cardiac, respiratory, GI, GU, skin, pain, psychosocial, safety) |
| `.fallrisk` | Morse Fall Scale assessment with interventions |
| `.skinassess` | Braden Scale + wound assessment |
| `.painassess` | Comprehensive pain assessment (OPQRST format) |
| `.ivsite` | IV site assessment (location, gauge, appearance, flush, dressing) |
| `.restraint` | Restraint assessment (type, indication, circulation checks, release schedule) |
| `.intake` | Intake/output documentation template |
| `.edunote` | Patient education documentation |
| `.discharge` | Discharge teaching checklist |
| `.handoff` | SBAR handoff template |
| `.code` | Rapid response/code documentation |

### Tier 2: Click Automation (Reminder Dialogues)

These require mapping CPRS control IDs for your specific dialogues:

| Workflow | What It Automates |
|----------|-------------------|
| **Shift Assessment Dialogue** | Auto-clicks through the standard checkboxes for "within normal limits" on a shift assessment, leaving only abnormals for manual entry |
| **Restraint Monitoring** | Pre-fills the 2-hour restraint check dialogue with standard monitoring fields |
| **Fall Prevention** | Auto-selects standard fall prevention interventions based on Morse score |
| **Pain Reassessment** | Pre-fills pain reassessment 30/60 min post-intervention |
| **Skin/Wound Rounds** | Steps through multi-site wound assessment dialogue |

### Tier 3: Workflow Orchestration

More complex automation combining multiple steps:

| Workflow | Steps Automated |
|----------|----------------|
| **Admission Bundle** | Open new note > select admission assessment title > fill template > open orders tab > pull up admission order set |
| **Discharge Bundle** | Open discharge note > fill template > verify med rec > print AVS |
| **Hourly Rounding** | Open encounter > select rounding template > pre-fill standard checks > advance to next patient |

---

## 10. VA Compliance & TRM Notes

### What IS Approved

| Technology | VA TRM Status | Through |
|------------|---------------|---------|
| AutoHotkey 2.0.x | Authorized with Constraints | CY2027 |
| PowerShell | Standard (built-in) | Always |
| .NET Framework | Standard (built-in) | Always |

### What IS NOT Approved (or Needs Checking)

| Technology | Status | Notes |
|------------|--------|-------|
| AutoHotkey 1.x | Becoming Unauthorized CY2026 | Must use 2.0+ |
| Python | Check current TRM status | May not be on standard VA image |
| Node.js | Check current TRM status | May not be on standard VA image |

### Critical Constraints (Per VA TRM for AutoHotkey)

1. **NEVER store credentials** in scripts (access codes, verify codes, PIV info)
2. **NEVER automate patient data processing** (your tool should automate the
   *UI workflow*, not extract or transmit patient data)
3. **Get supervisor + ISSO approval** before deploying
4. **Virus scan** all executables
5. **Comply with VA Handbook 6500** for any sensitive data handling

### The CPRSBooster Precedent

CPRSBooster proves that a UI automation overlay for CPRS can pass VA security
review and achieve national authorization. Your nursing addon would follow the
same model:

- Operates at the keystroke/UI level only
- Does not store or transmit patient data
- Does not modify CPRS itself
- Runs from a network share (no local install)
- Gets listed on VA Diffusion Marketplace

The review process took CPRSBooster approximately one year. Starting with
supervisor and ISSO approval at your facility is the first step.

---

## 11. Resources & References

### CPRS Source Code (In This Repo)

| Component | Path |
|-----------|------|
| CPRS main project | `Packages/Order Entry Results Reporting/CPRS/CPRS-Chart/CPRSChart.dpr` |
| Reminder dialogue UI | `Packages/Order Entry Results Reporting/CPRS/CPRS-Chart/fReminderDialog.pas` |
| Reminder data layer | `Packages/Order Entry Results Reporting/CPRS/CPRS-Chart/rReminders.pas` |
| Reminder utilities | `Packages/Order Entry Results Reporting/CPRS/CPRS-Chart/uReminders.pas` |
| Notes UI | `Packages/Order Entry Results Reporting/CPRS/CPRS-Chart/fNotes.pas` |
| TIU RPCs | `Packages/Order Entry Results Reporting/CPRS/CPRS-Chart/rTIU.pas` |
| Core RPCs | `Packages/Order Entry Results Reporting/CPRS/CPRS-Chart/rCore.pas` |
| RPC Broker BDK | `Packages/RPC Broker/BDK/` |

### External Resources

| Resource | URL |
|----------|-----|
| CPRSBooster (VA Marketplace) | https://marketplace.va.gov/innovations/cprs-booster |
| CPRSBooster Source (CloudVistA) | https://github.com/CloudVistA/cprs-booster |
| VA TRM - AutoHotkey | https://oit.va.gov/Services/TRM/ToolPage.aspx?tid=6458 |
| CPRS Technical Manual | https://www.va.gov/vdl/documents/Clinical/Comp_Patient_Recrd_Sys_(CPRS)/cprsguitm.pdf |
| Clinical Reminders Manager's Manual | https://www.va.gov/vdl/documents/clinical/cprs-clinical_reminders/pxrm_2_mm.pdf |
| RPC Broker Developer's Guide | https://www.va.gov/vdl/documents/Infrastructure/Remote_Proc_Call_Broker_(RPC)/xwb_1_1_dg.pdf |
| FOIA VistA PRD Files (Reminders) | https://foia-vista.worldvista.org/Patches_By_Application/PXRM-CLINICAL%20REMINDERS/PRD-Files/ |
| WorldVistA VEHU Demo DB | https://github.com/WorldVistA/VistA-VEHU-M |
| VistA Docker Images | https://hub.docker.com/u/worldvista |
| AutoHotkey v2.0 | https://www.autohotkey.com/ |
| Window Spy (AHK built-in) | Included with AutoHotkey installation |
| Accessibility Insights | https://accessibilityinsights.io/ |

### VA Documentation Library (VDL)

The VA Software Document Library has manuals for every VistA package:
https://www.va.gov/vdl/

Key manuals for nursing addon development:
- CPRS GUI Technical Manual
- Clinical Reminders Manager's Manual
- Clinical Reminders Install Guide
- TIU (Text Integration Utilities) Technical Manual
- PCE (Patient Care Encounter) Technical Manual
