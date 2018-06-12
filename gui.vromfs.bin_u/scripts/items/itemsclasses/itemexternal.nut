local inventoryClient = require("scripts/inventory/inventoryClient.nut")
local ItemGenerators = require("scripts/items/itemsClasses/itemGenerators.nut")
local ExchangeRecipes = require("scripts/items/exchangeRecipes.nut")
local guidParser = require("scripts/guidParser.nut")
local itemRarity = require("scripts/items/itemRarity.nut")
local time = require("scripts/time.nut")
local chooseAmountWnd = ::require("scripts/wndLib/chooseAmountWnd.nut")
local recipesListWnd = ::require("scripts/items/listPopupWnd/recipesListWnd.nut")
local itemTransfer = require("scripts/items/itemsTransfer.nut")

local emptyBlk = ::DataBlock()

local ItemExternal = class extends ::BaseItem
{
  static defaultLocId = ""
  static combinedNameLocId = null
  static descHeaderLocId = ""
  static openingCaptionLocId = "mainmenu/itemConsumed/title"
  static linkActionLocId = "msgbox/btn_find_on_marketplace"
  static linkActionIcon = "#ui/gameuiskin#gc.svg"
  static userlogOpenLoc = "coupon_exchanged"
  static linkBigQueryKey = "marketplace_item"
  static isPreferMarkupDescInTooltip = true
  static isDescTextBeforeDescDiv = false
  static hasRecentItemConfirmMessageBox = false
  static descReceipesListHeaderPrefix = "item/requires/"
  canBuy = true

  rarity = null
  expireTimestamp = -1

  itemDef = null
  metaBlk = null

  amountByUids = null //{ <uid> = <amount> }, need for recipe materials

  constructor(itemDefDesc, itemDesc = null, slotData = null)
  {
    base.constructor(emptyBlk)

    itemDef = itemDefDesc
    id = itemDef.itemdefid
    blkType  = itemDefDesc?.tags?.type ?? ""

    rarity = itemRarity.get(itemDef?.item_quality, itemDef?.name_color)
    shouldAutoConsume = !!itemDefDesc?.tags?.autoConsume

    link = inventoryClient.getMarketplaceItemUrl(id, itemDesc?.itemid) || ""
    forceExternalBrowser = true

    if (itemDesc)
    {
      isInventoryItem = true
      amount = 0
      uids = []
      amountByUids = {}
      if ("itemid" in itemDesc)
        addUid(itemDesc.itemid, itemDesc.quantity)
      lastChangeTimestamp = time.getTimestampFromIso8601(itemDesc?.timestamp)
      tradeableTimestamp = getTradebleTimestamp(itemDesc)
    }

    expireTimestamp = getExpireTimestamp(itemDefDesc, itemDesc)
    if (expireTimestamp != -1)
      expiredTimeSec = (::dagor.getCurTime() * 0.001) + (expireTimestamp - ::get_charserver_time_sec())

    local meta = getTblValue("meta", itemDef)
    if (meta && meta.len()) {
      metaBlk = ::DataBlock()
      if (!metaBlk.loadFromText(meta, meta.len())) {
        metaBlk = null
      }
    }

    canBuy = !isInventoryItem && checkPurchaseFeature()

    addResources()

    updateShopFilterMask()
  }

  function getTradebleTimestamp(itemDesc)
  {
    if (!::has_feature("Marketplace"))
      return 0
    local res = ::to_integer_safe(itemDesc?.tradable_after_timestamp || 0)
    return res > ::get_charserver_time_sec() ? res : 0
  }

  function updateShopFilterMask()
  {
    shopFilterMask = iType
  }

  function tryAddItem(itemDefDesc, itemDesc)
  {
    if (id != itemDefDesc.itemdefid
        || expireTimestamp != getExpireTimestamp(itemDefDesc, itemDesc)
        || tradeableTimestamp != getTradebleTimestamp(itemDesc))
      return false
    addUid(itemDesc.itemid, itemDesc.quantity)
    lastChangeTimestamp = ::max(lastChangeTimestamp, time.getTimestampFromIso8601(itemDesc?.timestamp))
    return true
  }

  function addUid(uid, count)
  {
    uids.append(uid)
    amountByUids[uid] <- count
    amount += count
  }

  onItemExpire     = @() ::ItemsManager.refreshExtInventory()
  onTradeAllowed   = @() ::ItemsManager.markInventoryUpdateDelayed()

  function getExpireTimestamp(itemDefDesc, itemDesc)
  {
    local tShop = time.getTimestampFromIso8601(itemDefDesc?.expireAt ?? "")
    local tInv  = time.getTimestampFromIso8601(itemDesc?.expireAt ?? "")
    return (tShop != -1 && (tInv == -1 || tShop < tInv)) ? tShop : tInv
  }

  updateNameLoc = @(locName) combinedNameLocId ? ::loc(combinedNameLocId, { name = locName }) : locName

  function getName(colored = true)
  {
    local res = ""
    if (isDisguised)
      res = ::loc("item/disguised")
    else
      res = updateNameLoc(itemDef?.name ?? "")

    if (colored)
      res = ::colorize(getRarityColor(), res)
    return res
  }

  function getDescription()
  {
    if (isDisguised)
      return ""

    local desc = [
      getResourceDesc()
    ]

    local tags = getTagsLoc()
    if (tags.len())
    {
      tags = ::u.map(tags, @(txt) ::colorize("activeTextColor", txt))
      desc.append(::loc("ugm/tags") + ::loc("ui/colon") + ::g_string.implode(tags, ::loc("ui/comma")))
    }

    desc.append(itemDef?.description ?? "")

    return ::g_string.implode(desc, "\n\n")
  }

  function getIcon(addItemName = true)
  {
    return isDisguised ? ::LayersIcon.getIconData("disguised_item")
      : ::LayersIcon.getIconData(null, itemDef.icon_url)
  }

  function getBigIcon()
  {
    if (isDisguised)
      return ::LayersIcon.getIconData("disguised_item")

    local url = !::u.isEmpty(itemDef.icon_url_large) ?
      itemDef.icon_url_large : itemDef.icon_url
    return ::LayersIcon.getIconData(null, url)
  }

  function getOpeningCaption()
  {
    return ::loc(openingCaptionLocId)
  }

  function isAllowSkipOpeningAnim()
  {
    return true
  }

  isCanBuy = @() canBuy && !inventoryClient.getItemCost(id).isZero()

  function getCost(ignoreCanBuy = false)
  {
    if (isCanBuy() || ignoreCanBuy)
      return inventoryClient.getItemCost(id)
    return ::Cost()
  }

  getTransferText = @() transferAmount > 0
    ? ::loc("items/waitItemsInTransaction", { amount = ::colorize("activeTextColor", transferAmount) })
    : ""

  getDescTimers   = @() [
    makeDescTimerData({
      id = "expire_timer"
      getText = getCurExpireTimeText
      needTimer = hasExpireTimer
    }),
    makeDescTimerData({
      id = "marketable_timer"
      getText = getMarketablePropDesc
      needTimer = @() getNoTradeableTimeLeft() > 0
    })
  ]

  function getLongDescriptionMarkup(params = null)
  {
    params = params || {}
    params.receivedPrizes <- false

    if (isDisguised)
      return ExchangeRecipes.getRequirementsMarkup(getMyRecipes(), this, params)

    local content = []
    local headers = [
      { header = getTransferText() }
      { header = getMarketablePropDesc(), timerId = "marketable_timer" }
    ]

    if (hasTimer())
      headers.append({ header = getCurExpireTimeText(), timerId = "expire_timer" })

    if (metaBlk)
    {
      headers.append({ header = ::colorize("grayOptionColor", ::loc(descHeaderLocId)) })
      content = [ metaBlk ]
      params.showAsTrophyContent <- true
      params.receivedPrizes <- false
      params.relatedItem <- id
    }

    params.header <- headers
    return ::PrizesView.getPrizesListView(content, params)
      + ExchangeRecipes.getRequirementsMarkup(getMyRecipes(), this, params)
  }

  function getMarketablePropDesc()
  {
    if (!::has_feature("Marketplace"))
      return ""

    local canSell = itemDef?.marketable
    local noTradeableSec = getNoTradeableTimeLeft()
    local locEnding = !canSell ? "no"
      : noTradeableSec > 0 ? "afterTime"
      : "yes"
    local text = ::loc("item/marketable/" + locEnding,
      { name =  ::g_string.utf8ToLower(getTypeName())
        time = noTradeableSec > 0
          ? ::colorize("badTextColor",
              ::stringReplace(time.hoursToString(time.secondsToHours(noTradeableSec), false, true, true), " ", ::nbsp))
          : ""
      })
    return ::loc("currency/gc/sign/colored", "") + " " +
      ::colorize(canSell ? "userlogColoredText" : "badTextColor", text)
  }

  function getResourceDesc()
  {
    if (!metaBlk || !metaBlk.resource || !metaBlk.resourceType)
      return ""
    local decoratorType = ::g_decorator_type.getTypeByResourceType(metaBlk.resourceType)
    local decorator = ::g_decorator.getDecorator(metaBlk.resource, decoratorType)
    if (!decorator)
      return ""
    return ::g_string.implode([
      decorator.getTypeDesc()
      decorator.getRestrictionsDesc()
    ], "\n")
  }

  function getDescRecipeListHeader(showAmount, totalAmount, isMultipleExtraItems)
  {
    if (showAmount < totalAmount)
      return ::loc("item/create_recipes",
        {
          count = totalAmount
          countColored = ::colorize("activeTextColor", totalAmount)
          exampleCount = showAmount
        })

    local isMultipleRecipes = showAmount > 1
    local headerSuffix = isMultipleRecipes && isMultipleExtraItems  ? "any_of_item_sets"
      : !isMultipleRecipes && isMultipleExtraItems ? "items_set"
      : isMultipleRecipes && !isMultipleExtraItems ? "any_of_items"
      : "item"
    return ::loc(descReceipesListHeaderPrefix + headerSuffix)
  }

  isRare              = @() isDisguised ? base.isRare() : rarity.isRare
  getRarity           = @() isDisguised ? base.getRarity() :rarity.value
  getRarityColor      = @() isDisguised ? base.getRarityColor() :rarity.color
  getTagsLoc          = @() rarity.tag && !isDisguised ? [ rarity.tag ] : []

  canConsume          = @() false
  canAssemble         = @() !isExpired() && getMyRecipes().len() > 0
  canConvertToWarbonds= @() isInventoryItem && !isExpired() && ::has_feature("ItemConvertToWarbond") && amount > 0 && getWarbondRecipe() != null

  function getMainActionName(colored = true, short = false)
  {
    return isCanBuy() ? getBuyText(colored, short)
      : amount && canConsume() ? ::loc("item/consume")
      : canAssemble() ? getAssembleButtonText()
      : ""
  }

  function doMainAction(cb, handler, params = null)
  {
    return buyExt(cb, params)
      || consume(cb, params)
      || assemble(cb, params)
  }

  getAltActionName   = @() amount && canConsume() && canAssemble() ? ::loc("item/assemble")
    : canConvertToWarbonds() ? ::loc("items/exchangeTo", { currency = getWarbondExchangeAmountText() })
    : ""
  doAltAction        = @(params) canConsume() && assemble(null, params) || convertToWarbonds(params)

  function consume(cb, params)
  {
    if (!uids || !uids.len() || !metaBlk || !canConsume())
      return false

    if (shouldAutoConsume)
    {
      consumeImpl(cb, params)
      return true
    }

    local canSell = itemDef?.marketable
    local text = ::loc("recentItems/useItem", { itemName = ::colorize("activeTextColor", getName()) })
      + "\n" + ::loc("msgBox/coupon_exchange")
    local msgboxParams = {
      cancel_fn = @() null
      baseHandler = ::get_cur_base_gui_handler() //FIX ME: handler used only for prizes tooltips
      data_below_text = ::PrizesView.getPrizesListView([ metaBlk ],
        { showAsTrophyContent = true, receivedPrizes = false, widthByParentParent = true })
      data_below_buttons = canSell
        ? ::format("textarea{overlayTextColor:t='warning'; text:t='%s'}", ::g_string.stripTags(::loc("msgBox/coupon_will_be_spent")))
        : null
    }
    local item = this //we need direct link, to not lose action on items list refresh.
    ::scene_msg_box("coupon_exchange", null, text, [
      [ "yes", @() item.consumeImpl(cb, params) ],
      [ "no" ]
    ], "yes", msgboxParams)
    return true
  }

  function consumeImpl(cb = null, params = null)
  {
    local uid = uids?[0]
    if (!uid)
      return

    local blk = ::DataBlock()
    blk.setInt("itemId", uid.tointeger())

    local itemAmountByUid = amountByUids[uid] //to not remove item while in progress
    local taskCallback = function() {
      local item = ::ItemsManager.findItemByUid(uid)
      //items list refreshed, but ext inventory only requested.
      //so update item amount to avoid repeated request before real update
      if (item && item.amountByUids[uid] == itemAmountByUid)
      {
        item.amountByUids[uid]--
        item.amount--
        if (item.amountByUids[uid] <= 0)
        {
          inventoryClient.removeItem(uid)
          if (item.uids?[0] == uid)
            item.uids.remove(0)
        }
      }
      if (cb)
        cb({ success = true })
    }

    local taskId = ::char_send_blk("cln_consume_inventory_item", blk)
    ::g_tasker.addTask(taskId, { showProgressBox = !shouldAutoConsume }, taskCallback)
  }

  getAssembleHeader       = @() ::loc("item/create_header", { itemName = getName() })
  getAssembleText         = @() ::loc("item/assemble")
  getAssembleButtonText   = @() getMyRecipes().len() > 1 ? ::loc("item/recipes") : getAssembleText()
  getCantAssembleLocId    = @() "msgBox/assembleItem/cant"
  getAssembleMessageData  = @(recipe) getEmptyAssembleMessageData().__update({
    text = ::loc("msgBox/assembleItem/confirm", { itemName = ::colorize("activeTextColor", getName()) })
      + (recipe.isMultipleItems ? "\n" + ::loc("msgBox/items_will_be_spent") : "")
    needRecipeMarkup = recipe.isMultipleItems
  })

  function assemble(cb = null, params = null)
  {
    if (!canAssemble())
      return false

    local recipesList = getMyRecipes()
    if (recipesList.len() == 1)
    {
      ExchangeRecipes.tryUse(recipesList, this)
      return true
    }

    local item = this
    recipesListWnd.open({
      recipesList = recipesList
      headerText = getAssembleHeader()
      buttonText = getAssembleText()
      alignObj = params?.obj
      onAcceptCb = function(recipe)
      {
        ExchangeRecipes.tryUse([recipe], item)
        return !recipe.isUsable
      }
    })
    return true
  }

  function getWarbondExchangeAmountText()
  {
    local recipe = getWarbondRecipe()
    if (amount <= 0 || !recipe)
      return ""
    local warbondItem = ::ItemsManager.findItemById(recipe.generatorId)
    local warbond = warbondItem && warbondItem.getWarbond()
    if (!warbond)
      return ""
    return warbondItem.getWarbondsAmount() + ::loc(warbond.fontIcon)
  }

  function convertToWarbonds(params = null)
  {
    if (!canConvertToWarbonds())
      return false
    local recipe = getWarbondRecipe()
    if (amount <= 0 || !recipe)
      return false

    local warbondItem = ::ItemsManager.findItemById(recipe.generatorId)
    local warbond = warbondItem && warbondItem.getWarbond()
    if (!warbond)
      return false

    local leftWbAmount = ::g_warbonds.getLimit() - warbond.getBalance()
    if (leftWbAmount <= 0)
    {
      ::showInfoMsgBox(::loc("items/cantExchangeToWarbondsMessage"))
      return true
    }

    local maxAmount = ::ceil(leftWbAmount.tofloat() / warbondItem.getWarbondsAmount()).tointeger()
    maxAmount = ::min(maxAmount, amount)
    if (maxAmount == 1 || !::has_feature("ItemConvertToWarbondMultiple"))
    {
      convertToWarbondsImpl(recipe, warbondItem, 1)
      return true
    }

    local item = this
    local icon = ::loc(warbond.fontIcon)
    chooseAmountWnd.open({
      parentObj = params?.obj
      align = params?.align ?? "bottom"
      minValue = 1
      maxValue = maxAmount
      curValue = maxAmount
      valueStep = 1

      headerText = ::loc("items/exchangeTo", { currency = icon })
      buttonText = ::loc("items/btnExchange")
      getValueText = @(value) value + " x " + warbondItem.getWarbondsAmount() + icon
        + " = " + value * warbondItem.getWarbondsAmount() + icon

      onAcceptCb = @(value) item.convertToWarbondsImpl(recipe, warbondItem, value)
      onCancelCb = null
    })
    return true
  }

  function convertToWarbondsImpl(recipe, warbondItem, convertAmount)
  {
    local msg = ::loc("items/exchangeMessage", {
      amount = convertAmount
      item = getName()
      currency = convertAmount * warbondItem.getWarbondsAmount() + ::loc(warbondItem.getWarbond()?.fontIcon)
    })
    ::scene_msg_box("warbond_exchange", null, msg, [
      [ "yes", @() recipe.doExchange(warbondItem, convertAmount) ],
      [ "no" ]
    ], "yes", { cancel_fn = @() null })
  }

  function hasLink()
  {
    return !isDisguised && base.hasLink() && ::has_feature("Marketplace")
  }

  function addResources() {
    if (!metaBlk || !metaBlk.resource || !metaBlk.resourceType)
      return
    local resource = metaBlk.resource
    if (!guidParser.isGuid(resource))
      return

    ::g_decorator.buildUgcDecoratorFromResource(metaBlk.resource, metaBlk.resourceType, itemDef)
    ::add_rta_localization(metaBlk.resource, itemDef?.name ?? "")
  }

  function getRelatedRecipes()
  {
    local res = []
    foreach (genItemdefId in inventoryClient.getChestGeneratorItemdefIds(id))
    {
      local gen = ItemGenerators.get(genItemdefId)
      if (gen)
        res.extend(gen.getRecipesWithComponent(id))
    }
    return res
  }

  function getWarbondRecipe()
  {
    foreach (genItemdefId in inventoryClient.getChestGeneratorItemdefIds(id))
    {
      local item = ::ItemsManager.findItemById(genItemdefId)
      if (item?.iType != itemType.WARBONDS)
        continue
      local gen = ItemGenerators.get(genItemdefId)
      if (!gen)
        continue
      local recipes = gen.getRecipesWithComponent(id)
      if (recipes.len())
        return recipes[0]
    }
    return null
  }

  function getMyRecipes()
  {
    local gen = ItemGenerators.get(id)
    return gen ? gen.getRecipes() : []
  }

  function getExpireTimeTextShort()
  {
    return ::colorize("badTextColor", base.getExpireTimeTextShort())
  }

  function getCurExpireTimeText()
  {
    if (expireTimestamp == -1)
      return ""
    return ::colorize("badTextColor", ::loc("items/expireDate", {
      datetime = time.buildDateTimeStr(::get_time_from_t(expireTimestamp))
      timeleft = getExpireTimeTextShort()
    }))
  }

  function needShowActionButtonAlways()
  {
    if (!canAssemble())
      return false

    foreach (recipes in getMyRecipes())
      if (recipes.isUsable)
        return true

    return false
  }

  isGoldPurchaseInProgress = @() ::u.search(itemTransfer.getSendingList(), @(data) (data?.goldCost ?? 0) > 0) != null

  function buyExt(cb = null, params = null)
  {
    if (!isCanBuy())
      return false

    if (isGoldPurchaseInProgress())
    {
      ::g_popups.add(null, ::loc("items/msg/waitPreviousGoldTransaction"), null, null, null, "waitPrevGoldTrans")
      return true
    }

    local blk = ::DataBlock()
    blk.key = ::inventory_generate_key()
    blk.itemDefId = id
    blk.goldCost = getCost().gold

    local onSuccess = function() {
      if (cb)
        cb({ success = true })
    }
    local onError = @(errCode) cb ? cb({ success = false }) : null

    local taskId = ::char_send_blk("cln_inventory_purchase_item", blk)
    ::g_tasker.addTask(taskId, { showProgressBox = true }, onSuccess, onError)
    return true
  }
}

return ItemExternal
