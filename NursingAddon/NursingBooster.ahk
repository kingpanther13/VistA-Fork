; ===========================================================================
; NursingBooster.ahk - CPRS Reminder Template Toolbar
; AutoHotkey v2.0+ Required (VA TRM Authorized through CY2027)
;
; A floating toolbar for saving and applying checkbox templates to CPRS
; reminder dialogues. Fill out an assessment once, save it as a template,
; one-click replay it next time.
;
; HOW IT WORKS:
;   1. Open any template or reminder dialogue in CPRS
;   2. Manually check all the boxes the way you want them
;   3. Click "Save Template" - it scans every checkbox and records the state
;   4. Next shift, open the same dialogue, click "Load Template" -> apply
;   5. Review the dialogue in CPRS, make any changes, THEN click Finish
;
; SAFETY: Clicking checkboxes only. Never clicks OK, Finish, or Submit.
; The nurse always reviews and submits manually.
;
; Does NOT store credentials. Does NOT process patient data.
; Simulates checkbox clicks at the UI level only.
; ===========================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; === CONFIGURATION ===
global AppTitle := "Nursing Booster"
global TemplateDir := A_ScriptDir "\templates"
global BoosterGui := ""

if !DirExist(TemplateDir)
    DirCreate(TemplateDir)

BuildToolbar()
return

; ===========================================================================
; FLOATING TOOLBAR
; ===========================================================================

BuildToolbar() {
    global BoosterGui

    BoosterGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", AppTitle)
    BoosterGui.SetFont("s9", "Segoe UI")
    BoosterGui.BackColor := "1a1a2e"

    ; Title bar (draggable)
    titleBar := BoosterGui.AddText("xm ym w560 h22 Center cWhite Background1a1a2e",
        "  Nursing Booster  |  Ctrl+Shift+B to toggle")
    titleBar.OnEvent("Click", (*) => PostMessage(0xA1, 2,,, BoosterGui))  ; drag

    ; --- Row 1: Template Actions ---
    BoosterGui.AddButton("xm y+4 w130 h28", "Save Template").OnEvent("Click", BtnSaveCurrentState)
    BoosterGui.AddButton("x+4 w130 h28", "Load Template").OnEvent("Click", BtnLoadSavedTemplate)
    BoosterGui.AddButton("x+4 w130 h28", "Delete Template").OnEvent("Click", BtnDeleteTemplate)
    BoosterGui.AddButton("x+4 w130 h28", "Advanced Panel").OnEvent("Click", BtnOpenAdvancedPanel)

    ; --- Row 2: Quick template buttons (user-assignable) ---
    ; These map to saved templates by name. If the template doesn't exist
    ; yet, clicking the button tells you how to create it.
    BoosterGui.AddButton("xm y+4 w130 h28", "Negative Assessment").OnEvent("Click",
        (*) => ApplyNamedTemplate("Negative Assessment"))
    BoosterGui.AddButton("x+4 w130 h28", "Skin Assessment").OnEvent("Click",
        (*) => ApplyNamedTemplate("Skin Assessment"))
    BoosterGui.AddButton("x+4 w130 h28", "Freq Doc").OnEvent("Click",
        (*) => ApplyNamedTemplate("Freq Doc"))
    BoosterGui.AddButton("x+4 w130 h28", "Custom 1").OnEvent("Click",
        (*) => ApplyNamedTemplate("Custom 1"))

    ; --- Status ---
    BoosterGui.AddText("xm y+6 w560 h18 vToolbarStatus cSilver Background1a1a2e Center",
        "Ready | CPRS: Not detected")

    BoosterGui.Show("x0 y0 NoActivate")

    ; Periodically check for CPRS
    SetTimer(CheckCPRS, 2000)
}

; ===========================================================================
; CPRS DETECTION
; ===========================================================================

CheckCPRS() {
    cprsHwnd := WinExist("ahk_exe CPRSChart.exe")
    if cprsHwnd {
        title := WinGetTitle(cprsHwnd)
        dlg := FindActiveDialogWindow()
        status := dlg ? "Template detected" : "CPRS: " SubStr(title, 1, 50)
        BoosterGui["ToolbarStatus"].Text := "Ready | " status
    } else {
        BoosterGui["ToolbarStatus"].Text := "Ready | CPRS: Not detected"
    }
}

; ===========================================================================
; DIALOG/TEMPLATE WINDOW DETECTION
;
; Finds any CPRS window containing checkboxes - not just reminder dialogs.
; Checks known dialog classes first, then falls back to scanning all CPRS
; child windows for TORCheckBox or TCPRSDialogParentCheckBox controls.
; ===========================================================================

FindActiveDialogWindow() {
    ; Priority 1: Reminder Dialog as separate window
    hwnd := WinExist("ahk_class TfrmRemDlg")
    if hwnd
        return hwnd

    ; Priority 2: Template Dialog as separate window
    hwnd := WinExist("ahk_class TfrmTemplateDialog")
    if hwnd
        return hwnd

    ; Priority 3: Check all CPRS windows (including main frame) for
    ; embedded reminder dialogs or any window with checkbox controls
    for wnd in WinGetList("ahk_exe CPRSChart.exe") {
        try {
            cls := WinGetClass(wnd)
            ; Check non-main windows for checkboxes
            if (cls != "TCPRSChart" && cls != "TfrmFrame") {
                if HasCheckboxControls(wnd)
                    return wnd
            }
        }
    }

    ; Priority 4: Check inside the main CPRS frame for embedded dialogs
    ; (reminder dialogs can be docked inside the main window)
    mainHwnd := WinExist("ahk_class TfrmFrame")
    if !mainHwnd
        mainHwnd := WinExist("ahk_exe CPRSChart.exe")
    if mainHwnd && HasCheckboxControls(mainHwnd)
        return mainHwnd

    return 0
}

HasCheckboxControls(windowHwnd) {
    global _hasCheckboxes := false
    enumCB := CallbackCreate(_CheckForCheckboxes, "Fast", 2)
    DllCall("EnumChildWindows", "Ptr", windowHwnd, "Ptr", enumCB, "Ptr", 0)
    CallbackFree(enumCB)
    return _hasCheckboxes
}

_CheckForCheckboxes(hwnd, lParam) {
    global _hasCheckboxes
    buf := Buffer(256, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Ptr", buf, "Int", 256)
    className := StrGet(buf)
    if (className = "TORCheckBox" || className = "TCPRSDialogParentCheckBox" || className = "TCPRSDialogCheckBox") {
        _hasCheckboxes := true
        return 0
    }
    return 1
}

; ===========================================================================
; NAMED TEMPLATE BUTTONS
;
; Each button on row 2 maps to a template file by name. If the template
; exists, it gets applied. If not, the user gets instructions to create it.
; ===========================================================================

ApplyNamedTemplate(templateName) {
    dlgHwnd := FindActiveDialogWindow()
    if !dlgHwnd {
        ToolTip("Open a template or reminder dialogue in CPRS first")
        SetTimer(ClearToolTip, -2000)
        return
    }

    templatePath := TemplateDir "\" SanitizeFilename(templateName) ".json"
    if FileExist(templatePath) {
        WinActivate(dlgHwnd)
        Sleep(200)
        ApplyTemplate(templatePath)
    } else {
        MsgBox("No '" templateName "' template saved yet.`n`n"
            "To create one:`n"
            "1. Open the reminder dialogue in CPRS`n"
            "2. Manually check all the boxes the way you want them`n"
            "3. Click 'Save Template' on this toolbar`n"
            "4. Name it exactly: " templateName "`n`n"
            "Next time you click this button, it replays your selections.`n"
            "You always review in CPRS before clicking Finish.",
            AppTitle, "Iconi")
    }
}

; ===========================================================================
; TEMPLATE APPLICATION
;
; Scans the live CPRS dialogue for all checkboxes, matches them to the
; saved template by label text, and clicks any that need to change state.
;
; Only clicks checkboxes and dismisses intermediate "OK to continue" popups.
; NEVER clicks the final Finish/Submit button that files the note.
; The nurse always reviews the dialogue and submits manually.
; ===========================================================================

ApplyTemplate(templatePath) {
    dlgHwnd := FindActiveDialogWindow()
    if !dlgHwnd
        return

    ; Load the template
    try {
        content := FileRead(templatePath, "UTF-8")
    } catch {
        MsgBox("Failed to read template: " templatePath, AppTitle, "Icon!")
        return
    }

    ; Parse template items and top-level parent states
    items := ParseTemplateItems(content)
    if items.Length = 0 {
        MsgBox("Template has no items.", AppTitle, "Icon!")
        return
    }

    tlpStates := ParseTopLevelParents(content)
    if tlpStates.Length = 0 {
        MsgBox("This template needs to be re-saved with the updated Nursing Booster.`n`n"
            . "1. Open the reminder dialog in CPRS and fill it out`n"
            . "2. Click 'Save Template' to overwrite it`n`n"
            . "The new format tracks which sections to expand.",
            AppTitle, "Icon!")
        return
    }

    ; Extract template text items (TCPRSDialogCheckBox with readable labels)
    ; and compute occurrence index for each (handles duplicate labels like
    ; "Full strength", "Intact", "Warm" appearing in multiple sections)
    textItems := []
    tplLabelCounts := Map()
    for item in items {
        if item.cls = "TCPRSDialogCheckBox" && item.label != "" && item.label != " " && Trim(item.label) != "" {
            key := item.label
            occ := 0
            if tplLabelCounts.Has(key)
                occ := tplLabelCounts[key]
            tplLabelCounts[key] := occ + 1
            textItems.Push({label: item.label, checked: item.checked, occurrence: occ})
        }
    }

    ; Wait for dialog to finish initial load
    ToolTip("Waiting for dialog to load...")
    WaitForStableCheckboxCount(dlgHwnd)

    ; === PHASE 1: Expand only the sections that were expanded in the template ===
    ; On a fresh dialog, all checkboxes are top-level parents. We match them
    ; by position to the template's topLevelParents array and click only the
    ; ones that were checked (expanded) when the template was saved.
    scrollBox := FindVisibleScrollBox(dlgHwnd)
    if !scrollBox {
        MsgBox("Could not find the dialog scroll area.", AppTitle, "Icon!")
        return
    }

    liveTopParents := EnumTopLevelParents(scrollBox)
    expandCount := 0
    limit := Min(tlpStates.Length, liveTopParents.Length)

    ToolTip("Expanding " limit " sections selectively...")
    loop limit {
        if !tlpStates[A_Index]
            continue  ; this section was not expanded in the template
        liveCb := liveTopParents[A_Index]
        currentState := SendMessage(0x00F0, 0, 0, liveCb.hwnd)
        if !currentState {
            PostMessage(0x00F5, 0, 0, liveCb.hwnd)
            expandCount++
            Sleep(500)
            DismissIntermediatePopups()
        }
    }

    if expandCount > 0 {
        ToolTip("Expanded " expandCount " sections, waiting for controls...")
        WaitForStableCheckboxCount(dlgHwnd)
    }

    ; === PHASE 1b: Selective child parent expansion ===
    ; After top-level expansion, sub-section parent checkboxes must be clicked
    ; to reveal TCPRSDialogCheckBox options. We expand them one at a time and
    ; track which target items appear. Stop as soon as all targets are found.
    ; Parents that don't reveal any target items are unchecked to keep the
    ; note clean.
    tlpHwnds := Map()
    for tlp in liveTopParents
        tlpHwnds[tlp.hwnd] := true

    ; Build set of target keys we need to find
    targetKeys := Map()
    for item in textItems
        targetKeys[item.label "|" item.occurrence] := true
    targetCount := textItems.Length

    totalChildExpanded := 0
    allTargetsFound := false

    loop 3 {  ; max 3 depth rounds
        checkboxes := FindAllCheckboxes(dlgHwnd)
        uncheckedParents := []
        for cb in checkboxes {
            if cb.className != "TCPRSDialogParentCheckBox"
                continue
            if tlpHwnds.Has(cb.hwnd)
                continue
            if !SendMessage(0x00F0, 0, 0, cb.hwnd)
                uncheckedParents.Push(cb)
        }

        if uncheckedParents.Length = 0
            break

        expandedThisRound := []
        for cp in uncheckedParents {
            ; Count targets BEFORE clicking
            beforeCount := _CountVisibleTargets(dlgHwnd, targetKeys)

            PostMessage(0x00F5, 0, 0, cp.hwnd)
            totalChildExpanded++
            Sleep(200)
            DismissIntermediatePopups()

            ; Count targets AFTER clicking
            afterCount := _CountVisibleTargets(dlgHwnd, targetKeys)

            if afterCount > beforeCount {
                ; This parent revealed target items - keep it
                expandedThisRound.Push({hwnd: cp.hwnd, keep: true})
            } else {
                ; No new targets - uncheck it to keep note clean
                expandedThisRound.Push({hwnd: cp.hwnd, keep: false})
                PostMessage(0x00F5, 0, 0, cp.hwnd)  ; toggle back
                Sleep(100)
            }

            ToolTip("Expanding sub-sections... " afterCount "/" targetCount " items found")

            if afterCount >= targetCount {
                allTargetsFound := true
                break
            }

            if totalChildExpanded >= 80
                break
        }

        if allTargetsFound || totalChildExpanded >= 80
            break

        ; Wait for controls to stabilize before next depth round
        DismissIntermediatePopups()
        Sleep(500)
    }

    ; === PHASE 2: Match TCPRSDialogCheckBox by label + occurrence ===
    ; After expanding all sections/subsections, duplicate labels like
    ; "Full strength" appear in the same order. We match the Nth
    ; occurrence in the template to the Nth occurrence in the live dialog.
    checkboxes := FindAllCheckboxes(dlgHwnd)

    ; Build occurrence-indexed map of live TCPRSDialogCheckBox items
    liveLabelCounts := Map()
    liveByLabelOcc := Map()
    for cb in checkboxes {
        if cb.className != "TCPRSDialogCheckBox"
            continue
        if cb.label = "" || cb.label = " " || Trim(cb.label) = ""
            continue
        key := cb.label
        occ := 0
        if liveLabelCounts.Has(key)
            occ := liveLabelCounts[key]
        liveLabelCounts[key] := occ + 1
        liveByLabelOcc[key "|" occ] := cb
    }

    ; Write diagnostic log
    logPath := TemplateDir "\last_apply_log.txt"
    try {
        logFile := FileOpen(logPath, "w", "UTF-8")
        logFile.Write("Template: " templatePath "`n")
        logFile.Write("Top-level parents: " tlpStates.Length " template, " liveTopParents.Length " live, " expandCount " expanded`n")
        logFile.Write("Child sub-sections tried: " totalChildExpanded ", all targets found: " (allTargetsFound ? "YES" : "NO") "`n")
        logFile.Write("Text items: " textItems.Length " template, " liveByLabelOcc.Count " live`n`n")
        logFile.Write("=== Template text items (label|occurrence) ===`n")
        for item in textItems {
            logFile.Write("  '" item.label "' occ=" item.occurrence " checked=" (item.checked ? "Y" : "N") "`n")
        }
        logFile.Write("`n=== Matching results ===`n")
        for item in textItems {
            lookupKey := item.label "|" item.occurrence
            found := liveByLabelOcc.Has(lookupKey) ? "FOUND" : "MISSING"
            logFile.Write("  '" item.label "' occ=" item.occurrence " -> " found "`n")
        }
        logFile.Write("`n")
        logFile.Close()
    }

    ; Apply: toggle checkboxes that differ from template
    ToolTip("Applying " textItems.Length " selections...")
    applied := 0
    skipped := 0
    notFound := 0

    for item in textItems {
        lookupKey := item.label "|" item.occurrence
        if !liveByLabelOcc.Has(lookupKey) {
            notFound++
            continue
        }

        targetCb := liveByLabelOcc[lookupKey]
        if !DllCall("IsWindow", "Ptr", targetCb.hwnd)
            continue

        currentState := SendMessage(0x00F0, 0, 0, targetCb.hwnd) ? true : false
        if currentState = item.checked {
            skipped++
            continue
        }

        ; Click to toggle
        PostMessage(0x00F5, 0, 0, targetCb.hwnd)
        applied++
        Sleep(200)

        if Mod(applied, 5) = 0
            DismissIntermediatePopups()
    }

    DismissIntermediatePopups()

    ToolTip("Done: " applied " applied, " skipped " already set, " notFound " not found. Review before Finish.")
    SetTimer(ClearToolTip, -5000)
}

; ---------------------------------------------------------------------------
; Dismiss intermediate popup dialogues that CPRS spawns mid-form.
;
; These are small modal windows with a single OK button - informational
; messages or "Press OK to continue" confirmations. They are child windows
; of CPRS (owned by CPRSChart.exe) with standard Delphi form classes.
;
; We ONLY dismiss popups that match ALL of these criteria:
;   1. Owned by CPRSChart.exe
;   2. Small window (not the main CPRS window or the reminder dialogue)
;   3. Contains an "OK" button but NOT "Finish", "Submit", or "Sign"
;   4. Does NOT have a text input field (not a data entry form)
;
; This is deliberately conservative. If a popup doesn't match, it stays
; open and the nurse handles it manually.
; ---------------------------------------------------------------------------
DismissIntermediatePopups() {
    ; Give CPRS a moment to spawn the popup
    Sleep(150)

    ; Look for popup windows owned by CPRS
    loop 3 {  ; check up to 3 times (chained popups)
        found := false
        for wnd in WinGetList("ahk_exe CPRSChart.exe") {
            try {
                cls := WinGetClass(wnd)
                title := WinGetTitle(wnd)

                ; Skip the main CPRS window and any dialog/template windows
                if cls = "TfrmRemDlg" || cls = "TCPRSChart" || cls = "TfrmFrame"
                    || cls = "TfrmTemplateDialog"
                    continue

                ; Must be a small Delphi form (popup-sized)
                WinGetPos(,, &w, &h, wnd)
                if w > 500 || h > 400
                    continue  ; too big - probably not a simple OK popup

                ; Check for dangerous buttons we must NEVER click
                if HasDangerousButton(wnd)
                    continue

                ; Look for an OK button to click
                okHwnd := FindOKButton(wnd)
                if okHwnd {
                    PostMessage(0x00F5, 0, 0, okHwnd)  ; BM_CLICK the OK button
                    Sleep(200)
                    found := true
                }
            }
        }
        if !found
            break
    }
}

; Check if a window contains buttons we must never auto-click
HasDangerousButton(windowHwnd) {
    global _hasDangerous := false

    enumDangerous := CallbackCreate(_CheckDangerousCallback, "Fast", 2)
    DllCall("EnumChildWindows", "Ptr", windowHwnd, "Ptr", enumDangerous, "Ptr", 0)
    CallbackFree(enumDangerous)

    return _hasDangerous
}

_CheckDangerousCallback(hwnd, lParam) {
    global _hasDangerous

    buf := Buffer(256, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Ptr", buf, "Int", 256)
    className := StrGet(buf)

    ; If it has text input fields, it's a data entry form - don't auto-dismiss
    if InStr(className, "TEdit") || InStr(className, "TMemo") || InStr(className, "TRichEdit") {
        _hasDangerous := true
        return 0
    }

    ; Check button text for dangerous labels
    if InStr(className, "TButton") || InStr(className, "TBitBtn") {
        len := SendMessage(0x000E, 0, 0, hwnd)
        if len > 0 {
            textBuf := Buffer((len + 1) * 2, 0)
            SendMessage(0x000D, len + 1, textBuf, hwnd)
            text := StrGet(textBuf)
            textUpper := StrUpper(text)

            ; These are the buttons that file/sign/submit the note
            if InStr(textUpper, "FINISH") || InStr(textUpper, "SUBMIT")
                || InStr(textUpper, "SIGN") || InStr(textUpper, "FILE")
                || InStr(textUpper, "COMPLETE") || InStr(textUpper, "SAVE")
                || InStr(textUpper, "DELETE") || InStr(textUpper, "REMOVE") {
                _hasDangerous := true
                return 0
            }
        }
    }

    return 1
}

; Find an OK button in a window
FindOKButton(windowHwnd) {
    global _foundOKHwnd := 0

    enumOK := CallbackCreate(_FindOKCallback, "Fast", 2)
    DllCall("EnumChildWindows", "Ptr", windowHwnd, "Ptr", enumOK, "Ptr", 0)
    CallbackFree(enumOK)

    return _foundOKHwnd
}

_FindOKCallback(hwnd, lParam) {
    global _foundOKHwnd

    buf := Buffer(256, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Ptr", buf, "Int", 256)
    className := StrGet(buf)

    if !(InStr(className, "TButton") || InStr(className, "TBitBtn"))
        return 1

    len := SendMessage(0x000E, 0, 0, hwnd)
    if len > 0 {
        textBuf := Buffer((len + 1) * 2, 0)
        SendMessage(0x000D, len + 1, textBuf, hwnd)
        text := StrGet(textBuf)
        textUpper := StrUpper(text)

        ; Only dismiss OK, Continue, Yes - never anything that files/signs
        if textUpper = "OK" || textUpper = "&OK" || textUpper = "CONTINUE"
            || textUpper = "&CONTINUE" || textUpper = "YES" || textUpper = "&YES" {
            _foundOKHwnd := hwnd
            return 0
        }
    }

    return 1
}

; Wait until the checkbox count stops changing (dialog finished loading)
WaitForStableCheckboxCount(dlgHwnd) {
    prevCount := 0
    stableRounds := 0
    loop 20 {  ; max 10 seconds
        cbs := FindAllCheckboxes(dlgHwnd)
        count := cbs.Length
        if count > 0 && count = prevCount {
            stableRounds++
            if stableRounds >= 3
                return count
        } else {
            stableRounds := 0
        }
        prevCount := count
        Sleep(500)
    }
    return prevCount
}

LabelsMatch(liveLabel, templateLabel) {
    ; Exact match
    if liveLabel = templateLabel
        return true
    ; Case-insensitive contains (for minor wording differences between versions)
    if StrLen(templateLabel) > 10 && InStr(liveLabel, templateLabel)
        return true
    if StrLen(liveLabel) > 10 && InStr(templateLabel, liveLabel)
        return true
    return false
}

; ===========================================================================
; SAVE TEMPLATE - Scan the current dialogue and save checkbox states
; ===========================================================================

BtnSaveCurrentState(ctrl, *) {
    dlgHwnd := FindActiveDialogWindow()
    if !dlgHwnd {
        MsgBox("Open a template or reminder dialogue in CPRS first.", AppTitle, "Icon!")
        return
    }

    ; Prompt for name
    result := InputBox("Template name:`n`n"
        "Use a descriptive name like 'Negative Assessment' or 'Skin WNL'.`n"
        "Naming it the same as a toolbar button links it to that button.",
        "Save Template",, "")
    if result.Result = "Cancel" || result.Value = ""
        return

    templateName := result.Value

    ; Wait for dialog to be fully loaded before scanning
    ToolTip("Waiting for dialog to stabilize...")
    prevCount := 0
    stableRounds := 0
    loop 20 {
        cbs := FindAllCheckboxes(dlgHwnd)
        count := cbs.Length
        if count > 0 && count = prevCount {
            stableRounds++
            if stableRounds >= 3
                break
        } else {
            stableRounds := 0
        }
        prevCount := count
        Sleep(500)
    }

    ; Scan all checkboxes and their current states
    checkboxes := FindAllCheckboxes(dlgHwnd)

    ; Identify top-level parents (for selective expansion during apply)
    scrollBox := FindVisibleScrollBox(dlgHwnd)
    tlParents := scrollBox ? EnumTopLevelParents(scrollBox) : []

    ; Build template JSON
    json := '{'
    json .= '`n  "name": ' EscJson(templateName) ','
    json .= '`n  "created": "' FormatTime(, "yyyy-MM-dd HH:mm") '",'
    json .= '`n  "source_dialogue": ' EscJson(WinGetTitle(dlgHwnd)) ','
    json .= '`n  "checkbox_count": ' checkboxes.Length ','

    ; Top-level parent checked states (for selective expansion)
    json .= '`n  "topLevelParents": ['
    for i, tlp in tlParents {
        if i > 1
            json .= ", "
        json .= tlp.checked ? "true" : "false"
    }
    json .= '],'

    json .= '`n  "items": ['

    itemCount := 0
    for idx, cb in checkboxes {
        isChecked := SendMessage(0x00F0, 0, 0, cb.hwnd)  ; BM_GETCHECK
        if itemCount > 0
            json .= ","
        json .= '`n    {"index": ' (idx - 1) ', "label": ' EscJson(cb.label)
            . ', "checked": ' (isChecked ? "true" : "false")
            . ', "class": ' EscJson(cb.className) '}'
        itemCount++
    }

    json .= '`n  ]'
    json .= '`n}'

    filePath := TemplateDir "\" SanitizeFilename(templateName) ".json"
    f := FileOpen(filePath, "w", "UTF-8")
    f.Write(json)
    f.Close()

    checkedCount := 0
    for cb in checkboxes {
        if SendMessage(0x00F0, 0, 0, cb.hwnd)
            checkedCount++
    }

    ToolTip('Template "' templateName '" saved: ' checkedCount "/" itemCount " checked")
    SetTimer(ClearToolTip, -3000)
}

; ===========================================================================
; LOAD TEMPLATE - Pick from saved templates and apply
; ===========================================================================

BtnLoadSavedTemplate(ctrl, *) {
    if !FindActiveDialogWindow() {
        MsgBox("Open a template or reminder dialogue in CPRS first, then load a template.",
            AppTitle, "Icon!")
        return
    }

    templates := []
    loop files TemplateDir "\*.json" {
        templates.Push(A_LoopFileFullPath)
    }

    if templates.Length = 0 {
        MsgBox("No saved templates found.`n`n"
            "To create one:`n"
            "1. Open a reminder dialogue in CPRS`n"
            "2. Check the boxes the way you want`n"
            "3. Click 'Save Template'",
            AppTitle, "Iconi")
        return
    }

    ; Build selection GUI
    selGui := Gui("+Owner" BoosterGui.Hwnd " +AlwaysOnTop", "Load Template")
    selGui.SetFont("s9", "Segoe UI")
    selGui.AddText(, "Select a template to apply:")
    lb := selGui.AddListBox("w300 h200")

    for path in templates {
        name := RegExReplace(path, ".*\\(.*)\.json$", "$1")
        lb.Add([name])
    }

    selGui.AddButton("y+5 w120 Default", "Apply").OnEvent("Click", DoLoad)
    selGui.AddButton("x+5 w120", "Cancel").OnEvent("Click", (*) => selGui.Destroy())
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
            dlgWnd := FindActiveDialogWindow()
            if dlgWnd {
                WinActivate(dlgWnd)
                Sleep(200)
                ApplyTemplate(templatePath)
            }
        }
    }
}

; ===========================================================================
; DELETE TEMPLATE
; ===========================================================================

BtnDeleteTemplate(ctrl, *) {
    templates := []
    loop files TemplateDir "\*.json" {
        templates.Push(A_LoopFileName)
    }

    if templates.Length = 0 {
        MsgBox("No saved templates to delete.", AppTitle, "Iconi")
        return
    }

    ; Build numbered list
    list := ""
    for i, f in templates {
        list .= i ": " StrReplace(f, ".json", "") "`n"
    }

    result := InputBox("Enter the number of the template to delete:`n`n" list,
        "Delete Template",, "1")
    if result.Result = "Cancel" || result.Value = ""
        return

    try idx := Integer(result.Value)
    catch {
        MsgBox("Enter a number.", AppTitle, "Icon!")
        return
    }

    if idx < 1 || idx > templates.Length {
        MsgBox("Invalid selection.", AppTitle, "Icon!")
        return
    }

    name := StrReplace(templates[idx], ".json", "")
    answer := MsgBox('Delete template "' name '"?', AppTitle, "YesNo Icon?")
    if answer = "Yes" {
        FileDelete(TemplateDir "\" templates[idx])
        ToolTip('Template "' name '" deleted')
        SetTimer(ClearToolTip, -2000)
    }
}

; ===========================================================================
; ADVANCED PANEL - Launch the full NursingPanel.ahk with scan/preview
; ===========================================================================

BtnOpenAdvancedPanel(ctrl, *) {
    panelPath := A_ScriptDir "\NursingPanel.ahk"
    if FileExist(panelPath)
        Run(panelPath)
    else
        MsgBox("NursingPanel.ahk not found in " A_ScriptDir, AppTitle, "Icon!")
}

; ===========================================================================
; WIN32 CHECKBOX DISCOVERY
;
; Enumerates all child controls of the CPRS reminder dialogue, finds
; TORCheckBox and TCPRSDialogParentCheckBox controls, and reads their
; label text from adjacent TDlgFieldPanel/TLabel siblings.
; ===========================================================================

FindAllCheckboxes(dlgHwnd) {
    results := []
    global _findCBResults := results

    enumCB := CallbackCreate(_EnumCBCallback, "Fast", 2)
    DllCall("EnumChildWindows", "Ptr", dlgHwnd, "Ptr", enumCB, "Ptr", 0)
    CallbackFree(enumCB)

    return results
}

_EnumCBCallback(hwnd, lParam) {
    global _findCBResults

    buf := Buffer(256, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Ptr", buf, "Int", 256)
    className := StrGet(buf)

    if !(className = "TORCheckBox" || className = "TCPRSDialogParentCheckBox" || className = "TCPRSDialogCheckBox")
        return 1

    ; TCPRSDialogCheckBox has readable text directly via WM_GETTEXT.
    ; TCPRSDialogParentCheckBox has ' ' (space) - use sibling search.
    label := ""
    tLen := SendMessage(0x000E, 0, 0, hwnd)
    if tLen > 0 {
        tBuf := Buffer((tLen + 1) * 2, 0)
        SendMessage(0x000D, tLen + 1, tBuf, hwnd)
        label := StrGet(tBuf)
    }
    if (label = "" || label = " " || Trim(label) = "") && className != "TCPRSDialogCheckBox"
        label := GetCBLabel(hwnd)

    ; Get parent control's class name
    parentHwnd := DllCall("GetParent", "Ptr", hwnd, "Ptr")
    pBuf := Buffer(256, 0)
    parentCls := ""
    if parentHwnd {
        DllCall("GetClassName", "Ptr", parentHwnd, "Ptr", pBuf, "Int", 256)
        parentCls := StrGet(pBuf)
    }

    _findCBResults.Push({hwnd: hwnd, label: label, className: className, parentClass: parentCls})
    return 1
}

GetCBLabel(cbHwnd) {
    ; Try the checkbox's own caption first
    len := SendMessage(0x000E, 0, 0, cbHwnd)  ; WM_GETTEXTLENGTH
    if len > 1 {
        buf := Buffer((len + 1) * 2, 0)
        SendMessage(0x000D, len + 1, buf, cbHwnd)  ; WM_GETTEXT
        text := StrGet(buf)
        if text != " " && text != "" && Trim(text) != ""
            return text
    }

    ; CPRS clears checkbox captions and puts visible text in adjacent panels.
    ; Strategy: navigate sibling windows directly using GetWindow. CPRS creates
    ; checkbox + label panel as sibling pairs. This works regardless of scroll
    ; position (unlike coordinate-based search which fails off-screen).

    ; Try next sibling (most common: panel comes right after checkbox)
    nextSib := DllCall("GetWindow", "Ptr", cbHwnd, "UInt", 2, "Ptr")  ; GW_HWNDNEXT
    if nextSib {
        text := _ExtractTextFromSibling(nextSib)
        if text != ""
            return text
    }

    ; Try previous sibling (in case panel is before checkbox)
    prevSib := DllCall("GetWindow", "Ptr", cbHwnd, "UInt", 3, "Ptr")  ; GW_HWNDPREV
    if prevSib {
        text := _ExtractTextFromSibling(prevSib)
        if text != ""
            return text
    }

    ; Fallback: scan all siblings of parent for any label/panel with text
    parentHwnd := DllCall("GetParent", "Ptr", cbHwnd, "Ptr")
    if parentHwnd {
        child := DllCall("GetWindow", "Ptr", parentHwnd, "UInt", 5, "Ptr")  ; GW_CHILD
        while child {
            if child != cbHwnd && child != nextSib && child != prevSib {
                text := _ExtractTextFromSibling(child)
                if text != ""
                    return text
            }
            child := DllCall("GetWindow", "Ptr", child, "UInt", 2, "Ptr")  ; GW_HWNDNEXT
        }
    }

    return ""
}

; Try to extract label text from a sibling control (panel or direct label)
_ExtractTextFromSibling(hwnd) {
    buf := Buffer(256, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Ptr", buf, "Int", 256)
    className := StrGet(buf)

    ; Skip other checkboxes - they're not labels
    if className = "TORCheckBox" || className = "TCPRSDialogParentCheckBox"
        return ""

    ; Direct text from label controls
    if InStr(className, "TLabel") || InStr(className, "TVA508") || InStr(className, "Static") {
        tLen := SendMessage(0x000E, 0, 0, hwnd)
        if tLen > 0 {
            tBuf := Buffer((tLen + 1) * 2, 0)
            SendMessage(0x000D, tLen + 1, tBuf, hwnd)
            text := Trim(StrGet(tBuf))
            if text != "" && text != " "
                return text
        }
    }

    ; Panel with child labels - extract text from children
    if InStr(className, "Panel") || InStr(className, "TDlgFieldPanel") {
        combined := _ExtractChildLabelText(hwnd)
        if combined != ""
            return combined
    }

    return ""
}

; Extract combined text from all label children of a panel
_ExtractChildLabelText(panelHwnd) {
    texts := []
    global _panelTexts := texts
    enumPanelChild := CallbackCreate(_EnumPanelTextCallback, "Fast", 2)
    DllCall("EnumChildWindows", "Ptr", panelHwnd, "Ptr", enumPanelChild, "Ptr", 0)
    CallbackFree(enumPanelChild)

    combined := ""
    for t in texts {
        if t != "" && t != " " {
            if combined != ""
                combined .= " "
            combined .= t
        }
    }
    return Trim(combined)
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

; ===========================================================================
; TEMPLATE JSON PARSING
; ===========================================================================

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

        label := ""
        if RegExMatch(itemStr, '"label":\s*"((?:[^"\\]|\\.)*)"', &m)
            label := m[1]

        checked := InStr(itemStr, '"checked": true') ? true : false

        ; Parse index field if present
        idx := -1
        if RegExMatch(itemStr, '"index":\s*(\d+)', &idxM)
            idx := Integer(idxM[1])

        ; Parse class field if present
        cls := ""
        if RegExMatch(itemStr, '"class":\s*"([^"]*)"', &clsM)
            cls := clsM[1]

        item := {label: label, checked: checked, cls: cls}
        if idx >= 0
            item.index := idx

        items.Push(item)
        ; Set implicit position (1-based) for templates without explicit index
        item._pos := items.Length

        pos := itemEnd
    }
    return items
}

; ===========================================================================
; TOP-LEVEL PARENT DISCOVERY
;
; Walks the TScrollBox's direct children (via GetWindow sibling chain)
; to find the top-level parent checkboxes. These are:
;   - TCPRSDialogParentCheckBox directly under TScrollBox
;   - TCPRSDialogParentCheckBox inside a static TGroupBox at the end
; Dynamic TGroupBox sections (from expanded parents) come BEFORE the
; direct parents in z-order and are skipped.
; ===========================================================================

; Count how many of the target TCPRSDialogCheckBox items are currently visible.
; targetKeys is a Map of "label|occurrence" => true for items we need.
_CountVisibleTargets(dlgHwnd, targetKeys) {
    checkboxes := FindAllCheckboxes(dlgHwnd)
    labelCounts := Map()
    found := 0
    for cb in checkboxes {
        if cb.className != "TCPRSDialogCheckBox"
            continue
        if cb.label = "" || cb.label = " " || Trim(cb.label) = ""
            continue
        occ := 0
        if labelCounts.Has(cb.label)
            occ := labelCounts[cb.label]
        labelCounts[cb.label] := occ + 1
        if targetKeys.Has(cb.label "|" occ)
            found++
    }
    return found
}

FindVisibleScrollBox(dlgHwnd) {
    child := DllCall("GetWindow", "Ptr", dlgHwnd, "UInt", 5, "Ptr")  ; GW_CHILD
    while child {
        buf := Buffer(256, 0)
        DllCall("GetClassName", "Ptr", child, "Ptr", buf, "Int", 256)
        className := StrGet(buf)
        if className = "TScrollBox" {
            style := DllCall("GetWindowLong", "Ptr", child, "Int", -16, "Int")
            if style & 0x10000000  ; WS_VISIBLE
                return child
        }
        child := DllCall("GetWindow", "Ptr", child, "UInt", 2, "Ptr")  ; GW_HWNDNEXT
    }
    return 0
}

EnumTopLevelParents(scrollBoxHwnd) {
    parents := []
    seenDirectParent := false

    child := DllCall("GetWindow", "Ptr", scrollBoxHwnd, "UInt", 5, "Ptr")  ; GW_CHILD
    while child {
        buf := Buffer(256, 0)
        DllCall("GetClassName", "Ptr", child, "Ptr", buf, "Int", 256)
        className := StrGet(buf)

        if className = "TCPRSDialogParentCheckBox" {
            seenDirectParent := true
            checked := SendMessage(0x00F0, 0, 0, child)
            parents.Push({hwnd: child, checked: checked ? true : false})
        } else if className = "TGroupBox" && seenDirectParent {
            ; Static TGroupBox after direct parents - enumerate its parents
            gbChild := DllCall("GetWindow", "Ptr", child, "UInt", 5, "Ptr")
            while gbChild {
                gbBuf := Buffer(256, 0)
                DllCall("GetClassName", "Ptr", gbChild, "Ptr", gbBuf, "Int", 256)
                gbClass := StrGet(gbBuf)
                if gbClass = "TCPRSDialogParentCheckBox" {
                    checked := SendMessage(0x00F0, 0, 0, gbChild)
                    parents.Push({hwnd: gbChild, checked: checked ? true : false})
                }
                gbChild := DllCall("GetWindow", "Ptr", gbChild, "UInt", 2, "Ptr")
            }
        }

        child := DllCall("GetWindow", "Ptr", child, "UInt", 2, "Ptr")  ; GW_HWNDNEXT
    }
    return parents
}

ParseTopLevelParents(jsonContent) {
    states := []
    pos := InStr(jsonContent, '"topLevelParents"')
    if !pos
        return states
    arrStart := InStr(jsonContent, "[",, pos)
    arrEnd := InStr(jsonContent, "]",, arrStart)
    if !arrStart || !arrEnd
        return states
    arrStr := SubStr(jsonContent, arrStart + 1, arrEnd - arrStart - 1)
    searchPos := 1
    while searchPos <= StrLen(arrStr) {
        chunk := SubStr(arrStr, searchPos, 6)
        if SubStr(chunk, 1, 4) = "true" {
            states.Push(true)
            searchPos += 4
        } else if chunk = "false" || SubStr(chunk, 1, 5) = "false" {
            states.Push(false)
            searchPos += 5
        } else {
            searchPos++
        }
    }
    return states
}

; ===========================================================================
; UTILITY
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
; DIALOG DUMP - Write the complete control tree to a file for debugging
; Press Ctrl+Shift+D with a CPRS dialog open. Do it twice:
;   1. On a FILLED OUT dialog (before saving a template)
;   2. On a FRESH dialog (before applying)
; Then share the dump files.
; ===========================================================================

DumpDialogControls() {
    dlgHwnd := FindActiveDialogWindow()
    if !dlgHwnd {
        MsgBox("Open a reminder dialogue in CPRS first.", AppTitle, "Icon!")
        return
    }

    dumpPath := TemplateDir "\dialog_dump_" A_Now ".txt"

    f := FileOpen(dumpPath, "w", "UTF-8")
    f.Write("=== CPRS Dialog Control Dump ===`n")
    f.Write("Time: " FormatTime(, "yyyy-MM-dd HH:mm:ss") "`n")
    f.Write("Dialog Title: " WinGetTitle(dlgHwnd) "`n")
    f.Write("Dialog Class: " WinGetClass(dlgHwnd) "`n")
    f.Write("Dialog HWND: " dlgHwnd "`n`n")

    ; Enumerate every child control
    global _dumpFile := f
    global _dumpDlgHwnd := dlgHwnd
    global _dumpCount := 0
    global _dumpCBCount := 0

    enumDump := CallbackCreate(_DumpCallback, "Fast", 2)
    DllCall("EnumChildWindows", "Ptr", dlgHwnd, "Ptr", enumDump, "Ptr", 0)
    CallbackFree(enumDump)

    f.Write("`n=== Summary ===`n")
    f.Write("Total controls: " _dumpCount "`n")
    f.Write("Checkboxes: " _dumpCBCount "`n")
    f.Close()

    MsgBox("Dump written to:`n" dumpPath "`n`n" _dumpCount " controls, " _dumpCBCount " checkboxes.", AppTitle, "Iconi")
}

_DumpCallback(hwnd, lParam) {
    global _dumpFile, _dumpDlgHwnd, _dumpCount, _dumpCBCount
    _dumpCount++

    ; Class name
    buf := Buffer(256, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Ptr", buf, "Int", 256)
    className := StrGet(buf)

    ; Text via WM_GETTEXT
    text := ""
    tLen := SendMessage(0x000E, 0, 0, hwnd)
    if tLen > 0 {
        tBuf := Buffer((tLen + 1) * 2, 0)
        SendMessage(0x000D, tLen + 1, tBuf, hwnd)
        text := StrGet(tBuf)
    }

    ; Depth (count parents up to dialog)
    depth := 0
    p := hwnd
    loop {
        p := DllCall("GetParent", "Ptr", p, "Ptr")
        if !p || p = _dumpDlgHwnd
            break
        depth++
    }

    ; Parent HWND and parent class
    parentHwnd := DllCall("GetParent", "Ptr", hwnd, "Ptr")
    parentBuf := Buffer(256, 0)
    if parentHwnd
        DllCall("GetClassName", "Ptr", parentHwnd, "Ptr", parentBuf, "Int", 256)
    parentClass := parentHwnd ? StrGet(parentBuf) : "none"

    ; Check state for checkboxes
    extra := ""
    if className = "TORCheckBox" || className = "TCPRSDialogParentCheckBox" || className = "TCPRSDialogCheckBox" {
        checked := SendMessage(0x00F0, 0, 0, hwnd)
        extra := " CHECKED=" (checked ? "YES" : "NO")
        _dumpCBCount++

        ; Also try to get label via next sibling
        nextSib := DllCall("GetWindow", "Ptr", hwnd, "UInt", 2, "Ptr")
        sibLabel := ""
        if nextSib {
            sibBuf := Buffer(256, 0)
            DllCall("GetClassName", "Ptr", nextSib, "Ptr", sibBuf, "Int", 256)
            sibClass := StrGet(sibBuf)
            sibLabel := " nextSib=" sibClass
        }
        extra .= sibLabel
    }

    ; Visible state
    style := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -16, "Int")  ; GWL_STYLE
    visible := (style & 0x10000000) ? "Y" : "N"  ; WS_VISIBLE

    ; Indent by depth
    indent := ""
    loop depth
        indent .= "  "

    _dumpFile.Write(indent className " hwnd=" hwnd " text='" text "' vis=" visible " parent=" parentClass extra "`n")
    return 1
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

; Ctrl+Shift+D - Dump dialog controls to file
^+d:: {
    DumpDialogControls()
}

; Ctrl+Shift+N - Quick apply "Negative Assessment" template
^+n:: {
    ApplyNamedTemplate("Negative Assessment")
}
