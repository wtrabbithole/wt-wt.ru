/* this probably should be part of standard library (as well as recursive copy and others)*/

local mergeElements = function(target, source, list_of_ignored_fields=[], list_of_appends=[]) {
  local ret = {}.__update(target)
  if (list_of_ignored_fields.len() + list_of_appends.len() == 0){
    return ret.__update(source)
  }
  
  if (list_of_ignored_fields.len() > 0) {
    local source = {}.__update(source)
    foreach (key in list_of_ignored_fields) {
      source.rawdelete(key)
    }
  }
  
  foreach (key, value in source) {
    if (list_of_appends.find(key)>-1) {
      if (key in ret) {
        if (type(value) == "array") {
          if (type(ret[key]) == "array") {
            ret[key].extend(value)
          } 
          else if (type(ret[key]) == "null") {
            ret[key]=value
          }
          else {
            ret[key]=[ret[key]]
            ret[key].extend(value)
          }
        } else {
          if (type(ret[key]) != "array") {
            ret[key]=[ret[key]]
          }
          ret[key].append(value)
        }
      } else {
        ret.__update({key=value})
      }
    }
    else {
      ret.__update({[key]=value})
    }
  }
  return ret
}

return {
  mergeElements = mergeElements
}