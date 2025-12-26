import std/strformat
import times
import nimtui




if isMainModule:
    init()

    var
        form, form2: View
        row, row2: Row

    proc viewAction(v: Widget): Action = 
        result = Action(view: v)
        result.onRepaint = proc(v: Widget) =
            drawText("1234567890123456789012345678901234567890123456789012345678901234567890", 0, 8, TEXT)
            let lbl = Label(id:"lbl0", name:"ABCDEFGHIJ", x:1, y:5)
            drawLabel(lbl, TEXT)

    form = View(id:"form1", name:"RowTest1", frame:1, y:0, textstyle:BTN_FOCUS, width:62, maxwidth:62, height:getTerminalHeight(), action:viewAction(form))
    row = Row(id:"row", layout:H3_33, textstyle:DEBUG, height:2)
    row.add(Label(id:"lbl1", name:"12345678901234567890", width:20, frame:0))
    row.add(Label(id:"lbl2", name:"abcdefghijabcdefghij", y:2, width:20, frame:0))
    row.add(Label(id:"lbl3", name:"abcdefghijabcdefghij", width:20, frame:0))
    form.add(row)

    form2 = View(id:"form2", name:"RowTest1", frame:1, x:63, y:0, textstyle:BTN_FOCUS, width:62, maxwidth:62, height:getTerminalHeight(), action:viewAction(form))
    row2 = Row(id:"row", layout:H3_33, textstyle:DEBUG, height:2)
    row2.add(Label(id:"lbl1", name:"12345678901234567890", width:20, frame:0))
    row2.add(Label(id:"lbl2", name:"abcdefghijabcdefghij", y:2, width:20, frame:0))
    row2.add(Label(id:"lbl3", name:"abcdefghijabcdefghij", width:20, frame:0))
    form2.add(row2)

    addView(form)
    addView(form2)

    enterEditLoop()
