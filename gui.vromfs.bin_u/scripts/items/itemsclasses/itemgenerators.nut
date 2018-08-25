local inventoryClient = require("scripts/inventory/inventoryClient.nut")
local ExchangeRecipes = require("scripts/items/exchangeRecipes.nut")
local time = require("scripts/time.nut")

local collection = {}

local ItemGenerator = class {
  id = -1
  genType = ""
  exchange = null
  bundle  = null
  timestamp = ""
  assembleTime = 0

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
    isPack   = ::isInArray(genType, [ "bundle", "delayedexchange" ])
    tags     = itemDefDesc?.tags ?? null
    timestamp = itemDefDesc?.Timestamp ?? ""
    assembleTime = time.getSecondsFromTemplate(itemDefDesc?.lifetime ?? "")
  }

  _exchangeRecipes = null
  _exchangeRecipesUpdateTime = 0

  function getRecipes()
  {
    if (!_exchangeRecipes || _exchangeRecipesUpdateTime <= ::ItemsManager.extInventoryUpdateTime)
    {
      local generatorId = id
      local generatorAssembleTime = assembleTime
      local parsedRecipes = inventoryClient.parseRecipesString(exchange)
      _exchangeRecipes = ::u.map(parsedRecipes, @(parsedRecipe) ExchangeRecipes({
         parsedRecipe = parsedRecipe,
         generatorId = generatorId
         assembleTime = generatorAssembleTime
      }))

      // Adding additional recipes
      local hasAdditionalRecipes
      local wBlk = ::DataBlock("config/workshop.blk")
      if (wBlk.additionalRecipes)
        foreach (itemBlk in (wBlk.additionalRecipes % "item"))
          if (::to_integer_safe(itemBlk.id) == id)
          {
            hasAdditionalRecipes = true
            foreach (paramName in ["fakeRecipe", "trueRecipe"])
              foreach (itemdefId in itemBlk % paramName)
              {
                local gen = collection?[itemdefId] ?? null
                local additionalParsedRecipes = gen ? inventoryClient.parseRecipesString(gen.exchange) : []
                _exchangeRecipes.extend(::u.map(additionalParsedRecipes, @(pr) ExchangeRecipes({
                  parsedRecipe = pr,
                  generatorId = gen.id
                  assembleTime = gen.assembleTime
                  isFake = paramName != "trueRecipe"
                })))
              }
            break
          }
      if (hasAdditionalRecipes)
      {
        local minIdx = _exchangeRecipes[0].idx
        ::math.init_rnd(::my_user_id_int64 + id)
        _exchangeRecipes = ::u.shuffle(_exchangeRecipes)
        foreach (recipe in _exchangeRecipes)
          recipe.idx = minIdx++
        ::randomize()
      }

      _exchangeRecipesUpdateTime = ::dagor.getCurTime()
    }
    return ::u.filter(_exchangeRecipes, @(ec) ec.isEnabled())
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
      foreach (cfg in set.components)
      {
        local item = ::ItemsManager.findItemById(cfg.itemdefid)
        local generator = !item ? collection?[cfg.itemdefid] : null

        if (item)
        {
          local b = ::DataBlock()
          b.item =  item.id
          if (cfg.quantity > 1)
            b.count = cfg.quantity
          _contentUnpacked.append(b)
        }
        else if (generator)
        {
          local content = generator.getContent(cfg.quantity)
          hasHiddenItems = hasHiddenItems || generator.hasHiddenItems
          hiddenTopPrizeParams = hiddenTopPrizeParams || generator.hiddenTopPrizeParams
          _contentUnpacked.extend(content)
        }
      }

    local isBundleHidden = !_contentUnpacked.len()
    hasHiddenItems = hasHiddenItems || isBundleHidden
    hiddenTopPrizeParams = isBundleHidden ? tags : hiddenTopPrizeParams
  }

  function getContent(quantityMul = 1)
  {
    if (!_contentUnpacked)
      _unpackContent()
    if (quantityMul > 1)
      return ::u.map(_contentUnpacked, @(v) ::PrizesView.miltiplyPrizeCount(v, quantityMul))
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

  function getRecipeByUid(uid)
  {
    return ::u.search(getRecipes(), @(r) r.uid == uid)
  }

  function markAllRecipes()
  {
    local recipes = getRecipes()
    if (!ExchangeRecipes.hasFakeRecipes(recipes))
      return

    local markedRecipes = []
    foreach(recipe in recipes)
      if (recipe.markRecipe(false, false))
        markedRecipes.append(recipe.uid)

    ExchangeRecipes.saveMarkedRecipes(markedRecipes)
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

local findGenByReceptUid = function(recipeUid) {
  foreach (gen in collection)
    if (gen.genType != "delayedexchange")
      foreach (recipe in gen.getRecipes())
        if (recipe.uid == recipeUid)
          return gen
}

return {
  get = get
  add = add
  findGenByReceptUid = findGenByReceptUid
}
