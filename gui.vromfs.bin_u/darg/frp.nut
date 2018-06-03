local function subCombine(obs, obss, func) {
  local function handler(new_val) {
    local values = obss.map(@(a) a.value)
    local res = func(values)
    obs.update(res)
  }

  foreach (w in obss) {
    w.subscribe(handler)
  }
}


local function combine(obss, func) {
  //this function create and returns observable that is subscribed to list of observables
  // and its value is combination of their values by provided function
  local initialVal = func(obss.map(@(a) a.value))
  local obs = ::Watched(initialVal)
  subCombine(obs,obss,func)
  return obs
}

local function invertBool(src_observable) {
  //creates new computed observable that is inverted value of source observable
  local obs = ::Watched(!src_observable.value)
  src_observable.subscribe(@(new_val) obs.update(!new_val))
  return obs
}

local function map(src_observable, func) {
  //creates new computed observable that is func value of source observable
  local obs = ::Watched(func(src_observable.value))
  src_observable.subscribe(@(new_val) bs.update(func(new_val)))
  return obs
}

local function reduceAny(list) {
  return list.reduce(@(a, b) a||b)
}

local function reduceNone(list) {
  return !list.reduce(@(a, b) a||b)
}


return {
  subCombine = subCombine
  combine = combine
  reduceAny = reduceAny
  reduceNone = reduceNone
  invertBool = invertBool
  map = map
}
