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
; MATCHING: Two-track structural matching.
;   - Top-level section parents: matched by position (1st, 2nd, 3rd, etc.)
;   - After expanding sections, each creates a TGroupBox with sub-controls.
;     Sub-controls are matched by their local enumeration index within
;     their TGroupBox (stable because same section = same internal structure).
;   - Leaf checkboxes (TCPRSDialogCheckBox): also matched by label text
;     as a verification layer.
;   Works with ANY CPRS reminder dialog type.
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

    titleBar := BoosterGui.AddText("xm ym w560 h22 Center cWhite Background1a1a2e",
        "  Nursing Booster  |  Ctrl+Shift+B to toggle")
    titleBar.OnEvent("Click", (*) => PostMessage(0xA1, 2,,, BoosterGui))

    BoosterGui.AddButton("xm y+4 w130 h28", "Save Template").OnEvent("Click", BtnSaveCurrentState)
    BoosterGui.AddButton("x+4 w130 h28", "Load Template").OnEvent("Click", BtnLoadSavedTemplate)
    BoosterGui.AddButton("x+4 w130 h28", "Delete Template").OnEvent("Click", BtnDeleteTemplate)
    BoosterGui.AddButton("x+4 w130 h28", "Advanced Panel").OnEvent("Click", BtnOpenAdvancedPanel)

    BoosterGui.AddButton("xm y+4 w130 h28", "Negative Assessment").OnEvent("Click",
        (*) => ApplyNamedTemplate("Negative Assessment"))
    BoosterGui.AddButton("x+4 w130 h28", "Skin Assessment").OnEvent("Click",
        (*) => ApplyNamedTemplate("Skin Assessment"))
    BoosterGui.AddButton("x+4 w130 h28", "Freq Doc").OnEvent("Click",
        (*) => ApplyNamedTemplate("Freq Doc"))
    BoosterGui.AddButton("x+4 w130 h28", "Custom 1").OnEvent("Click",
        (*) => ApplyNamedTemplate("Custom 1"))

    BoosterGui.AddText("xm y+6 w560 h18 vToolbarStatus cSilver Background1a1a2e Center",
        "Ready | CPRS: Not detected")

    BoosterGui.Show("x0 y0 NoActivate")
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
        status := dlg ? "Dialog detected" : "CPRS: " SubStr(title, 1, 50)
        BoosterGui["ToolbarStatus"].Text := "Ready | " status
    } else {
        BoosterGui["ToolbarStatus"].Text := "Ready | CPRS: Not detected"
    }
}

; ===========================================================================
; DIALOG WINDOW DETECTION
; ===========================================================================

FindActiveDialogWindow() {
    hwnd := WinExist("ahk_class TfrmRemDlg")
    if hwnd
        return hwnd
    hwnd := WinExist("ahk_class TfrmTemplateDialog")
    if hwnd
        return hwnd
    for wnd in WinGetList("ahk_exe CPRSChart.exe") {
        try {
            cls := WinGetClass(wnd)
            if (cls != "TCPRSChart" && cls != "TfrmFrame") {
                if HasCheckboxControls(wnd)
                    return wnd
            }
        }
    }
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
; SAVE TEMPLATE (format v3 - structural matching)
;
; Records:
;   1. topLevelParents - which TL sections are expanded (by position)
;   2. groups[] - for each TGroupBox in the scrollbox, all descendant
;      checkboxes by their local enumeration index within that TGroupBox
;   3. Labels are recorded for verification/debugging but matching uses
;      the structural position (group index + local index)
; ===========================================================================

BtnSaveCurrentState(ctrl, *) {
    dlgHwnd := FindActiveDialogWindow()
    if !dlgHwnd {
        MsgBox("Open a template or reminder dialogue in CPRS first.", AppTitle, "Icon!")
        return
    }

    result := InputBox("Template name:`n`n"
        "Use a descriptive name like 'Negative Assessment' or 'Skin WNL'.`n"
        "Naming it the same as a toolbar button links it to that button.",
        "Save Template",, "")
    if result.Result = "Cancel" || result.Value = ""
        return
    templateName := result.Value

    ToolTip("Scanning dialog...")
    WaitForStableCheckboxCount(dlgHwnd)

    ; Get scrollbox and top-level parents
    scrollBox := FindVisibleScrollBox(dlgHwnd)
    if !scrollBox {
        MsgBox("Could not find dialog scroll area.", AppTitle, "Icon!")
        return
    }

    tlParents := EnumTopLevelParents(scrollBox)
    if tlParents.Length = 0 {
        MsgBox("No sections found in dialog.", AppTitle, "Icon!")
        return
    }

    ; Get all TGroupBoxes that are direct children of the scrollbox
    allGroupBoxes := EnumScrollBoxGroupBoxes(scrollBox)

    ; Build JSON
    json := '{'
    json .= '`n  "name": ' EscJson(templateName) ','
    json .= '`n  "format": 3,'
    json .= '`n  "created": "' FormatTime(, "yyyy-MM-dd HH:mm") '",'
    json .= '`n  "source_dialogue": ' EscJson(WinGetTitle(dlgHwnd)) ','

    ; Top-level parent states
    json .= '`n  "topLevelParents": ['
    for i, tlp in tlParents {
        if i > 1
            json .= ", "
        json .= tlp.checked ? "true" : "false"
    }
    json .= '],'

    ; Groups: each TGroupBox with its descendant checkboxes
    json .= '`n  "groups": ['
    totalChecked := 0
    totalControls := 0
    for gi, gbHwnd in allGroupBoxes {
        if gi > 1
            json .= ","
        json .= '`n    {"checkboxes": ['

        ; Enumerate all descendant checkboxes within this TGroupBox
        descendants := EnumDescendantCheckboxes(gbHwnd)
        for ci, cb in descendants {
            if ci > 1
                json .= ","
            json .= '`n      {"idx": ' (ci - 1) ', "cls": ' EscJson(cb.className)
                . ', "checked": ' (cb.checked ? "true" : "false")
                . ', "depth": ' cb.depth
            if cb.label != ""
                json .= ', "label": ' EscJson(cb.label)
            json .= '}'
            totalControls++
            if cb.checked
                totalChecked++
        }
        json .= '`n    ]}'
    }
    json .= '`n  ]'
    json .= '`n}'

    filePath := TemplateDir "\" SanitizeFilename(templateName) ".json"
    f := FileOpen(filePath, "w", "UTF-8")
    f.Write(json)
    f.Close()

    ; Log every checkbox state
    _LogCheckboxStates("SAVE", allGroupBoxes)

    ToolTip('Saved "' templateName '": ' totalChecked "/" totalControls
        " checked across " allGroupBoxes.Length " groups")
    SetTimer(ClearToolTip, -3000)
}

; ===========================================================================
; APPLY TEMPLATE (format v3 - structural matching)
;
; Phase 1: Expand/collapse top-level sections to match template.
; Phase 2: For each TGroupBox, match descendant checkboxes by local
;          enumeration index and set their states.
;
; This works because:
;   - Same TL parent expanded = same TGroupBox created
;   - Same TGroupBox = same internal structure = same enumeration order
;   - Local index within a TGroupBox is stable (unlike global ClassNN)
; ===========================================================================

ApplyTemplate(templatePath) {
    dlgHwnd := FindActiveDialogWindow()
    if !dlgHwnd
        return

    try {
        content := FileRead(templatePath, "UTF-8")
    } catch {
        MsgBox("Failed to read template: " templatePath, AppTitle, "Icon!")
        return
    }

    ; Require format v3
    if !(InStr(content, '"format": 3') || InStr(content, '"format":3')) {
        MsgBox("This template must be re-saved with the updated Nursing Booster.`n`n"
            "1. Open the reminder dialog in CPRS and fill it out`n"
            "2. Click 'Save Template' to create a new version`n`n"
            "Old templates (format 1/2) are not compatible.",
            AppTitle, "Icon!")
        return
    }

    ; Parse template
    tlpStates := ParseTopLevelParents(content)
    templateGroups := ParseGroups(content)

    if templateGroups.Length = 0 {
        MsgBox("Template has no groups.", AppTitle, "Icon!")
        return
    }

    ; Wait for dialog to load
    ToolTip("Waiting for dialog to load...")
    WaitForStableCheckboxCount(dlgHwnd)

    scrollBox := FindVisibleScrollBox(dlgHwnd)
    if !scrollBox {
        MsgBox("Could not find dialog scroll area.", AppTitle, "Icon!")
        return
    }

    ; === PHASE 1: Expand/collapse top-level sections ===
    expandCount := 0
    if tlpStates.Length > 0 {
        liveTopParents := EnumTopLevelParents(scrollBox)
        limit := Min(tlpStates.Length, liveTopParents.Length)

        ToolTip("Setting up " limit " sections...")
        loop limit {
            liveCb := liveTopParents[A_Index]
            currentState := SendMessage(0x00F0, 0, 0, liveCb.hwnd) ? true : false
            desired := tlpStates[A_Index]

            if currentState != desired {
                try PostMessage(0x00F5, 0, 0, liveCb.hwnd)
                expandCount++
                Sleep(500)
                DismissIntermediatePopups()
            }
        }

        if expandCount > 0 {
            ToolTip("Expanded " expandCount " sections, waiting for controls...")
            WaitForStableCheckboxCount(dlgHwnd)
        }
    }

    ; === PHASE 2: Match groups, expand, apply states ===
    liveGroupBoxes := EnumScrollBoxGroupBoxes(scrollBox)

    totalApplied := 0
    totalNotFound := 0
    totalExpanded := 0
    groupsMatched := Min(templateGroups.Length, liveGroupBoxes.Length)

    ; --- Step 1: Match groups BEFORE expansion using label overlap ---
    ; Collect labels from each live group's base items (pre-expansion).
    ; Match to template groups that contain those same labels.
    ; This must happen before expansion to avoid corrupting group structure.
    groupMap := Map()  ; live index (1-based) → template index (1-based)
    usedTpl := Map()
    usedLive := Map()

    ; Build template label sets
    tplLabelSets := []
    for tplGroup in templateGroups {
        labels := Map()
        for tplCb in tplGroup {
            if tplCb.label != ""
                labels[tplCb.label] := true
        }
        tplLabelSets.Push(labels)
    }

    ; Build live base label sets and base fingerprints
    liveLabelSets := []
    liveFPs := []
    loop liveGroupBoxes.Length {
        desc := EnumDescendantCheckboxes(liveGroupBoxes[A_Index])
        labels := Map()
        for cb in desc {
            if cb.label != ""
                labels[cb.label] := true
        }
        liveLabelSets.Push(labels)
        liveFPs.Push(_GroupFingerprint(desc))
    }

    ; Build template base fingerprints (for non-label groups)
    tplFPs := []
    for tplGroup in templateGroups {
        tplFPs.Push(_GroupFingerprint(tplGroup))
    }

    ; Pass 1: Match groups that have labels by label overlap
    loop liveLabelSets.Length {
        liveIdx := A_Index
        liveLabels := liveLabelSets[liveIdx]
        liveHasLabels := false
        for _ in liveLabels {
            liveHasLabels := true
            break
        }
        if !liveHasLabels
            continue

        bestTpl := 0
        bestOverlap := 0
        matchCount := 0
        loop tplLabelSets.Length {
            tplIdx := A_Index
            if usedTpl.Has(tplIdx)
                continue
            ; Count how many live labels appear in this template group
            overlap := 0
            for lbl in liveLabels {
                if tplLabelSets[tplIdx].Has(lbl)
                    overlap++
            }
            if overlap > bestOverlap {
                bestOverlap := overlap
                bestTpl := tplIdx
                matchCount := 1
            } else if overlap = bestOverlap && overlap > 0 {
                matchCount++
            }
        }
        if bestTpl > 0 && matchCount = 1 {
            groupMap[liveIdx] := bestTpl
            usedTpl[bestTpl] := true
            usedLive[liveIdx] := true
        }
    }

    ; Pass 2: Match remaining groups by fingerprint (count + depth profile)
    loop liveFPs.Length {
        liveIdx := A_Index
        if usedLive.Has(liveIdx)
            continue
        matches := []
        loop tplFPs.Length {
            tplIdx := A_Index
            if !usedTpl.Has(tplIdx) && liveFPs[liveIdx] = tplFPs[tplIdx]
                matches.Push(tplIdx)
        }
        if matches.Length = 1 {
            groupMap[liveIdx] := matches[1]
            usedTpl[matches[1]] := true
            usedLive[liveIdx] := true
        }
    }

    ; Pass 3: Remaining unmatched groups by relative Y-position
    unmatchedTpl := []
    loop tplFPs.Length {
        if !usedTpl.Has(A_Index)
            unmatchedTpl.Push(A_Index)
    }
    unmatchedLive := []
    loop liveFPs.Length {
        if !usedLive.Has(A_Index)
            unmatchedLive.Push(A_Index)
    }
    posLimit := Min(unmatchedTpl.Length, unmatchedLive.Length)
    loop posLimit {
        groupMap[unmatchedLive[A_Index]] := unmatchedTpl[A_Index]
    }

    ; --- Step 2: Expansion pass (using correct group mapping) ---
    loop liveGroupBoxes.Length {
        liveIdx := A_Index
        if !groupMap.Has(liveIdx)
            continue
        tplIdx := groupMap[liveIdx]
        gbHwnd := liveGroupBoxes[liveIdx]
        tplGroup := templateGroups[tplIdx]

        ToolTip("Expanding group " liveIdx "/" liveGroupBoxes.Length "...")

        loop 8 {
            liveDesc := EnumDescendantCheckboxes(gbHwnd)
            if liveDesc.Length >= tplGroup.Length
                break

            expandedAny := false
            currentDepth := 0

            while currentDepth <= 4 && !expandedAny {
                tplAtDepth := []
                for tplCb in tplGroup {
                    if tplCb.depth = currentDepth && tplCb.cls = "TCPRSDialogParentCheckBox"
                        tplAtDepth.Push(tplCb)
                }

                liveAtDepth := []
                for liveCb in liveDesc {
                    if liveCb.depth = currentDepth && liveCb.className = "TCPRSDialogParentCheckBox"
                        liveAtDepth.Push(liveCb)
                }

                limit := Min(tplAtDepth.Length, liveAtDepth.Length)
                loop limit {
                    i := A_Index
                    if tplAtDepth[i].checked && !liveAtDepth[i].checked {
                        try {
                            if DllCall("IsWindow", "Ptr", liveAtDepth[i].hwnd)
                                PostMessage(0x00F5, 0, 0, liveAtDepth[i].hwnd)
                        }
                        expandedAny := true
                        totalExpanded++
                        Sleep(500)
                        DismissIntermediatePopups()
                    }
                }
                currentDepth++
            }

            if !expandedAny
                break

            Sleep(600)
        }
    }

    ; --- Step 3: Apply checkbox states (label-first matching) ---
    loop liveGroupBoxes.Length {
        liveIdx := A_Index
        if !groupMap.Has(liveIdx)
            continue
        tplIdx := groupMap[liveIdx]
        gbHwnd := liveGroupBoxes[liveIdx]
        tplGroup := templateGroups[tplIdx]

        ToolTip("Applying group " liveIdx " (tpl " tplIdx ")...")

        liveDescendants := EnumDescendantCheckboxes(gbHwnd)

        ; Build per-depth arrays for template
        tplByDepth := Map()
        for tplCb in tplGroup {
            d := tplCb.depth
            if !tplByDepth.Has(d)
                tplByDepth[d] := []
            tplByDepth[d].Push(tplCb)
        }

        ; Build per-depth arrays for live
        liveByDepth := Map()
        for liveCb in liveDescendants {
            d := liveCb.depth
            if !liveByDepth.Has(d)
                liveByDepth[d] := []
            liveByDepth[d].Push(liveCb)
        }

        ; Match items at each depth level using label-first strategy
        for d, tplItems in tplByDepth {
            if !liveByDepth.Has(d) {
                totalNotFound += tplItems.Length
                continue
            }
            liveItems := liveByDepth[d]
            claimed := Map()  ; live indices already matched

            ; Pass 1: Match all labeled template items by label text
            for tplCb in tplItems {
                if tplCb.label = ""
                    continue
                for liveJ, liveCb in liveItems {
                    if claimed.Has(liveJ)
                        continue
                    if liveCb.label = tplCb.label {
                        if liveCb.checked != tplCb.checked {
                            try {
                                if DllCall("IsWindow", "Ptr", liveCb.hwnd)
                                    PostMessage(0x00F5, 0, 0, liveCb.hwnd)
                            }
                            totalApplied++
                            Sleep(100)
                        }
                        claimed[liveJ] := true
                        break
                    }
                }
            }

            ; Pass 2: Match unlabeled template items to unclaimed live items
            unclaimedLive := []
            for liveJ, liveCb in liveItems {
                if !claimed.Has(liveJ)
                    unclaimedLive.Push(liveCb)
            }
            unlabeledTpl := []
            for tplCb in tplItems {
                if tplCb.label = ""
                    unlabeledTpl.Push(tplCb)
            }
            posLimit := Min(unlabeledTpl.Length, unclaimedLive.Length)
            loop posLimit {
                i := A_Index
                if unclaimedLive[i].checked != unlabeledTpl[i].checked {
                    try {
                        if DllCall("IsWindow", "Ptr", unclaimedLive[i].hwnd)
                            PostMessage(0x00F5, 0, 0, unclaimedLive[i].hwnd)
                    }
                    totalApplied++
                    Sleep(100)
                }
            }

            ; Count unmatched
            claimedCount := 0
            for _ in claimed
                claimedCount++
            totalMatched := claimedCount + posLimit
            if tplItems.Length > totalMatched
                totalNotFound += tplItems.Length - totalMatched

            if Mod(totalApplied, 8) = 0
                DismissIntermediatePopups()
        }

        DismissIntermediatePopups()
    }

    ; Count unmatched groups
    if templateGroups.Length > liveGroupBoxes.Length
        totalNotFound += templateGroups.Length - liveGroupBoxes.Length

    ; Log every checkbox state after apply
    _LogCheckboxStates("APPLY", liveGroupBoxes)

    ToolTip("Done: " totalApplied " toggled, " totalNotFound " not found. Review before Finish.")
    SetTimer(ClearToolTip, -5000)
}

; ===========================================================================
; CHECKBOX STATE LOGGING
; ===========================================================================

; Writes a timestamped log of every checkbox in every group.
; Called on both Save and Apply so the two logs can be diffed.
; action = "SAVE" or "APPLY"
_LogCheckboxStates(action, groupBoxHwnds) {
    logPath := TemplateDir "\" action "_" A_Now ".txt"
    try {
        f := FileOpen(logPath, "w", "UTF-8")
        f.Write(action " " FormatTime(, "yyyy-MM-dd HH:mm:ss") "`n")
        f.Write("Groups: " groupBoxHwnds.Length "`n`n")
        for gi, gbHwnd in groupBoxHwnds {
            descendants := EnumDescendantCheckboxes(gbHwnd)
            f.Write("--- Group " gi " (" descendants.Length " items) ---`n")
            for ci, cb in descendants {
                state := cb.checked ? "[X]" : "[ ]"
                cls := cb.className = "TCPRSDialogParentCheckBox" ? "PCB" : "CB "
                lbl := cb.label != "" ? cb.label : "(unlabeled)"
                f.Write("  " state " d" cb.depth " " cls " " lbl "`n")
            }
        }
        f.Close()
    }
}

; ===========================================================================
; GROUP FINGERPRINTING
; ===========================================================================

; Build a fingerprint string for a group of checkboxes.
; Combines sorted label set + depth profile so groups with different content
; get different fingerprints. Works with both template items (.label, .depth)
; and live items (.label, .depth).
_GroupFingerprint(items) {
    labels := []
    depthCounts := Map()
    for item in items {
        if item.label != ""
            labels.Push(item.label)
        d := item.depth
        if !depthCounts.Has(d)
            depthCounts[d] := 0
        depthCounts[d] := depthCounts[d] + 1
    }
    ; Sort labels alphabetically (insertion sort)
    if labels.Length > 1 {
        loop labels.Length - 1 {
            i := A_Index + 1
            key := labels[i]
            j := i - 1
            while j >= 1 && StrCompare(labels[j], key) > 0 {
                labels[j + 1] := labels[j]
                j--
            }
            labels[j + 1] := key
        }
    }
    ; Sort depth keys
    depthKeys := []
    for k in depthCounts
        depthKeys.Push(k)
    if depthKeys.Length > 1 {
        loop depthKeys.Length - 1 {
            i := A_Index + 1
            key := depthKeys[i]
            j := i - 1
            while j >= 1 && depthKeys[j] > key {
                depthKeys[j + 1] := depthKeys[j]
                j--
            }
            depthKeys[j + 1] := key
        }
    }
    fp := items.Length "|"
    for lbl in labels
        fp .= lbl ","
    fp .= "|"
    for dk in depthKeys
        fp .= dk ":" depthCounts[dk] ","
    return fp
}

; ===========================================================================
; CHECKBOX ENUMERATION
; ===========================================================================

; Enumerate all TGroupBox direct children of the scrollbox, sorted by
; screen Y position (visual top-to-bottom order). Z-order is unreliable
; because it reflects creation order, which differs between save and apply.
EnumScrollBoxGroupBoxes(scrollBoxHwnd) {
    raw := []
    child := DllCall("GetWindow", "Ptr", scrollBoxHwnd, "UInt", 5, "Ptr")  ; GW_CHILD
    while child {
        buf := Buffer(256, 0)
        DllCall("GetClassName", "Ptr", child, "Ptr", buf, "Int", 256)
        className := StrGet(buf)
        if className = "TGroupBox" {
            rect := Buffer(16)
            DllCall("GetWindowRect", "Ptr", child, "Ptr", rect)
            y := NumGet(rect, 4, "Int")  ; RECT.top = screen Y
            raw.Push({hwnd: child, y: y})
        }
        child := DllCall("GetWindow", "Ptr", child, "UInt", 2, "Ptr")  ; GW_HWNDNEXT
    }
    ; Sort by Y position (insertion sort - typically <10 items)
    if raw.Length > 1 {
        loop raw.Length - 1 {
            i := A_Index + 1
            key := raw[i]
            j := i - 1
            while j >= 1 && raw[j].y > key.y {
                raw[j + 1] := raw[j]
                j--
            }
            raw[j + 1] := key
        }
    }
    ; Return HWNDs in visual order
    sorted := []
    for item in raw
        sorted.Push(item.hwnd)
    return sorted
}

; Enumerate ALL descendant checkboxes within a container (via EnumChildWindows)
; Returns them sorted by screen Y position (with X tiebreaker) for consistent
; ordering regardless of z-order. Each item also has a depth field counting
; how many TGroupBox ancestors are between it and the container.
EnumDescendantCheckboxes(containerHwnd) {
    results := []
    global _descCBResults := results
    enumCB := CallbackCreate(_EnumDescCBCallback, "Fast", 2)
    DllCall("EnumChildWindows", "Ptr", containerHwnd, "Ptr", enumCB, "Ptr", 0)
    CallbackFree(enumCB)

    ; Compute nesting depth for each checkbox (TGroupBox ancestor count)
    for item in results {
        depth := 0
        p := DllCall("GetParent", "Ptr", item.hwnd, "Ptr")
        while p && p != containerHwnd {
            pBuf := Buffer(256, 0)
            DllCall("GetClassName", "Ptr", p, "Ptr", pBuf, "Int", 256)
            if StrGet(pBuf) = "TGroupBox"
                depth++
            p := DllCall("GetParent", "Ptr", p, "Ptr")
        }
        item.depth := depth
    }

    ; Sort by screen Y position (with X tiebreaker) for consistent ordering.
    ; Z-order varies between save and apply because nested TGroupBoxes are
    ; created in different orders. Y-position gives visual top-to-bottom order.
    if results.Length > 1 {
        loop results.Length - 1 {
            i := A_Index + 1
            key := results[i]
            j := i - 1
            while j >= 1 && (results[j].y > key.y
                || (results[j].y = key.y && results[j].x > key.x)) {
                results[j + 1] := results[j]
                j--
            }
            results[j + 1] := key
        }
    }

    return results
}

_EnumDescCBCallback(hwnd, lParam) {
    global _descCBResults
    buf := Buffer(256, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Ptr", buf, "Int", 256)
    className := StrGet(buf)
    if !(className = "TCPRSDialogParentCheckBox" || className = "TCPRSDialogCheckBox" || className = "TORCheckBox")
        return 1

    checked := SendMessage(0x00F0, 0, 0, hwnd) ? true : false

    ; Get screen position for Y-sorting
    rect := Buffer(16)
    DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rect)
    y := NumGet(rect, 4, "Int")
    x := NumGet(rect, 0, "Int")

    ; Read label for TCPRSDialogCheckBox (they have readable window text)
    label := ""
    if className = "TCPRSDialogCheckBox" || className = "TORCheckBox" {
        tLen := SendMessage(0x000E, 0, 0, hwnd)
        if tLen > 0 {
            tBuf := Buffer((tLen + 1) * 2, 0)
            SendMessage(0x000D, tLen + 1, tBuf, hwnd)
            label := Trim(StrGet(tBuf))
        }
    }

    _descCBResults.Push({hwnd: hwnd, className: className, checked: checked, label: label, y: y, x: x})
    return 1
}

; Lightweight count-only enumeration for stability checks
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
    _findCBResults.Push({hwnd: hwnd, className: className})
    return 1
}

; Wait until checkbox count stops changing
WaitForStableCheckboxCount(dlgHwnd) {
    prevCount := 0
    stableRounds := 0
    loop 20 {
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

; ===========================================================================
; DISMISS INTERMEDIATE POPUPS
; ===========================================================================

DismissIntermediatePopups() {
    Sleep(150)
    loop 3 {
        found := false
        for wnd in WinGetList("ahk_exe CPRSChart.exe") {
            try {
                cls := WinGetClass(wnd)
                if cls = "TfrmRemDlg" || cls = "TCPRSChart" || cls = "TfrmFrame"
                    || cls = "TfrmTemplateDialog"
                    continue
                WinGetPos(,, &w, &h, wnd)
                if w > 500 || h > 400
                    continue
                if HasDangerousButton(wnd)
                    continue
                okHwnd := FindOKButton(wnd)
                if okHwnd {
                    try PostMessage(0x00F5, 0, 0, okHwnd)
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
    buf := Buffer(256, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Ptr", buf, "Int", 256)
    className := StrGet(buf)
    if InStr(className, "TEdit") || InStr(className, "TMemo") || InStr(className, "TRichEdit") {
        _hasDangerous := true
        return 0
    }
    if InStr(className, "TButton") || InStr(className, "TBitBtn") {
        len := SendMessage(0x000E, 0, 0, hwnd)
        if len > 0 {
            textBuf := Buffer((len + 1) * 2, 0)
            SendMessage(0x000D, len + 1, textBuf, hwnd)
            textUpper := StrUpper(StrGet(textBuf))
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
        textUpper := StrUpper(StrGet(textBuf))
        if textUpper = "OK" || textUpper = "&OK" || textUpper = "CONTINUE"
            || textUpper = "&CONTINUE" || textUpper = "YES" || textUpper = "&YES" {
            _foundOKHwnd := hwnd
            return 0
        }
    }
    return 1
}

; ===========================================================================
; LOAD / DELETE / ADVANCED PANEL
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

BtnDeleteTemplate(ctrl, *) {
    templates := []
    loop files TemplateDir "\*.json" {
        templates.Push(A_LoopFileName)
    }
    if templates.Length = 0 {
        MsgBox("No saved templates to delete.", AppTitle, "Iconi")
        return
    }
    list := ""
    for i, f in templates
        list .= i ": " StrReplace(f, ".json", "") "`n"
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

BtnOpenAdvancedPanel(ctrl, *) {
    panelPath := A_ScriptDir "\NursingPanel.ahk"
    if FileExist(panelPath)
        Run(panelPath)
    else
        MsgBox("NursingPanel.ahk not found in " A_ScriptDir, AppTitle, "Icon!")
}

; ===========================================================================
; TOP-LEVEL PARENT DISCOVERY
; ===========================================================================

FindVisibleScrollBox(dlgHwnd) {
    child := DllCall("GetWindow", "Ptr", dlgHwnd, "UInt", 5, "Ptr")
    while child {
        buf := Buffer(256, 0)
        DllCall("GetClassName", "Ptr", child, "Ptr", buf, "Int", 256)
        if StrGet(buf) = "TScrollBox" {
            style := DllCall("GetWindowLong", "Ptr", child, "Int", -16, "Int")
            if style & 0x10000000
                return child
        }
        child := DllCall("GetWindow", "Ptr", child, "UInt", 2, "Ptr")
    }
    return 0
}

EnumTopLevelParents(scrollBoxHwnd) {
    parents := []
    seenDirectParent := false
    child := DllCall("GetWindow", "Ptr", scrollBoxHwnd, "UInt", 5, "Ptr")
    while child {
        buf := Buffer(256, 0)
        DllCall("GetClassName", "Ptr", child, "Ptr", buf, "Int", 256)
        className := StrGet(buf)
        if className = "TCPRSDialogParentCheckBox" {
            seenDirectParent := true
            checked := SendMessage(0x00F0, 0, 0, child)
            parents.Push({hwnd: child, checked: checked ? true : false})
        } else if className = "TGroupBox" && seenDirectParent {
            gbChild := DllCall("GetWindow", "Ptr", child, "UInt", 5, "Ptr")
            while gbChild {
                gbBuf := Buffer(256, 0)
                DllCall("GetClassName", "Ptr", gbChild, "Ptr", gbBuf, "Int", 256)
                if StrGet(gbBuf) = "TCPRSDialogParentCheckBox" {
                    checked := SendMessage(0x00F0, 0, 0, gbChild)
                    parents.Push({hwnd: gbChild, checked: checked ? true : false})
                }
                gbChild := DllCall("GetWindow", "Ptr", gbChild, "UInt", 2, "Ptr")
            }
        }
        child := DllCall("GetWindow", "Ptr", child, "UInt", 2, "Ptr")
    }
    return parents
}

; ===========================================================================
; TEMPLATE PARSING
; ===========================================================================

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
        } else if SubStr(chunk, 1, 5) = "false" {
            states.Push(false)
            searchPos += 5
        } else {
            searchPos++
        }
    }
    return states
}

; Parse groups array from format-3 JSON
; Returns array of arrays: groups[i] = array of {idx, cls, checked, label}
ParseGroups(jsonContent) {
    groups := []

    ; Find the "groups" array
    gPos := InStr(jsonContent, '"groups"')
    if !gPos
        return groups

    ; Find the opening [ of groups array
    gArrStart := InStr(jsonContent, "[",, gPos)
    if !gArrStart
        return groups

    ; Find matching ] using depth counting
    depth := 1
    scanPos := gArrStart + 1
    gArrEnd := 0
    while scanPos <= StrLen(jsonContent) && depth > 0 {
        ch := SubStr(jsonContent, scanPos, 1)
        if ch = "["
            depth++
        else if ch = "]"
            depth--
        if depth = 0
            gArrEnd := scanPos
        scanPos++
    }
    if !gArrEnd
        return groups

    ; Find each group object (contains "checkboxes" array)
    searchPos := gArrStart
    while true {
        ; Find next "checkboxes" keyword
        cbPos := InStr(jsonContent, '"checkboxes"', , searchPos + 1)
        if !cbPos || cbPos > gArrEnd
            break

        ; Find the [ of this checkboxes array
        cbArrStart := InStr(jsonContent, "[",, cbPos)
        if !cbArrStart || cbArrStart > gArrEnd
            break

        ; Find matching ]
        cbDepth := 1
        cbScan := cbArrStart + 1
        cbArrEnd := 0
        while cbScan <= StrLen(jsonContent) && cbDepth > 0 {
            c := SubStr(jsonContent, cbScan, 1)
            if c = "["
                cbDepth++
            else if c = "]"
                cbDepth--
            if cbDepth = 0
                cbArrEnd := cbScan
            cbScan++
        }
        if !cbArrEnd
            break

        ; Parse checkbox items within this group
        groupItems := []
        itemPos := cbArrStart
        while itemPos := InStr(jsonContent, "{",, itemPos + 1) {
            if itemPos > cbArrEnd
                break
            itemEnd := InStr(jsonContent, "}",, itemPos)
            if !itemEnd
                break
            itemStr := SubStr(jsonContent, itemPos, itemEnd - itemPos + 1)

            idx := 0
            if RegExMatch(itemStr, '"idx":\s*(\d+)', &idxM)
                idx := Integer(idxM[1])

            cls := ""
            if RegExMatch(itemStr, '"cls":\s*"([^"]*)"', &clsM)
                cls := clsM[1]

            checked := (InStr(itemStr, '"checked": true') || InStr(itemStr, '"checked":true'))
                ? true : false

            depth := 0
            if RegExMatch(itemStr, '"depth":\s*(\d+)', &depM)
                depth := Integer(depM[1])

            label := ""
            if RegExMatch(itemStr, '"label":\s*"((?:[^"\\]|\\.)*)"', &lblM)
                label := lblM[1]

            groupItems.Push({idx: idx, cls: cls, checked: checked, label: label, depth: depth})
            itemPos := itemEnd
        }

        groups.Push(groupItems)
        searchPos := cbArrEnd
    }

    return groups
}

; ===========================================================================
; DIALOG DUMP - Debug tool
; Press Ctrl+Shift+D with a CPRS dialog open.
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

    buf := Buffer(256, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Ptr", buf, "Int", 256)
    className := StrGet(buf)

    text := ""
    tLen := SendMessage(0x000E, 0, 0, hwnd)
    if tLen > 0 {
        tBuf := Buffer((tLen + 1) * 2, 0)
        SendMessage(0x000D, tLen + 1, tBuf, hwnd)
        text := StrGet(tBuf)
    }

    depth := 0
    p := hwnd
    loop {
        p := DllCall("GetParent", "Ptr", p, "Ptr")
        if !p || p = _dumpDlgHwnd
            break
        depth++
    }

    parentHwnd := DllCall("GetParent", "Ptr", hwnd, "Ptr")
    parentBuf := Buffer(256, 0)
    if parentHwnd
        DllCall("GetClassName", "Ptr", parentHwnd, "Ptr", parentBuf, "Int", 256)
    parentClass := parentHwnd ? StrGet(parentBuf) : "none"

    extra := ""
    if className = "TORCheckBox" || className = "TCPRSDialogParentCheckBox" || className = "TCPRSDialogCheckBox" {
        checked := SendMessage(0x00F0, 0, 0, hwnd)
        extra := " CHECKED=" (checked ? "YES" : "NO")
        _dumpCBCount++
    }

    style := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -16, "Int")
    visible := (style & 0x10000000) ? "Y" : "N"

    indent := ""
    loop depth
        indent .= "  "

    _dumpFile.Write(indent className " hwnd=" hwnd " text='" text "' vis=" visible " parent=" parentClass extra "`n")
    return 1
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

^+b:: {
    if WinExist(AppTitle) {
        if DllCall("IsWindowVisible", "Ptr", BoosterGui.Hwnd)
            BoosterGui.Hide()
        else
            BoosterGui.Show("NoActivate")
    }
}

^+d:: {
    DumpDialogControls()
}

^+n:: {
    ApplyNamedTemplate("Negative Assessment")
}
