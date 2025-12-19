import std/strutils
import std/streams
import yottadb
import ydbutils
import nimtui

# Define a signal
defineSignal(selectionChanged, Widget)
defineSignal(GlobalSelectionChanged, string)

# ------------- Globals Provider ------------
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
            emitGlobalSelectionChanged(provider.lines[0]) # select 1. global
    return getProviderData(page, pagesize, provider.lines)

var globalsProvider = DataProvider(callback: globalsProviderCallback)

const globalProviderCallback = proc(provider: var DataProvider, page: int, pagesize: int): (seq[string], bool) =
    if provider.selected.len > 0 and provider.selected != provider.selectedBefore:
        if not provider.selected.startsWith("("):
            provider.lines.setLen(0)
            provider.selectedBefore = provider.selected
            let start = provider.selected
            for (k, v) in queryItr @start.kv:
                let openPar = k.find('(')
                if openPar != -1:
                    provider.lines.add(k[openPar..^1] & "=" & v)
                else:
                    provider.lines.add(k & "=" & v)
    return getProviderData(page, pagesize, provider.lines)
var globalProvider = DataProvider(callback: globalProviderCallback)


# ------------------------------------------- 

var
    form: View
    param: View
    dropCount = 0

proc onFocusForm(v: Widget) =
    if texalotEvent of MouseEvent:
        let ev = MouseEvent(texalotEvent)
        case ev.key
        of EVENT_MOUSE_LEFT_DRAG:
            if not v.dragging:
                v.dragChild = findChild(v, ev)
            if v.dragChild != nil:
                v.dragging = true
                let (x,y) = mouseToOffset(v, ev)
                v.dragChild.x = x
                v.dragChild.y = y
        of EVENT_MOUSE_RIGHT, EVENT_MOUSE_RIGHT_DRAG:
            v.dragging = true
        of EVENT_MOUSE_MIDDLE, EVENT_MOUSE_MIDDLE_DRAG:
            v.dragging = true
        of EVENT_MOUSE_WHEEL_DOWN, EVENT_MOUSE_WHEEL_UP:
            v.dragging = true
        of EVENT_MOUSE_MOVE:
            v.allowDrop = findChild(v, ev).isNil
        of EVENT_MOUSE_RELEASE:
            if mouseInView(v, ev):
                if not v.dragging and v.allowDrop:             
                    inc dropCount   
                    let name = "DataField" & $dropCount & ": "
                    let (x,y) = mouseToOffset(v, v.mouseX, v.mouseY)
                    var child = TextField(id:name, x:x, y:y, name:name, fieldlen:20, value:"")
                    v.add(child)
                else:
                    v.dragChild = findChild(v, ev)
                    if v.dragChild != nil:
                        #selectChild(v, v.dragChild)
                        selectChild(v.dragChild)
                        #v.info = v.dragChild.name
                        emitSelectionChanged(v.dragChild)
                    v.dragging = false
                    v.dragChild = nil
        else:
            discard


proc updateField(v: Widget) =
    if v.editChild.isNil or v.dragChild.isNil: return
    if v.editChild of TextField and v.dragChild of TextField:
        var t = TextField(v.editChild)
        let tn = TextField(v.dragChild)
        case t.id 
        of "NAME": tn.name = t.value
        of "LEN": tn.fieldlen = try: parseInt(t.value) except: 0
        of "TYP": tn.fieldtyp = try: parseInt(t.value) except: 0


proc onSelectionChanged(v: var View; value: Widget) =
    v.editX = 0
    v.editY = 0
    v.dragChild = value
    if value of TextField:
        let t = TextField(value)
        TextField(v.childs[0]).value = t.name
        TextField(v.childs[1]).value = $t.fieldlen
        TextField(v.childs[2]).value = $t.fieldtyp

connectSelectionChanged(proc(value: Widget) =
    param.onSelectionChanged(value)
)

proc onGlobalsSelectionChanged(value: string) =
    setValue(form, "selgbl", value)
    setValue(form, "global", value)

connectGlobalSelectionChanged(proc(value: string) =
    onGlobalsSelectionChanged(value)
)

if isMainModule:
    init()

    let width = getTerminalWidth()
    let height = getTerminalHeight()
    let tw = 36

    proc formActions(v: Widget): Action =
        result = Action()
        result.onFocus = onFocusForm

    proc paramActions(v: Widget): Action =
        result = Action()
        result.onUpdate = updateField

    const stringProviderCallback = proc(provider: var DataProvider, page: int, pagesize: int): (seq[string], bool) =
        return getProviderData(page, pagesize, provider.lines)
    var stringProvider = DataProvider(
        callback: stringProviderCallback,
        lines: @["Hello", "World", "aaaaa", "12345678901234567890bbbbbb", "ccccccc", "dddddddd", "eeeeeee", "ffffff", "Hello2", "World2", "2aaaaa", "2bbbbbb", "2ccccccc", "2dddddddd", "2eeeeeee", "2ffffff"]
        )

    block:
        # The Form View
        form = View(id:"form", action:formActions(form), name:"FormEditor", frame:1, x:0, y:0, height:height, width:width-tw)
        form.add(TextField(id:"selgbl", name:"Selected Global:", x:0, y:0, fieldlen:20))
        var lb = ListBox(focus:true, id:"globals", name:"Globals", selectionChanged:onGlobalsSelectionChanged, provider:globalsProvider, frame:1, x:0, y:1, width:20, height:12)
        form.add(lb)
        var lbglobal = ListBox(focus:false, id:"global", name:"Globals", provider:globalProvider, frame:1, x:21, y:1, width:80, height:12)
        form.add(lbglobal)
        selectChild(lb)

    block:
        # The Params View
        param = View(id:"params", action:paramActions(param), name:"Field Params", frame:1, x:width-tw, y:0, height:height, width:tw)
        param.add(TextField(id:"NAME", x:0, y:0, name:"Fieldname: ", fieldlen:20))
        param.add(TextField(id:"LEN", x:0, y:1, name:"      Len: ", fieldlen:3))
        param.add(TextField(id:"TYP", x:0, y:2, name:"      Typ: ", fieldlen:1))

        var lb = ListBox(focus:false, id:"lb", name:"ListBox", provider:stringProvider, frame:1, x:0, y:6, width:20, height:5)
        param.add(lb)

    proc deleteAction(v: View): Action = 
        result = Action(view: v)
        result.isEnabled = proc(): bool =
            getSelectedChild(v) != nil
        
        result.onAction = proc(v: Widget) =
            let selectedChild = getSelectedChild(v)
            let idx = deleteChild(selectedChild)     
            v.editChild = nil
            param.clearFields()
            v.nextField()
            emitSelectionChanged(v.editChild)

    proc showAction(v: View): Action = 
        result = Action(view: v)
        result.isEnabled = proc(): bool =
            v.childs.len > 0
        
        result.onAction = proc(v: Widget) =
            if findView("dialog").isNil:
                var dialog = View(id:"dialog", name:"Dialog", frame:1, x:20, y:5, height:6, width:40)
                for child in v.childs:
                    var copy = deepCopy(child)
                    copy.parent = dialog
                    dialog.add(copy)
                addView(dialog)
                setFocus(dialog)
            else:
                removeView("dialog")


    proc serializeFormData(v: View): Action =
        result = Action(view: v)
        result.onAction = proc(v: Widget) =
            for child in v.childs:
                echo child.id," ", child.name, " ", typeof(child.parent)


    proc saveAction(v: View): Action = 
        result = Action(view: v)
        result.isEnabled = proc(): bool =
            v.childs.len > 0
        
        result.onAction = proc(v: Widget) =
            if findView("savedialog").isNil:
                var savedlg = View(frame:1, id:"savedialog", modal:true, name:"Save Form", x:20, y:5, height:6, width:40)
                savedlg.add(TextField(id:"id", x:0, y:0, name:"  Form-Id : ", fieldlen:20))
                savedlg.add(TextField(id:"name", x:0, y:1, name:"     Name : ", fieldlen:20))
                savedlg.add(TextField(id:"filename", x:0, y:2, name:" Filename : ", fieldlen:20))
                savedlg.add(Button(id:"save", x:0, y:3, frame:1, name:"Save", action:serializeFormData(form)))

                addView(savedlg)
                setFocus(savedlg)
                toFirstEditField(savedlg)

    proc quitAction(v: View): Action = 
        result = Action(view: v)
        result.onAction = proc(v: Widget) =
            onExit()

    param.add(Button(frame:1, id:"delete", name:"Delete", action:deleteAction(form)))
    param.add(Button(frame:1, id:"show", name:"Show", action:showAction(form)))
    param.add(Button(frame:1, id:"save", name:"Save", action:saveAction(form)))
    param.add(Button(frame:1, id:"quit", name:"Quit", action:quitAction(form)))    

    addView(form)
    addView(param)

    setFocus(form)
    enterEditLoop()