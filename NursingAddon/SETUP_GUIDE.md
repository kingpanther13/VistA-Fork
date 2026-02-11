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

## 4b. VAAES PRD Files -- What's Available for Download

The following VAAES PRD files are publicly available on the FOIA mirror at:
`https://foia-vista.worldvista.org/Patches_By_Application/PXRM-CLINICAL%20REMINDERS/PRD-Files/`

| PRD File | Content | Size |
|----------|---------|------|
| `UPDATE_2_0_102 VAAES SKIN INSPECTION-ASSESSMENT.PRD` | Skin assessment (original) | 607K |
| `UPDATE_2_0_160 VA-AES ACUTE INPATIENT NSG SHIFT ASSESSMENT.PRD` | Shift assessment + frequent documentation + IV insertion | 3.1M |
| `UPDATE_2_0_174 VAAES TEMPLATE UPDATES.PRD` | Template revisions | 1.0M |
| `UPDATE_2_0_195 VAAES SKIN INSPECTION-ASSESSMENT UPDATE.PRD` | Skin assessment update | 911K |
| `UPDATE_2_0_212 VAAES SHIFT ASSESSMENT BUNDLE.PRD` | Updated shift assessment bundle | 4.1M |
| `UPDATE_2_0_340 VAAES TEMPLATES.PRD` | Template refresh | 2.0M |
| `UPDATE_2_0_362 VAAES TEMPLATES UPDATE.PRD` | Another template refresh | 4.0M |
| `UPDATE_2_0_460 VA-VAAES SKIN INSPECTION-ASSESSMENT UPDATE.PRD` | Skin assessment (latest available) | 1.3M |

Install guides (PDFs) are at the VA VDL:
- Shift Assessment: https://www.va.gov/vdl/documents/Clinical/CPRS-Clinical_Reminders/Update_2_0_160_IG-508.pdf
- Skin Assessment: https://www.va.gov/vdl/documents/Clinical/CPRS-Clinical_Reminder_Updates/Update_2_0_460_IG-508.pdf

### Important: Version Lag

The FOIA mirror is **significantly behind** what's deployed at VA facilities.
The current VAAES Acute Inpatient Nsg Shift Assessment in production is **v2.2**
but the newest publicly available PRD is from the UPDATE_2_0_212 era (~2022).
The v2.2 was distributed internally via `vaww.va.gov` (VA intranet only).

For addon development, the older versions are structurally similar enough to
test automation against. The dialogue layout, checkbox patterns, and health
factor filing mechanism are the same -- only specific field content differs.

---

## 4c. How Reminder Dialogues Actually Work (Source Code Analysis)

Understanding this is critical for building your addon. Reminder dialogues
produce **two separate outputs** when you click Finish, and health factors are
the tricky part.

### The Two Outputs

**Output 1: Note Text** -- purely client-side string assembly. Each checked
checkbox has display text (`FPNText`/`FText`). CPRS concatenates all checked
items' text with indentation and inserts it into the note's rich text editor.
No RPC call. Easy to replicate.

**Output 2: PCE Data (Health Factors, Diagnoses, etc.)** -- structured data
filed into VistA's encounter database. This is the real clinical data. Health
factors land in the V HEALTH FACTORS file (9000010.23), referencing the master
HEALTH FACTORS file (9999999.64 / `^AUTTHF` global).

### Complete Data Flow: Checkbox Click to VistA

Source files (all in `Packages/Order Entry Results Reporting/CPRS/CPRS-Chart/`):

```
uReminders.pas   -- Core classes: TRemDlgElement, TRemData, TRemPrompt
fReminderDialog.pas -- UI form with Finish button handler (btnFinishClick)
rReminders.pas   -- RPC calls to VistA
uPCE.pas         -- PCE data objects (TPCEHealth for health factors)
rPCE.pas         -- PCE save RPC (ORWPCE SAVE)
```

#### Step-by-step flow:

```
1. User clicks a checkbox in the reminder dialogue
        |
        v
2. TRemDlgElement.cbClicked fires (uReminders.pas:4126)
        |
        v
3. SetChecked(true) called (uReminders.pas:3982)
        |
        v
4. GetData called -- lazy-loads finding definitions from VistA
   RPC: "ORQQPXRM DIALOG PROMPTS"
   Returns record type 3 data with finding type code
   For health factors: piece 4 = 'HF'
        |
        v
5. TRemData objects created with type rdtHealthFactor
   TRemPrompt objects created (ptComment, ptLevelSeverity, etc.)
        |
        v
6. User clicks FINISH (fReminderDialog.pas:1529 btnFinishClick)
        |
        v
7. Phase 1 -- Validation
   FinishProblems checks for required items, missing fields
        |
        v
8. Phase 2 -- Text Generation (client-side only)
   TReminderDialog.AddText builds note text from checked elements
        |
        v
9. Phase 3 -- PCE Data Collection
   TRemDlgElement.AddData -> TRemData.AddData builds delimited strings:

   For health factors, the format is:
   HF+^<IEN>^<Category>^<Narrative>^<Level>^<Provider>^<Mag>^<UCUM>^^^<CommentSeq>^<GecRem>
   COM^<Seq>^<CommentText>

   Example:
   HF+^305^^TOBACCO USE^M^12345^^^^^^1
   COM^1^Patient states they smoke 1 pack per day
        |
        v
10. Phase 4 -- PCE Data Routing
    Each data line is parsed into typed objects by category prefix:
    Health factors -> TPCEHealth -> PCEObj.SetHealthFactors
    Diagnoses     -> TPCEDiag   -> PCEObj.SetDiagnoses
    Procedures    -> TPCEProc   -> PCEObj.SetProcedures
    Exams         -> TPCEExams  -> PCEObj.SetExams
    Vitals, orders, MH tests go through separate pathways
        |
        v
11. Phase 5 -- Save to VistA
    PCEObj.Save builds the complete PCE list:
      HDR^...
      VST^DT^<DateTime>
      VST^PT^<PatientDFN>
      VST^HL^<LocationIEN>
      HF+^305^^TOBACCO USE^M^12345^^^^^^1
      COM^1^Patient states they smoke 1 pack per day

    RPC: "ORWPCE SAVE" sends it all to VistA in one call
    M routine DATA2PCE files into V HEALTH FACTORS (9000010.23)
        |
        v
12. Phase 6 -- Text Insertion (only after save succeeds)
    Note text inserted into the TIU note rich text editor
```

### Key Object Model (uReminders.pas)

```
TReminderDialog
  +-- FElements: list of TRemDlgElement
  +-- FPCEDataObj: TPCEData (the encounter)

TRemDlgElement (one checkbox/item in the dialog)
  +-- FCheckBox: TORCheckBox (the visual control)
  +-- FData: list of TRemData (the findings)
  +-- FPrompts: list of TRemPrompt (comment, severity, etc.)
  +-- FChecked: boolean
  +-- FText: string (display/note text)

TRemData (one finding attached to an element)
  +-- FDataType: rdtHealthFactor, rdtDiagnosis, rdtExam, etc.
  +-- FPCERoot: shared sync object
  +-- Code: health factor IEN from file 9999999.64

TRemPrompt (a user input control)
  +-- PromptType: ptComment, ptLevelSeverity, ptQuantity, etc.
  +-- FValue: current user entry
```

Data type codes used in exchange:
```
POV = Diagnosis       CPT = Procedure      PED = Patient Education
XAM = Exam            HF  = Health Factor  IMM = Immunization
SK  = Skin Test       VIT = Vitals         Q   = Order
MH  = Mental Health   SC  = Standard Code
```

### All RPCs Used by Reminder Dialogues

| RPC | When Called | Purpose |
|-----|-----------|---------|
| `ORQQPXRM REMINDER DIALOG` | Dialog opens | Loads element definitions |
| `ORQQPXRM DIALOG PROMPTS` | Element checked (lazy) | Loads finding/prompt data |
| `ORQQPXRM DIALOG ACTIVE` | Dialog opens | Checks element active status |
| `ORQQPXRM PROGRESS NOTE HEADER` | Finish clicked | Gets "Clinical Maintenance" header |
| `ORQQPXRM GEC DIALOG` | Finish (HF only) | Geriatric Extended Care check |
| **`ORWPCE SAVE`** | **Finish** | **Saves ALL PCE data (health factors, diagnoses, etc.)** |
| `ORQQPXRM MST UPDATE` | Finish (if MST) | Military Sexual Trauma data |
| `ORQQPXRM REMINDER EVALUATION` | After save | Re-evaluates reminder status |
| `PXRMRPCG GENFUPD` | Finish (gen findings) | General findings save |
| `PXRMRPCG CANCEL` | Cancel clicked | Clears server-side temp data |

### Why This Matters for Your Addon

**If you automate at the GUI level** (clicking checkboxes via AutoHotkey or
PowerShell UIAutomation), CPRS handles ALL of the above internally. You don't
need to construct `HF+^...` strings or call `ORWPCE SAVE` yourself. You just:
1. Click the right checkboxes
2. Fill in any free-text prompts
3. Click Finish
...and CPRS does the rest. Health factors get filed correctly because CPRS
already knows which checkbox maps to which health factor IEN (it loaded that
mapping from the `ORQQPXRM DIALOG PROMPTS` RPC when the dialog opened).

**If you automate at the RPC level** (bypassing the GUI), you'd need to:
1. Call `ORQQPXRM REMINDER DIALOG` to get the dialog structure
2. Determine which elements to "check" programmatically
3. Call `ORQQPXRM DIALOG PROMPTS` for each to get health factor IENs
4. Construct the `HF+^...` PCE data strings yourself
5. Call `ORWPCE SAVE` with the complete PCE list
This is significantly more complex but also more robust and faster.

**Recommended approach:** GUI automation via companion panel. The addon clicks
the same checkboxes a nurse would, so CPRS handles the health factor data layer
correctly. But instead of the nurse scrolling through a 1,251-checkbox form, they
interact with a compact 28-category panel and let the addon translate their
selections into checkbox clicks via Win32 `SendMessage(hwnd, BM_CLICK, 0, 0)`.

---

## 4d. VAAES Shift Assessment Structure (From Spreadsheet)

The VAAES Acute Inpatient Nsg Shift Assessment has **28 body system categories**
containing **1,279 total health factors**. This is why it's so tedious to fill
out manually — each category expands into dozens of nested checkboxes.

See `NursingAddon/vaaes_shift_assessment_map.json` for the complete mapping
extracted from the health factors spreadsheet.

| Category | Health Factors | Notes |
|----------|---------------|-------|
| MORSE FALL SCALE SCORE | 3 | High/moderate/low risk |
| POSITIONING | 5 | Lying L/R, prone, sitting, supine |
| ADL | 62 | Dressing, eating, pericare, toileting, personal care, foot care |
| CARDIO | 66 | HR/rhythm, pulses, cap refill, edema, embolism prevention, pacing |
| DRAIN | 45 | Drains/tubes 1-4, types, drainage methods |
| EDU | 24 | Education methods, provided to, understanding |
| EDUCATION NEEDS | 17 | Learning barriers, teaching strategies |
| ENVIRON SAFETY MGMT | 36 | Safety equipment, precautions |
| FREQ | 44 | Frequent documentation items |
| GASTRO | 56 | Bowel sounds, diet, tubes, nausea, stool |
| GEN INFO | 10 | General patient information |
| ID RISK | 7 | Identification risk factors |
| LINE | 274 | IV lines 1-8, central lines, PICC, arterial, types, sites |
| MOB | 100 | Mobility, transfers, bed mobility, ambulation |
| NEURO | 114 | LOC, orientation, pupils, speech, cranial nerves, motor, sensory |
| NEURO AVPU | 4 | Alert, verbal, pain, unresponsive |
| NEURO/EXT | 16 | Extremity neuro assessment |
| ORAL CARE | 21 | Oral assessment and care |
| PAIN | 72 | Pain assessment, location, quality, interventions |
| PSYCH | 1 | Psychosocial header |
| RESP | 198 | Breath sounds, O2, airway, ventilator, chest tubes, trach |
| SUICIDE | 6 | Suicide risk screening |
| URO | 79 | Urinary output, catheter, bladder scan |

Also generated: `vaaes_freq_doc_map.json` (35 categories, 608 HFs) and
`vaaes_skin_assessment_map.json` (14 categories, 371 HFs).

### Why a Companion Panel, Not Click Automation

Pure click automation (scrolling through and clicking each checkbox) is
impractical for 1,279 health factors. The dialogue has:
- Nested elements that only appear when parents are clicked (triggering RPCs)
- A long scrolling TScrollBox that would need programmatic scrolling
- Conditional sub-sections that vary by patient

The companion panel approach works differently:
1. You open the VAAES dialogue in CPRS normally
2. Your addon shows a compact panel with all 28 categories as buttons
3. Click **"All WNL"** — the addon clicks all "within normal limits" checkboxes
   in the CPRS dialogue using `SendMessage(hwnd, BM_CLICK, 0, 0)` which works
   even for controls scrolled off-screen
4. Toggle any category to **"Abnormal"** and specify details
5. Click **"Apply"** — the addon adjusts only the changed sections
6. You review in CPRS and click Finish yourself

The companion panel doesn't need to know about health factor IENs because it
lets CPRS handle all the data plumbing. It just needs to know which checkbox
labels correspond to which body system categories — and that's what the JSON
config files provide.

### Runtime Control Discovery

The addon discovers checkboxes at runtime by:
1. Finding the `TfrmRemDlg` window (the reminder dialogue)
2. Enumerating `TCPRSDialogParentCheckBox` controls in the `TScrollBox`
3. Reading each checkbox's associated `TDlgFieldPanel` text to determine
   what it represents (the checkbox's own Caption is cleared to `' '` — the
   visible text is in the panel, per `uReminders.pas:5750-5754`)
4. Matching panel text against the body system category names from the JSON config

This means the addon adapts to whatever version of the VAAES dialogue is
installed — it doesn't hardcode control positions or IDs.

### The Nested Element Problem

When a parent checkbox is clicked, CPRS:
1. Calls `SetChecked(true)` which calls `GetData` (an RPC to VistA)
2. Rebuilds the control tree via `BuildControls` to show child elements

The addon handles this by:
1. Clicking all parent checkboxes first (to expand all sections)
2. Waiting briefly for RPC responses and control rebuilds (~200ms per section)
3. Then enumerating the now-visible child controls
4. Clicking the appropriate "WNL" children

For the "stop and edit" workflow: the addon can apply sections one at a time.
If you mark RESP as abnormal, the addon skips that section entirely, leaving it
for you to fill in manually while it handles the other 27 categories.

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
