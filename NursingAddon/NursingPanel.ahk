; ===========================================================================
; NursingPanel.ahk - CPRS Nursing Assessment Companion Panel
; AutoHotkey v2.0+ Required (VA TRM Authorized through CY2027)
;
; A companion panel that sits alongside CPRS and lets you:
; 1. Scan the open reminder dialogue to discover all checkboxes
; 2. Save checkbox selections as reusable templates ("Negative Assessment")
; 3. Apply templates with one click, then override individual sections
; 4. Works with VAAES Shift Assessment, Freq Doc, Skin, and any other
;    reminder dialogue
;
; IMPORTANT: This tool does NOT store credentials, does NOT process patient
; data, and does NOT modify CPRS. It simulates checkbox clicks at the UI
; level only, the same as a user clicking manually.
; ===========================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; === GLOBALS ===
global AppTitle := "CPRS Nursing Panel"
global TemplateDir := A_ScriptDir "\templates"
global ScanResults := Map()     ; hwnd -> {text, checked, depth, parent_hwnd}
global CurrentTemplate := Map() ; text_label -> checked (bool)
global StatusText := ""
global MainGui := ""
global TemplateListBox := ""
global StatusBar := ""
global ScanListView := ""
global CPRSRemDlgHwnd := 0

; Create template directory if needed
if !DirExist(TemplateDir)
    DirCreate(TemplateDir)

BuildMainGui()
return

; ===========================================================================
; GUI CONSTRUCTION
; ===========================================================================

BuildMainGui() {
    global MainGui, TemplateListBox, StatusBar, ScanListView

    MainGui := Gui("+AlwaysOnTop +Resize", AppTitle)
    MainGui.SetFont("s9", "Segoe UI")
    MainGui.OnEvent("Close", (*) => ExitApp())
    MainGui.OnEvent("Size", GuiResize)

    ; --- Top section: CPRS Connection ---
    MainGui.AddText("xm ym w400", "CPRS Reminder Dialogue:")
    MainGui.AddText("xm vTxtCPRSStatus w400 cRed", "Not connected - open a reminder dialogue in CPRS")

    MainGui.AddButton("xm y+5 w120 h28", "Scan Dialogue").OnEvent("Click", BtnScan)
    MainGui.AddButton("x+5 w120 h28", "Refresh").OnEvent("Click", BtnRefresh)
    MainGui.AddButton("x+5 w150 h28", "Apply Checked to CPRS").OnEvent("Click", BtnApply)

    ; --- Middle section: Checkbox tree from scanned dialogue ---
    MainGui.AddText("xm y+10 w400", "Dialogue Controls (scan first):")
    ScanListView := MainGui.AddListView("xm y+3 w430 h300 Checked", ["Label", "Depth"])
    ScanListView.OnEvent("ItemCheck", OnItemCheck)

    ; --- Quick actions ---
    MainGui.AddButton("xm y+5 w105 h28", "Check All").OnEvent("Click", BtnCheckAll)
    MainGui.AddButton("x+5 w105 h28", "Uncheck All").OnEvent("Click", BtnUncheckAll)
    MainGui.AddButton("x+5 w105 h28", "Invert").OnEvent("Click", BtnInvert)
    MainGui.AddButton("x+5 w105 h28", "Check Top-Level").OnEvent("Click", BtnCheckTopLevel)

    ; --- Template section ---
    MainGui.AddText("xm y+10 w400", "Saved Templates:")
    TemplateListBox := MainGui.AddListBox("xm y+3 w430 h100")
    RefreshTemplateList()

    MainGui.AddButton("xm y+5 w105 h28", "Load Template").OnEvent("Click", BtnLoadTemplate)
    MainGui.AddButton("x+5 w105 h28", "Save As...").OnEvent("Click", BtnSaveTemplate)
    MainGui.AddButton("x+5 w105 h28", "Delete").OnEvent("Click", BtnDeleteTemplate)
    MainGui.AddButton("x+5 w105 h28", "Rename").OnEvent("Click", BtnRenameTemplate)

    ; --- Status bar ---
    StatusBar := MainGui.AddText("xm y+10 w430 h20 vStatusBar", "Ready. Open a reminder dialogue in CPRS and click Scan.")

    MainGui.Show("w460")
}

GuiResize(thisGui, minMax, w, h) {
    if minMax = -1  ; minimized
        return
    ; Resize list view and template list proportionally
    if IsObject(ScanListView)
        ScanListView.Move(,, w - 30, h - 310)
}

; ===========================================================================
; SCANNING - Find and enumerate all checkboxes in the CPRS Reminder Dialogue
; ===========================================================================

BtnScan(ctrl, *) {
    global ScanResults, CPRSRemDlgHwnd, ScanListView
    ScanResults := Map()
    ScanListView.Delete()

    SetStatus("Scanning for CPRS Reminder Dialogue...")

    ; Find the reminder dialogue window
    ; CPRS reminder dialogues use the class TfrmRemDlg
    CPRSRemDlgHwnd := FindRemDlgWindow()

    if !CPRSRemDlgHwnd {
        SetStatus("No reminder dialogue found. Open one in CPRS first.")
        MainGui["TxtCPRSStatus"].Text := "Not connected - no reminder dialogue found"
        MainGui["TxtCPRSStatus"].SetFont("cRed")
        return
    }

    ; Get the window title for display
    title := WinGetTitle(CPRSRemDlgHwnd)
    MainGui["TxtCPRSStatus"].Text := "Connected: " title
    MainGui["TxtCPRSStatus"].SetFont("cGreen")

    SetStatus("Enumerating controls...")

    ; Enumerate all child controls recursively
    controls := EnumChildControls(CPRSRemDlgHwnd)

    ; Filter to checkboxes and extract their associated text
    checkboxes := []
    for ctrl in controls {
        if ctrl.className = "TORCheckBox" || ctrl.className = "TCPRSDialogParentCheckBox" {
            ; Get the checkbox's text. The caption is usually ' ' (space)
            ; because CPRS puts the visible text in an associated TDlgFieldPanel.
            ; We need to find the panel text.
            labelText := GetCheckboxLabelText(ctrl.hwnd, CPRSRemDlgHwnd)
            if labelText = "" || labelText = " "
                labelText := ctrl.text  ; fallback to caption

            isChecked := IsCheckboxChecked(ctrl.hwnd)

            entry := {
                hwnd: ctrl.hwnd,
                text: labelText,
                checked: isChecked,
                className: ctrl.className,
                depth: ctrl.depth
            }
            checkboxes.Push(entry)
            ScanResults[ctrl.hwnd] := entry
        }
    }

    ; Populate the ListView
    for cb in checkboxes {
        depthStr := ""
        loop cb.depth
            depthStr .= "  "
        row := ScanListView.Add(cb.checked ? "Check" : "", depthStr cb.text, cb.depth)
    }

    count := checkboxes.Length
    checked := 0
    for cb in checkboxes
        if cb.checked
            checked++

    SetStatus("Found " count " checkboxes (" checked " checked). Ready.")
}

BtnRefresh(ctrl, *) {
    ; Re-scan to pick up newly appeared child controls
    BtnScan(ctrl)
}

; Find the CPRS Reminder Dialogue window
FindRemDlgWindow() {
    ; Try class name first (most reliable)
    hwnd := WinExist("ahk_class TfrmRemDlg")
    if hwnd
        return hwnd

    ; Fallback: search for windows with "Reminder" in title owned by CPRS
    for wnd in WinGetList() {
        try {
            title := WinGetTitle(wnd)
            cls := WinGetClass(wnd)
            if InStr(title, "Reminder") && (InStr(cls, "Tfrm") || InStr(cls, "TForm"))
                return wnd
        }
    }
    return 0
}

; Enumerate all child controls recursively
EnumChildControls(parentHwnd, depth := 0) {
    results := []
    enumCallback := CallbackCreate(EnumChildProc, "Fast", 2)

    ; Store results and depth in a global for the callback
    global _enumResults := results
    global _enumDepth := depth
    global _enumParent := parentHwnd

    DllCall("EnumChildWindows", "Ptr", parentHwnd, "Ptr", enumCallback, "Ptr", 0)
    CallbackFree(enumCallback)

    return results
}

EnumChildProc(hwnd, lParam) {
    global _enumResults, _enumDepth

    className := GetClassName(hwnd)
    text := GetWindowText(hwnd)

    ; Calculate depth by counting parents up to the dialogue
    depth := 0
    parent := hwnd
    loop {
        parent := DllCall("GetParent", "Ptr", parent, "Ptr")
        if !parent || parent = _enumParent
            break
        depth++
    }

    _enumResults.Push({
        hwnd: hwnd,
        className: className,
        text: text,
        depth: depth
    })

    return 1  ; continue enumeration
}

; Get the Win32 class name of a control
GetClassName(hwnd) {
    buf := Buffer(256, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Ptr", buf, "Int", 256)
    return StrGet(buf)
}

; Get window/control text via WM_GETTEXT
GetWindowText(hwnd) {
    len := SendMessage(0x000E, 0, 0, hwnd)  ; WM_GETTEXTLENGTH
    if len <= 0
        return ""
    buf := Buffer((len + 1) * 2, 0)
    SendMessage(0x000D, len + 1, buf, hwnd)  ; WM_GETTEXT
    return StrGet(buf)
}

; Check if a checkbox is checked via BM_GETCHECK
IsCheckboxChecked(hwnd) {
    result := SendMessage(0x00F0, 0, 0, hwnd)  ; BM_GETCHECK
    return result = 1  ; BST_CHECKED
}

; Get the label text associated with a checkbox
; CPRS clears checkbox captions and puts text in a TDlgFieldPanel sibling
GetCheckboxLabelText(cbHwnd, dialogHwnd) {
    ; Strategy 1: Look at the checkbox's "Associate" panel
    ; The panel is positioned right next to the checkbox and contains
    ; TLabel or TVA508StaticText children with the actual text

    parentHwnd := DllCall("GetParent", "Ptr", cbHwnd, "Ptr")
    if !parentHwnd
        return ""

    cbRect := GetControlRect(cbHwnd)

    ; Find sibling panels (TPanel, TDlgFieldPanel) at similar Y position
    bestText := ""
    bestDist := 999999

    enumCallback := CallbackCreate(_FindPanelTextCallback, "Fast", 2)
    global _panelSearchCbRect := cbRect
    global _panelSearchBestText := ""
    global _panelSearchBestDist := 999999
    global _panelSearchCbHwnd := cbHwnd

    DllCall("EnumChildWindows", "Ptr", parentHwnd, "Ptr", enumCallback, "Ptr", 0)
    CallbackFree(enumCallback)

    return _panelSearchBestText
}

_FindPanelTextCallback(hwnd, lParam) {
    global _panelSearchCbRect, _panelSearchBestText, _panelSearchBestDist, _panelSearchCbHwnd

    if hwnd = _panelSearchCbHwnd
        return 1

    className := GetClassName(hwnd)
    if !(InStr(className, "TPanel") || InStr(className, "TDlgFieldPanel"))
        return 1

    rect := GetControlRect(hwnd)

    ; Check if this panel is roughly aligned with the checkbox (same Y row)
    yDiff := Abs(rect.top - _panelSearchCbRect.top)
    if yDiff > 10  ; must be on same row (within 10px)
        return 1

    ; Must be to the right of the checkbox
    if rect.left < _panelSearchCbRect.right
        return 1

    dist := rect.left - _panelSearchCbRect.right
    if dist < _panelSearchBestDist {
        ; Extract text from this panel's children (labels)
        text := ExtractPanelText(hwnd)
        if text != "" {
            _panelSearchBestDist := dist
            _panelSearchBestText := text
        }
    }

    return 1
}

; Extract all text from labels inside a panel
ExtractPanelText(panelHwnd) {
    texts := []

    enumCallback := CallbackCreate(_ExtractLabelCallback, "Fast", 2)
    global _extractTexts := texts

    DllCall("EnumChildWindows", "Ptr", panelHwnd, "Ptr", enumCallback, "Ptr", 0)
    CallbackFree(enumCallback)

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

_ExtractLabelCallback(hwnd, lParam) {
    global _extractTexts
    className := GetClassName(hwnd)

    if InStr(className, "TLabel") || InStr(className, "TVA508StaticText")
        || InStr(className, "TCPRSDialogStaticLabel") {
        text := GetWindowText(hwnd)
        if text != "" && text != " "
            _extractTexts.Push(text)
    }
    return 1
}

; Get a control's screen rectangle
GetControlRect(hwnd) {
    rect := Buffer(16, 0)
    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rect)
    return {
        left: NumGet(rect, 0, "Int"),
        top: NumGet(rect, 4, "Int"),
        right: NumGet(rect, 8, "Int"),
        bottom: NumGet(rect, 12, "Int")
    }
}

; ===========================================================================
; APPLYING SELECTIONS TO CPRS
; ===========================================================================

BtnApply(ctrl, *) {
    global ScanResults, CPRSRemDlgHwnd, ScanListView

    if !CPRSRemDlgHwnd || !WinExist(CPRSRemDlgHwnd) {
        SetStatus("No CPRS dialogue connected. Scan first.")
        return
    }

    ; Build list of desired changes from the ListView
    changes := []
    rowNum := 0
    scanKeys := []
    for hwnd, entry in ScanResults
        scanKeys.Push(hwnd)

    loop ScanListView.GetCount() {
        rowNum := A_Index
        isCheckedInList := (ScanListView.GetText(rowNum) != "")

        ; The ListView rows correspond to ScanResults entries in order
        if rowNum > scanKeys.Length
            break

        hwnd := scanKeys[rowNum]
        entry := ScanResults[hwnd]
        currentlyChecked := IsCheckboxChecked(hwnd)

        ; Compare desired state with current CPRS state
        wantChecked := GetListViewCheckState(rowNum)

        if wantChecked != currentlyChecked {
            changes.Push({
                hwnd: hwnd,
                text: entry.text,
                wantChecked: wantChecked
            })
        }
    }

    if changes.Length = 0 {
        SetStatus("No changes to apply - CPRS already matches.")
        return
    }

    SetStatus("Applying " changes.Length " changes to CPRS...")

    ; Apply changes via BM_CLICK messages
    ; BM_CLICK (0x00F5) simulates a button click, firing the OnClick handler
    ; This works even for controls scrolled off-screen
    applied := 0
    for change in changes {
        ; BM_CLICK sends WM_LBUTTONDOWN + WM_LBUTTONUP internally
        ; which triggers Delphi's OnClick -> cbClicked -> SetChecked -> GetData
        PostMessage(0x00F5, 0, 0, change.hwnd)  ; BM_CLICK

        applied++
        SetStatus("Applied " applied "/" changes.Length ": " change.text)

        ; Wait for CPRS to process (GetData fires an RPC which takes time)
        Sleep(300)

        ; Some checkboxes trigger intermediate popup dialogues
        ; ("Press OK to continue", informational messages, etc.)
        ; Auto-dismiss these so template application continues smoothly.
        ; NEVER dismisses the final Finish/Submit - only OK/Continue/Yes
        ; on small popups that don't contain text input or dangerous buttons.
        DismissIntermediatePopups()
    }

    ; One final check for any lingering popups
    DismissIntermediatePopups()

    ; Re-scan to pick up any newly appeared child controls
    SetStatus("Applied " applied " changes. Re-scanning for new controls...")
    Sleep(500)
    BtnScan(ctrl)
}

GetListViewCheckState(rowNum) {
    ; ListView_GetCheckState: send LVM_GETITEMSTATE with LVIS_STATEIMAGEMASK
    state := SendMessage(0x102C, rowNum - 1, 0x2000, ScanListView.hwnd)  ; LVM_GETITEMSTATE, LVIS_STATEIMAGEMASK
    return (state >> 12) - 1  ; 0 = unchecked, 1 = checked
}

; ===========================================================================
; QUICK ACTION BUTTONS
; ===========================================================================

BtnCheckAll(ctrl, *) {
    loop ScanListView.GetCount()
        ScanListView.Modify(A_Index, "Check")
    SetStatus("All items checked in panel (not yet applied to CPRS).")
}

BtnUncheckAll(ctrl, *) {
    loop ScanListView.GetCount()
        ScanListView.Modify(A_Index, "-Check")
    SetStatus("All items unchecked in panel (not yet applied to CPRS).")
}

BtnInvert(ctrl, *) {
    loop ScanListView.GetCount() {
        if GetListViewCheckState(A_Index)
            ScanListView.Modify(A_Index, "-Check")
        else
            ScanListView.Modify(A_Index, "Check")
    }
    SetStatus("Selections inverted in panel (not yet applied to CPRS).")
}

BtnCheckTopLevel(ctrl, *) {
    ; Check only depth-0 items (top-level body system checkboxes)
    loop ScanListView.GetCount() {
        depthStr := ScanListView.GetText(A_Index, 2)
        if depthStr = "0" || depthStr = ""
            ScanListView.Modify(A_Index, "Check")
    }
    SetStatus("Top-level items checked. Apply to expand sections, then re-scan.")
}

OnItemCheck(ctrl, item, checked) {
    ; Visual feedback when user manually toggles a checkbox in the panel
    ; No-op for now; changes only go to CPRS when "Apply" is clicked
}

; ===========================================================================
; TEMPLATE SYSTEM - Save/Load checkbox selections as reusable profiles
; ===========================================================================

BtnSaveTemplate(ctrl, *) {
    global ScanListView, ScanResults

    if ScanListView.GetCount() = 0 {
        MsgBox("Scan a dialogue first before saving a template.", AppTitle, "Icon!")
        return
    }

    ; Prompt for template name
    nameGui := Gui("+Owner" MainGui.Hwnd, "Save Template")
    nameGui.SetFont("s9", "Segoe UI")
    nameGui.AddText(, "Template name:")
    nameEdit := nameGui.AddEdit("w250", "")
    nameGui.AddText("y+8", "Description (optional):")
    descEdit := nameGui.AddEdit("w250", "")
    nameGui.AddButton("y+10 w80 Default", "Save").OnEvent("Click", DoSave)
    nameGui.AddButton("x+5 w80", "Cancel").OnEvent("Click", (*) => nameGui.Destroy())
    nameGui.Show()

    DoSave(btn, *) {
        name := nameEdit.Value
        desc := descEdit.Value
        if name = "" {
            MsgBox("Enter a template name.", AppTitle, "Icon!")
            return
        }

        ; Build template data from current ListView check states
        template := {
            name: name,
            description: desc,
            created: FormatTime(, "yyyy-MM-dd HH:mm"),
            source_dialogue: WinGetTitle(CPRSRemDlgHwnd),
            items: []
        }

        scanKeys := []
        for hwnd, entry in ScanResults
            scanKeys.Push(hwnd)

        loop ScanListView.GetCount() {
            if A_Index > scanKeys.Length
                break
            hwnd := scanKeys[A_Index]
            entry := ScanResults[hwnd]
            isChecked := GetListViewCheckState(A_Index)

            template.items.Push({
                label: entry.text,
                checked: isChecked ? true : false,
                depth: entry.depth
            })
        }

        ; Save as JSON
        filePath := TemplateDir "\" SanitizeFilename(name) ".json"
        SaveTemplateFile(filePath, template)

        nameGui.Destroy()
        RefreshTemplateList()
        SetStatus('Template "' name '" saved with ' template.items.Length ' items.')
    }
}

BtnLoadTemplate(ctrl, *) {
    global TemplateListBox, ScanListView, ScanResults

    selected := TemplateListBox.Text
    if selected = "" {
        MsgBox("Select a template from the list first.", AppTitle, "Icon!")
        return
    }

    filePath := TemplateDir "\" SanitizeFilename(selected) ".json"
    if !FileExist(filePath) {
        MsgBox("Template file not found: " filePath, AppTitle, "Icon!")
        return
    }

    template := LoadTemplateFile(filePath)
    if !template {
        MsgBox("Failed to load template.", AppTitle, "Icon!")
        return
    }

    ; If no scan has been done, just show the template data
    if ScanListView.GetCount() = 0 {
        MsgBox("Scan a CPRS dialogue first, then load the template to apply it.",
            AppTitle, "Iconi")
        return
    }

    ; Match template items to scanned controls by label text (fuzzy match)
    matched := 0
    unmatched := 0

    for templateItem in template.items {
        targetLabel := templateItem.label
        bestRow := 0
        bestScore := 0

        ; Find the best matching row in the ListView
        scanKeys := []
        for hwnd, entry in ScanResults
            scanKeys.Push(hwnd)

        loop ScanListView.GetCount() {
            if A_Index > scanKeys.Length
                break
            hwnd := scanKeys[A_Index]
            entry := ScanResults[hwnd]

            ; Exact match first
            if entry.text = targetLabel {
                bestRow := A_Index
                bestScore := 100
                break
            }

            ; Fuzzy: case-insensitive contains
            if InStr(entry.text, targetLabel) || InStr(targetLabel, entry.text) {
                score := StrLen(entry.text) > StrLen(targetLabel)
                    ? StrLen(targetLabel) / StrLen(entry.text) * 90
                    : StrLen(entry.text) / StrLen(targetLabel) * 90
                if score > bestScore {
                    bestScore := score
                    bestRow := A_Index
                }
            }
        }

        if bestRow > 0 && bestScore >= 50 {
            if templateItem.checked
                ScanListView.Modify(bestRow, "Check")
            else
                ScanListView.Modify(bestRow, "-Check")
            matched++
        } else {
            unmatched++
        }
    }

    SetStatus('Template "' selected '" loaded: ' matched ' matched, '
        unmatched ' unmatched. Click "Apply Checked to CPRS" to apply.')
}

BtnDeleteTemplate(ctrl, *) {
    global TemplateListBox

    selected := TemplateListBox.Text
    if selected = "" {
        MsgBox("Select a template first.", AppTitle, "Icon!")
        return
    }

    result := MsgBox('Delete template "' selected '"?', AppTitle, "YesNo Icon?")
    if result = "Yes" {
        filePath := TemplateDir "\" SanitizeFilename(selected) ".json"
        if FileExist(filePath)
            FileDelete(filePath)
        RefreshTemplateList()
        SetStatus('Template "' selected '" deleted.')
    }
}

BtnRenameTemplate(ctrl, *) {
    global TemplateListBox

    selected := TemplateListBox.Text
    if selected = "" {
        MsgBox("Select a template first.", AppTitle, "Icon!")
        return
    }

    newName := InputBox("New name for template:", AppTitle,, selected)
    if newName.Result = "Cancel" || newName.Value = ""
        return

    oldPath := TemplateDir "\" SanitizeFilename(selected) ".json"
    newPath := TemplateDir "\" SanitizeFilename(newName.Value) ".json"

    if FileExist(oldPath) {
        template := LoadTemplateFile(oldPath)
        if template {
            template.name := newName.Value
            SaveTemplateFile(newPath, template)
            FileDelete(oldPath)
        }
    }

    RefreshTemplateList()
    SetStatus('Template renamed to "' newName.Value '".')
}

; ===========================================================================
; TEMPLATE FILE I/O (Simple JSON)
; ===========================================================================

SaveTemplateFile(filePath, template) {
    ; Manual JSON serialization (AHK v2 doesn't have built-in JSON)
    json := '{'
    json .= '`n  "name": ' EscapeJsonStr(template.name) ','
    json .= '`n  "description": ' EscapeJsonStr(template.description) ','
    json .= '`n  "created": ' EscapeJsonStr(template.created) ','
    json .= '`n  "source_dialogue": ' EscapeJsonStr(template.source_dialogue) ','
    json .= '`n  "items": ['

    for i, item in template.items {
        json .= '`n    {'
        json .= '"label": ' EscapeJsonStr(item.label)
        json .= ', "checked": ' (item.checked ? "true" : "false")
        json .= ', "depth": ' item.depth
        json .= '}'
        if i < template.items.Length
            json .= ','
    }

    json .= '`n  ]'
    json .= '`n}'

    f := FileOpen(filePath, "w", "UTF-8")
    f.Write(json)
    f.Close()
}

LoadTemplateFile(filePath) {
    ; Simple JSON parser for our known template format
    try {
        content := FileRead(filePath, "UTF-8")
    } catch {
        return false
    }

    template := {
        name: ExtractJsonString(content, "name"),
        description: ExtractJsonString(content, "description"),
        created: ExtractJsonString(content, "created"),
        source_dialogue: ExtractJsonString(content, "source_dialogue"),
        items: []
    }

    ; Parse items array
    itemsStart := InStr(content, '"items"')
    if !itemsStart
        return template

    ; Find each item object
    pos := itemsStart
    while pos := InStr(content, "{", , pos + 1) {
        ; Check we're still inside the items array
        closeBracket := InStr(content, "]", , itemsStart)
        if pos > closeBracket
            break

        itemEnd := InStr(content, "}", , pos)
        if !itemEnd
            break

        itemStr := SubStr(content, pos, itemEnd - pos + 1)

        label := ExtractJsonString(itemStr, "label")
        checked := InStr(itemStr, '"checked": true') ? true : false
        depthMatch := ""
        if RegExMatch(itemStr, '"depth":\s*(\d+)', &depthMatch)
            depth := Integer(depthMatch[1])
        else
            depth := 0

        template.items.Push({
            label: label,
            checked: checked,
            depth: depth
        })

        pos := itemEnd
    }

    return template
}

ExtractJsonString(json, key) {
    pattern := '"' key '":\s*"((?:[^"\\]|\\.)*)\"'
    if RegExMatch(json, pattern, &match)
        return StrReplace(StrReplace(match[1], "\n", "`n"), '\"', '"')
    return ""
}

EscapeJsonStr(str) {
    str := StrReplace(str, "\", "\\")
    str := StrReplace(str, '"', '\"')
    str := StrReplace(str, "`n", "\n")
    str := StrReplace(str, "`r", "\r")
    str := StrReplace(str, "`t", "\t")
    return '"' str '"'
}

SanitizeFilename(name) {
    ; Remove characters not safe for filenames
    name := RegExReplace(name, '[<>:"/\\|?*]', "_")
    return Trim(name)
}

RefreshTemplateList() {
    global TemplateListBox, TemplateDir

    TemplateListBox.Delete()
    if !DirExist(TemplateDir)
        return

    loop files TemplateDir "\*.json" {
        ; Load each template to get its display name
        template := LoadTemplateFile(A_LoopFileFullPath)
        if template && template.name
            TemplateListBox.Add([template.name])
        else
            TemplateListBox.Add([StrReplace(A_LoopFileName, ".json", "")])
    }
}

; ===========================================================================
; INTERMEDIATE POPUP DISMISSAL
;
; Some CPRS checkboxes trigger popup dialogues mid-form ("Press OK to
; continue", informational messages, confirmation prompts). These block
; further checkbox clicking until dismissed.
;
; We auto-dismiss popups that match ALL of these criteria:
;   1. Owned by CPRSChart.exe
;   2. Small window (under 500x400 px - not the main form)
;   3. Contains an OK/Continue/Yes button
;   4. Does NOT contain Finish/Submit/Sign/File/Save/Delete buttons
;   5. Does NOT contain text input fields (not a data entry form)
;
; We NEVER dismiss the final Finish/Submit that files the note.
; ===========================================================================

DismissIntermediatePopups() {
    Sleep(150)

    loop 3 {
        found := false
        for wnd in WinGetList("ahk_exe CPRSChart.exe") {
            try {
                cls := WinGetClass(wnd)

                ; Skip the main windows
                if cls = "TfrmRemDlg" || cls = "TCPRSChart" || cls = "TfrmFrame"
                    continue

                ; Must be popup-sized
                WinGetPos(,, &w, &h, wnd)
                if w > 500 || h > 400
                    continue

                ; Check for buttons we must never auto-click
                if HasDangerousButton(wnd)
                    continue

                ; Find and click the OK button
                okHwnd := FindOKButton(wnd)
                if okHwnd {
                    PostMessage(0x00F5, 0, 0, okHwnd)  ; BM_CLICK
                    Sleep(200)
                    found := true
                }
            }
        }
        if !found
            break
    }
}

HasDangerousButton(windowHwnd) {
    global _hasDangerous := false

    enumDangerous := CallbackCreate(_CheckDangerousCallback, "Fast", 2)
    DllCall("EnumChildWindows", "Ptr", windowHwnd, "Ptr", enumDangerous, "Ptr", 0)
    CallbackFree(enumDangerous)

    return _hasDangerous
}

_CheckDangerousCallback(hwnd, lParam) {
    global _hasDangerous

    className := GetClassName(hwnd)

    ; Text input fields mean this is a data entry form, not just an OK popup
    if InStr(className, "TEdit") || InStr(className, "TMemo") || InStr(className, "TRichEdit") {
        _hasDangerous := true
        return 0
    }

    ; Check button text for labels that file/sign/submit the note
    if InStr(className, "TButton") || InStr(className, "TBitBtn") {
        text := GetWindowText(hwnd)
        textUpper := StrUpper(text)

        if InStr(textUpper, "FINISH") || InStr(textUpper, "SUBMIT")
            || InStr(textUpper, "SIGN") || InStr(textUpper, "FILE")
            || InStr(textUpper, "COMPLETE") || InStr(textUpper, "SAVE")
            || InStr(textUpper, "DELETE") || InStr(textUpper, "REMOVE") {
            _hasDangerous := true
            return 0
        }
    }

    return 1
}

FindOKButton(windowHwnd) {
    global _foundOKHwnd := 0

    enumOK := CallbackCreate(_FindOKCallback, "Fast", 2)
    DllCall("EnumChildWindows", "Ptr", windowHwnd, "Ptr", enumOK, "Ptr", 0)
    CallbackFree(enumOK)

    return _foundOKHwnd
}

_FindOKCallback(hwnd, lParam) {
    global _foundOKHwnd

    className := GetClassName(hwnd)

    if !(InStr(className, "TButton") || InStr(className, "TBitBtn"))
        return 1

    text := GetWindowText(hwnd)
    textUpper := StrUpper(text)

    ; Only dismiss OK, Continue, Yes - never anything that files/signs
    if textUpper = "OK" || textUpper = "&OK" || textUpper = "CONTINUE"
        || textUpper = "&CONTINUE" || textUpper = "YES" || textUpper = "&YES" {
        _foundOKHwnd := hwnd
        return 0
    }

    return 1
}

; ===========================================================================
; UTILITY
; ===========================================================================

SetStatus(msg) {
    global StatusBar, StatusText
    StatusText := msg
    if IsObject(StatusBar)
        StatusBar.Text := msg
}

; ===========================================================================
; HOTKEYS (while CPRS is active)
; ===========================================================================

; Ctrl+Shift+N - Open/focus the Nursing Panel
^+n:: {
    if WinExist(AppTitle)
        WinActivate(AppTitle)
}

; Ctrl+Shift+S - Quick scan (rescan the current dialogue)
^+s:: {
    if WinExist(AppTitle) {
        WinActivate(AppTitle)
        BtnScan("")
    }
}
