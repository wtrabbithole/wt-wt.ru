local inventoryClient = require("scripts/inventory/inventoryClient.nut")
local u = ::require("std/u.nut")
local asyncActions = ::require("sqStdLibs/helpers/asyncActions.nut")
local time = require("scripts/time.nut")


enum MARK_RECIPE {
  NONE
  BY_USER
  USED
}

local markRecipeSaveId = "markRecipe/"

local lastRecipeIdx = 0
local ExchangeRecipes = class {
  idx = 0
  uid = ""
  components = null
  generatorId = null
  requirement = null
  mark = MARK_RECIPE.NONE

  isUsable = false
  isMultipleItems = false
  isMultipleExtraItems = false
  isFake = false

  assembleTime = 0
  initedComponents = null

  constructor(params)
  {
    idx = lastRecipeIdx++
    generatorId = params.generatorId
    isFake = params?.isFake ?? false
    assembleTime = params?.assembleTime ?? 0
    local parsedRecipe = params.parsedRecipe

    initedComponents = parsedRecipe.components
    requirement = parsedRecipe.requirement

    uid = generatorId + ";" + (requirement ? getRecipeStr() : parsedRecipe.recipeStr)

    updateComponents()
    loadStateRecipe()
  }

  function updateComponents()
  {
    local componentsCount = initedComponents.len()
    isUsable = componentsCount > 0
    isMultipleItems = componentsCount > 1

    local extraItemsCount = 0
    components = []
    foreach (component in initedComponents)
    {
      local items = ::ItemsManager.getInventoryList(itemType.ALL, @(item) item.id == component.itemdefid)

      local curQuantity = ::u.reduce(items, @(item, res) res + item.amount, 0)
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
      if (component.itemdefid != generatorId)
        extraItemsCount++
    }

    isMultipleExtraItems = extraItemsCount > 1
  }

  function isEnabled()
  {
    return requirement == null || ::has_feature(requirement)
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

  function getItemsListForPrizesView(params = null)
  {
    local res = []
    foreach (component in components)
      if (component.itemdefId != params?.componentToHide?.id)
        res.append(::DataBlockAdapter({
          item  = component.itemdefId
          commentText = getComponentQuantityText(component, params)
        }))
    return res
  }

  function getTextMarkup(params = null)
  {
    if (!params)
      params = {}
    params = params.__merge({isLocked = isRecipeLocked()})

    local list = getItemsListForPrizesView(params)
    return ::PrizesView.getPrizesListView(list, params, false)
  }

  function getText(params = null)
  {
    local list = getItemsListForPrizesView(params)
    local headerFunc = params?.header && @(...) params.header
    return ::PrizesView.getPrizesListText(list, headerFunc)
  }

  function hasAssembleTime()
  {
    return assembleTime > 0
  }

  function getAssembleTime()
  {
    return assembleTime
  }

  function getAssembleTimeText()
  {
    return ::loc("icon/hourglass") + " " + time.secondsToString(assembleTime, true, true)
  }

  function getIconedMarkup()
  {
    local itemsViewData = []
    foreach (component in components)
    {
      local item = ItemsManager.findItemById(component.itemdefId)
      if (item)
        itemsViewData.append(item.getViewData({
          count = getComponentQuantityText(component, { needColoredText = false })
          overlayAmountTextColor = getComponentQuantityColor(component)
          contentIcon = false
          hasTimer = false
          addItemName = false
          showPrice = false
          showAction = false
          shouldHideAdditionalAmmount = true
          craftTimerText = item.getAdditionalTextInAmmount(false)
        }))
    }
    return ::handyman.renderCached("gui/items/item", { items = itemsViewData })
  }

  function getMarkIcon()
  {
    if (mark == MARK_RECIPE.NONE)
      return ""

    local imgPrefix = "#ui/gameuiskin#"
    if (mark == MARK_RECIPE.USED)
      return imgPrefix + (isFake ? "icon_primary_fail" : "icon_primary_ok")

    if (mark == MARK_RECIPE.BY_USER)
      return imgPrefix + "icon_primary_attention"
  }

  function getMarkLocIdByPath(path)
  {
    if (mark == MARK_RECIPE.NONE)
      return ""

    if (mark == MARK_RECIPE.USED)
      return ::loc(path + (isFake ? "fake" : "true"))

    if (mark == MARK_RECIPE.BY_USER)
      return ::loc(path + "fakeByUser")

    return ""
  }

  getMarkText = @() getMarkLocIdByPath("item/recipes/markDesc/")
  getMarkTooltip = @() getMarkLocIdByPath("item/recipes/markTooltip/")

  function getMarkDescMarkup()
  {
    local title = getMarkText()
    if (title == "")
      return ""

    local view = {
      list = [{
        icon  = getMarkIcon()
        title = title
        tooltip = getMarkTooltip()
      }]
    }
    return ::handyman.renderCached("gui/items/trophyDesc", view)
  }

  isRecipeLocked = @() mark == MARK_RECIPE.BY_USER || (mark == MARK_RECIPE.USED && isFake)
  getCantAssembleMarkedFakeLocId = @() mark == MARK_RECIPE.BY_USER ? "msgBox/craftProcess/cant/markByUser"
    : (mark == MARK_RECIPE.USED && isFake) ? "msgBox/craftProcess/cant/isFake"
    : ""

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
    local isMultipleExtraItems = false

    local recipesToShow = recipes
    if (!isFullRecipesList)
    {
      recipesToShow = u.filter(recipes, @(r) r.isUsable && !r.isRecipeLocked())
      if (recipesToShow.len() > maxRecipes)
        recipesToShow = recipesToShow.slice(0, maxRecipes)
      else if (recipesToShow.len() < maxRecipes)
        foreach(r in recipes)
          if (!r.isUsable && !r.isRecipeLocked())
          {
            recipesToShow.append(r)
            if (recipesToShow.len() == maxRecipes)
              break
          }
    }

    foreach (recipe in recipesToShow)
      isMultipleExtraItems = isMultipleExtraItems || recipe.isMultipleExtraItems

    local headerFirst = ::colorize("grayOptionColor",
      componentItem.getDescRecipeListHeader(recipesToShow.len(), recipes.len(),
                                            isMultipleExtraItems, hasFakeRecipes(recipes),
                                            getRecipesAssembleTimeText(recipes)))
    local headerNext = isMultipleRecipes && isMultipleExtraItems ?
      ::colorize("grayOptionColor", ::loc("hints/shortcut_separator")) : null

    params.componentToHide <- componentItem
    params.showCurQuantities <- componentItem.descReceipesListWithCurQuantities

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

  static function getRecipesAssembleTimeText(recipes)
  {
    local minSeconds = ::max(::u.min(recipes, @(r) r?.assembleTime ?? 0)?.assembleTime ?? 0, 0)
    local maxSeconds = ::max(::u.max(recipes, @(r) r?.assembleTime ?? 0)?.assembleTime ?? 0, 0)
    if (minSeconds <= 0 && maxSeconds <= 0)
      return ""

    local timeText = ::loc("icon/hourglass") + " " + time.secondsToString(minSeconds, true, true)
    if (minSeconds != maxSeconds)
      timeText += " " + ::loc("event_dash") + " " + time.secondsToString(maxSeconds, true, true)

    return ::loc("msgBox/assembleItem/time", {time = timeText})
  }

  static hasFakeRecipes = @(recipes) ::u.search(recipes, @(r) r?.isFake) != null

  static function saveMarkedRecipes(newMarkedRecipesUid)
  {
    if (!newMarkedRecipesUid.len())
      return

    local markRecipeBlk = ::load_local_account_settings(markRecipeSaveId)
    if (!markRecipeBlk)
      markRecipeBlk = ::DataBlock()
    foreach(uid in newMarkedRecipesUid)
      markRecipeBlk[uid] = MARK_RECIPE.USED

    ::save_local_account_settings(markRecipeSaveId, markRecipeBlk)
  }

  static function getComponentQuantityText(component, params = null)
  {
    if (!(params?.showCurQuantities ?? true))
      return component.reqQuantity > 1 ?
        (::nbsp + ::format(::loc("weapons/counter/right/short"), component.reqQuantity)) : ""

    local locText = ::loc("ui/parentheses/space",
      { text = component.curQuantity + "/" + component.reqQuantity })
    if (params?.needColoredText ?? true)
      return ::colorize(getComponentQuantityColor(component, true), locText)

    return locText
  }

  static getComponentQuantityColor = @(component, needCheckRecipeLocked = false)
    isRecipeLocked() && needCheckRecipeLocked ? "fadedTextColor"
      : component.has ? "goodTextColor"
      : "badTextColor"

  static function tryUse(recipes, componentItem, params = null)
  {
    if (componentItem.hasReachedMaxAmount())
    {
      ::scene_msg_box("reached_max_amount", null, ::loc("item/reached_max_amount"),
        [["cancel"]], "cancel")
      return false
    }

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
      if (params?.shouldSkipMsgBox)
      {
        recipe.doExchange(componentItem)
        return true
      }

      local msgData = params?.messageData || componentItem.getAssembleMessageData(recipe)
      local msgboxParams = { cancel_fn = function() {} }

      if (params?.isDisassemble && params?.bundleContent)
      {
        msgboxParams.__update({
          data_below_text = ::PrizesView.getPrizesListView(params.bundleContent, { widthByParentParent = true })
          baseHandler = ::get_cur_base_gui_handler()
        })
      }
      else if (msgData?.needRecipeMarkup)
        msgboxParams.__update({
          data_below_text = recipe.getExchangeMarkup(componentItem, { widthByParentParent = true })
          baseHandler = ::get_cur_base_gui_handler()
        })

      ::scene_msg_box("chest_exchange", null, msgData.text, [
        [ "yes", ::Callback(function()
          {
            recipe.updateComponents()
            if (recipe.isUsable)
              recipe.doExchange(componentItem, 1, params)
            else
              showUseErrorMsg(recipes, componentItem)
          }, this) ],
        [ "no" ]
      ], "yes", msgboxParams)
      return true
    }

    showUseErrorMsg(recipes, componentItem)
    return false
  }

  function showUseErrorMsg(recipes, componentItem)
  {
    local locId = componentItem.getCantAssembleLocId()
    local text = ::colorize("badTextColor", ::loc(locId))
    local msgboxParams = {
      data_below_text = getRequirementsMarkup(recipes, componentItem, { widthByParentParent = true }),
      baseHandler = ::get_cur_base_gui_handler(), //FIX ME: used only for tooltip
      cancel_fn = function() {}
    }

    //Suggest to buy not enough item on marketplace
    local requiredItem = null
    if (::ItemsManager.isMarketplaceEnabled() && recipes.len() == 1)
      foreach (c in recipes[0].components)
        if (c.itemdefId != componentItem.id && c.curQuantity < c.reqQuantity)
        {
          local item = ::ItemsManager.findItemById(c.itemdefId)
          if (!item || !item.hasLink())
            continue
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
  }


  //////////////////////////////////// Internal functions ////////////////////////////////////

  function getMaterialsListForExchange(usedUidsList)
  {
    local res = []
    foreach (component in components)
    {
      local leftCount = component.reqQuantity
      local itemsList = ::ItemsManager.getInventoryList(itemType.ALL, @(item) item.id == component.itemdefId)
      foreach(item in itemsList)
      {
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
        if (!leftCount)
          break
      }
    }
    return res
  }

  function doExchange(componentItem, amount = 1, params = null)
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
      --leftAmount <= 0,
      requirement
    )).bindenv(recipe)

    local exchangeActions = array(amount, exchangeAction)
    exchangeActions.append(@(cb) recipe.onExchangeComplete(componentItem, resultItems, params))

    asyncActions.callAsyncActionsList(exchangeActions)
  }

  function onExchangeComplete(componentItem, resultItems, params = null)
  {
    ::ItemsManager.markInventoryUpdate()

    local isShowOpening  = @(extItem) extItem?.itemdef?.type == "item" &&
                                      !extItem?.itemdef?.tags?.devItem
    local resultItemsShowOpening  = ::u.filter(resultItems, isShowOpening)

    local parentGen = componentItem.getParentGen()
    local parentRecipe = parentGen?.getRecipeByUid?(componentItem.craftedFrom)
    if ((parentRecipe?.markRecipe?() ?? false) && !parentRecipe?.isFake)
      parentGen.markAllRecipes()

    local rewardTitle = parentRecipe ? parentRecipe.getRewardTitleLocId() : ""
    local rewardListLocId = params?.rewardListLocId ? params.rewardListLocId :
      parentRecipe ? componentItem.getItemsListLocId() : ""

    if (resultItemsShowOpening.len())
    {
      local openTrophyWndConfigs = u.map(resultItemsShowOpening, @(extItem) {
        id = componentItem.id
        item = extItem?.itemdef?.itemdefid
        count = extItem?.quantity ?? 0
      })
      ::gui_start_open_trophy({ [componentItem.id] = openTrophyWndConfigs,
        rewardTitle = ::loc(rewardTitle),
        rewardListLocId = rewardListLocId
        isDisassemble = params?.isDisassemble ?? false
      })
    }

    ::ItemsManager.autoConsumeItems()
  }

  getSaveId = @() markRecipeSaveId + uid

  function markRecipe(isUserMark = false, needSave = true)
  {
    local marker = !isUserMark ? MARK_RECIPE.USED
      : (isUserMark && mark == MARK_RECIPE.NONE) ? MARK_RECIPE.BY_USER
      : MARK_RECIPE.NONE

    if(mark == marker)
      return false

    mark = marker
    if (needSave)
      ::save_local_account_settings(getSaveId(), mark)

    return true
  }

  function loadStateRecipe()
  {
    mark = ::load_local_account_settings(getSaveId(), MARK_RECIPE.NONE)
  }

  getRewardTitleLocId = @() getMarkLocIdByPath("mainmenu/craftFinished/title/")

  getRecipeStr = @() ::g_string.implode(
    u.map(initedComponents, @(component) component.itemdefid.tostring()
      + (component.quantity > 1 ? ("x" + component.quantity) : "")),
    ",")
}

u.registerClass("Recipe", ExchangeRecipes, @(r1, r2) r1.idx == r2.idx)

return ExchangeRecipes
