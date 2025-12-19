import std/strutils
import std/strformat
import std/unicode
import std/os
import std/tables
import macros
import texalot

when compileOption("profiler"):
  import std/nimprof

const
    ROUND_DOT = "\u02f3"
    FILLER* = ROUND_DOT

    TOP_LEFT_CORNER = "\u2554"
    TOP_RIGHT_CORNER = "\u2557"
    HORIZONTAL = "\u2550"
    VERTICAL = "\u2551"
    BOT_LEFT_CORNER = "\u255A"
    BOT_RIGHT_CORNER = "\u255D"

    BOX_CHARS_FRAME = [
        TOP_LEFT_CORNER,
        TOP_RIGHT_CORNER,
        HORIZONTAL,
        VERTICAL,
        BOT_LEFT_CORNER,
        BOT_RIGHT_CORNER
    ]

    BTN_TOP_LEFT_CORNER = "\u256D"
    BTN_TOP_RIGHT_CORNER = "\u256e"
    BTN_HORIZONTAL = "\u2500"
    BTN_VERTICAL = "\u2502"
    BTN_BOT_LEFT_CORNER = "\u2570"
    BTN_BOT_RIGHT_CORNER = "\u256f"

    BTN_BOX_CHARS_FRAME = [
        BTN_TOP_LEFT_CORNER,
        BTN_TOP_RIGHT_CORNER,
        BTN_HORIZONTAL,
        BTN_VERTICAL,
        BTN_BOT_LEFT_CORNER,
        BTN_BOT_RIGHT_CORNER
    ]

    DefaultBG* = rgb("#f6f3fc")
    DefaultFG* = rgb("#2e2d3e")
    TextFG* = rgb("#111111")
    PlaceholderFG* = rgb("#9cA3AF")
    FocusedBG* = rgb("#EEF5FF")

    MODAL* = TextStyle(fg: Gray, bg: Light_gray, style: STYLE_FAINT)
    ALARM* = TextStyle(fg: Red, bg: White, style: STYLE_NONE)
    DEFAULT* = TextStyle(fg: DefaultFG, bg: DefaultBG, style: STYLE_NONE)
    FRAME_FOCUS* = TextStyle(fg: Dark_green, bg: DefaultBG, style: STYLE_NONE)
    FRAME_FOCUS_MODAL* = TextStyle(fg: Dark_goldenrod, bg: DefaultBG, style: STYLE_NONE)    
    FAINT* = TextStyle(fg: DefaultFG, bg: DefaultBG, style: STYLE_FAINT)
    TEXT* = TextStyle(fg: DefaultFG, bg: DefaultBG, style: STYLE_NONE)
    BTN_TEXT* = TextStyle(fg: Royal_blue, bg: DefaultBG, style: STYLE_BOLD)
    BTN_FOCUS* = TextStyle(fg: Whitesmoke , bg: Royal_blue, style: STYLE_BOLD)
    BTN_DISABLED* = TextStyle(fg: Gray , bg: DefaultBG, style: STYLE_NONE)
    TEXT_VALUE* = TextStyle(fg: Dark_blue, bg: DefaultBG, style: STYLE_BOLD)    
    TEXT_MOVING* = TextStyle(fg: Green, bg: DefaultBG, style: STYLE_BOLD)
    TEXT_NODROP* = TextStyle(fg: Red, bg: DefaultBG, style: STYLE_BOLD)    
    TEXT_EDIT* = TextStyle(fg: Cornflower_blue, bg: FocusedBG, style: STYLE_NONE)
    TEXT_CURSOR* = TextStyle(fg: DefaultBG, bg: DefaultFG, style: STYLE_NONE)
    TEXT_SELECTED* = TextStyle(fg: TextFG , bg: DefaultBG, style: STYLE_BOLD)
    FIELD_FOCUS* = TextStyle(fg: TextFG, bg: Light_goldenrod_yellow, style: STYLE_NONE)
    FIELD_FOCUS_INSERT* = TextStyle(fg: DefaultFG, bg: Alice_blue, style: STYLE_NONE)

type
    Direction* = enum
        Forward
        Backward

    Align* = enum 
        NONE,
        TOP_LEFT,
        TOP_CENTER,
        TOP_RIGHT,
        BOT_LEFT,
        BOT_CENTER,
        BOT_RIGHT

    Layout* = enum 
        NONE = (-1, "-1"),
        H2_10 = (0, "10"),
        H2_20 = (1, "20"),
        H2_25 = (2, "25"),
        H2_30 = (3, "30"),
        H2_40 = (4, "40"),
        H2_50 = (5, "50"),
        H2_75 = (6, "75"),
        H3_33 = (7, "33"),
        H3_66 = (8, "66"),
        H4_25 = (9, "25")
        H5_20 = (10, "20")

    DPCallback* = proc(provider: var DataProvider, page: int, pagesize: int): (seq[string], bool)
    DataProvider* = object of RootObj
        lines*: seq[string]
        selected*: string
        selectedBefore*: string
        callback*: DPCallback

    Action* = ref object
        view*: Widget
        isEnabled*: proc(): bool
        onFocus*: proc(v: Widget)
        onAction*: proc(v: Widget)
        onUpdate*: proc(v: Widget)
        onQuit*: proc(v: Widget)

    Widget* = ref object of RootObj
        parent* {.cursor.}: Widget
        x*: int = 0
        y*: int = 0
        width*: int
        height*: int
        align*: Align = Align.NONE
        editX*: int
        editY*: int
        frame*: int = 0
        id*: string
        name*: string
        childs*: seq[Widget]
        action*: Action
        enabled*: bool = true
        editable*: bool = true
        focus*: bool
        modal*: bool
        selected*: bool
        dragging*: bool
        editChild*: Widget
        dragChild*: Widget
        allowDrop*: bool
        provider*: DataProvider
        mouseX*: int
        mouseY*: int
        enableSelection*: bool = true
        # state
        visible*: bool = true
        insert*: bool = false
        more*: bool
        page*: int
        # gui
        ch*: string = " "
        textStyle*: TextStyle = DEFAULT
        layout*: Layout = NONE
        
    View* = ref object of Widget
    Dialog* = ref object of Widget
    Grid* = ref object of Widget

    DataType = enum 
        AlphaNumeric
        Numeric
        Natural
        Float 
        RegEx 

    TextField* = ref object of Widget
        len*: int
        fieldtyp*: int
        value*: string

    Label* = ref object of Widget

    Button* = ref object of Widget

    ListBox* = ref object of Widget
        line*: int
        lines*: seq[string]
        selectionChanged*: proc(value:string)

var
    views*: seq[Widget]
    currentFocus*: int
    cursorOn: bool
    modal: bool


proc onExit*() {.noconv.} =
    deinitTextalot()
    quit(0)


proc init*() =
  setControlCHook(onExit)
  initTextalot()
  enableMouseTracking()


macro defineSignal*(name: untyped; T: typed): untyped =
  # Create identifier nodes correctly
  let sigName      = newIdentNode(name.strVal & "Signal")
  let handlersName = newIdentNode(name.strVal & "Handlers")
  let connectName  = newIdentNode("connect" & name.strVal)
  let emitName     = newIdentNode("emit" & name.strVal)

  result = quote do:
    type
      #`sigName` = proc(value: `T`) {.nimcall.}
      `sigName` = proc(value: `T`) {.closure.}

    var `handlersName`: seq[`sigName`] = @[]

    proc `connectName`(cb: `sigName`) =
      `handlersName`.add(cb)

    proc `emitName`(value: `T`) =
      for cb in `handlersName`:
        cb(value)

proc addView*(v: Widget) =
    if v.id.isEmptyOrWhitespace: raise newException(ValueError, "'id' must be set for View")
    # View already there?
    for view in views: 
        if view.id == v.id: return 
    views.add(v)


proc findView*(id: string): Widget =
    for v in views:
        if id == v.id:
            return v
    nil 

proc isModal*(): bool =
    for v in views:
        if v.modal: return true



proc lineDown*(lb: var ListBox) =
    lb.mouseX = 0
    inc lb.mouseY
    if lb.mouseY >= lb.height and lb.more:
        lb.mouseY = 0
        inc lb.page
    if lb.mouseY >= lb.lines.len:
        lb.mouseY = lb.lines.len - 1


proc lineUp*(lb: var ListBox) =
    lb.mouseX = 0
    dec lb.mouseY
    if lb.mouseY < 0 and lb.page > 0:
        dec lb.page
        if lb.page < 0: lb.page = 0
        lb.mouseY = lb.height - 1
    elif lb.mouseY < 0: lb.mouseY = 0


proc pageHome(lb: var ListBox) =
    lb.mouseX = 0
    lb.mouseY = 0
    lb.page = 0


proc pageEnd(lb: var ListBox) =
    lb.mouseX = 0
    lb.page = lb.provider.lines.len div lb.height
    lb.mouseY = lb.provider.lines.len - (lb.page * lb.height)
    lineUp(lb)


proc pageUp(lb: var ListBox) =
    lb.mouseX = 0
    lb.mouseY = 0
    dec lb.page
    if lb.page < 0: lb.page = 0


proc pageDown*(lb: var ListBox) =
    lb.mouseX = 0
    lb.mouseY = 0
    inc lb.page
    if lb.page * lb.height >= lb.provider.lines.len:
        dec lb.page
    if lb.mouseY >= lb.lines.len:
        lb.mouseY = lb.lines.len - 1


# func offset*(v: Widget, x: int, y: int): (int, int) =
#     result = (v.x + x + v.frame, v.y + y + v.frame)
func offset(v: Widget, w: Widget): (int, int) =
    result = (v.x + w.x + v.frame, v.y + w.y + v.frame)
func offset(w: Widget): (int, int) =
    offset(w.parent, w)
func offset(v: Widget, x: int, y: int): (int, int) =
    result = (v.x + x + v.frame, v.y + y + v.frame)

proc mouseToOffset*(v: Widget, x,y: int): (int, int) =
    let refw = if v of ListBox and v.parent of Grid: v.parent else: v
    result = (x - refw.x - refw.frame, y - refw.y - v.frame)

func mouseToOffset*(v: Widget, me: MouseEvent): (int, int) =
    let refw = if v of ListBox and v.parent of Grid: v.parent else: v
    result = (me.x - refw.x - refw.frame, me.y - refw.y - v.frame)


func allowDrop*(t: TextField): bool =
    for child in t.parent.childs:
        if child == t: continue
        let validY = if t.y >= child.y and t.y <= child.y: true else: false
        if child of TextField:
            let tf = TextField(child)
            let fulllength = child.name.len + tf.len
            if t.x >= child.x and t.x <= child.x + fulllength and validY:
                return false
            if child.x >= t.x and child.x <= t.x + fulllength and validY:
                return false
        else:
            if t.x >= child.x and t.x <= child.x + child.name.len:
                if t.y >= child.y and t.y <= child.y:
                    return false
                return false
    return true


func mouseInView*(v: Widget, me: MouseEvent): bool =
    if me.x >= v.x and me.x <= v.x + v.width-1:
        if me.y >= v.y and me.y <= v.y + v.height-1:
            return true
    return false


proc collectChilds(v: Widget, t: type): (seq[t], int) =
    var 
        collection: seq[t]
        selected: int
    for child in v.childs:
        if child of Grid:
            for sc in child.childs:
                if sc of t:
                    collection.add(t(sc))
        elif child of t:
            collection.add(t(child))
    for idx, child in collection:
        if child.selected:
            selected = idx
            break
    return (collection, selected)

proc collectChilds(v: Widget): (seq[Widget], int) =
    collectChilds(v, Widget)

proc deselectButton(v: Widget) =
    var buttons: seq[Widget]
    for child in v.childs:
        if child of Button: buttons.add(child)
    if buttons.len > 1: # dont flicker a single button
        for child in buttons:
            child.selected = false

proc selectButton*(w: Widget) =
    for child in w.parent.childs:
        if child of Button: child.selected = false
    if w of Button:
        w.selected = true

proc calculateXY(w: Widget) =
    var x,y: int
    let parent = w.parent
    case w.align
    of NONE: # x,y used
        discard
    of TOP_RIGHT:
        w.x = parent.x + parent.width - parent.frame*2 - w.name.len - w.frame*2
        w.y = parent.y
    of TOP_LEFT:
        discard 
    of TOP_CENTER:
        discard      
    of BOT_RIGHT:  
        w.x = parent.x + parent.width - parent.frame - w.name.len - w.frame*2
        w.y = parent.y + parent.height - parent.frame - w.frame*2
    of BOT_LEFT:
        var maxx: int
        for c in parent.childs:
            if c.align == BOT_LEFT and c.x > 0:
                maxx = c.x - parent.x + c.name.len + c.frame
        w.x = maxx + parent.x + parent.frame
        w.y = parent.y + parent.height - parent.frame - w.frame*2
    of BOT_CENTER: 
        w.x = ((w.x + w.width) div 2) + w.x + w.frame
        w.y = parent.y + parent.height - parent.frame - w.frame*2

proc add*(parent: Widget, w: Widget) =
    if w != nil and w.id.isEmptyOrWhitespace: raise newException(ValueError, "Must have a id")
    if w of Grid and (w.width == 0 or w.height == 0):
        raise newException(ValueError, "Must have width & height")
    for child in parent.childs:
        # check for duplicate id
        if child.id == w.id: raise newException(ValueError, "Duplicate id '" & child.id & "'")

    # check button for x,y / alignment
    if w of Button and w.x == 0 and w.y == 0 and w.align == Align.NONE:
        w.align = Align.BOT_LEFT

    w.parent = parent
    calculateXY(w)
    parent.childs.add(w)



# proc add*(parent: Widget, w: Widget) =
#     if w != nil and w.id.isEmptyOrWhitespace:
#         raise newException(ValueError, "Must have a id")
#     if w of Grid and (w.width == 0 or w.height == 0):
#         raise newException(ValueError, "Must have width & height")
#     for child in parent.childs:
#         if child.id == w.id: raise newException(ValueError, "Widget with id '" & child.id & "' already there")

#     if w of Button:
#         # calculate position when x,y not set
#         var maxx = 0
#         if w.x == 0 and w.y == 0:
#             for c in parent.childs:
#                 if c of Button:
#                     maxx = c.x + c.name.len + c.frame + 1
#             w.x = maxx
#             w.y = parent.height - parent.frame - 1 - w.frame*2
#             w.recalculated = true

#     var maxElements: int
#     let percent = parseInt($parent.layout)
#     case parent.layout
#     of NONE:
#         maxElements = int.high
#     of H2_10, H2_20, H2_25, H2_30, H2_40, H2_50, H2_75:
#         maxElements = 2
#     of H3_33, H3_66:
#         maxElements = 3
#     of H4_25:
#         maxElements = 4
#     of H5_20:
#         maxElements = 5

#     if parent.childs.len < maxElements:
#         parent.childs.add(w)
#         w.parent = parent
#     else:
#         raise newException(ValueError, "Maximum number of children reached. Use another layout")

proc getFocus*(): Widget =
    for v in views:
        if v.focus:
            result = v
            break 
    if result.isNil and views.len > 0:
        views[0].focus = true
        result = views[0]

proc selectChild*(w: Widget) =
    var (collected, _) = collectChilds(w.parent)
    for child in collected:
        if child.id == w.id:
            child.selected = true
        else:
            child.selected = false
    #if w != nil: w.selected = true


proc getSelectedChild*(w: Widget): Widget =
    var (collected, selected) = collectChilds(w)
    if collected.len == 0: nil
    else: collected[selected]

proc getSelectedChild*(): Widget =
    let v = getFocus()
    getSelectedChild(v)


proc findChild*(v: Widget, id: string): Widget =
    var (collected, _) = collectChilds(v)
    for child in collected:
        if child.id == id: result = child

proc findChild*(v: Widget, x, y: int): Widget =
    var (collected, _) = collectChilds(v)
    for child in collected:
        let refw = if child.parent of Grid: child.parent else: child
        let framey = if child.frame > 0: child.frame + 1 else: 0
        var ox,oy: int
        if child.align == NONE:
            (ox, oy) = mouseToOffset(v, x, y)
        else:
            ox = child.x
            oy = child.y

        if child of TextField:
            let tf = TextField(child)
            if ox >= child.x and ox <= child.x + child.name.len + tf.len:
                if oy >= child.y and oy <= child.y: 
                    result = child
        elif child of Button:
            if child.align == NONE:
                let (ox, oy) = mouseToOffset(v, x, y)
                if ox >= child.x and ox <= child.x + child.name.len + child.frame:
                    if oy >= child.y and oy <= child.y + framey: 
                        result = child
            else:
                if x >= child.x and x <= child.x + child.name.len + child.frame:
                    if y >= child.y and y <= child.y + framey: 
                        result = child
        elif child of ListBox:
            if ox >= child.x and ox <= child.x + child.width:
                if oy >= refw.y and oy <= refw.y + child.height:
                    result = child
        elif child of Grid:
            if ox >= child.x and ox <= child.x + child.width:
                if oy >= child.y and oy <= child.y + child.height: 
                    result = findChild(child, x, y) # search in the grid
        else:
            if ox >= child.x and ox <= child.x + child.name.len:
                if oy >= child.y and oy <= child.y: result = child


proc findChild*(v: Widget, e: MouseEvent): Widget =
    #let (x,y) = mouseToOffset(v, e)
    findChild(v, e.x, e.y)


proc updateField(v: Widget) =
    if v.action != nil and v.action.onUpdate != nil:
        v.action.onUpdate(v)


proc setEditChild*(w: Widget) = 
    selectChild(w)
    w.parent.editChild = w
    w.parent.editX = 0


proc stepField(v: Widget, direction: Direction, t: type): Widget =
    var (collection, selected) = collectChilds(v, t)
    if collection.len == 0: return nil

    if direction == Forward:
        if selected < collection.len-1: result = collection[selected+1]
        else: result = collection[0]
    else:
        if selected > 0: result = collection[selected-1]
        else: result = collection[^1]
    
    # deselect last 
    collection[selected].selected = false


proc nextField*(v: Widget) =
    let widget = stepField(v, Forward, Widget)
    setEditChild(widget)


proc nextTextField*(v: Widget) =
    let widget = stepField(v, Forward, TextField)
    setEditChild(widget)


proc previousField*(v: Widget) =
    let widget = stepField(v, Backward, Widget)
    setEditChild(widget)


proc toFirstEditField*(v: Widget) =
    var (collected, _) = collectChilds(v, TextField)
    if collected.len > 0:
        setEditChild(collected[0])


proc toLastEditField*(v: Widget) =
    var (collected, _) = collectChilds(v, TextField)  
    if collected.len > 0:
        setEditChild(collected[^1])


proc setValue*(v: Widget, id: string, value: string) =
    if v.isNil: raise newException(ValueError, "First parameter is nil")

    var (collected, _) = collectChilds(v)        
    for child in collected:
        if child.id == id:
            if child of TextField:
                TextField(child).value = value
                return
            elif child of ListBox:
                var lb = ListBox(child)
                lb.provider.selected = value
                lb.pageHome()
                return
            elif child of Label:
                Label(child).name = value

    echo "No child with id ", id, " found!"


proc getValue*(v: Widget, id: string): string =
    var (collected, _) = collectChilds(v)
    for child in collected:
        if child.id == id:
            if child of TextField:
                return TextField(child).value
            if child of ListBox:
                return ListBox(child).provider.selected
        if child of Grid:
            return getValue(child, id)

    echo "No child with id ", id, " found!"


proc processButton*(btn: var Button) =
    if texalotEvent of KeyEvent:
        let ke = KeyEvent(texalotEvent)        
        if ke.key == EVENT_KEY_ENTER:
            if btn.action != nil and btn.action.onAction != nil:
                btn.selected = false
                btn.action.onAction(btn.action.view)
        elif ke.key == EVENT_KEY_TAB:
            btn.parent.nextField()
    elif texalotEvent of MouseEvent:
        let ev = MouseEvent(texalotEvent)
        if ev.key == EVENT_MOUSE_RELEASE:
            btn.parent.updateField()
            if modal and not btn.parent.modal: return # ignore click events on nonmodal views
            let enabled = if btn.action != nil and btn.action.isEnabled != nil: btn.action.isEnabled() else: true
            if enabled:
                if btn.action != nil and btn.action.onAction != nil:
                    if btn.action.view != nil:
                        btn.selected = false
                        btn.action.onAction(btn.action.view)
                    else:
                        raise newException(ValueError, "'view' field not set on Action")


proc processTextField*(v: var Widget, t: var TextField) =
    if texalotEvent of KeyEvent:
        if (v.editChild.isNil) or not (v.editChild of TextField): return
        if not t.editable: return

        var nr: seq[Rune]
        var runes = t.value.toRunes()

        let ke = KeyEvent(texalotEvent)
        case ke.key
        of EVENT_KEY_ARROW_DOWN, EVENT_KEY_TAB:
            v.updateField()
            v.nextField()
            return
        of EVENT_KEY_ENTER:
            v.updateField()
            v.nextTextField()
            return
        of EVENT_KEY_ARROW_UP:
            v.updateField()
            v.previousField()
            return
        of EVENT_KEY_PGDN:
            v.updateField()
            v.toLastEditField()
            return
        of EVENT_KEY_PGUP:
            v.updateField()
            v.toFirstEditField()
            return
        of EVENT_KEY_DELETE:
            if runes.len <= 1: 
                t.value = ""
                v.editX = 0
            elif runes.len - 1 > 0:
                nr.add(runes[0..v.editX-1])
                if v.editX < runes.len-1:
                    nr.add(runes[v.editX+1..^1])
                t.value = $nr
                if v.editX > nr.len-1:
                    v.editX = nr.len-1
        of EVENT_KEY_BACKSPACE:
            if runes.len <= 1: 
                t.value = ""
                v.editX = 0
            elif runes.len - 1 > 0:
                if v.editX > 0:
                    dec v.editX
                    nr.add(runes[0..v.editX-1])
                    nr.add(runes[v.editX+1..^1])
                    t.value = $nr
        of EVENT_KEY_ARROW_RIGHT:
            if v.editX < runes.len and v.editX < t.len-1: inc v.editX
        of EVENT_KEY_ARROW_LEFT:
            if v.editX > 0: dec v.editX
        of EVENT_KEY_END:
            v.editX = runes.len
            if v.editX > t.len-1: v.editX = t.len-1
        of EVENT_KEY_HOME:
            v.editX = 0
        of EVENT_KEY_INSERT:
            v.insert = not v.insert
        else:
            if v.insert:
                if runes.len == t.len:
                    nr.add(runes[0..v.editX-1])
                    nr.add(ke.str.toRunes())
                    t.value = $nr
                    return

                if v.editX <= runes.len - 1:
                    if v.editX == 0:
                        nr.add(ke.str.toRunes())
                        nr.add(runes)
                        t.value = $nr
                        inc v.editX
                    else:
                        if v.editX < t.len:
                            nr.add(runes[0..v.editX-1])
                            nr.add(ke.str.toRunes())
                            nr.add(runes[v.editX..^1])
                            t.value = $nr
                            inc v.editX
                else:
                    nr.add(runes)
                    nr.add(ke.str.toRunes())
                    if nr.len <= t.len:
                        t.value = $nr
                        inc v.editX
                v.editX = min(v.editX, t.len - 1)
            else: # not f.insert
                if v.editX <= t.len - 1:
                    nr.add(runes[0..v.editX-1])
                    nr.add(ke.str.toRunes())
                    if v.editX < t.value.toRunes().len:
                        nr.add(runes[v.editX+1..^1])
                    t.value = $nr
                    inc v.editX


proc lineSelect*(lb: var ListBox) =
    lb.mouseX = 0
    if lb.mouseY >= 0 and lb.mouseY < lb.height:
        if lb.mouseY >= lb.lines.len: lb.mouseY = lb.lines.len - 1
        lb.provider.selected = lb.lines[lb.mouseY]
    else:
        lb.provider.selected = ""

    if lb.selectionChanged != nil:
        lb.selectionChanged(lb.provider.selected)


proc processListBox(v: var Widget, lb: var ListBox) =
    if texalotEvent of KeyEvent:
        let ke = KeyEvent(texalotEvent)
        case ke.key
        of EVENT_KEY_PGUP, EVENT_KEY_BACKSPACE:
            pageUp(lb)
        of EVENT_KEY_PGDN, EVENT_KEY_SPACE:
            pageDown(lb)
        of EVENT_KEY_ARROW_DOWN:
            lineDown(lb)
        of EVENT_KEY_ARROW_UP:
            lineUp(lb)    
        of EVENT_KEY_ARROW_LEFT:
            dec(lb.mouseX, 10)
            if lb.mouseX < 0: lb.mouseX = 0
        of EVENT_KEY_ARROW_RIGHT:
            inc(lb.mouseX, 10)
            if lb.mouseX > lb.lines[lb.mouseY].len: lb.mouseX = lb.lines[lb.mouseY].len
        of EVENT_KEY_HOME:
            pageHome(lb)
        of EVENT_KEY_END:
            pageEnd(lb)
        of EVENT_KEY_ENTER:
            lineSelect(lb)
        of EVENT_KEY_TAB:
            v.updateField()
            v.nextField()
        else: discard
    elif texalotEvent of MouseEvent:
        let ev = MouseEvent(texalotEvent)
        case ev.key
        of EVENT_MOUSE_RELEASE:
            let refw = if lb.parent of Grid: lb.parent else: lb
            let (_, y) = mouseToOffset(refw, ev)
            lb.mouseY = max(y - 1, 0)
            lineSelect(lb)
        of EVENT_MOUSE_WHEEL_UP:
            lineUp(lb)
        of EVENT_MOUSE_WHEEL_DOWN:
            lineDown(lb)
        else: discard


proc updateFocus*() =
    var v: Widget = nil
    for view in views:
        if view.focus:
            v = view
            break
    if v.isNil: return # no focused view found
    
    if v.action != nil and v.action.onFocus != nil:
        v.action.onFocus(v)

    # Check for MouseMove that changed focus of buttons only
    if texalotEvent of MouseEvent:
        let ev = MouseEvent(texalotEvent)
        if ev.key == EVENT_MOUSE_MOVE:
            deselectButton(v)
            let w = findChild(v, ev)
            if w != nil and w of Button:
                selectButton(w)
        elif ev.key == EVENT_MOUSE_RELEASE:
            v.updateField()
            if modal and not v.modal: return # ignore click events on nonmodal views
            var child = findChild(v, ev)
            v.editChild = child
            if child == nil: return
            if child of TextField and not child.editable: return
            selectChild(child)

            if child of TextField:
                let tf = TextField(child)
                if not tf.editable: return
                let runes = tf.value.toRunes()
                let (x, _) = mouseToOffset(v, ev)
                v.editX = x - tf.name.len
                if v.editX < 0: v.editX = 0
                if v.editX > runes.len: v.editX = runes.len


proc setFocus*(view: Widget) =
    # Check for modal view
    for v in views.mitems:
        if v.modal:
            v.focus = true
        else:
            v.focus = false

    if not modal: # change focus only if no modal view exists
        for v in views.mitems:
            if v.id == view.id: 
                v.focus = true


proc setFocus*(view: Widget, id: string) =
    setFocus(view)
    var found = false
    var (collected, _) = collectChilds(view)
    for child in collected:
        if child.id == id:
            selectChild(child)
            found = true
            break
    if not found:
        raise newException(ValueError, "No widget with id '" & id & "' found")

proc removeView*(id: string) =
    if id.isEmptyOrWhitespace: raise newException(ValueError, "'id' must be set to find View")    
    for idx, view in views:
        if view.id == id:
            views.del(idx)
            break
    if views.len > 0:
        setFocus(views[0])

proc processBaseEvents*(v: var Widget) =
    if texalotEvent of ResizeEvent:
        # resize events only valid for View's (not subdialogs)
        for view in views:
            if not (view of View): return
            view.height = getTerminalHeight()
            view.width = getTerminalWidth()
            let (collected, _) = collectChilds(view)
            # reset all aligned widgets
            for child in collected:
                if child.align != NONE:
                    child.x = 0
                    child.y = 0
            # recalculate xy for aligned widgets
            for child in collected:
                calculateXY(child)
    elif texalotEvent of MouseEvent:
        let ev = MouseEvent(texalotEvent)
        var child = findChild(v, ev)
        if child != nil:
            if child of ListBox:
                processListBox(v, ListBox(child))
            elif child of TextField:
                processTextField(v, TextField(child))
            elif child of Button:
                processButton(Button(child))
        else:
            case ev.key
            of EVENT_MOUSE_MOVE:
                for v in views.mitems:
                    if mouseInView(v, ev):
                        v.mouseX = ev.x
                        v.mouseY = ev.y
                        setFocus(v)
            else: discard

    elif texalotEvent of KeyEvent:
        let ke = KeyEvent(texalotEvent)
        # First, general Navigation for all field types
        case ke.key
        of EVENT_KEY_ESC:
            if modal: removeView(v.id)
            else: onExit()
        else: discard
                
        # Type specific event handlers
        var selectedChild = getSelectedChild(v)
        if selectedChild != nil:
            if selectedChild of ListBox:
                processListBox(v, ListBox(selectedChild))
            elif selectedChild of TextField:
                processTextField(v, TextField(selectedChild))
            elif selectedChild of Button:
                processButton(Button(selectedChild))


proc deleteChild*(w: Widget):int =
    if w != nil:
        result = w.parent.childs.find(w)
        if result != -1:
            w.parent.childs.del(result)


proc clearFields*(v: Widget) =
    for child in v.childs:
        if child of TextField:
            TextField(child).value = ""


proc drawFrame*(v: Widget, bxch: array[6, string]) =
    # TOP_LEFT_CORNER = bxch[0]
    # TOP_RIGHT_CORNER = bxch[1]
    # HORIZONTAL = bxch[2]
    # VERTICAL = bxch[3]
    # BOT_LEFT_CORNER = bxch[4]
    # BOT_RIGHT_CORNER = bxch[5]
    if v.width < 3 or v.height < 3: return

    let x2 = v.x + v.width
    let y2 = v.y + v.height
    var (bg, fg, charstyle) = (v.textstyle.bg, v.textstyle.fg, v.textstyle.style)
    if modal and not v.modal:
        bg = MODAL.bg
        fg = MODAL.fg
        charstyle = MODAL.style

    drawRectangle(v.x, v.y, x2, y2, bg, fg, v.ch, charstyle) 
    let width = x2 - v.x - 2
    
    # draw focus frame around
    if v.focus:
        fg = if v.modal: FRAME_FOCUS_MODAL.fg else: FRAME_FOCUS.fg
    if v.frame > 0:
        if v.name.len > 0:
            let rept = max(0, width - v.name.len - 2)
            drawText(bxch[0] & " ", v.x, v.y, bg, fg, charstyle)
            drawText(v.name & " ", v.x+2, v.y, TEXT)
            drawText(repeat(bxch[2], rept) & bxch[1], v.x+3+v.name.len, v.y, bg, fg, charstyle)
        else:
            drawText(bxch[0] & repeat(bxch[2], width) & bxch[1], v.x, v.y, bg, fg, charstyle)
        drawText(bxch[4] & repeat(bxch[2], width) & bxch[5], v.x, v.y + v.height - 1, bg, fg, charstyle)
        for y in v.y + 1..v.y + v.height - v.frame - 1:
            drawText(bxch[3], v.x, y, bg, fg, charstyle)
            drawText(bxch[3], x2-1, y, bg, fg, charstyle)


proc drawOuterFrame*(v: var Widget) =
    drawFrame(v, BOX_CHARS_FRAME)


proc editTextField*(v: Widget) =
    # Is a textfield selected?
    if v.focus and v.editChild != nil and v.editChild of TextField and v.editChild.selected:
        let txt = TextField(v.editChild)
        #let (x,y) = offset(v, txt.x, txt.y)
        let (x,y) = offset(v, txt)
        # display field for editing
        var cursorStyle = if v.insert: FIELD_FOCUS_INSERT else: FIELD_FOCUS
        if not txt.editable: cursorStyle = DEFAULT
        if modal and txt.parent.modal == false: cursorStyle = MODAL
     
        drawText(txt.value, x + txt.name.len, y, cursorStyle)
        let rpt = txt.len - txt.value.toRunes().len
        if rpt > 0: drawText(repeat(FILLER, rpt), cursorStyle)

        # Draw cursor reverse
        let charAtX = getChar(x + txt.name.len + v.editX, y)
        if cursorOn: cursorStyle = TEXT_CURSOR
        if modal and txt.parent.modal == false: cursorStyle = MODAL
        drawChar(charAtX, cursorStyle)


proc drawLabel(t: Label, style: TextStyle) =
    #let (x,y) = offset(t.parent, t.x, t.y)
    let (x,y) = offset(t.parent, t)
    var stl = if t.textstyle != DEFAULT: t.textstyle else: style
    if modal and t.parent.modal == false: stl = MODAL
    drawText(t.name, x, y, stl)


proc drawTextField(t: TextField, style: TextStyle) =
    #let (x,y) = offset(t.parent, t.x, t.y)
    let (x,y) = offset(t.parent, t)
    var stl = if t.textstyle != DEFAULT: t.textstyle else: style
    if modal and t.parent.modal == false: stl = MODAL
    drawText(t.name, x, y, stl)
    stl = FAINT
    if modal and t.parent.modal == false: stl = MODAL
    if t.editable:
        drawText(repeat(FILLER, t.len), x + t.name.toRunes().len, y, stl)
    stl = TEXT_VALUE
    if modal and t.parent.modal == false: stl = MODAL
    drawText(t.value, x + t.name.len, y, stl)
    if t.editable: editTextField(t.parent)


proc drawButton*(btn: Button) =
    let bxch = BTN_BOX_CHARS_FRAME
    var x,y: int
    if btn.align == NONE:
        (x,y) = offset(btn)
    else:
        (x,y) = (btn.x, btn.y)
    #let (x, y) = (btn.x, btn.y)
    let x2 = x + btn.name.len
    let width = btn.name.len

    let enabled = if btn.action != nil and btn.action.isEnabled != nil: btn.action.isEnabled() else: true
    var style = if enabled: BTN_TEXT else: FAINT
    if modal and btn.parent.modal == false:
        style = MODAL

    if btn.frame > 0:
        # Draw box around
        drawText(bxch[0] & repeat(bxch[2], width) & bxch[1], x, y, FAINT)
        drawText(bxch[4] & repeat(bxch[2], width) & bxch[5], x, y+2, FAINT)
        drawText(bxch[3], x, y+1, FAINT)
        drawText(bxch[3], x2+1, y+1, FAINT)

    # Draw Text
    let styleTxt = if enabled and btn.selected: BTN_FOCUS else: style
    drawText(btn.name, x+btn.frame, y+btn.frame, styleTxt)


proc drawListBox(lb: var ListBox, style: TextStyle = TEXT) =
    let stl = if lb.textstyle != DEFAULT: lb.textstyle else: style
    let bxch = BTN_BOX_CHARS_FRAME
    let (x, y) = offset(lb.parent, lb)
    #let (x, y) = offset(lb.parent, lb.x, lb.y)
    let x2 = x + lb.width
    let y2 = y + lb.height + lb.frame
    var style = if not lb.enabled: FAINT else: style
    if modal and lb.parent.modal == false:
        style = MODAL

    if lb.frame > 0:
        # Draw box around
        drawText(bxch[0] & repeat(bxch[2], lb.width) & bxch[1], x, y, FAINT)
        drawText(bxch[4] & repeat(bxch[2], lb.width) & bxch[5], x, y2, FAINT)
        for y in y + 1..y2-1:
            drawText(bxch[3], x, y, FAINT)
            drawText(bxch[3], x2+1, y, FAINT)

    # We must have a DataProvider, ask and paint
    (lb.lines, lb.more) = lb.provider.callback(lb.provider, lb.page, lb.height)
    if lb.lines.len == 0 and lb.page > 0: dec lb.page
    # calculate max linelength
    var maxLength = 0
    for txt in lb.lines:
        maxLength = max(maxLength, txt.len)
    if maxLength < lb.width:
        lb.mouseX = 0
    let posx = max(0, lb.mouseX)
    for line, txt in lb.lines:
        var lineLength = max(lb.mouseX, (min(txt.len, lb.mouseX + lb.width - 1)))
        if lineLength > txt.len - 1: lineLength = txt.len - 1
        if posx < lineLength:
            drawText(txt[posx..lineLength], x+lb.frame, y+lb.frame+line, style)
    if lb.lines.len > 0:
        var linestyle = if lb.selected: FIELD_FOCUS else: TEXT
        if modal and lb.parent.modal == false:
            linestyle = MODAL
        
        if lb.mouseY < lb.lines.len:
            let line = lb.lines[lb.mouseY]
            var lineLength = max(lb.mouseX, (min(line.len, lb.mouseX + lb.width - 1)))
            if lineLength > line.len - 1: lineLength = line.len - 1
            drawText(line[posx..lineLength], x+lb.frame, y+lb.frame+lb.mouseY, linestyle)
    # Draw arrows (next/prev page)
    if lb.page > 0:
        drawText("\u2191", x + lb.width-1, y2, style)
    if lb.more: 
        drawText("\u2193", x + lb.width, y2, style)

proc drawGrid(g: Grid) =
    let parent = g.parent
    for child in g.childs:
        if child of TextField:
            drawTextField(TextField(child), g.textstyle)
        elif child of Button:
            drawButton(Button(child))
        elif child of ListBox:
            var lb = ListBox(child)
            drawListBox(lb, g.textstyle)
        elif child of Label:
            drawLabel(Label(child), g.textstyle)
        else: discard


proc drawChilds(v: var Widget) =
    var 
        allowDrop = true
        style: TextStyle

    if v.dragChild != nil and v.dragChild of TextField:
        v.allowDrop = allowDrop(TextField(v.dragChild))

    for num, child in v.childs:
        style = TEXT
        if child == v.dragChild and v.dragging:
                if not v.allowDrop: style = TEXT_NODROP
                elif child == v.dragChild: style = TEXT_MOVING
        elif child.selected:
            style = TEXT_SELECTED

        if modal and child.parent.modal == false:
            style = FAINT

        if child of TextField:
            drawTextField(TextField(child), style)
        elif child of Label:
            drawLabel(Label(child), style)
        elif child of Button:
            drawButton(Button(child))
        elif child of ListBox:
            var lb = ListBox(child)
            drawListBox(lb)
        elif child of Grid:
            drawGrid(Grid(child))


proc drawViews*() =
    for v in views.mitems:
        if v.visible:
            drawOuterFrame(v)
            drawChilds(v)


proc enterEditLoop*() =
    cursorOn = true
    # Initial drawing
    updateFocus()
    # set focus on first editfield
    var v = getFocus() # view!
    #toFirstEditField(v)
    processBaseEvents(v)
    drawViews()
    texalotRender()

    while true:
        let event = updateTextalot()
        if event of NoneEvent: 
            # Trigger gui update when state changes
            if cursorOn != event.cursorOn:
                cursorOn = event.cursorOn
            else:
                os.sleep(2)
                continue

        # select view and handle events
        updateFocus()
        v = getFocus()
        processBaseEvents(v)

        # Update state(s)
        modal = isModal()

        # Update UI
        drawViews()
        texalotRender()


# --------------
# Providers
# --------------
# proc getProviderData(page: int, pagesize: int, data: seq[string]): (seq[string], bool) =
#     var lower = page*pagesize
#     if lower >= data.len: return
#     var upper = lower + pagesize
#     if upper > data.len: upper = data.len
#     elif data.len < upper: upper = data.len
#     let more = upper < data.len
#     return (data[lower..<upper], more)

#   proc walk(path: string): seq[string] =
#     for kind, path in walkDir(path):
#         case kind:
#         of pcFile, pcLinkToFile:
#             result.add(path)
#         of pcDir, pcLinkToDir:
#             result.add(walk(path))

# const dirProviderCallback = proc(provider: var DataProvider, page: int, pagesize: int): (seq[string], bool) =
#     provider.lines = walk(".")
#     getProviderData(page, pagesize, provider.lines)

# const fileProviderCallback = proc(provider: var DataProvider, page: int, pagesize: int): (seq[string], bool) =
#     if provider.selected.len > 0 and provider.selected != provider.selectedBefore:
#         if fileExists(provider.selected):
#             provider.lines = split(readFile(provider.selected), "\n")
#             provider.selectedBefore = provider.selected
#     return getProviderData(page, pagesize, provider.lines)

# const stringProviderCallback = proc(provider: var DataProvider, page: int, pagesize: int): (seq[string], bool) =
#     return getProviderData(page, pagesize, @["Hello", "World", "aaaaa", "bbbbbb", "ccccccc", "dddddddd", "eeeeeee", "ffffff", "Hello2", "World2", "2aaaaa", "2bbbbbb", "2ccccccc", "2dddddddd", "2eeeeeee", "2ffffff"])
#
# var dirProvider = DataProvider(callback: dirProviderCallback)
# var fileProvider = DataProvider(callback: fileProviderCallback)
# var stringProvider = DataProvider(callback: stringProviderCallback)
