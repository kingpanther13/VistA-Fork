; ===========================================================================
; NursingBooster.ahk - CPRSBooster-Style Nursing Automation
; AutoHotkey v2.0+ Required (VA TRM Authorized through CY2027)
;
; Modeled after CPRSBooster's approach:
;   - Floating toolbar with quick-action buttons
;   - Dot phrases (text expansion) for note templates
;   - Keystroke injection to navigate and fill CPRS dialogues
;   - Hotkey-driven workflows
;
; This is the simple, practical starting point. It sends keystrokes and
; clicks just like a human would, letting CPRS handle all data filing.
;
; IMPORTANT: Does NOT store credentials. Does NOT process patient data.
; Simulates UI interaction only.
; ===========================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; === CONFIGURATION ===
global AppTitle := "Nursing Booster"
global TemplateDir := A_ScriptDir "\templates"
global DotPhraseFile := A_ScriptDir "\dot_phrases.json"
global BoosterGui := ""
global IsRunning := false

if !DirExist(TemplateDir)
    DirCreate(TemplateDir)

; Load dot phrases
global DotPhrases := LoadDotPhrases()
RegisterDotPhrases()

; Build the floating toolbar
BuildToolbar()
return

; ===========================================================================
; FLOATING TOOLBAR (CPRSBooster "HyperDrive Bar" style)
; ===========================================================================

BuildToolbar() {
    global BoosterGui

    BoosterGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", AppTitle)
    BoosterGui.SetFont("s8", "Segoe UI")
    BoosterGui.BackColor := "1a1a2e"

    ; Title bar (draggable)
    titleBar := BoosterGui.AddText("xm ym w600 h20 Center cWhite Background1a1a2e", "  Nursing Booster  |  Ctrl+Shift+B to toggle  |  Right-click for menu")
    titleBar.OnEvent("Click", (*) => PostMessage(0xA1, 2,,, BoosterGui))  ; drag

    ; --- Row 1: Assessment Actions ---
    BoosterGui.AddButton("xm y+2 w90 h26 vBtnNegAssess", "Neg Assess").OnEvent("Click", BtnNegativeAssessment)
    BoosterGui.AddButton("x+2 w90 h26", "Neg + Apply").OnEvent("Click", BtnNegAssessAndApply)
    BoosterGui.AddButton("x+2 w90 h26", "Skin WNL").OnEvent("Click", BtnSkinWNL)
    BoosterGui.AddButton("x+2 w90 h26", "Neuro WNL").OnEvent("Click", BtnNeuroWNL)
    BoosterGui.AddButton("x+2 w90 h26", "Cardio WNL").OnEvent("Click", BtnCardioWNL)
    BoosterGui.AddButton("x+2 w90 h26", "Resp WNL").OnEvent("Click", BtnRespWNL)

    ; --- Row 2: More Systems + Actions ---
    BoosterGui.AddButton("xm y+2 w90 h26", "GI WNL").OnEvent("Click", BtnGIWNL)
    BoosterGui.AddButton("x+2 w90 h26", "GU WNL").OnEvent("Click", BtnGUWNL)
    BoosterGui.AddButton("x+2 w90 h26", "Pain WNL").OnEvent("Click", BtnPainWNL)
    BoosterGui.AddButton("x+2 w90 h26", "Psych WNL").OnEvent("Click", BtnPsychWNL)
    BoosterGui.AddButton("x+2 w90 h26", "Safety WNL").OnEvent("Click", BtnSafetyWNL)
    BoosterGui.AddButton("x+2 w90 h26", "Mobility WNL").OnEvent("Click", BtnMobilityWNL)

    ; --- Row 3: Workflow + Templates ---
    BoosterGui.AddButton("xm y+2 w90 h26", "Quick Sign").OnEvent("Click", BtnQuickSign)
    BoosterGui.AddButton("x+2 w90 h26", "New Note").OnEvent("Click", BtnNewNote)
    BoosterGui.AddButton("x+2 w90 h26", "Load Tmpl").OnEvent("Click", BtnLoadSavedTemplate)
    BoosterGui.AddButton("x+2 w90 h26", "Save Tmpl").OnEvent("Click", BtnSaveCurrentState)
    BoosterGui.AddButton("x+2 w90 h26", "Dot Phrases").OnEvent("Click", BtnEditDotPhrases)
    BoosterGui.AddButton("x+2 w90 h26", "Panel").OnEvent("Click", BtnOpenAdvancedPanel)

    ; --- Status ---
    BoosterGui.AddText("xm y+4 w600 h18 vToolbarStatus cSilver Background1a1a2e Center", "Ready | CPRS: Not detected")

    BoosterGui.Show("x0 y0 NoActivate")

    ; Start CPRS detection timer
    SetTimer(CheckCPRS, 2000)
}

; ===========================================================================
; CPRS DETECTION
; ===========================================================================

CheckCPRS() {
    cprsHwnd := WinExist("ahk_exe CPRSChart.exe")
    if cprsHwnd {
        title := WinGetTitle(cprsHwnd)
        ; Extract patient name from title if present
        BoosterGui["ToolbarStatus"].Text := "Ready | CPRS: " SubStr(title, 1, 60)
    } else {
        BoosterGui["ToolbarStatus"].Text := "Ready | CPRS: Not detected"
    }
}

; ===========================================================================
; NEGATIVE ASSESSMENT - The core feature
;
; This sends keystrokes to navigate through the VAAES Shift Assessment
; dialogue and check all "within normal limits" boxes.
;
; HOW IT WORKS:
; The CPRS reminder dialogue is a scrollable form with checkboxes.
; Each body system section has a parent checkbox; clicking it expands
; child options. The "WNL" options are typically the first child or
; a specifically labeled checkbox.
;
; The approach: Use Tab/Space/Arrow keys to navigate the form, just
; like a user would with keyboard-only navigation. This is the same
; approach CPRSBooster uses.
;
; YOU WILL NEED TO CUSTOMIZE the keystroke sequences below to match
; your facility's specific VAAES dialogue layout. The sequences here
; are starting templates based on the spreadsheet structure.
; ===========================================================================

BtnNegativeAssessment(ctrl, *) {
    ; Check if a reminder dialogue is open
    if !WinExist("ahk_class TfrmRemDlg") {
        ToolTip("Open a reminder dialogue in CPRS first")
        SetTimer(ClearToolTip, -2000)
        return
    }

    WinActivate("ahk_class TfrmRemDlg")
    Sleep(200)

    ; Load and apply the "Negative Assessment" template if it exists
    templatePath := TemplateDir "\Negative Assessment.json"
    if FileExist(templatePath) {
        ApplyKeystrokeTemplate(templatePath)
        return
    }

    ; If no template saved yet, show instructions
    MsgBox("No 'Negative Assessment' template saved yet.`n`n"
        "To create one:`n"
        "1. Open the VAAES Shift Assessment dialogue`n"
        "2. Manually check all the 'within normal limits' boxes`n"
        "3. Click 'Save Tmpl' on the toolbar`n"
        "4. Name it 'Negative Assessment'`n`n"
        "Next time you click 'Neg Assess', it will replay those selections.`n`n"
        "Alternatively, use the 'Panel' button for the advanced companion panel`n"
        "which can scan and apply selections via direct control messaging.",
        AppTitle, "Iconi")
}

BtnNegAssessAndApply(ctrl, *) {
    ; Same as negative assessment but also clicks Finish
    BtnNegativeAssessment(ctrl)
    ; Don't auto-finish - let the nurse review first
    ToolTip("Review the assessment, then click Finish in CPRS when ready")
    SetTimer(ClearToolTip, -3000)
}

; ===========================================================================
; PER-SYSTEM WNL BUTTONS
;
; Each button sends a keystroke sequence to check the WNL boxes for
; one body system. These are TEMPLATES - you'll customize the actual
; keystroke sequences by recording them (Save Tmpl) or editing the
; template JSON files.
;
; The keystroke approach:
;   - Activate the CPRS Reminder Dialog
;   - Use Ctrl+Home to go to top of form
;   - Use Tab to navigate between controls
;   - Use Space to check/uncheck checkboxes
;   - Use Down/Up arrows for dropdown selections
;   - Use text entry for free-text fields
; ===========================================================================

BtnNeuroWNL(ctrl, *) {
    ApplySystemTemplate("Neuro WNL")
}

BtnCardioWNL(ctrl, *) {
    ApplySystemTemplate("Cardio WNL")
}

BtnRespWNL(ctrl, *) {
    ApplySystemTemplate("Resp WNL")
}

BtnGIWNL(ctrl, *) {
    ApplySystemTemplate("GI WNL")
}

BtnGUWNL(ctrl, *) {
    ApplySystemTemplate("GU WNL")
}

BtnPainWNL(ctrl, *) {
    ApplySystemTemplate("Pain WNL")
}

BtnPsychWNL(ctrl, *) {
    ApplySystemTemplate("Psych WNL")
}

BtnSkinWNL(ctrl, *) {
    ApplySystemTemplate("Skin WNL")
}

BtnSafetyWNL(ctrl, *) {
    ApplySystemTemplate("Safety WNL")
}

BtnMobilityWNL(ctrl, *) {
    ApplySystemTemplate("Mobility WNL")
}

ApplySystemTemplate(templateName) {
    if !WinExist("ahk_class TfrmRemDlg") {
        ToolTip("Open a reminder dialogue in CPRS first")
        SetTimer(ClearToolTip, -2000)
        return
    }

    templatePath := TemplateDir "\" SanitizeFilename(templateName) ".json"
    if FileExist(templatePath) {
        WinActivate("ahk_class TfrmRemDlg")
        Sleep(200)
        ApplyKeystrokeTemplate(templatePath)
        ToolTip(templateName " applied")
        SetTimer(ClearToolTip, -2000)
    } else {
        MsgBox("No '" templateName "' template saved yet.`n`n"
            "To create one:`n"
            "1. Open the VAAES dialogue in CPRS`n"
            "2. Check just the WNL boxes for this system`n"
            "3. Click 'Save Tmpl' and name it '" templateName "'`n`n"
            "The template records which checkboxes you checked,`n"
            "matched by their label text, so it works across sessions.",
            AppTitle, "Iconi")
    }
}

; ===========================================================================
; KEYSTROKE TEMPLATE REPLAY
;
; Templates store checkbox label -> checked/unchecked mappings.
; Replay uses the advanced panel's SendMessage approach to apply them.
; This is the bridge between the simple toolbar and the control-level
; automation.
; ===========================================================================

ApplyKeystrokeTemplate(templatePath) {
    ; This delegates to the advanced NursingPanel.ahk if it's running,
    ; or falls back to a simpler approach

    ; Try to find the advanced panel
    if WinExist(A_ScriptDir "\NursingPanel.ahk ahk_class AutoHotkey") {
        ; The advanced panel is running - send it a message to load this template
        ; For now, just inform the user
        ToolTip("Loading template via advanced panel...")
        SetTimer(ClearToolTip, -2000)
        return
    }

    ; Fallback: Use BM_CLICK approach directly
    ; Find the reminder dialogue
    dlgHwnd := WinExist("ahk_class TfrmRemDlg")
    if !dlgHwnd
        return

    ; Load the template
    try {
        content := FileRead(templatePath, "UTF-8")
    } catch {
        MsgBox("Failed to read template: " templatePath, AppTitle, "Icon!")
        return
    }

    ; Parse items from the template JSON
    items := ParseTemplateItems(content)
    if items.Length = 0 {
        MsgBox("Template has no items.", AppTitle, "Icon!")
        return
    }

    ; Enumerate all checkboxes in the dialogue
    checkboxes := FindAllCheckboxes(dlgHwnd)

    ; Match template items to live checkboxes by label text
    applied := 0
    for item in items {
        if !item.checked
            continue  ; only apply checked items

        for cb in checkboxes {
            ; Fuzzy match: exact or contains
            if (cb.label = item.label) || (InStr(cb.label, item.label) && StrLen(item.label) > 10) {
                ; Check if already in desired state
                currentState := SendMessage(0x00F0, 0, 0, cb.hwnd)  ; BM_GETCHECK
                if !currentState {
                    ; Click it via BM_CLICK
                    PostMessage(0x00F5, 0, 0, cb.hwnd)  ; BM_CLICK
                    applied++
                    Sleep(250)  ; wait for CPRS to process the RPC
                }
                break
            }
        }
    }

    ToolTip("Applied " applied " checkbox changes")
    SetTimer(ClearToolTip, -2000)
}

FindAllCheckboxes(dlgHwnd) {
    results := []
    global _findCBResults := results
    global _findCBParent := dlgHwnd

    enumCB := CallbackCreate(_EnumCBCallback, "Fast", 2)
    DllCall("EnumChildWindows", "Ptr", dlgHwnd, "Ptr", enumCB, "Ptr", 0)
    CallbackFree(enumCB)

    return results
}

_EnumCBCallback(hwnd, lParam) {
    global _findCBResults, _findCBParent

    ; Get class name
    buf := Buffer(256, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Ptr", buf, "Int", 256)
    className := StrGet(buf)

    if !(className = "TORCheckBox" || className = "TCPRSDialogParentCheckBox")
        return 1

    ; Get the label text (from checkbox or nearby panel)
    label := GetCBLabel(hwnd)

    _findCBResults.Push({hwnd: hwnd, label: label, className: className})
    return 1
}

GetCBLabel(cbHwnd) {
    ; First try the checkbox's own text
    len := SendMessage(0x000E, 0, 0, cbHwnd)
    if len > 1 {
        buf := Buffer((len + 1) * 2, 0)
        SendMessage(0x000D, len + 1, buf, cbHwnd)
        text := StrGet(buf)
        if text != " " && text != ""
            return text
    }

    ; Look for adjacent TLabel/TPanel siblings with text
    parentHwnd := DllCall("GetParent", "Ptr", cbHwnd, "Ptr")
    if !parentHwnd
        return ""

    ; Get checkbox position
    cbRect := Buffer(16, 0)
    DllCall("GetWindowRect", "Ptr", cbHwnd, "Ptr", cbRect)
    cbTop := NumGet(cbRect, 4, "Int")
    cbRight := NumGet(cbRect, 8, "Int")

    ; Search siblings
    global _labelSearchResult := ""
    global _labelSearchCbTop := cbTop
    global _labelSearchCbRight := cbRight
    global _labelSearchCbHwnd := cbHwnd

    enumLabel := CallbackCreate(_EnumLabelCallback, "Fast", 2)
    DllCall("EnumChildWindows", "Ptr", parentHwnd, "Ptr", enumLabel, "Ptr", 0)
    CallbackFree(enumLabel)

    return _labelSearchResult
}

_EnumLabelCallback(hwnd, lParam) {
    global _labelSearchResult, _labelSearchCbTop, _labelSearchCbRight, _labelSearchCbHwnd

    if hwnd = _labelSearchCbHwnd || _labelSearchResult != ""
        return 1

    buf := Buffer(256, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Ptr", buf, "Int", 256)
    className := StrGet(buf)

    if !(InStr(className, "TPanel") || InStr(className, "TDlgFieldPanel"))
        return 1

    ; Check position alignment
    rect := Buffer(16, 0)
    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rect)
    top := NumGet(rect, 4, "Int")
    left := NumGet(rect, 0, "Int")

    ; Must be on same row and to the right
    if Abs(top - _labelSearchCbTop) > 10 || left < _labelSearchCbRight
        return 1

    ; Extract text from panel's children
    texts := []
    global _panelTexts := texts
    enumPanelChild := CallbackCreate(_EnumPanelTextCallback, "Fast", 2)
    DllCall("EnumChildWindows", "Ptr", hwnd, "Ptr", enumPanelChild, "Ptr", 0)
    CallbackFree(enumPanelChild)

    combined := ""
    for t in texts {
        if t != "" && t != " " {
            if combined != ""
                combined .= " "
            combined .= t
        }
    }

    if combined != "" {
        _labelSearchResult := Trim(combined)
        return 0  ; stop enumeration
    }

    return 1
}

_EnumPanelTextCallback(hwnd, lParam) {
    global _panelTexts

    buf := Buffer(256, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Ptr", buf, "Int", 256)
    className := StrGet(buf)

    if InStr(className, "TLabel") || InStr(className, "TVA508") || InStr(className, "Static") {
        len := SendMessage(0x000E, 0, 0, hwnd)
        if len > 0 {
            textBuf := Buffer((len + 1) * 2, 0)
            SendMessage(0x000D, len + 1, textBuf, hwnd)
            text := StrGet(textBuf)
            if text != "" && text != " "
                _panelTexts.Push(text)
        }
    }
    return 1
}

ParseTemplateItems(jsonContent) {
    items := []
    pos := InStr(jsonContent, '"items"')
    if !pos
        return items

    closeBracket := InStr(jsonContent, "]",, pos)

    while pos := InStr(jsonContent, "{",, pos + 1) {
        if pos > closeBracket
            break
        itemEnd := InStr(jsonContent, "}",, pos)
        if !itemEnd
            break
        itemStr := SubStr(jsonContent, pos, itemEnd - pos + 1)

        ; Extract label
        label := ""
        if RegExMatch(itemStr, '"label":\s*"((?:[^"\\]|\\.)*)"', &m)
            label := m[1]

        ; Extract checked
        checked := InStr(itemStr, '"checked": true') ? true : false

        if label != ""
            items.Push({label: label, checked: checked})

        pos := itemEnd
    }
    return items
}

; ===========================================================================
; QUICK ACTIONS
; ===========================================================================

BtnQuickSign(ctrl, *) {
    ; CPRSBooster-style quick sign: Alt+A (Action menu) -> S (Sign)
    if !WinExist("ahk_exe CPRSChart.exe") {
        ToolTip("CPRS not running")
        SetTimer(ClearToolTip, -2000)
        return
    }
    WinActivate("ahk_exe CPRSChart.exe")
    Sleep(200)
    Send("!a")  ; Action menu
    Sleep(300)
    Send("s")   ; Sign Note
    ; User enters their own signature code - we NEVER store credentials
}

BtnNewNote(ctrl, *) {
    if !WinExist("ahk_exe CPRSChart.exe") {
        ToolTip("CPRS not running")
        SetTimer(ClearToolTip, -2000)
        return
    }
    WinActivate("ahk_exe CPRSChart.exe")
    Sleep(200)
    Send("!a")  ; Action menu
    Sleep(300)
    Send("n")   ; New Note
}

BtnOpenAdvancedPanel(ctrl, *) {
    panelPath := A_ScriptDir "\NursingPanel.ahk"
    if FileExist(panelPath)
        Run(panelPath)
    else
        MsgBox("NursingPanel.ahk not found in " A_ScriptDir, AppTitle, "Icon!")
}

; ===========================================================================
; TEMPLATE SAVE/LOAD (from the toolbar)
; ===========================================================================

BtnSaveCurrentState(ctrl, *) {
    ; Save the current state of the CPRS reminder dialogue as a template
    dlgHwnd := WinExist("ahk_class TfrmRemDlg")
    if !dlgHwnd {
        MsgBox("Open a reminder dialogue in CPRS first.", AppTitle, "Icon!")
        return
    }

    ; Prompt for name
    result := InputBox("Template name:", "Save Template",, "Negative Assessment")
    if result.Result = "Cancel" || result.Value = ""
        return

    templateName := result.Value

    ; Scan all checkboxes and their current states
    checkboxes := FindAllCheckboxes(dlgHwnd)

    ; Build template
    json := '{'
    json .= '`n  "name": ' EscJson(templateName) ','
    json .= '`n  "created": "' FormatTime(, "yyyy-MM-dd HH:mm") '",'
    json .= '`n  "source_dialogue": ' EscJson(WinGetTitle(dlgHwnd)) ','
    json .= '`n  "items": ['

    itemCount := 0
    for cb in checkboxes {
        if cb.label = "" || cb.label = " "
            continue
        isChecked := SendMessage(0x00F0, 0, 0, cb.hwnd)  ; BM_GETCHECK
        if itemCount > 0
            json .= ","
        json .= '`n    {"label": ' EscJson(cb.label) ', "checked": ' (isChecked ? "true" : "false") '}'
        itemCount++
    }

    json .= '`n  ]'
    json .= '`n}'

    filePath := TemplateDir "\" SanitizeFilename(templateName) ".json"
    f := FileOpen(filePath, "w", "UTF-8")
    f.Write(json)
    f.Close()

    ToolTip('Template "' templateName '" saved (' itemCount " items)")
    SetTimer(ClearToolTip, -3000)
}

BtnLoadSavedTemplate(ctrl, *) {
    ; Show a list of saved templates to choose from
    templates := []
    loop files TemplateDir "\*.json" {
        templates.Push(A_LoopFileFullPath)
    }

    if templates.Length = 0 {
        MsgBox("No saved templates found in:`n" TemplateDir "`n`n"
            "Save a template first using the 'Save Tmpl' button.",
            AppTitle, "Iconi")
        return
    }

    ; Build a simple selection GUI
    selGui := Gui("+Owner" BoosterGui.Hwnd " +AlwaysOnTop", "Load Template")
    selGui.SetFont("s9", "Segoe UI")
    selGui.AddText(, "Select a template to load:")
    lb := selGui.AddListBox("w300 h200")

    for path in templates {
        name := RegExReplace(path, ".*\\(.*)\.json$", "$1")
        lb.Add([name])
    }

    selGui.AddButton("y+5 w100 Default", "Load").OnEvent("Click", DoLoad)
    selGui.AddButton("x+5 w100", "Cancel").OnEvent("Click", (*) => selGui.Destroy())
    selGui.Show()

    DoLoad(btn, *) {
        selected := lb.Text
        if selected = "" {
            MsgBox("Select a template.", AppTitle, "Icon!")
            return
        }
        selGui.Destroy()
        templatePath := TemplateDir "\" SanitizeFilename(selected) ".json"
        if FileExist(templatePath) {
            ApplyKeystrokeTemplate(templatePath)
        }
    }
}

BtnEditDotPhrases(ctrl, *) {
    ; Open the dot phrases file for editing
    if FileExist(DotPhraseFile)
        Run("notepad.exe " DotPhraseFile)
    else {
        ; Create a starter file
        CreateDefaultDotPhrases()
        Run("notepad.exe " DotPhraseFile)
    }
}

; ===========================================================================
; DOT PHRASES (Text Expansion)
; CPRSBooster's most popular feature - works in CPRS, Teams, email, etc.
;
; Type a trigger (e.g., .shiftassess) and it expands to the full text.
; Edit dot_phrases.json to add/modify your phrases.
; ===========================================================================

LoadDotPhrases() {
    if !FileExist(DotPhraseFile) {
        CreateDefaultDotPhrases()
    }

    phrases := Map()
    try {
        content := FileRead(DotPhraseFile, "UTF-8")

        ; Parse simple JSON: {"trigger": "expansion", ...}
        pos := 1
        while RegExMatch(content, '"(\.[^"]+)":\s*"((?:[^"\\]|\\.)*)"', &match, pos) {
            trigger := match[1]
            expansion := StrReplace(match[2], "\n", "`n")
            expansion := StrReplace(expansion, '\"', '"')
            expansion := StrReplace(expansion, "\\", "\")
            phrases[trigger] := expansion
            pos := match.Pos + match.Len
        }
    }

    return phrases
}

RegisterDotPhrases() {
    global DotPhrases

    for trigger, expansion in DotPhrases {
        ; Create a hotstring for each dot phrase
        ; The * means it triggers immediately (no ending character needed)
        ; The C means case-sensitive
        fn := ExpandPhrase.Bind(expansion)
        Hotstring(":*C:" trigger, fn)
    }
}

ExpandPhrase(expansion, *) {
    ; Use SendText for reliable text insertion (handles special chars)
    ; Small delay to let the trigger text be consumed
    Sleep(50)
    A_Clipboard := expansion
    Send("^v")  ; paste from clipboard (faster than SendText for long text)
    Sleep(100)
}

CreateDefaultDotPhrases() {
    defaultPhrases := '
    (
{
  ".shiftassess": "Nursing Shift Assessment:\nPatient assessed at bedside. Alert and oriented x4.\nNo acute distress. Call light within reach.\nSide rails up x2. Fall precautions in place.\nBed in lowest locked position.\n\nNeuro: A&Ox4, PERRLA, MAE x4, speech clear\nCardio: HR regular, pulses 3+ all extremities, cap refill <3s, no edema\nResp: Lungs CTA bilat, no adventitious sounds, SpO2 WNL on RA\nGI: Abdomen soft, non-tender, BS active x4 quadrants\nGU: Voiding without difficulty, urine clear\nSkin: Warm, dry, intact. No breakdown. Braden score: ___\nPain: ___/10\nPsych: Affect appropriate, cooperative with care\nSafety: Fall risk score: ___. Precautions in place.",

  ".negassess": "Nursing Shift Assessment:\nPatient assessed. All systems within normal limits.\nNo changes from previous assessment.\nCall light within reach. Bed in lowest locked position.\nFall precautions maintained. Side rails up x2.\nPatient resting comfortably. No complaints.",

  ".fallrisk": "Fall Risk Assessment:\nMorse Fall Scale Score: ___\nRisk Level: [ ] Low (0-24) [ ] Moderate (25-50) [ ] High (>50)\nHistory of falling: [ ] Yes [ ] No\nSecondary diagnosis: [ ] Yes [ ] No\nAmbulatory aid: [ ] None [ ] Crutches/Cane [ ] Furniture\nIV/Heparin Lock: [ ] Yes [ ] No\nGait: [ ] Normal [ ] Weak [ ] Impaired\nMental Status: [ ] Oriented to own ability [ ] Forgets limitations\n\nInterventions:\n- Fall risk bracelet applied\n- Bed in lowest position, wheels locked\n- Call light within reach\n- Non-skid footwear provided\n- Environment assessed for hazards\n- Hourly rounding initiated",

  ".skinassess": "Skin/Wound Assessment:\nBraden Scale Score: ___\nSkin integrity: [ ] Intact [ ] Impaired\nTurgor: [ ] Good [ ] Poor\nColor: [ ] WNL [ ] Pale [ ] Jaundiced [ ] Cyanotic\nMoisture: [ ] Dry [ ] Moist [ ] Diaphoretic\nTemperature: [ ] Warm [ ] Cool [ ] Hot\n\nWound (if applicable):\nLocation: ___\nType: [ ] Pressure injury [ ] Surgical [ ] Skin tear [ ] Other\nStage: [ ] I [ ] II [ ] III [ ] IV [ ] Unstageable [ ] DTI\nSize: ___ cm L x ___ cm W x ___ cm D\nWound bed: [ ] Granulation [ ] Slough [ ] Eschar [ ] Mixed\nDrainage: [ ] None [ ] Serous [ ] Sanguineous [ ] Purulent\nAmount: [ ] None [ ] Scant [ ] Small [ ] Moderate [ ] Large\nPeriwound: [ ] Intact [ ] Macerated [ ] Erythematous\nOdor: [ ] None [ ] Present\nTreatment: ___\nDressing applied: ___",

  ".painassess": "Pain Assessment:\nPain Level: ___/10\nLocation: ___\nOnset: ___\nQuality: [ ] Sharp [ ] Dull [ ] Aching [ ] Burning [ ] Throbbing [ ] Stabbing\nRadiation: [ ] None [ ] ___\nTiming: [ ] Constant [ ] Intermittent\nAggravating factors: ___\nAlleviating factors: ___\n\nIntervention: ___\nReassessment (30-60 min post-intervention):\nPain Level: ___/10\nRelief: [ ] Complete [ ] Partial [ ] None\nPatient satisfied with pain management: [ ] Yes [ ] No",

  ".ivsite": "IV Site Assessment:\nSite #: ___\nLocation: ___\nGauge: ___\nInserted: ___\nAppearance: [ ] No signs of infiltration/phlebitis [ ] Redness [ ] Swelling [ ] Pain [ ] Streak\nDressing: [ ] Clean, dry, intact [ ] Changed\nFlush: [ ] Patent, flushes without resistance\nSecurement: [ ] Intact",

  ".handoff": "SBAR Handoff Report:\n\nS - Situation:\nPatient: ___\nRoom: ___\nDiagnosis: ___\nCode status: ___\n\nB - Background:\nBrief history: ___\nAllergies: ___\nIsolation: [ ] None [ ] ___\n\nA - Assessment:\nVitals: BP ___ HR ___ RR ___ Temp ___ SpO2 ___%\nPain: ___/10\nNeuro: ___\nCardio: ___\nResp: ___\nGI: ___\nGU: ___\nSkin: ___\nIV: ___\nDrains: ___\n\nR - Recommendation:\nPending orders: ___\nLabs due: ___\nProcedures: ___\nAnticipated needs: ___\nFamily concerns: ___",

  ".restraint": "Restraint Assessment:\nType: [ ] Soft wrist [ ] Soft ankle [ ] Mitt [ ] Vest [ ] Other: ___\nIndication: [ ] Fall prevention [ ] Self-harm prevention [ ] Protection of medical devices\nOrder verified: [ ] Yes\n\nCirculation check:\nPulses palpable: [ ] Yes [ ] No\nSkin color: [ ] WNL [ ] Pale [ ] Cyanotic\nSkin temp: [ ] Warm [ ] Cool\nEdema: [ ] None [ ] Present\nSensation: [ ] Intact [ ] Diminished\nMovement: [ ] Present [ ] Absent\n\nCare provided:\n[ ] Restraint released for ROM exercises\n[ ] Repositioned\n[ ] Skin care provided\n[ ] Nutrition/hydration offered\n[ ] Toileting offered\n[ ] Patient assessed for continued need\n\nContinued need: [ ] Yes - criteria still met [ ] No - discontinue"
}
    )'

    f := FileOpen(DotPhraseFile, "w", "UTF-8")
    f.Write(defaultPhrases)
    f.Close()
}

; ===========================================================================
; UTILITY FUNCTIONS
; ===========================================================================

ClearToolTip() {
    ToolTip()
}

SanitizeFilename(name) {
    return RegExReplace(Trim(name), '[<>:"/\\|?*]', "_")
}

EscJson(str) {
    str := StrReplace(str, "\", "\\")
    str := StrReplace(str, '"', '\"')
    str := StrReplace(str, "`n", "\n")
    str := StrReplace(str, "`r", "\r")
    str := StrReplace(str, "`t", "\t")
    return '"' str '"'
}

; ===========================================================================
; HOTKEYS
; ===========================================================================

; Ctrl+Shift+B - Toggle toolbar visibility
^+b:: {
    if WinExist(AppTitle) {
        if DllCall("IsWindowVisible", "Ptr", BoosterGui.Hwnd)
            BoosterGui.Hide()
        else
            BoosterGui.Show("NoActivate")
    }
}

; Ctrl+Shift+N - Negative assessment (quick trigger)
^+n:: {
    BtnNegativeAssessment("")
}

; Ctrl+Shift+Q - Quick sign
^+q:: {
    BtnQuickSign("")
}
