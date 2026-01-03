import texalotbase

proc QuitAction*(v: Widget): EventHandler = 
    result = EventHandler(view: v)
    result.onAction = proc(v: Widget) =
        onExit()

