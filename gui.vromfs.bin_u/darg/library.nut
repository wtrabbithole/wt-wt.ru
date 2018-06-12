local string = require("string")
local math = require("math")
tostring_r <- require("std/string.nut").tostring_r

local darg_tostring = {
  compare = @(val) ::type(val) == "instance" && val.getclass()==Watched
  tostring = @(val) "Watched: " + tostring_r(val.value,{maxdeeplevel = 3, splitlines=false})
}

local function vlog_r(...){
  local out = ""
  if (vargv.len()==1)
    out += tostring_r(vargv[0],{splitlines=false, compact=true, maxdeeplevel=4 tostringfunc=darg_tostring})
  else
    foreach (a in vargv)
      out+=" " +tostring_r(a,{splitlines=false, compact=true, maxdeeplevel=4 tostringfunc=darg_tostring})
  vlog(out.slice(0,min(out.len(),200)))
}

local function print_r(...) {
  local out = ""
  if (vargv.len()==1)
    print(tostring_r(vargv[0],{compact=true, maxdeeplevel=4 tostringfunc=darg_tostring}) + "\n" + " ")
  else
    foreach (a in vargv)
      print(tostring_r(a,{compact=true, maxdeeplevel=4 tostringfunc=darg_tostring}) + "\n" + " ")
}

dlog <- function(...) { 
  vlog_r.acall([this].extend(vargv))
  print_r.acall([this].extend(vargv))
}

dlogs <- function(...) { 
  print_r.acall([this].extend(vargv))
  if (vargv.len()==1)
    vargv=vargv[0]
  local out = tostring_r(vargv,{tostringfunc=darg_tostring})
  local s = string.split(out,"\n")
  for (local i=0; i < min(50,s.len()); i++) {
    vlog(s[i])
  }
}

function isDargComponent(comp) {
//better to have natived daRg function to check if it is valid component!
  local c = comp
  if (::type(c) == "function") {
    local info = c.getinfos()
    if (info?.parameters && info?.parameters.len() > 1)
      return false
    c = c()
  }
  local c_type = ::type(c)
  if (c_type == "null")
    return true
  if (c_type != "table" && c_type != "class")
    return false
  local knownProps = ["size","rendObj","children","watch","behavior","halign","valign","flow","pos","hplace","vplace"]
  foreach(k,val in c) {
    if (knownProps.find(k) != null)
      return true
  }
  return false
}


function with_table(tbl, func) {
  local roottbl = ::getroottable()
  local accessor = class {
    _get = @(field) tbl?[field] ?? roottbl[field]
    _set = @(field, val) tbl[field] <- val
  }()

  func.bindenv(accessor)()

  return tbl
}

/*
  this function is safe wrapper to array.extend(). Can handle obj and val of any type.
*/
function extend_to_array (obj, val) {
  if (obj != null) {
    obj = (typeof obj == "array") ? obj : [obj]
    if (typeof val == "array") {
      obj.extend(val)
    } else {
      obj.append(val)
    }
    return obj
  } else {
    return typeof val == "array" ? val : [val]
  }
}


/*
//===== DARG specific methods=====
  this function create element that has internal basic stateFlags (S_HOVER S_ACTIVE S_DRAG)
*/
function watchElemState(builder) {
  local stateFlags = ::Watched(0)
  return function() {
    local desc = builder(stateFlags.value)
    local watch = desc.__get("watch") || []
    if (::type(watch) != "array")
      watch = [watch]
    watch.append(stateFlags)
    desc.watch <- watch
    desc.onElemState <- @(sf) stateFlags.update(sf)
    return desc
  }
}


NamedColor <-{
  red = Color(255,0,0)
  blue = Color(0,0,255)
  green = Color(0,255,0)
  magenta = Color(255,0,255)
  yellow = Color(255,255,0)
  cyan = Color(0,255,255)
  gray = Color(128,128,128)
  lightgray = Color(192,192,192)
  darkgray = Color(64,64,64)
  black = Color(0,0,0)
  white = Color(255,255,255)
}

/*
//===== DARG specific methods=====
  this function returns sh() for pixels for fullhd resolution (1080p)
*/
function hdpx(pixels) {
  return sh((math.floor(pixels) + 0.5) * 100.0 / 1080.0)
}


local complex_types = ["table", "array", "instance"]

local function deep_clone_complex(source) {
  local deep_clone_complex = ::callee()
  local result = clone source
  foreach (attr, value in result)
    if (complex_types.find(::type(value)) != null)
      result[attr] = deep_clone_complex(value)
  return result
}

function deep_clone(source) {
  if (complex_types.find(::type(source)) == null)
    return source
  return deep_clone_complex(source)
}


function mergeRecursive(target, source) {
  local mergeRecursive = ::callee()

  local res = clone target
  foreach (key, value in source) {
    if (::type(value) == "table" && key in target) {
      res[key] = mergeRecursive(target[key], value)
    } else {
      res[key] <- source[key]
    }
  }
  return res
}


/*
  defensive function - try to not to fail in all ways (for example for data driven function)
  you can insert array in a certain index of another array safely
*/

function insert_array(array, index, value) {
  if (index < 0)
    index = max(0, array.len() + index)
  if (index > array.len()) {
    index = array.len()
  }
  if (index == array.len()) {
    array.extend(value)
    return
  } else {
    local prev_len = array.len()
    local head_len = index
    local add_elems = (type(value)=="array") ? value.len() : 1
    local tail = array.slice(index)
    array.resize(prev_len + add_elems)
    foreach (idx, val in array) {
      if (idx >= head_len && idx < head_len + add_elems)
        array[idx] = (type(value)=="array") ? value[idx - head_len] : value
      if (idx >= head_len + add_elems)
        array[idx] = tail[idx - head_len - add_elems]
    }
    return
  }
}

local wrapParams= {width=0, flowElemProto={}, hGap=null, vGap=null, height=null, flow=FLOW_HORIZONTAL}
function wrap(elems, params=wrapParams) {
  //TODO: move this to native code
  local paddingLeft=params?.paddingLeft
  local paddingRight=params?.paddingRight
  local paddingTop=params?.paddingTop
  local paddingBottom=params?.paddingBottom
  local flow = params?.flow ?? FLOW_HORIZONTAL
  assert([FLOW_HORIZONTAL, FLOW_VERTICAL].find(flow)!=null, "flow should be correct")
  local isFlowHor = flow==FLOW_HORIZONTAL
  local height = params?.height ?? SIZE_TO_CONTENT
  local width = params?.width ?? SIZE_TO_CONTENT
  local dimensionLim = isFlowHor ? width : height
  local secondaryDimensionLim = isFlowHor ? height : width
  assert(["array"].find(type(elems))!=null, "elems should be array")
  assert(["float","integer"].find(type(dimensionLim))!=null, "can't flow over {0} non numeric type".subst([isFlowHor ? "width" :"height"]))

  local gap = isFlowHor ? params?.hGap : params?.vGap
  local secondaryGap = isFlowHor ? params?.vGap : params?.hGap
  if (["float","integer"].find(type(gap)) !=null)
    gap = isFlowHor ? {size=[gap,0]} : {size=[0,gap]}
  local flowElemProto = params?.flowElemProto ?? {}
  local flowSizeIdx = isFlowHor ? 0 : 1
  local secondaryFlowSizeIdx = isFlowHor ? 1 : 0
  local flowElems = []
  if (paddingTop && isFlowHor)
    flowElem.append(paddingTop)
  if (paddingLeft && !isFlowHor)
    flowElem.append(paddingLeft)
  local ret = {}
  local tail = elems
  function buildFlowElem(elems, gap, flowElemProto, dimensionLim) {
    local children = []
    local curwidth=0.0
    local tailidx = 0
    foreach (i, elem in elems) {
      local esize = calc_comp_size(elem)[flowSizeIdx]
      local gapsize = calc_comp_size(gap)[flowSizeIdx]
      if (i==0 && curwidth + esize < dimensionLim) {
        children.append(elem)
        curwidth = curwidth + esize
        tailidx = i
      }
      else if (curwidth + esize + gapsize < dimensionLim) {
        children.extend([gap, elem])
        curwidth = curwidth + esize + gapsize
        tailidx = i
      }
      else {
        tail = elems.slice(tailidx+1)
        break
      }
      if (i==elems.len()-1)
        tail = []
    }
    flowElems.append(flowElemProto.__merge({children=children flow=isFlowHor ? FLOW_HORIZONTAL : FLOW_VERTICAL size=SIZE_TO_CONTENT}))
  }
  do {
    buildFlowElem(tail,gap,flowElemProto, dimensionLim)
  } while (tail.len()>0)
  if (paddingTop && isFlowHor)
    flowElem.append(paddingBottom)
  if (paddingLeft && !isFlowHor)
    flowElem.append(paddingRight)
  return {flow=isFlowHor ? FLOW_VERTICAL : FLOW_HORIZONTAL gap=secondaryGap children=flowElems halign = params?.halign valign=params?.valign hplace=params?.hplace vplace=params?.vplace size=[width?? SIZE_TO_CONTENT, height ?? SIZE_TO_CONTENT]}
}


function deep_compare(a, b, params = {ignore_keys = [], compare_only_keys = []}) {
  local compare_only_keys = params?.compare_only_keys ?? []
  local ignore_keys = params?.ignore_keys ?? []
  local type_a = ::type(a)
  local type_b = ::type(b)

  if (type_a != type_b)
    return false

  if (type_a == "integer" || type_a == "float" || type_a == "bool" || type_a == "string")
    return a == b

  if (type_a == "array") {
    if (a.len() != b.len())
      return false

    foreach (idx, val in a) {
      if (!deep_compare(val, b[idx], params)) {
        return false
      }
    }
  } else if (type_a == "table" || type_a == "class") {
    if (a.len() != b.len())
      return false

    foreach (key, val in a) {
      if (!b.rawin(key)) {
        return false
      }
      if (compare_only_keys.len() > 0) {
        if (compare_only_keys.find(key)!=null && !deep_compare(val, b[key], params)) {
          return false
        }
      } else if (ignore_keys.find(key)==null && !deep_compare(val, b[key], params)) {
        return false
      }
    }
  }
  return true
}
