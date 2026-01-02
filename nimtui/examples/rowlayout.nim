import std/times
import ../texalot
import ../texalotbase


if isMainModule:
    init()

    var
        form, form2: View
        row, row2: Row
        col: Col

    let clocklbl = Label(id:"clocklbl", x:40, y:1, textstyle:ALARM)

    proc viewAction(v: Widget): Action = 
        result = Action(view: v)
        result.onRepaint = proc(v: Widget) =
            clocklbl.name = $now()
            drawLabel(clocklbl, TEXT)

    form = View(id:"form1", name:"RowTest1", frame:1, height:getTerminalHeight(), action:viewAction(form))

    row = Row(id:"row", name:"Row1", layout:H3_33, textstyle:TEXT_MOVING)
    row.add(Label(id:"rlbl1", name:"ABCEDFGHIJKLMNOPQ"))
    row.add(Label(id:"rlbl2", name:"YYYYYYYYYYY", textstyle:ALARM))
    row.add(Label(id:"rlbl3", name:"XXXXX"))

    col = Col(id:"col", name:"Col1", layout:V4_25, textstyle:TEXT_MOVING)
    col.add(Label(id:"lbl1", name:"12345678901234567890"))
    col.add(Label(id:"lbl2", name:"Rabcdefghijabcdefghij"))
    col.add(Label(id:"lbl3", name:"12345678901234567890"))
    #col.add(TextField(id:"txt1", name:"Textfeld:", len:20))
    col.add(row)
    form.add(col)

#    form.add(row)

    # row2 = Row(id:"row2", name:"Row2", frame:1, textstyle:BTN_DISABLED, height:getTerminalHeight(), action:viewAction(form))
    # row2.add(Label(id:"lbl11", name:"09876543210987654321"))
    # row2.add(Label(id:"lbl21", name:"ABCDEFGHIJKLMNOPQRST"))
    # row2.add(Label(id:"lbl31", name:"abcdefghijabcdefghij"))
    # form.add(row2)


    addView(form)
    enterEditLoop()
