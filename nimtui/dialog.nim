import std/strutils
import texalotbase

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
        dlg = Dialog(frame:1, id:"yesno", modal:true, name:title.toUpper(), x:20, y:3, height:11, width:40)
        dlg.add(Label(id:"lbl", x:1, y:2, name:content))
        dlg.add(Button(id:"yes", name:"Yes", frame:1, textstyle:FAINT, align:BOT_CENTER, action:onYes(dlg)))
        dlg.add(Button(id:"no", name:"No", frame:1, align:BOT_CENTER, action:onNo(dlg)))
        addView(dlg)
        setFocus(dlg, "no")