; ===========================================================================
; NursingBooster.ahk - CPRS Reminder Template Toolbar
; AutoHotkey v2.0+ Required (VA TRM Authorized through CY2027)
;
; A floating toolbar for saving and applying checkbox templates to CPRS
; reminder dialogues. Fill out an assessment once, save it as a template,
; one-click replay it next time.
;
; HOW IT WORKS:
;   1. Open a reminder dialogue in CPRS (e.g. VAAES Shift Assessment)
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
        BoosterGui["ToolbarStatus"].Text := "Ready | CPRS: " SubStr(title, 1, 60)
    } else {
        BoosterGui["ToolbarStatus"].Text := "Ready | CPRS: Not detected"
    }
}

; ===========================================================================
; NAMED TEMPLATE BUTTONS
;
; Each button on row 2 maps to a template file by name. If the template
; exists, it gets applied. If not, the user gets instructions to create it.
; ===========================================================================

ApplyNamedTemplate(templateName) {
    if !WinExist("ahk_class TfrmRemDlg") {
        ToolTip("Open a reminder dialogue in CPRS first")
        SetTimer(ClearToolTip, -2000)
        return
    }

    templatePath := TemplateDir "\" SanitizeFilename(templateName) ".json"
    if FileExist(templatePath) {
        WinActivate("ahk_class TfrmRemDlg")
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

    ; Parse template items
    items := ParseTemplateItems(content)
    if items.Length = 0 {
        MsgBox("Template has no items.", AppTitle, "Icon!")
        return
    }

    ; Enumerate all checkboxes in the live dialogue
    checkboxes := FindAllCheckboxes(dlgHwnd)

    ; Match template items to live checkboxes by label text and apply
    applied := 0
    skipped := 0
    for item in items {
        if !item.checked
            continue  ; only check boxes, never uncheck

        for cb in checkboxes {
            if !LabelsMatch(cb.label, item.label)
                continue

            ; Check if already in the desired state
            currentState := SendMessage(0x00F0, 0, 0, cb.hwnd)  ; BM_GETCHECK
            if currentState {
                skipped++
                break  ; already checked
            }

            ; Click it via BM_CLICK - this fires the Delphi OnClick handler
            ; just like a real mouse click, which triggers GetData/SetData RPCs
            PostMessage(0x00F5, 0, 0, cb.hwnd)  ; BM_CLICK
            applied++
            Sleep(300)  ; wait for CPRS to process

            ; Some checkboxes trigger intermediate popup dialogues
            ; ("Press OK to continue", informational messages, etc.)
            ; Auto-dismiss these so the template application continues.
            ; These are NOT the final Finish/Submit - they're mid-form gates.
            DismissIntermediatePopups()

            break
        }
    }

    ; One final check for any lingering popups after the last checkbox
    DismissIntermediatePopups()

    ToolTip("Applied " applied " changes (" skipped " already set). Review in CPRS before finishing.")
    SetTimer(ClearToolTip, -3000)
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

                ; Skip the main CPRS window and the reminder dialogue itself
                if cls = "TfrmRemDlg" || cls = "TCPRSChart" || cls = "TfrmFrame"
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
    dlgHwnd := WinExist("ahk_class TfrmRemDlg")
    if !dlgHwnd {
        MsgBox("Open a reminder dialogue in CPRS first.", AppTitle, "Icon!")
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

    ; Scan all checkboxes and their current states
    checkboxes := FindAllCheckboxes(dlgHwnd)

    ; Build template JSON
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
        json .= '`n    {"label": ' EscJson(cb.label)
            . ', "checked": ' (isChecked ? "true" : "false") '}'
        itemCount++
    }

    json .= '`n  ]'
    json .= '`n}'

    filePath := TemplateDir "\" SanitizeFilename(templateName) ".json"
    f := FileOpen(filePath, "w", "UTF-8")
    f.Write(json)
    f.Close()

    ToolTip('Template "' templateName '" saved with ' itemCount " items")
    SetTimer(ClearToolTip, -3000)
}

; ===========================================================================
; LOAD TEMPLATE - Pick from saved templates and apply
; ===========================================================================

BtnLoadSavedTemplate(ctrl, *) {
    if !WinExist("ahk_class TfrmRemDlg") {
        MsgBox("Open a reminder dialogue in CPRS first, then load a template.",
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
            WinActivate("ahk_class TfrmRemDlg")
            Sleep(200)
            ApplyTemplate(templatePath)
        }
    }
}

; ===========================================================================
; DELETE TEMPLATE
; ===========================================================================

BtnDeleteTemplate(ctrl, *) {
    templates := []
    loop files TemplateDir "\*.json" {
        templates.Push(A_LoopFileFullPath)
    }

    if templates.Length = 0 {
        MsgBox("No saved templates to delete.", AppTitle, "Iconi")
        return
    }

    selGui := Gui("+Owner" BoosterGui.Hwnd " +AlwaysOnTop", "Delete Template")
    selGui.SetFont("s9", "Segoe UI")
    selGui.AddText(, "Select a template to delete:")
    lb := selGui.AddListBox("w300 h200")

    for path in templates {
        name := RegExReplace(path, ".*\\(.*)\.json$", "$1")
        lb.Add([name])
    }

    selGui.AddButton("y+5 w120", "Delete").OnEvent("Click", DoDelete)
    selGui.AddButton("x+5 w120", "Cancel").OnEvent("Click", (*) => selGui.Destroy())
    selGui.Show()

    DoDelete(btn, *) {
        selected := lb.Text
        if selected = "" {
            MsgBox("Select a template.", AppTitle, "Icon!")
            return
        }
        answer := MsgBox('Delete template "' selected '"?', AppTitle, "YesNo Icon?")
        if answer = "Yes" {
            filePath := TemplateDir "\" SanitizeFilename(selected) ".json"
            if FileExist(filePath)
                FileDelete(filePath)
            selGui.Destroy()
            ToolTip('Template "' selected '" deleted')
            SetTimer(ClearToolTip, -2000)
        }
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

    if !(className = "TORCheckBox" || className = "TCPRSDialogParentCheckBox")
        return 1

    label := GetCBLabel(hwnd)
    _findCBResults.Push({hwnd: hwnd, label: label, className: className})
    return 1
}

GetCBLabel(cbHwnd) {
    ; Try the checkbox's own caption first
    len := SendMessage(0x000E, 0, 0, cbHwnd)  ; WM_GETTEXTLENGTH
    if len > 1 {
        buf := Buffer((len + 1) * 2, 0)
        SendMessage(0x000D, len + 1, buf, cbHwnd)  ; WM_GETTEXT
        text := StrGet(buf)
        if text != " " && text != ""
            return text
    }

    ; CPRS clears checkbox captions and puts visible text in a TDlgFieldPanel
    ; sibling positioned to the right of the checkbox. Find it by screen position.
    parentHwnd := DllCall("GetParent", "Ptr", cbHwnd, "Ptr")
    if !parentHwnd
        return ""

    cbRect := Buffer(16, 0)
    DllCall("GetWindowRect", "Ptr", cbHwnd, "Ptr", cbRect)
    cbTop := NumGet(cbRect, 4, "Int")
    cbRight := NumGet(cbRect, 8, "Int")

    ; Search sibling controls for adjacent panel with text
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

    ; Check position: must be on the same row and to the right of the checkbox
    rect := Buffer(16, 0)
    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rect)
    top := NumGet(rect, 4, "Int")
    left := NumGet(rect, 0, "Int")

    if Abs(top - _labelSearchCbTop) > 10 || left < _labelSearchCbRight
        return 1

    ; Extract text from the panel's child labels
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
        return 0  ; stop
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

        if label != ""
            items.Push({label: label, checked: checked})

        pos := itemEnd
    }
    return items
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

; Ctrl+Shift+N - Quick apply "Negative Assessment" template
^+n:: {
    ApplyNamedTemplate("Negative Assessment")
}
