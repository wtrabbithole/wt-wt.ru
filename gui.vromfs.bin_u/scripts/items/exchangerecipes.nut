local inventoryClient = require("scripts/inventory/inventoryClient.nut")
local u = ::require("std/u.nut")
local asyncActions = ::require("std/asyncActions.nut")

local lastRecipeUid = 0
local ExchangeRecipes = class {
  uid = 0
  components = null
  generatorId = null

  isUsable = false
  isMultipleItems = false
  isMultipleExtraItems = false

  constructor(parsedRecipe, _generatorId)
  {
    uid = lastRecipeUid++
    generatorId = _generatorId

    local componentsCount = parsedRecipe.len()
    isUsable = componentsCount > 0
    isMultipleItems = componentsCount > 1

    local extraItemsCount = 0
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
      if (component.itemdefid != _generatorId)
        extraItemsCount++
    }

    isMultipleExtraItems = extraItemsCount > 1
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

  function getItemsListForPrizesView(componentIdToHide = null)
  {
    local res = []
    foreach (component in components)
      if (component.itemdefId != componentIdToHide)
        res.append(::DataBlockAdapter({
          item  = component.itemdefId
          commentText = getComponentQuantityText(component)
        }))
    return res
  }

  function getTextMarkup(params = null)
  {
    local list = getItemsListForPrizesView(params?.componentToHide?.id)
    return ::PrizesView.getPrizesListView(list, params)
  }

  function getText(params = null)
  {
    local list = getItemsListForPrizesView(params?.componentToHide?.id)
    local headerFunc = params?.header && @(...) params.header
    return ::PrizesView.getPrizesListText(list, headerFunc)
  }

  function getIconedMarkup()
  {
    local itemsViewData = []
    foreach (component in components)
    {
      local item = ItemsManager.findItemById(component.itemdefId)
      if (item)
        itemsViewData.append(item.getViewData({
          count = getComponentQuantityText(component)
          contentIcon = false
          hasTimer = false
          addItemName = false
          showPrice = false
          showAction = false
        }))
    }
    return ::handyman.renderCached("gui/items/item", { items = itemsViewData })
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
    local maxRecipes = (params?.maxRecipes ?? componentItem.getMaxRecipesToShow()) || recipes.len()
    local isFullRecipesList = recipes.len() <= maxRecipes

    local isMultipleRecipes = recipes.len() > 1
    local isMultipleItems = false
    local isMultipleExtraItems = false

    local recipesToShow = recipes
    if (!isFullRecipesList)
    {
      recipesToShow = u.filter(recipes, @(r) r.isUsable)
      if (recipesToShow.len() > maxRecipes)
        recipesToShow = recipesToShow.slice(0, maxRecipes)
      else if (recipesToShow.len() < maxRecipes)
        foreach(r in recipes)
          if (!r.isUsable)
          {
            recipesToShow.append(r)
            if (recipesToShow.len() == maxRecipes)
              break
          }
    }

    foreach (recipe in recipesToShow)
    {
      isMultipleItems      = isMultipleItems      || recipe.isMultipleItems
      isMultipleExtraItems = isMultipleExtraItems || recipe.isMultipleExtraItems
    }

    if (!isMultipleRecipes && !isMultipleItems)
      return ""

    local headerFirst = ::colorize("grayOptionColor",
      componentItem.getDescRecipeListHeader(recipesToShow.len(), recipes.len(), isMultipleExtraItems))
    local headerNext = isMultipleRecipes && isMultipleExtraItems ?
      ::colorize("grayOptionColor", ::loc("hints/shortcut_separator")) : null

    params.componentToHide <- componentItem
    local res = []
    foreach (recipe in recipesToShow)
    {
      params.header <- !res.len() ? headerFirst : headerNext
      if (shouldReturnMarkup)
        res.append(recipe.getTextMarkup(params))
      else
        res.append(recipe.getText(params))
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
      local msgData = componentItem.getAssembleMessageData(recipe)
      local msgboxParams = { cancel_fn = function() {} }
      if (msgData.needRecipeMarkup)
        msgboxParams.__update({
          data_below_text = recipe.getExchangeMarkup(componentItem, { widthByParentParent = true })
          baseHandler = ::get_cur_base_gui_handler()
        })
      ::scene_msg_box("chest_exchange", null, msgData.text, [
        [ "yes", ::Callback(@() recipe.doExchange(componentItem), this) ],
        [ "no" ]
      ], "yes", msgboxParams)
      return true
    }

    local locId = componentItem.getCantAssembleLocId()
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

    asyncActions.callAsyncActionsList(exchangeActions)
  }

  function onExchangeComplete(componentItem, resultItems)
  {
    ::ItemsManager.markInventoryUpdate()

    local openTrophyWndConfigs = u.map(resultItems, @(extItem) {
      id = componentItem.id
      item = extItem?.itemdef?.itemdefid
      count = extItem?.quantity ?? 0
    })
    if (openTrophyWndConfigs.len())
      ::gui_start_open_trophy({ [componentItem.id] = openTrophyWndConfigs })

    ::ItemsManager.autoConsumeItems()
  }
}

u.registerClass("Recipe", ExchangeRecipes, @(r1, r2) r1.uid == r2.uid)

return ExchangeRecipes
