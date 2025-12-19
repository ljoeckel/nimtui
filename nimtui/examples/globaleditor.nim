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
    grid: Grid
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
    log("onGlobalsSelectionChanged value=" & value)
    setValue(grid, "global", value)

connectGlobalSelectionChanged(proc(value: string) =
    onGlobalsSelectionChanged(value)
)

if isMainModule:
    init()
    let width = getTerminalWidth()
    let height = getTerminalHeight()
    let yoff = 6
    form = View(id:"form", name:"Globals-Editor", frame:1, width:width, height:height)
    grid = Grid(id:"grid", layout:Layout.H2_25, y:0, width:width, height:height, frame:1)
    grid.add(ListBox(focus:true, id:"globals", name:"Globals", selectionChanged:onGlobalsSelectionChanged, provider:globalsProvider, frame:1, x:0, y:0, width:25, height:height-yoff))
    grid.add(ListBox(id:"global", name:"Global", provider:globalProvider, frame:1, x:26, y:0, width:width-30, height:height-yoff))
    form.add(grid)

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
        result = Action(view: v)
        result.onAction = proc(v: Widget) =
            let gbl = v.getValue("global")
            kill: @gbl
            var reload = v.findChild("reload")
            if reload != nil and reload of Button:
                reload.action.onAction(form)

    proc statsAction(v: Widget): Action = 
        result = Action(view: v)

        proc closeView(v: Widget): Action =
            result = Action(view: v)
            result.onAction = proc(v: Widget) =
                if findView(v.id) != nil: 
                    removeView(v.id)
                setFocus(form, "globals")

        result.onAction = proc(v: Widget) =
            let gbl = v.getValue("globals")
            var statsdlg: View
            if findView("statsdlg").isNil:
                statsdlg = View(frame:1, id:"stats", modal:true, name:"Statistics", x:20, y:3, height:11, width:40)
                statsdlg.add(TextField(id:"global", editable:false, x:1, y:0,    name:"Global      : ", fieldlen:20))
                statsdlg.add(TextField(id:"records", editable:false, x:1, y:1,   name:"Recods      : ", fieldlen:12))
                statsdlg.add(TextField(id:"keybytes", editable:false, x:1, y:2,  name:"Key bytes   : ", fieldlen:12))
                statsdlg.add(TextField(id:"keymax", editable:false, x:1, y:3,    name:"Max Keylen  : ", fieldlen:12))                
                statsdlg.add(TextField(id:"databytes", editable:false, x:1, y:4, name:"Data bytes  : ", fieldlen:12))
                statsdlg.add(TextField(id:"datamax", editable:false, x:1, y:5,   name:"Max Datalen : ", fieldlen:12))
                statsdlg.add(TextField(id:"processed", editable:false, x:1, y:6, name:"Duration    : ", fieldlen:8))

                statsdlg.add(Button(id:"close", name:"Close", frame:1, action:closeView(statsdlg)))
                addView(statsdlg)
                setFocus(statsdlg, "close")

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

    form.add(Button(frame:1, id:"reload", name:"Reload", action:reloadAction(form)))
    form.add(Button(frame:1, id:"kill", name:"Kill", action:killAction(form)))    
    form.add(Button(frame:1, id:"stats", name:"Stats", action:statsAction(form)))    
    form.add(Button(frame:1, id:"quit", name:"Quit", action:quitAction(form)))    

    addView(form)
    setFocus(form, "globals")
    enterEditLoop()