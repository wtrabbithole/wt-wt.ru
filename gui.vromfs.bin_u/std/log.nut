local dagorDebug = require("dagor.debug")
local string = require("string.nut")
local tostring_r = string.tostring_r
local implode = string.implode //like join, but skip emptylines
local join = string.join //like join, but skip emptylines

local function print_(val, separator="\n"){
  print(val+separator)
}

local function Log(tostringfunc=null) {
  local function vlog(...){
    local out = ""
    if (vargv.len()==1)
      out += tostring_r(vargv[0],{splitlines=false, compact=true, maxdeeplevel=4, tostringfunc=tostringfunc})
    else
      out = join(vargv.map(@(val) tostring_r(val,{splitlines=false, compact=true, maxdeeplevel=4, tostringfunc=tostringfunc}))," ")
    dagorDebug.screenlog(out.slice(0,min(out.len(),200)))
  }

  local function log(...) {
    if (vargv.len()==1)
      print_(tostring_r(vargv[0],{compact=true, maxdeeplevel=4 tostringfunc=tostringfunc}))
    else
      foreach (a in vargv)
        print_(tostring_r(a,{compact=true, maxdeeplevel=4 tostringfunc=tostringfunc})," ")
  }

  local function dlog(...) {
    vlog.acall([this].extend(vargv))
    log.acall([this].extend(vargv))
  }

  local function dlogsplit(...) {
    log.acall([this].extend(vargv))
    if (vargv.len()==1)
      vargv=vargv[0]
    local out = tostring_r(vargv,{tostringfunc=tostringfunc})
    local s = string.split(out,"\n")
    for (local i=0; i < min(80,s.len()); i++) {
      dagorDebug.screenlog(s[i])
    }
  }
  local function debugTableData(value, params={recursionLevel=3, addStr="", printFn=null, silentMode=true}){
    local addStr = params?.addStr ?? ""
    local silentMode = params?.silentMode ?? true
    local recursionLevel = params?.recursionLevel ?? 3
    local printFn = params?.printFn ?? print
    local prefix = silentMode ? "" : "DD: "

    local newline = "\n"+prefix+addStr
    local maxdeeplevel = recursionLevel+1

    if (addStr=="" && !silentMode)
      printFn("DD: START")
    printFn(tostring_r(value,{compact=false, maxdeeplevel=maxdeeplevel, newline=newline, showArrIdx=false, tostringfunc=tostringfunc}))
  }

  local function console_print(data,params={}) {
    debugTableData(data, params.__merge({printFn=dagorDebug.console_print}))
  }

  return {
    vlog = vlog
    v = vlog
    log = log
    dlog = dlog
    d = dlog
    dlogsplit = dlogsplit
    debugTableData = debugTableData
    console_print = console_print
    //lowlevel dagor functions
    debug = dagorDebug.debug
    logerr = dagorDebug.logerr
    screenlog = dagorDebug.screenlog
  }.setdelegate({_call = @(...) log.acall(vargv)}) //now it is callable
}

return Log
