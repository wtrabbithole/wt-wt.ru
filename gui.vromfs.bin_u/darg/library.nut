local string = require("string")
local s = require("std/string.nut")
local math = require("math")
::tostring_r <- s.tostring_r
local dagorMath = require("dagor.math")

local tostringfuncTbl = [
  {
    compare = @(val) val instanceof Watched
    tostring = @(val) "Watched: " + ::tostring_r(val.value,{maxdeeplevel = 3, splitlines=false})
  }
  {
    compare = @(val) val instanceof dagorMath.Point3
    tostring = function(val){
      return "Point3: {x}, {y}, {z}".subst({x=val.x, y=val.y, z=val.z})
    }
  }
  {
    compare = @(val) val instanceof dagorMath.Point2
    tostring = function(val){
      return "Point2: {x}, {y}".subst({x=val.x, y=val.y})
    }
  }
  {
    compare = @(val) val instanceof dagorMath.TMatrix
    tostring = function(val){
      local o = []
      for (local i=0; i<4;i++)
        o.append("[{x}, {y}, {z}]".subst({x=val[i].x,y=val[i].y, z=val[i].z}))
      o = s.join(o, " ")
      return "TMatix: [" + o +"]"
    }
  }
]

local log = require("std/log.nut")(tostringfuncTbl)

::dlog <- log.dlog
::log <- log
::dlogsplit <- log.dlogsplit
::vlog <- log.vlog
::console_print <- log.console_print

function make_persists(val){
  assert(type(val)=="table", "not a table value passed!")
//  local ret = {}
  foreach (k,v in val)
    val[k]<-persist(k, @() v)
  return val
}

function isDargComponent(comp) {
//better to have natived daRg function to check if it is valid component!
  local c = comp
  if (::type(c) == "function") {
    local info = c.getfuncinfos()
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
  this function returns new array that is combination of two arrays, or extended arrays
  is safe wrapper to array.extend(). Can handle obj and val of any type.
  this is really helpful when manipulating behaviours\chlidren\watch, that can be null, array, class, table, function or instance
*/
function extend_to_array (obj, val, skipNulls=true) {
  local isObjArray = ::type(obj) == "array"
  local isValArray = ::type(val) == "array"
  
  if (obj == null && val == null && skipNulls)
    return []
  if (obj == null && skipNulls)
    return (isValArray) ? clone val : [val]
  if (val == null && skipNulls)
    return (isObjArray) ? obj : [obj]
  local obj_ = (isObjArray) ? clone obj : [obj]
  if (isValArray)
    obj_.extend(val)
  else
    obj_.append(val)

  return obj_
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


::NamedColor <-{
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
  return sh(100.0 * pixels / 1080)
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

local wrapParams= {width=0, flowElemProto={}, hGap=null, vGap=0, height=null, flow=FLOW_HORIZONTAL}
function wrap(elems, params=wrapParams) {
  //TODO: move this to native code
  local paddingLeft=params?.paddingLeft
  local paddingRight=params?.paddingRight
  local paddingTop=params?.paddingTop
  local paddingBottom=params?.paddingBottom
  local flow = params?.flow ?? FLOW_HORIZONTAL
  assert([FLOW_HORIZONTAL, FLOW_VERTICAL].find(flow)!=null, "flow should be FLOW_VERTICAL or FLOW_HORIZONTAL")
  local isFlowHor = flow==FLOW_HORIZONTAL
  local height = params?.height ?? SIZE_TO_CONTENT
  local width = params?.width ?? SIZE_TO_CONTENT
  local dimensionLim = isFlowHor ? width : height
  local secondaryDimensionLim = isFlowHor ? height : width
  assert(["array"].find(type(elems))!=null, "elems should be array")
  assert(["float","integer"].find(type(dimensionLim))!=null, "can't flow over {0} non numeric type".subst(isFlowHor ? "width" :"height"))
  local hgap = params?.hGap ?? wrapParams?.hGap
  local vgap = params?.vGap ?? wrapParams?.vGap
  local gap = isFlowHor ? hgap : vgap
  local secondaryGap = isFlowHor ? vgap : hgap
  if (["float","integer"].find(type(gap)) !=null)
    gap = isFlowHor ? {size=[gap,0]} : {size=[0,gap]}
  gap = gap ?? 0
  local flowElemProto = params?.flowElemProto ?? {}
  local flowSizeIdx = isFlowHor ? 0 : 1
  local secondaryFlowSizeIdx = isFlowHor ? 1 : 0
  local flowElems = []
  if (paddingTop && isFlowHor)
    flowElems.append(paddingTop)
  if (paddingLeft && !isFlowHor)
    flowElems.append(paddingLeft)
  local ret = {}
  local tail = elems
  local function buildFlowElem(elems, gap, flowElemProto, dimensionLim) {
    local children = []
    local curwidth=0.0
    local tailidx = 0
    foreach (i, elem in elems) {
      local esize = calc_comp_size(elem)[flowSizeIdx]
      local gapsize = isDargComponent(gap) ? calc_comp_size(gap)[flowSizeIdx] : gap
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
    flowElems.append(paddingBottom)
  if (paddingLeft && !isFlowHor)
    flowElems.append(paddingRight)
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

  local deep_compare = ::callee()

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


function dump_observables() {
  local list = ::gui_scene.getAllObservables()
  ::print("{0} observables:".subst(list.len()))
  foreach (obs in list)
    ::print(tostring_r(obs))
}

function mul_color(color, mult) {
  return Color(min(255, ((color >> 16) & 0xff) * mult),
               min(255, ((color >>  8) & 0xff) * mult),
               min(255, (color & 0xff) * mult),
               min(255, ((color >> 24) & 0xff) * mult))
}
