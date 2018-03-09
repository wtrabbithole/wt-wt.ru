tostring_r <- require("std/string.nut").tostring_r
vlog_r <- function(val, maxdeeplevel=null) {
  local out = tostring_r(val, " ", maxdeeplevel)
  vlog(out.slice(0,min(out.len(),200)))
}
print_r <- function(val, maxdeeplevel=null) {
  print(tostring_r(val," ", maxdeeplevel) + "\n")
}
dlog <- function(val, maxdeeplevel=null) { vlog_r(val, maxdeeplevel); print_r(val, maxdeeplevel) }

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
    else
      return false
  }
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
  return sh((::math.floor(pixels) + 0.5) * 100.0 / 1080.0)
}


function deep_clone(source) {
  local complex_types = ["table", "array", "instance"]
  if (complex_types.find(::type(source)) == null)
    return source

  local deep_clone_unsafe = function(source) {
    local result = clone source
    foreach (attr, value in result)
      if (complex_types.find(::type(value)) != null)
        result[attr] = callee()(value)
    return result
  }

  return deep_clone_unsafe(source)
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


function deep_compare(a, b, params = {ignore_keys = [], compare_only_keys = []}) {
  local compare_only_keys = []
  if (params.rawin("compare_only_keys")) {
    compare_only_keys = params.compare_only_keys
  }
  local ignore_keys = []
  if (params.rawin("ignore_keys"))
    ignore_keys = params.ignore_keys

  if (::type(a) != ::type(b)) {
    return false
  }
  if (::type(a) == "integer" || ::type(a) == "float" ||
    ::type(a) == "bool" || ::type(a) == "string") {
    return a == b
  }
  if (::type(a) == "array") {
    if (a.len() != b.len()) {
      return false
    }
    foreach (idx, val in a) {
      if (!deep_compare(val, b[idx], params)) {
        return false
      }
    }
  } else if (::type(a) == "table" || ::type(a) == "class") {
    if (a.len() != b.len()) {
      return false
    }
    foreach (key, val in a) {
      if (!b.rawin(key)) {
        return false
      }
      if (compare_only_keys.len() > 0) {
        if (compare_only_keys.find(key) > -1 && !deep_compare(val, b[key], params)) {
          return false
        }
      } else if (!deep_compare(val, b[key], params) && ignore_keys.find(key) < 0) {
        return false
      }
    }
  }
  return true
}

/*
function tests() {
  local a = [
    {a = 1}
    {a = 1 b = [1 2]}
    2,
    null,
    [1 2],
    [1, {c = 3}],
    [1, [2 3], 4],
    {a = 1 b = {c = 2 d = [ 1 2 ]}},
    {a = 1 b = null},
    [null null null],
    true,
    @() true,
    [1 @() true],
    {a = 1 b = @() true}
  ]
//  a = [{a = 1 b = 2 c = null d = [1 2] e = @() true}]
  foreach (idx, i in a) {
    print (tostring_r(i))
  }
}
tests()
*/
