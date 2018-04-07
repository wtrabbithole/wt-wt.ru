local inventoryClient = require("scripts/inventory/inventoryClient.nut")
local u = ::require("std/u.nut")

local callAsyncActionsList = null
callAsyncActionsList = function(actionsList)
{
  if (!actionsList.len())
    return

  local action = actionsList.remove(0)
  action(@(...) callAsyncActionsList(actionsList))
}

local ExchangeRecipes = class {
  components = null
  generatorId = null

  isUsable = false
  isMultipleItems = false
  isMultipleExtraItems = false

  constructor(parsedRecipe, _generatorId)
  {
    generatorId = _generatorId

    local componentsCount = parsedRecipe.len()
    isUsable = componentsCount > 0
    isMultipleItems = isMultipleItems || componentsCount > 1
    isMultipleExtraItems = isMultipleExtraItems || componentsCount > 2

    components = []
    foreach (component in parsedRecipe)
    {
      local items = ::ItemsManager.getInventoryList(itemType.ALL, @(item) item.id == component.itemdefid)
      local inventoryItem = items?[0] ?? null

      local curQuantity = inventoryItem ? inventoryItem.amount : 0
      local reqQuantity = component.quantity
      local isHave = curQuantity >= reqQuantity
      isUsable = isUsable && isHave

      components.append({
        has = isHave
        itemdefId = component.itemdefid
        reqQuantity = reqQuantity
        curQuantity = curQuantity
      })

      if (reqQuantity > 1)
        isMultipleItems = true
    }
  }

  function hasComponent(itemdefid)
  {
    foreach (c in components)
      if (c.itemdefId == itemdefid)
        return true
    return false
  }

  function getExchangeMarkup(componentItem, params)
  {
    local list = []
    foreach (component in components)
    {
      if (component.itemdefId == componentItem.id)
        continue
      list.append(::DataBlockAdapter({
        item  = component.itemdefId
        commentText = getComponentQuantityText(component)
      }))
    }
    return ::PrizesView.getPrizesListView(list, params)
  }

  static function getRequirementsMarkup(recipes, componentItem, params)
  {
    return _getRequirements(recipes, componentItem, params, true)
  }

  static function getRequirementsText(recipes, componentItem, params)
  {
    return _getRequirements(recipes, componentItem, params, false)
  }

  static function _getRequirements(recipes, componentItem, params, shouldReturnMarkup)
  {
    local isMultipleRecipes = recipes.len() > 1
    local isMultipleItems = false
    local isMultipleExtraItems = false

    foreach (recipe in recipes)
    {
      isMultipleItems      = isMultipleItems      || recipe.isMultipleItems
      isMultipleExtraItems = isMultipleExtraItems || recipe.isMultipleExtraItems
    }

    if (!isMultipleRecipes && !isMultipleItems)
      return ""

    local headerPrefix = componentItem.iType == itemType.CHEST ? "chest/requires/"
      : componentItem.iType == itemType.KEY ? "key/requires/"
      : "item/requires/"
    local headerSuffix = isMultipleRecipes && isMultipleExtraItems  ? "any_of_item_sets"
      : !isMultipleRecipes && isMultipleExtraItems ? "items_set"
      : isMultipleRecipes && !isMultipleExtraItems ? "any_of_items"
      : "item"
    local headerFirst = ::colorize("grayOptionColor", ::loc(headerPrefix + headerSuffix))
    local headerNext = isMultipleRecipes && isMultipleExtraItems ?
      ::colorize("grayOptionColor", ::loc("hints/shortcut_separator")) : null

    local res = []
    foreach (recipe in recipes)
    {
      local list = []
      foreach (component in recipe.components)
      {
        if (component.itemdefId == componentItem.id)
          continue
        list.append(::DataBlockAdapter({
          item  = component.itemdefId
          commentText = getComponentQuantityText(component)
        }))
      }
      params.header <- !res.len() ? headerFirst : headerNext
      if (shouldReturnMarkup)
        res.append(::PrizesView.getPrizesListView(list, params))
      else
        res.append(::PrizesView.getPrizesListText(list, @(...) params.header))
    }

    return ::g_string.implode(res, shouldReturnMarkup ? "" : "\n")
  }

  static function getComponentQuantityText(component)
  {
    return ::colorize(component.has ? "goodTextColor" : "badTextColor",
      ::loc("ui/parentheses/space", { text = component.curQuantity + "/" + component.reqQuantity }))
  }

  static function tryUse(recipes, componentItem)
  {
    local recipe = null
    foreach (r in recipes)
      if (r.isUsable)
      {
        recipe = r
        break
      }

    local iType = componentItem.iType
    if (recipe)
    {
      local locId = iType == itemType.CHEST ? "msgBox/chestOpen/confirm"
        : "msgBox/assembleItem/confirm"
      local text = ::loc(locId, { itemName = ::colorize("activeTextColor", componentItem.getName()) })
      local markup = ""
      local handler = null
      if (recipe.isMultipleItems)
      {
        text += "\n" + ::loc(iType == itemType.CHEST ? "msgBox/extra_items_will_be_spent" : "msgBox/items_will_be_spent")
        markup = recipe.getExchangeMarkup(componentItem, { widthByParentParent = true })
        handler = ::get_cur_base_gui_handler()
      }
      local msgboxParams = { data_below_text = markup, baseHandler = handler, cancel_fn = function() {} }

      ::scene_msg_box("chest_exchange", null, text, [
        [ "yes", ::Callback(@() recipe.doExchange(componentItem), this) ],
        [ "no" ]
      ], "yes", msgboxParams)
      return true
    }

    local locId = iType == itemType.CHEST ? "msgBox/chestOpen/cant" : "msgBox/assembleItem/cant"
    local text = ::colorize("badTextColor", ::loc(locId))
    local msgboxParams = {
      data_below_text = getRequirementsMarkup(recipes, componentItem, { widthByParentParent = true }),
      baseHandler = ::get_cur_base_gui_handler(), //FIX ME: used only for tooltip
      cancel_fn = function() {}
    }

    // If only one item is required (usually a Key for a Chest), suggest to buy it now.
    local requiredItem = null
    if (::ItemsManager.isMarketplaceEnabled() && recipes.len() == 1 && recipes[0].components.len() == 2)
      foreach (c in recipes[0].components)
        if (c.itemdefId != componentItem.id)
        {
          local item = ::ItemsManager.findItemById(c.itemdefId)
          if (item && item.link != "")
            requiredItem = item
          break
        }

    local buttons = [ ["cancel"] ]
    local defBtn = "cancel"
    if (requiredItem)
    {
      buttons.insert(0, [ "find_on_marketplace", ::Callback(@() requiredItem.openLink(), this) ])
      defBtn = "find_on_marketplace"
    }

    ::scene_msg_box("cant_open_chest", null, text, buttons, defBtn, msgboxParams)
    return false
  }


  //////////////////////////////////// Internal functions ////////////////////////////////////

  function getMaterialsListForExchange(usedUidsList)
  {
    local res = []
    foreach (component in components)
    {
      local item = u.search(::ItemsManager.getInventoryList(), @(item) item.id == component.itemdefId)
      if (!item)
        continue

      local leftCount = component.reqQuantity
      foreach(uid in item.uids)
      {
        local leftByUid = usedUidsList?[uid] ?? item.amountByUids[uid]
        if (leftByUid <= 0)
          continue

        local count = ::min(leftCount, leftByUid)
        res.append([ uid, count ])
        usedUidsList[uid] <- leftByUid - count
        leftCount -= count
        if (!leftCount)
          break
      }
    }
    return res
  }

  function doExchange(componentItem, amount = 1)
  {
    local resultItems = []
    local usedUidsList = {}
    local recipe = this //to not remove recipe until operation complete
    local leftAmount = amount
    local exchangeAction = (@(cb) inventoryClient.exchange(
      getMaterialsListForExchange(usedUidsList),
      generatorId,
      function(items) {
        resultItems.extend(items)
        cb()
      },
      --leftAmount <= 0
    )).bindenv(recipe)

    local exchangeActions = array(amount, exchangeAction)
    exchangeActions.append(@(cb) recipe.onExchangeComplete(componentItem, resultItems))

    callAsyncActionsList(exchangeActions)
  }

  function onExchangeComplete(componentItem, resultItems)
  {
    ::ItemsManager.markInventoryUpdate()

    local actionsList = []
    local openTrophyWndConfigs = []
    foreach (extItem in resultItems)
    {
      local item = ::ItemsManager.findItemByUid(extItem?.itemid)
      if (item?.shouldAutoConsume)
        actionsList.append(@(cb) item.consume(cb, {}) || cb())

      openTrophyWndConfigs.append({
        id = componentItem.id
        item = extItem?.itemdef?.itemdefid
      })
    }

    if (openTrophyWndConfigs.len())
      ::gui_start_open_trophy({ [componentItem.id] = openTrophyWndConfigs })
    callAsyncActionsList(actionsList)
  }
}

return ExchangeRecipes
