import std/strutils
import texalot
import texalotbase

proc centerDialog(width, height: int): (int, int) =
    let x = ((getTerminalWidth() - width) / 2).int
    let y = ((getTerminalHeight() - height) / 2).int
    result = (x, y)

proc YesNoDialog*(title: string, content: string, yes: proc(), no: proc() = nil) =
    proc onYes(v: Widget): Action = 
        result = Action(view: v)
        result.onAction = proc(v: Widget) =
            yes()
            removeView(v.id)

    proc onNo(v: Widget): Action =
        result = Action(view: v)
        result.onAction = proc(v: Widget) =
            if no != nil: no()
            removeView(v.id)

    var dlg: Dialog
    if findView("dlg").isNil:
        let (width, height) = (40, 6)
        let (x,y) = centerDialog(width, height)
        dlg = Dialog(frame:1, id:"yesno", modal:true, name:title.toUpper(), x:x, y:y, height:height, width:width)
        dlg.add(Label(id:"lbl", x:1, y:1, name:content))
        dlg.add(Button(id:"yes", name:"Yes", frame:1, textstyle:FAINT, align:BOT_CENTER, action:onYes(dlg)))
        dlg.add(Button(id:"no", name:"No", frame:1, align:BOT_CENTER, action:onNo(dlg)))
        addView(dlg)
        setFocus(dlg, "no")