//Clones arrays and tables recursively
local recursivetypes =["table","array","class"]
local function isArray(arr){return ::type(arr)=="array"}

local function deep_clone(val){}
deep_clone = function(val){
  if(recursivetypes.find(::type(val)) == null)
    return val
  return val.map(deep_clone)
}


//Updates (mutates) target arrays and tables recursively with source
local function deep_update(target, source){}
deep_update = function(target, source) {
  if ((recursivetypes.find(::type(source)) == null)) {
    target = source
    return target
  }
  if (::type(target)!=::type(source)){
    target = deep_clone(source)
    return target
  }

  if (isArray(source) && target.len() < source.len()){
    target.resize(source.len())
  }
  foreach(k, v in source){
    if (!(k in target)){
      target[k] <- deep_clone(v)
    }
    else if (recursivetypes.find(::type(v)) == null){
      target[k] = v
    }
    else {
      target[k]=deep_update(target[k], v)
    }
  }
  return target
}

//Creates new value from target and source, by merges (mutates) target arrays and tables recursively with source
local function deep_merge(target, source){}
deep_merge = function(target, source){
  local ret = deep_clone(target)
  return deep_update(ret, source)
}

return {
  _clone = deep_clone,
  _update = deep_update,
  _merge = deep_merge
}