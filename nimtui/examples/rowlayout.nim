import std/strformat
import times
import nimtui




if isMainModule:
    init()

    var
        form, form2: View
        row, row2: Row

    let clocklbl = Label(id:"clocklbl", x:2, y:5, textstyle:ALARM)

    proc viewAction(v: Widget): Action = 
        result = Action(view: v)
        result.onRepaint = proc(v: Widget) =
            drawText("1234567890123456789012345678901234567890123456789012345678901234567890", 2, 8, TEXT)
            clocklbl.name = $now()
            drawLabel(clocklbl, TEXT)

    form = View(id:"form1", name:"RowTest1", frame:1, textstyle:BTN_FOCUS, height:getTerminalHeight(), action:viewAction(form))
    row = Row(id:"row", name:"Row1", layout:H3_33, textstyle:DEBUG)
    row.add(Label(id:"lbl1", name:"12345678901234567890"))
    row.add(Label(id:"lbl2", name:"abcdefghijabcdefghij"))
    row.add(Label(id:"lbl3", name:"12345678901234567890"))
    form.add(row)
    addView(form)

    # form2 = View(id:"form2", name:"RowTest1", frame:1, textstyle:BTN_FOCUS, height:getTerminalHeight(), action:viewAction(form))
    # row2 = Row(id:"row2", name:"Row2", layout:H3_33, textstyle:FAINT, height:2)
    # row2.add(Label(id:"lbl11", name:"09876543210987654321"))
    # row2.add(Label(id:"lbl21", name:"ABCDEFGHIJKLMNOPQRST"))
    # row2.add(Label(id:"lbl31", name:"abcdefghijabcdefghij"))
    # form2.add(row2)
    #addView(form2)

    enterEditLoop()
