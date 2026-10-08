; Window Cascade input integration.
; The shared Keybindings library owns configuration and registrations.
; Caps + Pause Layers is optional: normal shortcuts and window management work
; without its service. Never start or stop the service from Window Cascade.

InitializeCascadeKeybindings()
{
    global cascade_keybindings, rotate_key
    global cascade_command_focus_previous, cascade_command_focus_next
    global cascade_command_rotate_slot_previous, cascade_command_rotate_slot_next
    global cascade_command_swap_window_up, cascade_command_swap_window_down
    global cascade_command_adopt_active, cascade_command_rotate_layers
    global cascade_command_toggle_minimize, cascade_command_bring_forward
    global cascade_command_close_active, cascade_command_close_scope
    global cascade_command_gather_to_monitor, cascade_command_show_help
    global cascade_command_move_monitor_left, cascade_command_move_monitor_right
    global cascade_command_toggle_auto_placement

    manager := Keybindings("window-cascade", "Window Cascade", {
        layerFactory: (name, status) => CapsPauseClient(name, status),
        statusCallback: CascadeKeybindingStatus
    })

    ; Preserve the user's previous Space/Tab selection as the first-run default.
    ; After migration these two actions are fully configurable in Keybindings.
    rotationKey := rotate_key = "Tab" ? "Tab" : "Space"

    CascadeAddAction(manager, "swap-up", "swap visible window up",
        cascade_command_swap_window_up, "Caps + Up", "window navigation")
    CascadeAddAction(manager, "swap-down", "swap visible window down",
        cascade_command_swap_window_down, "Caps + Down", "window navigation")
    CascadeAddAction(manager, "slot-previous", "previous layer in this slot",
        cascade_command_rotate_slot_previous, "Caps + Left", "window navigation")
    CascadeAddAction(manager, "slot-next", "next layer in this slot",
        cascade_command_rotate_slot_next, "Caps + Right", "window navigation")
    CascadeAddAction(manager, "focus-previous", "focus visible window up",
        cascade_command_focus_previous, "Caps + PgUp", "window navigation")
    CascadeAddAction(manager, "focus-next", "focus visible window down",
        cascade_command_focus_next, "Caps + PgDn", "window navigation")
    CascadeAddAction(manager, "rotate-next", "rotate all slots forward",
        cascade_command_rotate_layers, "Caps + " rotationKey, "window navigation")
    CascadeAddAction(manager, "rotate-previous", "rotate all slots backward",
        cascade_command_rotate_layers, "Caps + Alt + " rotationKey,
        "window navigation", -1)
    CascadeAddAction(manager, "move-left", "move window to left monitor",
        cascade_command_move_monitor_left, "Caps + Alt + Left", "window navigation", "foreground")
    CascadeAddAction(manager, "move-right", "move window to right monitor",
        cascade_command_move_monitor_right, "Caps + Alt + Right", "window navigation", "foreground")

    CascadeAddAction(manager, "adopt", "adopt or re-slot active window",
        cascade_command_adopt_active, "Caps + Insert", "cascade commands")
    CascadeAddAction(manager, "bring-forward", "bring this monitor's cascade forward",
        cascade_command_bring_forward, "Caps + Home", "cascade commands")
    CascadeAddAction(manager, "minimize", "minimize or restore managed windows",
        cascade_command_toggle_minimize, "Caps + M", "cascade commands")
    CascadeAddAction(manager, "auto-placement", "pause or resume automatic cascading",
        cascade_command_toggle_auto_placement, "Caps + P", "cascade commands")
    CascadeAddAction(manager, "gather", "gather cascades onto this monitor",
        cascade_command_gather_to_monitor, "Caps + F7", "cascade commands")
    CascadeAddAction(manager, "close-active", "close active window",
        cascade_command_close_active, "Caps + Delete", "cascade commands")
    CascadeAddAction(manager, "close-monitor", "close this monitor's cascade",
        cascade_command_close_scope, "Caps + F4", "cascade commands")
    CascadeAddAction(manager, "help", "show Window Cascade help",
        cascade_command_show_help, "Caps + H", "interface")

    ; Local diagnostics (not the legacy broadcast message interface).
    CascadeAddAction(manager, "reset-log", "clear debug log",
        -1, "Caps + F5", "diagnostics")
    CascadeAddAction(manager, "copy-log", "copy debug log",
        -2, "Caps + F6", "diagnostics")

    ; Store the instance before Start(), since startup reports are synchronous.
    cascade_keybindings := manager
    try manager.Start()
    catch Error as failure {
        try manager.Stop()
        cascade_keybindings := 0
        throw failure
    }
}

CascadeAddAction(manager, id, label, commandId, binding, category, parameter := 0)
{
    manager.AddAction(id, label, CascadeBindingEvent.Bind(commandId, parameter),
        [binding], {category: category})
}

CascadeBindingEvent(commandId, parameter, event)
{
    ; Never run window operations directly in a keybinding/event callback.
    ; Event handlers deliver down/up/cancel, but commands activate only once.
    if event.phase != "down"
        return

    if commandId = -1 {
        SetTimer(CascadeResetLogFromBinding, -1)
        return
    }
    if commandId = -2 {
        SetTimer(CascadeCopyLogFromBinding, -1)
        return
    }

    ; Move commands need the foreground HWND from the original input event.
    if parameter = "foreground"
        parameter := event.foregroundHwnd
    QueueCascadeCommand(commandId, parameter, event.foregroundHwnd)
}

CascadeResetLogFromBinding(*)
{
    ShowCascadeStatusTip(ResetDebugLog() ? "debug log cleared" : "debug log clear failed")
}

CascadeCopyLogFromBinding(*)
{
    ShowCascadeStatusTip(CopyDebugLogToClipboard() ? "debug log copied" : "debug log copy failed")
}

CascadeKeybindingStatus(message)
{
    DebugLog("Keybindings: " message)
}

ShowCascadeKeybindings(*)
{
    global cascade_keybindings
    if IsObject(cascade_keybindings)
        cascade_keybindings.ShowSettings()
    else
        MsgBox("Keybindings did not initialize. Window management is still available.",
            "Window Cascade", "Icon!")
}

ShutdownCascadeKeybindings()
{
    global cascade_keybindings
    if IsObject(cascade_keybindings) {
        try cascade_keybindings.Stop()
        cascade_keybindings := 0
    }
}
