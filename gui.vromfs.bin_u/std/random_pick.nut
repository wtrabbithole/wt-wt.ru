local Rand = require("rand.nut")
local math = require("math")

local function get_rand_norm_value(totalWeight=1) {
  return math.rand().tofloat()*totalWeight/math.RAND_MAX
}
local function pickword(dictionary, seed=null, allow_cache=false){
  local rand = Rand(seed)
  local totalWeight = 0
  assert(["table","array"].find(::type(dictionary))!=null, "dictionary should be array or table")
  if (type(dictionary) == "table"){
    if (!("___totalWeight___" in dictionary)) {
      foreach (word, weight in dictionary)
        totalWeight += weight
      if (allow_cache)
        dictionary["___totalWeight___"] <- totalWeight //cache it dictionary
    }
    else
      totalWeight = dictionary["___totalWeight___"]
  }  else {
    totalWeight = dictionary.len()
  }
  if (totalWeight <= 0.0)
    return null
  local rand_val = rand.rfloat(0, totalWeight)
  local ret = null
  local cur_rand_sum = 0
  foreach (key, val in dictionary) {
    local isArray = ::type(dictionary) == "array"
    local word = isArray ? val : key
    local weight = isArray ? 1 : val.tofloat()
    if (word == "___totalWeight___")
      continue
    cur_rand_sum += weight
    if (rand_val <= cur_rand_sum)
      return word
  }
  return ret
}

return pickword