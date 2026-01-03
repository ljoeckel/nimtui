import std/times
import ../texalot
import ../texalotbase


if isMainModule:
    init()

    var view: View

    proc viewHandler(v: Widget): EventHandler = 
        result = EventHandler(view: v)
        result.onRepaint = proc(v: Widget) =
            let clk = findChild(v, "clock")
            if clk != nil: clk.name = $now()

    view = View(id:"form1", name:"RowTest1", frame:1, height:getTerminalHeight(), handler:viewHandler(view))

    var row = Row(id:"row", name:"Row1", layout:H4_25, textstyle:TEXT_MOVING)
    row.add(Label(id:"rlbl1", name:"ABCEDFGHIJKLMNOPQ"))
    row.add(Label(id:"rlbl2", name:"YYYYYYYYYYY", textstyle:ALARM))
    row.add(Label(id:"rlbl3", name:"XXXXX"))
    let tm = $now()
    row.add(Label(id:"clock", name:tm, textstyle:ALARM))
    view.add(row)

    # col = Col(id:"col", name:"Col1", layout:V4_25, textstyle:TEXT_MOVING)
    # col.add(Label(id:"lbl1", name:"12345678901234567890"))
    # col.add(Label(id:"lbl2", name:"Rabcdefghijabcdefghij"))
    # col.add(Label(id:"lbl3", name:"12345678901234567890"))
    # col.add(row)
    # form.add(col)

    # row2 = Row(id:"row2", name:"Row2", frame:1, textstyle:BTN_DISABLED, height:getTerminalHeight(), action:viewAction(form))
    # row2.add(Label(id:"lbl11", name:"09876543210987654321"))
    # row2.add(Label(id:"lbl21", name:"ABCDEFGHIJKLMNOPQRST"))
    # row2.add(Label(id:"lbl31", name:"abcdefghijabcdefghij"))
    # form.add(row2)

    addView(view)
    enterEditLoop()
