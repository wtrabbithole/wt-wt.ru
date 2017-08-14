function max(a,b) {
  return a>b ? a : b
}


function min(a,b) {
  return a<b ? a : b
}


function clamp(x, lo, hi) {
  if (x < lo)
    return lo
  if (x > hi)
    return hi
  return x
}


function with_table(tbl, func) {
  local roottbl = ::getroottable()
  local accessor = class{
    _get = @(field) tbl.get(field) || roottbl[field]
    _set = @(field, val) tbl[field] <- val
  }()

  func.bindenv(accessor)()

  return tbl
}


function watchElemState(builder) {
  local stateFlags = ::Watched(0)
  return function() {
    local desc = builder(stateFlags.value)
    local watch = desc.__get("watch") || []
    if (type(watch) != "array")
      watch = [watch]
    watch.append(stateFlags)
    desc.watch <- watch
    desc.onElemState <- @(sf) stateFlags.update(sf)
    return desc
  }
}


function hdpx(pixels) {
  return sh((::math.floor(pixels)+0.5)*100.0/1080.0)
}

/* 
  defensive function - try to not to fail in all ways (for example for data driven function)
  insert elemnt in array even if index is out of range - just at the end
*/
function safe_insert(array, index, value) {
  if (index < 0)
    index = array.len() + index
  if (array.len() < index)
    index = array.len()
  array.insert(index, value)
}

/*
  defensive function - try to not to fail in all ways (for example for data driven function)
  you can insert array in a certain index of another array safely
*/

function insert_array(array, index, value) {
  if (index < 0)
    index = array.len() + index
  if (index > array.len()) {
    index = array.len()
  }
  if (index == array.len()) {
    array.extend(value)
    return
  } else {
    local prev_len = array.len()
    local head_len = index
    local add_elems = value.len()
    local tail = array.slice(index)
    array.resize(prev_len + add_elems)
    foreach (idx, val in array) {
      if (idx >= head_len && idx < head_len + add_elems)
        array[idx] = value[idx-head_len]
      if (idx >= head_len + add_elems)
        array[idx]=tail[idx-head_len - add_elems]
    }
    return
  }
}
function tostring_any(input) {
  if (type(input) != "userdata"){
    return input.tostring()
  }
  else
    return "#USERDATA#"
}

function tostring_r(input, indent = "  ") {
  local out = ""
  
  local table_types = ["class","table","instance"]
  local simple_types = ["string", "float", "bool", "integer"]
  local complex_types = ["userdata","weakreference"]
  local function_types = ["function", "generator", "thread"]
  local rawtypes = []
  rawtypes.extend(complex_types)
  rawtypes.extend(simple_types)
  
  function func_tostring(func) {
   local info = func.getinfos()
   local out = ""
   if (!info.native) {
     local params = info.parameters.reduce(@(res,curval) res.tostring() + ", " + curval)
     local fname = "" +info.name
     if (fname.find("(null : 0x0") != null)
       fname = "@"
     out += "(function): " + info.src + ",(" + fname + ") arguments(" +params+ ")"
   } else if (info.native) {
     out += "(nativefunction): " + info.name

   } else {
     out += func.tostring()
   }
     return out
  }

  function sub_tostring_r(input, indent, arrayElem = false, separator = "\n") {
    local out = ""
    foreach (key, value in input ) {
      if (simple_types.find(type(value)) != null && function_types.find(type(value)) != -1) {
        out += separator
        if (!arrayElem) {
           out += indent + tostring_any(key) +  " = "
        }
        out += value.tostring() 
      }
      else if (function_types.find(type(value)) != null && function_types.find(type(value)) != -1) {
        out += separator
        if (!arrayElem) {
           out += indent+ tostring_any(key) +  " = "
        }
        out += func_tostring(value)
      }
      else if (["null"].find(type(value)) != null) {
        out += separator
        if (!arrayElem) {
           out += indent + tostring_any(key) +  " = "
        }
        out += "null"
      }
      else if (type(value) == "array" && function_types.find(type(value)) != -1) {
        out += separator
        if (!arrayElem) {
          out += indent + key.tostring() +  " = " 
        }
        out += "[" + sub_tostring_r(value, indent + "  ", true, " ") + " ]"
      }
      else if (table_types.find(type(value)) != null && table_types.find(type(value)) != -1) {
        out += "\n" + indent 
        if (!arrayElem) {
          out += tostring_any(key) +  " = " 
        }
        out += "{" + sub_tostring_r(value, indent + "  ") + "\n" + indent + "}"
        if (arrayElem)
          out += "\n"
      }
      else {
        out += "\n" + indent 
        if (!arrayElem) {
          tostring_any(key) +  " = " 
        }
        out += tostring_any(value) + "\n"
      }
    }
    return out
  }
  if (table_types.find(type(input)) != null && table_types.find(type(input)) != -1) {
    out += input.tostring() + " { "
    out += sub_tostring_r(input, indent, false,"\n")
    out += "\n}"
  } else if (type(input)=="array"){
    out += input.tostring() + " ["
    out += sub_tostring_r(input, "  ", true, " ")
    if (out.slice(-1) != "\n")
      out += " "
    out += "]"
  } else {
    out += sub_tostring_r([input], "", true, "")
  }
  
  return out +"\n"
}

function deep_compare(a,b, params = {ignore_keys=[], compare_only_keys=[]}) {
  local compare_only_keys = []
  if (params.rawin("compare_only_keys")) {
    compare_only_keys = params.compare_only_keys
  }
  local ignore_keys = []
  if (params.rawin("ignore_keys"))
    ignore_keys = params.ignore_keys

  if (type(a) != type(b)) {
    return false
  }
  if (type(a) =="integer" || type(a) =="float" || type(a) =="bool" || type(a) =="string") {
    return a == b 
  }
  if (type(a) == "array") {
    if (a.len() != b.len()) {
      return false
    }
    foreach (idx, val in a) {
      if (!deep_compare(val,b[idx], params)) {
        return false
      }
    }
  } else if (type(a) == "table" || type(a) == "class") {
    if (a.len() != b.len()) {
      return false
    }
    foreach (key, val in a) {
      if (!b.rawin(key)) {
        return false
      }
      if (compare_only_keys.len()>0) {
        if (compare_only_keys.find(key) > -1 && !deep_compare(val,b[key], params)) {
          return false
        }
      } else if (!deep_compare(val,b[key], params) && ignore_keys.find(key) < 0) {
        return false
      }
    }
  }
  return true
}

/*
function tests() {
  local a = [ 
    {a=1}
    {a=1 b=[1 2]}
    2,
    null,
    [1 2],
    [1, {c=3}],
    [1, [2 3], 4],
    {a = 1 b = {c = 2 d = [ 1 2 ]}},
    {a = 1 b=null},
    [null null null],
    true,
    @() true,
    [1 @() true],
    {a=1 b=@() true}
  ]
//  a = [{a=1 b=2 c =null d = [1 2] e =@() true}]
  foreach (idx, i in a) {
    print (tostring_r(i))
  }
}
tests()
*/