import std/strutils
import std/strformat
import times
import yottadb
import ydbutils
import nimtui

defineSignal(GlobalSelectionChanged, string)

# ------------- Globals Provider ------------

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
    stats: Stats

proc getProviderData(page: int, pagesize: int, data: seq[string]): (seq[string], bool) =
    var lower = page*pagesize
    if lower >= data.len: return
    var upper = lower + pagesize
    if upper > data.len: upper = data.len
    elif data.len < upper: upper = data.len
    let more = upper < data.len
    return (data[lower..<upper], more)

const globalsProviderCallback = proc(provider: var DataProvider, page: int, pagesize: int): (seq[string], bool) =
    if provider.lines.len == 0:
        provider.lines = getGlobals()
        if provider.lines.len > 0:
            provider.selected = provider.lines[0]
            emitGlobalSelectionChanged(provider.lines[0]) # select 1. global
    return getProviderData(page, pagesize, provider.lines)

const globalProviderCallback = proc(provider: var DataProvider, page: int, pagesize: int): (seq[string], bool) =
    if provider.selected.len > 0 and provider.selected != provider.selectedBefore:
        if not provider.selected.startsWith("("):
            provider.lines.setLen(0)
            provider.selectedBefore = provider.selected
            let gbl = provider.selected
            stats = Stats()
            let t1 = getTime()
            for (k, v) in queryItr @gbl.kv:
                # collect stats
                inc(stats.keybytes, k.len)
                inc(stats.databytes, v.len)
                inc stats.records
                stats.datamax = max(stats.datamax, v.len)
                stats.keymax = max(stats.keymax, k.len)

                # remove leading ^globalname
                let openPar = k.find('(')
                let value = if v.isEmptyOrWhitespace: "" else: "=" & v
                if openPar != -1:
                    provider.lines.add(k[openPar..^1] & value)
                else:
                    provider.lines.add(k & value)

            # Calculate time
            let t2 = getTime()
            var duration = (t2 - t1).inMilliseconds
            if duration <= 1: # < 1ms
                duration = (t2 - t1).inMicroseconds
                stats.unit = "µs"
            stats.processed = duration

    return getProviderData(page, pagesize, provider.lines)

var
    globalsProvider = DataProvider(callback: globalsProviderCallback)
    globalProvider = DataProvider(callback: globalProviderCallback)

proc onGlobalsSelectionChanged(value: string) =
    setValue(row, "global", value)

connectGlobalSelectionChanged(proc(value: string) =
    onGlobalsSelectionChanged(value)
)

proc YesNoDialog(title: string, content: string, action: proc()) =
    proc onYes(v: Widget): Action = 
        result = Action(view: v)
        result.onAction = proc(v: Widget) =
            action()
            removeView(v.id)

    proc onNo(v: Widget): Action =
        result = Action(view: v)
        result.onAction = proc(v: Widget) =
            removeView(v.id)

    var dlg: Dialog
    if findView("dlg").isNil:
        dlg = Dialog(frame:1, id:"yesno", modal:true, name:title.toUpper(), x:20, y:3, height:11, width:40)
        dlg.add(Label(id:"lbl", x:1, y:2, name:content))
        dlg.add(Button(id:"yes", name:"Yesyesyes", frame:1, textstyle:FAINT, align:BOT_CENTER, action:onYes(dlg)))
        dlg.add(Button(id:"no", name:"Nonono", frame:1, align:BOT_CENTER, action:onNo(dlg)))
        addView(dlg)
        setFocus(dlg, "no")


if isMainModule:
    init()
    let width = getTerminalWidth()
    let height = getTerminalHeight()
    let yoff = 6
    var cnt = 0

    form = View(id:"form", name:"Globals-Editor", frame:1, width:width, height:height)
    row = Row(id:"row", y:1, height:height-yoff, layout:H2_30)
    row.add(ListBox(id:"globals", name:"Globals", selectionChanged:onGlobalsSelectionChanged, provider:globalsProvider, frame:1, focus:true))
    row.add(ListBox(id:"global", name:"Global", provider:globalProvider, frame:1))
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
            #kill: @gbl
            echo "kill global var ", gbl
            #let gbl = v.getValue("global")
            #kill: @gbl
            var reload = v.findChild("reload")
            if reload != nil and reload of Button:
                reload.action.onAction(form)

        result.onAction = proc(v: Widget) =
            YesNoDialog("Kill Global", "Really kill global?", killGlobalVar)

    # proc killAction(v: Widget): Action = 
    #     result = Action(view: v)
    #     result.onAction = proc(v: Widget) =
    #         let gbl = v.getValue("global")
    #         kill: @gbl
    #         var reload = v.findChild("reload")
    #         if reload != nil and reload of Button:
    #             reload.action.onAction(form)

    proc statsAction(v: Widget): Action = 
        result = Action(view: v)

        proc closeView(v: Widget): Action =
            result = Action(view: v)
            result.onAction = proc(v: Widget) =
                if findView(v.id) != nil: 
                    removeView(v.id)
                setFocus(form, "globals")

        result.onAction = proc(v: Widget) =
            var statsdlg: Dialog
            if findView("statsdlg").isNil:
                statsdlg = Dialog(frame:1, id:"stats", modal:true, name:"Statistics", x:20, y:3, height:11, width:40)
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

            if not stats.isNil:
                let gbl = v.getValue("globals")
                setValue(statsdlg, "global", gbl)
                setValue(statsdlg, "records", $stats.records)
                setValue(statsdlg, "keybytes", $stats.keybytes)
                setValue(statsdlg, "keymax", $stats.keymax)
                setValue(statsdlg, "databytes", $stats.databytes)
                setValue(statsdlg, "datamax", $stats.datamax)            
                setValue(statsdlg, "processed", $stats.processed & " " & stats.unit)

    proc quitAction(v: Widget): Action = 
        result = Action(view: v)
        result.onAction = proc(v: Widget) =
            onExit()

    form.add(Button(frame:1, id:"kill", name:"Kill", align:BOT_LEFT, action:killAction(form)))    
    form.add(Button(frame:1, id:"reload", name:"Reload", align:BOT_LEFT, action:reloadAction(form)))
    form.add(Button(frame:1, id:"stats", name:"Stats", align:BOT_LEFT, action:statsAction(form)))    
    form.add(Button(frame:1, id:"quit", name:"Quit", align:BOT_RIGHT, action:quitAction(form)))    

    addView(form)
    setFocus(form, "globals")
    enterEditLoop()
