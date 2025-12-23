import std/strutils
import texalotbase
import yottadb
import ydbutils


defineSignal(GlobalSelectionChanged, string)

proc getProviderData(page: int, pagesize: int, data: seq[string]): (seq[string], bool) =
    var lower = page*pagesize
    if lower >= data.len: return
    var upper = lower + pagesize
    if upper > data.len: upper = data.len
    elif data.len < upper: upper = data.len
    let more = upper < data.len
    return (data[lower..<upper], more)

# -------- YottaDB Globals Provider ------------
const globalsProviderCallback = proc(provider: var DataProvider, page: int, pagesize: int): (seq[string], bool) =
    if provider.lines.len == 0:
        provider.lines = getGlobals()
        if provider.lines.len > 0:
            provider.selected = provider.lines[0]
            emitGlobalSelectionChanged(provider.lines[0]) # select 1. global
    return getProviderData(page, pagesize, provider.lines)

# -------- YottaDB Global Provider ------------
const globalProviderCallback = proc(provider: var DataProvider, page: int, pagesize: int): (seq[string], bool) =
    if provider.selected.len > 0 and provider.selected != provider.selectedBefore:
        if not provider.selected.startsWith("("):
            provider.lines.setLen(0)
            provider.selectedBefore = provider.selected
            let gbl = provider.selected
            for (k, v) in queryItr @gbl.kv:
                # remove leading ^globalname
                let openPar = k.find('(')
                let value = if v.isEmptyOrWhitespace: "" else: "=" & v
                if openPar != -1:
                    provider.lines.add(k[openPar..^1] & value)
                else:
                    provider.lines.add(k & value)

    return getProviderData(page, pagesize, provider.lines)

var
    YDBGlobals* = DataProvider(callback: globalsProviderCallback)
    YDBGlobal* = DataProvider(callback: globalProviderCallback)
