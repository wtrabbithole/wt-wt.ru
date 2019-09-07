local function combine(obss, func) {
  //this function create and returns observable that is subscribed to list of observables
  // and its value is combination of their values by provided function
  assert(["array","table"].find(type(obss))!=null, "frp combine supports only tables and arrays")
  local function calc_array(...){
    return func(obss.map(@(a) a.value))
  }
  local function calc_table(...){
    local val = {}
    foreach (k,v in obss){
      val[k]<-v.value
    }
    return func(val)
  }
  local obs = ::Watched((type(obss)=="array") ? calc_array() : calc_table())
  local handler = (type(obss)=="array") ? @(...) obs.update(calc_array()) : @(...) obs.update(calc_table())
  foreach (k,v in obss)
    v.subscribe(handler)
  return obs
}

local function map(src_observable, func) {
  //creates new computed observable that is func value of source observable
  local obs = ::Watched(func(src_observable.value))
  src_observable.subscribe(@(new_val) obs.update(func(new_val)))
  return obs
}

local function invertBool(src_observable) {
  return map(src_observable, @(val) !val)
}

local function reduceAny(list) {
  return list.reduce(@(a, b) a||b)
}

local function reduceNone(list) {
  return !list.reduce(@(a, b) a||b)
}

local function subscribe(list, func){
  foreach(idx, observable in list)
    observable.subscribe(func)
}

return {
  combine = combine
  reduceAny = reduceAny
  reduceNone = reduceNone
  invertBool = invertBool
  map = map
  subscribe = subscribe
}
