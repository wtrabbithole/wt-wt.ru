local collection = {}

local ItemGenerator = class {
  id = ""
  bundle  = ""
  genType = ""

  constructor(itemDefDesc)
  {
    id = itemDefDesc.itemdefid
    bundle  = itemDefDesc?.bundle ?? ""
    genType = itemDefDesc?.type ?? ""
  }
}

local get = function(itemdefId) {
  return collection?[itemdefId]
}

local add = function(itemDefDesc) {
  collection[itemDefDesc.itemdefid] <- ItemGenerator(itemDefDesc)
}

return {
  get = get
  add = add
}
