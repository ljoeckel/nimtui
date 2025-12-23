import texalotbase

proc QuitAction*(v: Widget): Action = 
    result = Action(view: v)
    result.onAction = proc(v: Widget) =
        onExit()

