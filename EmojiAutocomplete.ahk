#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; Emoji Autocomplete for Windows
; The catalog and settings remain external so packaged builds stay editable.

SetWorkingDir(A_ScriptDir)
CoordMode("Caret", "Screen")
CoordMode("Mouse", "Screen")
SendMode("Input")

global App := {
    active: false,
    query: "",
    matches: [],
    selected: 1,
    gui: 0,
    controls: [],
    tiles: [],
    catalog: [],
    disabledApps: Map(),
    bottomAnchorApps: Map(),
    maxResults: 7,
    minChars: 1,
    suppress: false,
    observer: 0,
    targetWindow: 0,
    lastActivity: 0,
    trackedWindow: 0,
    trackedX: 0,
    trackedY: 0,
    trackedAt: 0,
    lastTargetWindow: 0,
    lastTargetProcess: "",
    toggleMenuLabel: "Disable/enable last active app",
    managerGui: 0
}

LoadSettings()
if HandleCommandLine()
    ExitApp()
LoadCatalog()
ConfigureTray()
CreatePopup()
StartObserver()
SetTimer(WatchSession, 200)
SetTimer(TrackForegroundApp, 150)
OnExit((*) => StopObserver())

; Navigation is intercepted only while a suggestion popup is active.
#HotIf IsSessionActive()
Left::MoveSelection(-1)
Up::MoveSelection(-1)
Right::MoveSelection(1)
Down::MoveSelection(1)
Enter::AcceptSelection()
Tab::AcceptSelection()
Esc::CancelSession()
~Backspace::HandleBackspace()
~Delete::CancelSession()
~Home::CancelSession()
~End::CancelSession()
~PgUp::CancelSession()
~PgDn::CancelSession()
~LButton::HandleOutsideClick()
#HotIf

~LButton::RememberClick()
^!e::ToggleFocusedApp()

IsSessionActive() {
    global App
    return App.active
}

LoadSettings() {
    global App
    path := A_ScriptDir "\config\settings.ini"
    if !FileExist(path)
        return
    try App.maxResults := Max(1, Min(12, Integer(IniRead(path, "popup", "max_results", 7))))
    try App.minChars := Max(1, Min(10, Integer(IniRead(path, "matching", "minimum_characters", 1))))
    App.disabledApps := Map()
    disabled := IniRead(path, "disabled_apps", "process_names", "")
    for processName in StrSplit(disabled, ",") {
        processName := StrLower(Trim(processName))
        if processName != ""
            App.disabledApps[processName] := true
    }
    App.bottomAnchorApps := Map()
    bottomAnchors := IniRead(path, "positioning", "bottom_anchor_apps", "")
    for processName in StrSplit(bottomAnchors, ",") {
        processName := StrLower(Trim(processName))
        if processName != ""
            App.bottomAnchorApps[processName] := true
    }
}

HandleCommandLine() {
    global App
    if A_Args.Length < 2
        return false
    action := StrLower(A_Args[1])
    processName := StrLower(Trim(A_Args[2]))
    if !RegExMatch(processName, "^[a-z0-9_.+ -]+\.exe$")
        return false
    if action = "--disable-app"
        App.disabledApps[processName] := true
    else if action = "--enable-app" {
        if App.disabledApps.Has(processName)
            App.disabledApps.Delete(processName)
    } else
        return false
    SaveDisabledApps()
    return true
}

ConfigureTray() {
    global App
    A_TrayMenu.Add()
    A_TrayMenu.Add("Manage disabled apps...", ShowDisabledAppsManager)
    A_TrayMenu.Add(App.toggleMenuLabel, ToggleCurrentApp)
    A_TrayMenu.Add("Reload settings", ReloadSettings)
    A_TrayMenu.Add("Start with Windows", ToggleStartup)
    A_IconTip := "Emoji Autocomplete"
    UpdateStartupMenu()
}

GetStartupCommand() {
    if A_IsCompiled
        return '"' A_ScriptFullPath '"'
    return '"' A_AhkPath '" "' A_ScriptFullPath '"'
}

IsStartupEnabled() {
    key := "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run"
    try return RegRead(key, "EmojiAutocomplete") = GetStartupCommand()
    catch
        return false
}

UpdateStartupMenu() {
    try A_TrayMenu.Uncheck("Start with Windows")
    if IsStartupEnabled()
        try A_TrayMenu.Check("Start with Windows")
}

ToggleStartup(*) {
    key := "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run"
    if IsStartupEnabled() {
        try RegDelete(key, "EmojiAutocomplete")
        message := "Emoji Autocomplete will no longer start with Windows"
    } else {
        RegWrite(GetStartupCommand(), "REG_SZ", key, "EmojiAutocomplete")
        message := "Emoji Autocomplete will start with Windows"
    }
    UpdateStartupMenu()
    TrayTip(message, "Emoji Autocomplete", 1)
}

GetActiveProcessName() {
    try {
        return StrLower(WinGetProcessName("A"))
    } catch {
        return ""
    }
}

IsAppDisabled() {
    global App
    processName := GetActiveProcessName()
    return processName != "" && App.disabledApps.Has(processName)
}

TrackForegroundApp() {
    global App
    windowId := WinExist("A")
    if !windowId
        return
    try processId := WinGetPID("ahk_id " windowId)
    catch
        return
    if processId = ProcessExist()
        return
    try processName := StrLower(WinGetProcessName("ahk_id " windowId))
    catch
        return
    if processName = ""
        return

    App.lastTargetWindow := windowId
    App.lastTargetProcess := processName
    UpdateToggleMenuLabel(processName)
}

UpdateToggleMenuLabel(processName) {
    global App
    action := App.disabledApps.Has(processName) ? "Enable in " : "Disable in "
    newLabel := action processName
    if newLabel != App.toggleMenuLabel {
        try A_TrayMenu.Rename(App.toggleMenuLabel, newLabel)
        App.toggleMenuLabel := newLabel
    }
}

ToggleCurrentApp(*) {
    global App
    processName := App.lastTargetProcess
    if processName = ""
        return
    ToggleAppByName(processName)
}

ToggleFocusedApp(*) {
    global App
    processName := GetActiveProcessName()
    if processName = ""
        return
    App.lastTargetProcess := processName
    App.lastTargetWindow := WinExist("A")
    ToggleAppByName(processName)
}

ToggleAppByName(processName) {
    global App
    if App.disabledApps.Has(processName) {
        App.disabledApps.Delete(processName)
        message := "Emoji autocomplete enabled in " processName
    } else {
        App.disabledApps[processName] := true
        message := "Emoji autocomplete disabled in " processName
        CancelSession()
    }
    SaveDisabledApps()
    UpdateToggleMenuLabel(processName)
    TrayTip(message, "Emoji Autocomplete", 1)
}

SaveDisabledApps() {
    global App
    names := ""
    for name in App.disabledApps
        names .= (names = "" ? "" : ",") name
    IniWrite(names, A_ScriptDir "\config\settings.ini", "disabled_apps", "process_names")
}

ShowDisabledAppsManager(*) {
    global App
    if App.managerGui {
        try App.managerGui.Show()
        return
    }

    manager := Gui("+AlwaysOnTop +Resize", "Emoji Autocomplete - Disabled apps")
    manager.SetFont("s9", "Segoe UI")
    manager.AddText("w560", "Check applications where Emoji Autocomplete should stay off.")
    list := manager.AddListView("xm y+8 w560 r15 Checked", ["Application", "Open window"])

    apps := Map()
    for windowId in WinGetList() {
        try {
            title := Trim(WinGetTitle("ahk_id " windowId))
            processName := StrLower(WinGetProcessName("ahk_id " windowId))
            processId := WinGetPID("ahk_id " windowId)
            if (title = "" || processName = "" || processId = ProcessExist())
                continue
            if !apps.Has(processName)
                apps[processName] := title
        }
    }
    ; Keep disabled applications visible even when they are not currently open.
    for processName in App.disabledApps {
        if !apps.Has(processName)
            apps[processName] := "Not currently running"
    }

    for processName, title in apps {
        options := App.disabledApps.Has(processName) ? "Check" : ""
        list.Add(options, processName, title)
    }
    list.ModifyCol(1, 180)
    list.ModifyCol(2, 350)

    saveButton := manager.AddButton("xm y+10 w100 Default", "Save")
    cancelButton := manager.AddButton("x+8 w100", "Cancel")
    saveButton.OnEvent("Click", SaveDisabledAppsManager.Bind(manager, list))
    cancelButton.OnEvent("Click", CloseDisabledAppsManager.Bind(manager))
    manager.OnEvent("Close", CloseDisabledAppsManager.Bind(manager))
    manager.OnEvent("Escape", CloseDisabledAppsManager.Bind(manager))
    App.managerGui := manager
    manager.Show()
}

SaveDisabledAppsManager(manager, list, *) {
    global App
    selected := Map()
    row := 0
    while row := list.GetNext(row, "C") {
        processName := StrLower(Trim(list.GetText(row, 1)))
        if processName != ""
            selected[processName] := true
    }
    App.disabledApps := selected
    SaveDisabledApps()
    CancelSession()
    App.managerGui := 0
    manager.Destroy()
    TrackForegroundApp()
    TrayTip("Disabled-app list saved", "Emoji Autocomplete", 1)
}

CloseDisabledAppsManager(manager, *) {
    global App
    App.managerGui := 0
    manager.Destroy()
}

ReloadSettings(*) {
    LoadSettings()
    CancelSession()
    TrayTip("Settings reloaded", "Emoji Autocomplete", 1)
}

LoadCatalog() {
    global App
    path := A_ScriptDir "\data\emoji.tsv"
    if !FileExist(path) {
        MsgBox("Emoji catalog not found:`n" path, "Emoji Autocomplete", "Iconx")
        ExitApp()
    }

    text := FileRead(path, "UTF-8")
    for line in StrSplit(text, "`n", "`r") {
        line := Trim(line)
        if (line = "" || SubStr(line, 1, 1) = "#")
            continue
        columns := StrSplit(line, "`t")
        if columns.Length < 2
            continue
        emoji := columns[1]
        name := StrLower(Trim(columns[2]))
        aliases := columns.Length >= 3 ? StrLower(Trim(columns[3])) : ""
        keywords := columns.Length >= 4 ? StrLower(Trim(columns[4])) : ""
        terms := [name]
        for alias in StrSplit(aliases, ",") {
            alias := Trim(alias)
            if alias != ""
                terms.Push(alias)
        }
        App.catalog.Push({emoji: emoji, name: name, aliases: aliases, keywords: keywords, terms: terms})
    }

    if App.catalog.Length = 0 {
        MsgBox("The emoji catalog contains no valid entries.", "Emoji Autocomplete", "Iconx")
        ExitApp()
    }
}

StartObserver() {
    global App
    ih := InputHook("V L0")
    ih.OnChar := ObserveCharacter
    ih.Start()
    App.observer := ih
}

StopObserver() {
    global App
    try App.observer.Stop()
    DestroyPopup()
}

ObserveCharacter(ih, char) {
    global App
    if App.suppress
        return
    if IsAppDisabled() {
        if App.active
            CancelSession()
        return
    }

    ; Some controls deliver pasted chunks through OnChar. Process each code point.
    Loop Parse, char {
        App.lastActivity := A_TickCount
        ch := A_LoopField
        TrackTypedCharacter(ch)
        if ch = ":" {
            StartSession()
            continue
        }
        if !App.active
            continue
        if RegExMatch(ch, "^[A-Za-z0-9_+\-]$") {
            App.query .= StrLower(ch)
            RefreshMatches()
        } else {
            CancelSession()
        }
    }
}

RememberClick() {
    global App
    MouseGetPos(&mouseX, &mouseY, &windowId)
    App.trackedWindow := WinExist("A")
    App.trackedX := mouseX
    App.trackedY := mouseY
    App.trackedAt := A_TickCount
}

TrackTypedCharacter(character) {
    global App
    if !App.trackedWindow || App.trackedWindow != WinExist("A")
        return
    if (character = "`n" || character = "`r") {
        App.trackedY += 20
        return
    }
    if RegExMatch(character, "^[ilI\.,'!:;|]$")
        width := 4
    else if RegExMatch(character, "^[mwMW@#%]$")
        width := 11
    else if character = " "
        width := 5
    else
        width := 8
    App.trackedX += width
    App.trackedAt := A_TickCount
}

StartSession() {
    global App
    CancelSession()
    App.active := true
    App.query := ""
    App.selected := 1
    App.targetWindow := WinExist("A")
    App.lastActivity := A_TickCount
}

WatchSession() {
    global App
    if !App.active
        return
    ; Close when focus leaves the text application's top-level window or the
    ; session has been idle for 30 seconds. The popup uses WS_EX_NOACTIVATE,
    ; so interacting with it does not steal focus from the target window.
    if (App.targetWindow && WinExist("A") != App.targetWindow)
        CancelSession()
    else if (A_TickCount - App.lastActivity > 30000)
        CancelSession()
}

HandleBackspace() {
    global App
    App.lastActivity := A_TickCount
    if App.trackedWindow = WinExist("A")
        App.trackedX := Max(0, App.trackedX - 8)
    ; Let the application receive Backspace first, then update our model.
    if StrLen(App.query) = 0 {
        CancelSession()
        return
    }
    App.query := SubStr(App.query, 1, -1)
    SetTimer(RefreshMatches, -10)
}

RefreshMatches() {
    global App
    if !App.active
        return
    if StrLen(App.query) < App.minChars {
        App.matches := []
        DestroyPopup()
        return
    }

    prefix := []
    partialMatches := []
    seen := Map()
    for item in App.catalog {
        rank := 0
        for term in item.terms {
            if SubStr(term, 1, StrLen(App.query)) = App.query {
                rank := 2
                break
            }
            if InStr(term, App.query)
                rank := Max(rank, 1)
        }
        if rank = 0 && InStr(item.keywords, App.query)
            rank := 1
        if rank = 2
            prefix.Push(item)
        else if rank = 1
            partialMatches.Push(item)
    }

    App.matches := []
    for group in [prefix, partialMatches] {
        for item in group {
            key := item.emoji "|" item.name
            if seen.Has(key)
                continue
            seen[key] := true
            App.matches.Push(item)
            if App.matches.Length >= App.maxResults
                break 2
        }
    }

    if App.matches.Length = 0 {
        DestroyPopup()
        return
    }
    App.selected := Min(Max(App.selected, 1), App.matches.Length)
    RenderPopup()
}

CreatePopup() {
    global App
    Critical("On")
    popup := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000", "Emoji suggestions")
    App.gui := popup
    popup.BackColor := "17212B"
    popup.MarginX := 0
    popup.MarginY := 0
    App.controls := []
    App.tiles := []

    placeholder := A_ScriptDir "\assets\emoji\" App.catalog[1].name ".png"
    Loop App.maxResults {
        index := A_Index
        tileX := 7 + ((index - 1) * 48)
        tile := popup.AddProgress("x" tileX " y7 w44 h44 c17212B Background17212B Hidden", 100)
        control := popup.AddPicture("x" (tileX + 6) " y13 w32 h32 BackgroundTrans Hidden", placeholder)
        control.OnEvent("Click", SelectByClick.Bind(index))
        App.tiles.Push(tile)
        App.controls.Push(control)
    }

    popup.Show("Hide w" (14 + (App.maxResults * 48) - 4) " h58")
}

RenderPopup() {
    global App
    Critical("On")
    for index in Range(App.maxResults) {
        tile := App.tiles[index]
        control := App.controls[index]
        if index <= App.matches.Length {
            item := App.matches[index]
            imagePath := A_ScriptDir "\assets\emoji\" item.name ".png"
            control.Value := imagePath
            tile.Opt("-Hidden")
            control.Opt("-Hidden")
        } else {
            control.Opt("+Hidden")
            tile.Opt("+Hidden")
        }
    }

    width := 14 + (App.matches.Length * 48) - 4
    height := 58
    App.gui.Show("Hide w" width " h" height)
    WinSetRegion("0-0 W" width " H" height " R14-14", App.gui.Hwnd)
    UpdateSelection()
    GetPopupPosition(width, height, &x, &y)
    App.gui.Show("x" x " y" y " w" width " h" height " NA")
}

Range(count) {
    values := []
    Loop count
        values.Push(A_Index)
    return values
}

GetPopupPosition(width, height, &x, &y) {
    global App
    target := App.targetWindow ? App.targetWindow : WinExist("A")
    processName := ""
    try processName := StrLower(WinGetProcessName("ahk_id " target))
    useBottomAnchor := processName != "" && App.bottomAnchorApps.Has(processName)

    hasTrackedAnchor := (App.trackedWindow = target
        && A_TickCount - App.trackedAt < 300000
        && App.trackedX > 0 && App.trackedY > 0)

    if !useBottomAnchor && hasTrackedAnchor {
        x := App.trackedX
        y := App.trackedY - height - 16
    } else if !useBottomAnchor && CaretGetPos(&caretX, &caretY) {
        x := caretX
        y := caretY - height - 8
    } else {
        ; Custom Chromium/Electron editors often expose neither a Win32 nor
        ; MSAA caret. Their composer is usually at the bottom of the active
        ; window, which is a much better fallback than an unrelated mouse
        ; pointer position.
        try WinGetPos(&windowX, &windowY, &windowWidth, &windowHeight, "ahk_id " target)
        catch {
            windowX := 0
            windowY := 0
            windowWidth := A_ScreenWidth
            windowHeight := A_ScreenHeight
        }
        x := windowX + 100
        y := windowY + windowHeight - height - 165

        ; If the pointer is inside the lower composer area, its horizontal
        ; position is a useful approximation of the caret for custom editors.
        MouseGetPos(&mouseX, &mouseY)
        if (mouseX >= windowX && mouseX <= windowX + windowWidth
            && mouseY >= windowY + (windowHeight * 0.65)
            && mouseY <= windowY + windowHeight)
            x := mouseX
    }

    monitor := MonitorGetPrimary()
    MonitorGetWorkArea(monitor, &left, &top, &right, &bottom)
    x := Max(left + 4, Min(x, right - width - 4))
    if y < top
        y := top + 4
}

MoveSelection(delta) {
    global App
    if App.matches.Length = 0
        return
    App.selected += delta
    if App.selected < 1
        App.selected := App.matches.Length
    else if App.selected > App.matches.Length
        App.selected := 1
    App.lastActivity := A_TickCount
    UpdateSelection()
}

UpdateSelection() {
    global App
    for index, tile in App.tiles {
        color := index = App.selected ? "3A6D99" : "17212B"
        try tile.Opt("c" color " Background" color)
    }
    ; Updating a Progress control can paint over controls above it on some
    ; Windows themes. Redraw the PNG layer in z-order after changing tiles.
    for control in App.controls
        try control.Redraw()
    try WinRedraw("ahk_id " App.gui.Hwnd)
}

AcceptSelection() {
    global App
    if App.matches.Length = 0
        return
    InsertEmoji(App.matches[App.selected].emoji)
}

SelectByClick(index, *) {
    global App
    if !App.active || index > App.matches.Length
        return
    InsertEmoji(App.matches[index].emoji)
}

InsertEmoji(emoji) {
    global App
    charsToRemove := StrLen(App.query) + 1
    App.suppress := true
    DestroyPopup()
    App.active := false
    Send("{Backspace " charsToRemove "}")
    SendText(emoji)
    SetTimer(() => App.suppress := false, -75)
    App.query := ""
    App.matches := []
}

HandleOutsideClick() {
    global App
    if !App.gui
        return
    MouseGetPos(,, &windowId)
    try {
        if windowId != App.gui.Hwnd
            SetTimer(CancelSession, -10)
    }
}

CancelSession(*) {
    global App
    App.active := false
    App.query := ""
    App.matches := []
    App.selected := 1
    App.targetWindow := 0
    App.lastActivity := 0
    DestroyPopup()
}

DestroyPopup() {
    global App
    Critical("On")
    if App.gui
        try App.gui.Hide()
}
