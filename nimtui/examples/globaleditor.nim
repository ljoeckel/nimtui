import std/strformat
import times
import yottadb
import nimtui


type Stats = ref object
    records: int
    databytes: int
    keybytes: int
    datamax: int
    keymax: int
    processed: int
    unit: string = "ms"

var 
    form: View
    row: Row


# Dataprovider stuff
proc onGlobalsSelectionChanged(value: string) =
    setValue(row, "global", value)

# Generated from defineSignal(GlobalSelectionChanged, string)
connectGlobalSelectionChanged(proc(value: string) =
    onGlobalsSelectionChanged(value)
)


if isMainModule:
    init()
    let width = getTerminalWidth()
    let height = getTerminalHeight()
    var globalsProvider = YDBGlobals

    form = View(id:"form", name:"Globals-Viewer", frame:1, width:width, height:height)
    row = Row(id:"row", layout:H2_30, textstyle:DEBUG)
    row.add(ListBox(id:"globals", name:"Globals", selectionChanged:onGlobalsSelectionChanged, provider:globalsProvider, frame:1))
    row.add(ListBox(id:"global", name:"Global", provider:YDBGlobal, frame:1))
    form.add(row)

    proc reloadAction(v: Widget): Action = 
        result = Action(view: v)
        result.onAction = proc(v: Widget) =
            var child = v.findChild("globals")
            if child != nil and child of ListBox:
                ListBox(child).provider.lines = @[]
                child.page = 0
                child.mouseY = 0
                selectChild(child)

    proc killAction(v: Widget): Action = 
        result = Action(view:v)

        proc killGlobalVar() =
            let gbl = v.getValue("global")
            kill: @gbl
            var reload = v.findChild("reload")
            if reload != nil and reload of Button:
                reload.action.onAction(form)

        result.onAction = proc(v: Widget) =
            let gbl = v.getValue("global")
            YesNoDialog("Kill Global", fmt"Ok to kill global {gbl}?", killGlobalVar)


    proc statsAction(v: Widget): Action = 
        result = Action(view: v)
        proc closeView(v: Widget): Action =
            result = Action(view: v)
            result.onAction = proc(v: Widget) =
                if findView(v.id) != nil: 
                    removeView(v.id)
                setFocus(form, "globals")

        result.onAction = proc(v: Widget) =
            var child = v.findChild("globals")
            if child == nil: return
            let gbl = child.provider.selected

            var statsdlg: Dialog
            if findView("statsdlg").isNil:
                let (width, height) = (40, 11)
                let x = ((getTerminalWidth() - width) / 2).int
                let y = ((getTerminalHeight() - height) / 2).int
                statsdlg = Dialog(frame:1, x:x, y:y, id:"stats", modal:true, name:"Statistics", height:height, width:width)
                statsdlg.add(TextField(id:"global", editable:false, x:1, y:0,    name:"Global      : ", len:20))
                statsdlg.add(TextField(id:"records", editable:false, x:1, y:1,   name:"Recods      : ", len:12))
                statsdlg.add(TextField(id:"keybytes", editable:false, x:1, y:2,  name:"Key bytes   : ", len:12))
                statsdlg.add(TextField(id:"keymax", editable:false, x:1, y:3,    name:"Max Keylen  : ", len:12))                
                statsdlg.add(TextField(id:"databytes", editable:false, x:1, y:4, name:"Data bytes  : ", len:12))
                statsdlg.add(TextField(id:"datamax", editable:false, x:1, y:5,   name:"Max Datalen : ", len:12))
                statsdlg.add(TextField(id:"processed", editable:false, x:1, y:6, name:"Duration    : ", len:8))
                statsdlg.add(Button(id:"close", name:"Close", frame:1, align:BOT_RIGHT, action:closeView(statsdlg)))
                addView(statsdlg)
                setFocus(statsdlg, "close")

            var stats = Stats()
            let t1 = getTime()
            # collect data
            for (k, v) in queryItr @gbl.kv:
                inc(stats.keybytes, k.len)
                inc(stats.databytes, v.len)
                inc stats.records
                stats.datamax = max(stats.datamax, v.len)
                stats.keymax = max(stats.keymax, k.len)
            # Calculate run time
            let t2 = getTime()
            var duration = (t2 - t1).inMilliseconds
            if duration <= 1: # < 1ms
                duration = (t2 - t1).inMicroseconds
                stats.unit = "µs"
            stats.processed = duration

            setValue(statsdlg, "global", gbl)
            setValue(statsdlg, "records", $stats.records)
            setValue(statsdlg, "keybytes", $stats.keybytes)
            setValue(statsdlg, "keymax", $stats.keymax)
            setValue(statsdlg, "databytes", $stats.databytes)
            setValue(statsdlg, "datamax", $stats.datamax)            
            setValue(statsdlg, "processed", $stats.processed & " " & stats.unit)

    form.add(Button(frame:1, id:"kill", name:"Kill", align:TOP_RIGHT, action:killAction(form)))    
    form.add(Button(frame:1, id:"reload", name:"Reload", align:TOP_RIGHT, action:reloadAction(form)))
    form.add(Button(frame:1, id:"stats", name:"Stats", align:TOP_RIGHT, action:statsAction(form)))    
    form.add(Button(frame:1, id:"quit", name:"Quit", align:TOP_RIGHT, action:QuitAction(form)))

    addView(form)
    setFocus(form, "globals")
    enterEditLoop()
