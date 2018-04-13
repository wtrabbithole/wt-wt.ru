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
  hiddenTopPrizeParams = null
  tags = null

  _contentUnpacked = null

  constructor(itemDefDesc)
  {
    id = itemDefDesc.itemdefid
    genType = itemDefDesc?.type ?? ""
    exchange = itemDefDesc?.exchange ?? ""
    bundle   = itemDefDesc?.bundle ?? ""
    isPack   = genType == "bundle"
    tags     = itemDefDesc?.tags ?? null
    timestamp = itemDefDesc?.Timestamp ?? ""
  }

  _exchangeRecipes = null
  _exchangeRecipesUpdateTime = 0
  function getRecipes()
  {
    if (!_exchangeRecipes || _exchangeRecipesUpdateTime <= ::ItemsManager.extInventoryUpdateTime)
    {
      local generatorId = id
      local parsedRecipes = inventoryClient.parseRecipesString(exchange)
      _exchangeRecipes = ::u.map(parsedRecipes, @(parsedRecipe) ExchangeRecipes(parsedRecipe, generatorId))
      _exchangeRecipesUpdateTime = ::dagor.getCurTime()
    }
    return _exchangeRecipes
  }

  function getRecipesWithComponent(componentItemdefId)
  {
    return ::u.filter(getRecipes(), @(ec) ec.hasComponent(componentItemdefId))
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
          hiddenTopPrizeParams = hiddenTopPrizeParams || generator.hiddenTopPrizeParams
          _contentUnpacked.extend(content)
        }
      }

    local isBundleHidden = !_contentUnpacked.len()
    hasHiddenItems = hasHiddenItems || isBundleHidden
    hiddenTopPrizeParams = isBundleHidden ? tags : hiddenTopPrizeParams
  }

  function getContent()
  {
    if (!_contentUnpacked)
      _unpackContent()
    return _contentUnpacked
  }

  function isHiddenTopPrize(prize)
  {
    local content = getContent()
    if (!hasHiddenItems || !prize?.item)
      return false
    foreach (v in content)
      if (prize.item == v?.item)
        return false
    return true
  }
}

local get = function(itemdefId) {
  ::ItemsManager.findItemById(itemdefId) // calls pending generators list update
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
