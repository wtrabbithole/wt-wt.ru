local inventoryClient = require("scripts/inventory/inventoryClient.nut")
local ExchangeRecipes = require("scripts/items/exchangeRecipes.nut")

local collection = {}

local ItemGenerator = class {
  id = ""
  genType = ""
  exchange = null
  bundle  = null
  timestamp = ""

  isPack = false
  hasHiddenItems = false

  _contentUnpacked = null

  _exchangeRecipes = null
  _exchangeRecipesUpdateTime = 0

  constructor(itemDefDesc)
  {
    id = itemDefDesc.itemdefid
    genType = itemDefDesc?.type ?? ""
    exchange = itemDefDesc?.exchange ?? ""
    bundle   = itemDefDesc?.bundle ?? ""
    isPack   = genType == "bundle"
    timestamp = itemDefDesc?.Timestamp ?? ""
  }

  function getRecipesWithComponent(componentItemdefId)
  {
    if (!_exchangeRecipes || _exchangeRecipesUpdateTime <= ::ItemsManager.extInventoryUpdateTime)
    {
      local generatorId = id
      local parsedRecipes = inventoryClient.parseRecipesString(exchange)
      _exchangeRecipes = ::u.map(parsedRecipes, @(parsedRecipe) ExchangeRecipes(parsedRecipe, generatorId))
      _exchangeRecipesUpdateTime = ::dagor.getCurTime()
    }

    return ::u.filter(_exchangeRecipes, @(ec) ec.hasComponent(componentItemdefId))
  }

  function _unpackContent()
  {
    _contentUnpacked = []
    local parsedBundles = inventoryClient.parseRecipesString(bundle)

    foreach (set in parsedBundles)
      foreach (cfg in set)
      {
        local item = ::ItemsManager.findItemById(cfg.itemdefid)
        local generator = !item ? collection?[cfg.itemdefid] : null

        if (item)
        {
          local b = ::DataBlock()
          b.item =  item.id
          _contentUnpacked.append(b)
        }
        else if (generator)
        {
          local content = generator.getContent()
          hasHiddenItems = hasHiddenItems || generator.hasHiddenItems
          _contentUnpacked.extend(content)
        }
      }

    hasHiddenItems = hasHiddenItems || !_contentUnpacked.len()
  }

  function getContent()
  {
    if (!_contentUnpacked)
      _unpackContent()
    return _contentUnpacked
  }
}

local get = function(itemdefId) {
  return collection?[itemdefId]
}

local add = function(itemDefDesc) {
  if (itemDefDesc?.Timestamp != collection?[itemDefDesc.itemdefid]?.timestamp)
    collection[itemDefDesc.itemdefid] <- ItemGenerator(itemDefDesc)
}

return {
  get = get
  add = add
}
