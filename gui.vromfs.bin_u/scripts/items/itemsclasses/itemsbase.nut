/* Item API:
  getCost                    - return item cost
  buy(cb, handler)            - buy item, call cb when buy success
  getViewData()               - generate item view data for item.tpl
  getContentIconData()        - return table to fill contentIconData in visual item
                                { contentIcon, [contentType] }
  getAmount()

  getName()
  getNameMarkup()             - type icon and title as markup, with full tooltip
  getIcon()                   - main functions for item image
  getSmallIconName()          - small icon for using insede the text
  getBigIcon()
  getOpenedIcon()             - made for trophies-like items
  getOpenedBigIcon()
  getDescription()
  getShortDescription()        - assume that it will be name and short decription info
                               better up to 30 letters approximatly
  getLongDescription()         - unlimited length description as text.
  getLongDescriptionMarkup(params)   - unlimited length description as markup.
  getDescriptionTitle()
  getItemTypeDescription(loc_params)     - show description of item type in tooltip of "?" image
  getShortItemTypeDescription() - show short description of item type above item image

  getDescriptionAboveTable()  - return description part right above table.
  getDescriptionUnderTable()   - Returns description part which is placed under the table.
                                 Both table and this description part are optional.

  getStopConditions()          - added for boosters, but perhaps, it have in some other items

  getMainActionName(colored = true, short = false)
                                    - get main action name (short will be on item button)
  doMainAction(cb, handler)         - do main action. (buy, activate, etc)

  canStack(item)                    - (bool) compare with item same type can it be stacked in one
  updateStackParams(stackParams)     - update stack params to correct show stack name //completely depend on itemtype
  getStackName(stackParams)         - get stack name by stack params
  isForEvent(checkEconomicName)     - check is checking event id is for current item (used in tickets for now)
*/


local time = require("scripts/time.nut")

::items_classes <- {}

class ::BaseItem
{
  id = ""
  static iType = itemType.UNKNOWN
  static defaultLocId = "unknown"
  static defaultIcon = "#ui/gameuiskin#items_silver_bg"
  static defaultIconStyle = null
  static typeIcon = "#ui/gameuiskin#item_type_placeholder"
  static linkActionLocId = "mainmenu/btnBrowser"
  static linkActionIcon = ""
  static isPreferMarkupDescInTooltip = false
  static isDescTextBeforeDescDiv = true

  static includeInRecentItems = true
  static hasRecentItemConfirmMessageBox = true

  blkType = ""
  canBuy = false
  isInventoryItem = false
  allowBigPicture = true
  iconStyle = ""
  shopFilterMask = null

  uids = null //only for inventory items
  expiredTimeSec = 0 //to comapre with 0.001 * ::dagor.getCurTime()
  expiredTimeAfterActivationH = 0
  spentInSessionTimeMin = 0
  lastChangeTimestamp = -1

  amount = 1
  sellCountStep = 1

  // Empty string means no purchase feature.
  purchaseFeature = ""
  isDevItem = false

  locId = null
  showBoosterInSeparateList = false

  link = ""
  static linkBigQueryKey = "item_shop"
  forceExternalBrowser = false

  // Zero means no limit.
  limitGlobal = 0
  limitPersonalTotal = 0
  limitPersonalAtTime = 0

  isToStringForDebug = true

  constructor(blk, invBlk = null, slotData = null)
  {
    id = blk.getBlockName() || (invBlk && invBlk.id) || ""
    locId = blk.locId
    blkType = blk.type
    isInventoryItem = invBlk != null
    purchaseFeature = ::getTblValue("purchase_feature", blk, "")
    isDevItem = !isInventoryItem && purchaseFeature == "devItemShop"
    canBuy = canBuy && !isInventoryItem && getCost() > ::zero_money && checkPurchaseFeature()
    iconStyle = blk.iconStyle || id
    link = blk.link || ""
    forceExternalBrowser = blk.forceExternalBrowser || false

    shopFilterMask = iType
    local types = blk % "additionalShopItemType"
    foreach(type in types)
      shopFilterMask = shopFilterMask | ::ItemsManager.getInventoryItemType(type)

    expiredTimeAfterActivationH = blk.expiredTimeHAfterActivation || 0

    if (isInventoryItem)
    {
      uids = ::getTblValue("uids", slotData, [])
      amount = ::getTblValue("count", slotData, 1)
      if (invBlk.expiredTime)
        expiredTimeSec = invBlk.expiredTime + 0.001 * ::dagor.getCurTime()
    } else
    {
      sellCountStep = blk.sell_count_step || 1
      limitGlobal = blk.limitGlobal || 0
      limitPersonalTotal = blk.limitPersonalTotal || 0
      limitPersonalAtTime = blk.limitPersonalAtTime || 0
    }
  }

  function getLimitData()
  {
    return ::g_item_limits.getLimitDataByItemName(id)
  }

  function checkPurchaseFeature()
  {
    return purchaseFeature == "" || ::has_feature(purchaseFeature)
  }

  function getDebugName()
  {
    local myClass = getclass()
    foreach(name, iClass in ::items_classes)
      if (myClass == iClass)
        return name
    return "BaseItem"
  }

  function _tostring()
  {
    return ::format("Item %s (id = %s)", getDebugName(), id.tostring())
  }

  function isCanBuy()
  {
    return canBuy
  }

  function getCost(ignoreCanBuy = false)
  {
    if (isCanBuy() || ignoreCanBuy)
      return ::Cost(::wp_get_item_cost(id), ::wp_get_item_cost_gold(id)).multiply(getSellAmount())
    return ::Cost()
  }

  function getIcon(addItemName = true)
  {
    return ::LayersIcon.getIconData(iconStyle + "_shop", defaultIcon, 1.0, defaultIconStyle)
  }

  function getSmallIconName()
  {
    return typeIcon
  }

  function getBigIcon()
  {
    return getIcon()
  }

  function getOpenedIcon()
  {
    return getIcon()
  }

  function getOpenedBigIcon()
  {
    return getBigIcon()
  }

  function setIcon(obj, params = {})
  {
    if (!::checkObj(obj))
      return

    local bigPicture = ::getTblValue("bigPicture", params, false)

    local addItemName = ::getTblValue("addItemName", params, true)
    local imageData = bigPicture? getBigIcon() : getIcon(addItemName)
    if (!imageData)
      return

    local guiScene = obj.getScene()
    obj.doubleSize = bigPicture? "yes" : "no"
    guiScene.replaceContentFromText(obj, imageData, imageData.len(), null)
  }

  function getName(colored = true)
  {
    local name = ::loc("item/" + id, ::loc("item/" + defaultLocId))
    if (locId != null)
      name = ::loc(locId, name)
    return name
  }

  function getTypeName()
  {
    return ::loc("item/" + defaultLocId)
  }

  function getNameMarkup(count = 0, showTitle = true)
  {
    return ::handyman.renderCached("gui/items/itemString", {
      title = showTitle? colorize("activeTextColor",getName()) : null
      icon = typeIcon
      tooltipId = ::g_tooltip.getIdItem(id)
      count = count > 1? (colorize("activeTextColor", " x") + colorize("userlogColoredText", count)) : null
    })
  }

  function getDescriptionTitle()
  {
    return getName()
  }

  function getAmount()
  {
    return amount
  }

  function getSellAmount()
  {
    return sellCountStep
  }

  function getShortItemTypeDescription()
  {
    return ::loc("item/" + id + "/shortTypeDesc", ::loc("item/" + blkType + "/shortTypeDesc", ""))
  }

  function getItemTypeDescription(loc_params = {})
  {
    local idText = ""
    if (locId != null)
    {
      idText = ::loc(locId, locId + "/typeDesc", loc_params)
      if (idText != "")
        return idText
    }

    idText = ::loc("item/" + id + "/typeDesc", "", loc_params)
    if (idText != "")
      return idText

    idText = ::loc("item/" + blkType + "/typeDesc", "", loc_params)
    if (idText != "")
      return idText

    return ""
  }

  function getDescription()
  {
    return ::loc("item/" + id + "/desc", "")
  }

  function getDescriptionUnderTable() { return "" }
  function getDescriptionAboveTable() { return "" }
  function getLongDescriptionMarkup(params = null) { return "" }
  function getStopConditions() { return "" }

  function getLongDescription() { return getDescription() }

  function getShortDescription(colored = true) { return getName(colored) }

  function isActive(...) { return false }

  function getViewData(params = {})
  {
    local openedPicture = ::getTblValue("openedPicture", params, false)
    local bigPicture = ::getTblValue("bigPicture", params, false)
    local addItemName = ::getTblValue("addItemName", params, true)
    local res = {
      layered_image = openedPicture? (bigPicture? getOpenedBigIcon() : getOpenedIcon()) : bigPicture? getBigIcon() : getIcon(addItemName)
      enableBackground = ::getTblValue("enableBackground", params, true)
      isItemLocked = ::getTblValue("isItemLocked", params, false)
    }

    if (::getTblValue("showTooltip", params, true))
      res.tooltipId <- isInventoryItem && uids && uids.len()
                       ? ::g_tooltip.getIdInventoryItem(uids[0])
                       : ::g_tooltip.getIdItem(id)

    if (::getTblValue("showPrice", params, true))
      res.price <- getCost().getTextAccordingToBalance()

    if (::getTblValue("showAction", params, true))
    {
      local actionText = getMainActionName(true, true)
      if (actionText != "" && getLimitsCheckData().result)
        res.modActionName <- actionText
    }

    foreach(paramName, value in params)
      res[paramName] <- value

    local amountVal = ::getTblValue("count", params) || getAmount()
    if (amountVal > 1)
      res.amount <- amountVal

    if (::getTblValue("showSellAmount", params, false))
    {
      local sellAmount = getSellAmount()
      if (sellAmount > 1)
        res.amount <- sellAmount
    }

    if (hasTimer() && ::getTblValue("hasTimer", params, true))
      res.expireTime <- getTimeLeftText()

    if (isRare())
      res.rarityColor <- getRarityColor()

    if (isActive())
      res.active <- true

    res.hasButton <- ::getTblValue("hasButton", params, true)
    res.onClick <- ::getTblValue("onClick", params, null)
    res.hasHoverBorder <- ::getTblValue("hasHoverBorder", params, false)

    if (::getTblValue("contentIcon", params, true))
      res.contentIconData <- getContentIconData()

    return res
  }

  function getContentIconData()
  {
    return null
  }

  function hasLink()
  {
    return link != "" && ::has_feature("AllowExternalLink")
  }

  function openLink()
  {
    if (!hasLink())
      return
    local validLink = ::g_url.validateLink(link)
    if (validLink)
      ::open_url(validLink, forceExternalBrowser, false, linkBigQueryKey)
  }

  function _requestBuy(params = {})
  {
    local blk = ::DataBlock()
    blk.setStr("name", id)
    blk.setInt("count", ::getTblValue("count", params, getSellAmount()))

    return ::char_send_blk("cln_buy_item", blk)
  }

  function _buy(cb, params = {})
  {
    if (!isCanBuy() || !check_balance_msgBox(getCost()))
      return false

    local item = this
    local onSuccessCb = (@(cb, item) function() {
      ::update_gamercards()
      item.forceRefreshLimits()
      if (cb) cb({
        success = true
        item = this
      })
      ::broadcastEvent("ItemBought", { item = item })
    })(cb, item)
    local onErrorCb = (@(item) function(res) { item.forceRefreshLimits() })(item)

    local taskId = _requestBuy(params)
    ::g_tasker.addTask(taskId, { showProgressBox = true }, onSuccessCb, onErrorCb)
    return taskId >= 0
  }

  function buy(cb, handler = null, params = {})
  {
    if (!isCanBuy() || !check_balance_msgBox(getCost()))
      return false

    handler = handler || ::get_cur_base_gui_handler()

    local name = getName()
    local price = getCost().getTextAccordingToBalance()
    local msgText = ::loc("onlineShop/needMoneyQuestion",
                          { purchase = name, cost = price })
    local item = this
    handler.msgBox("need_money", msgText,
          [["purchase", (@(item, cb, params) function() { item._buy(cb, params) })(item, cb, params) ],
          ["cancel", function() {} ]], "purchase")

    return true
  }

  function getBuyText(colored, short)
  {
    local res = ::loc("mainmenu/btnBuy")
    if (short)
      return res

    local cost = getCost()
    local costText = colored? cost.getTextAccordingToBalance() : cost.getUncoloredText()
    return res + ((costText == "")? "" : " (" + costText + ")")
  }

  function getMainActionName(colored = true, short = false)
  {
    if (isCanBuy())
      return getBuyText(colored, short)
    return ""  //open, but no such function on host yet.
  }

  function doMainAction(cb, handler, params = null)
  {
    return buy(cb, handler, params)
  }

  function hasTimer()
  {
    return expiredTimeSec > 0
  }

  function canPreview()
  {
    return false
  }

  function doPreview()
  {
  }

  function getTimeLeftText()
  {
    if (expiredTimeSec <= 0)
      return ""
    local curSeconds = ::dagor.getCurTime() * 0.001
    local deltaSeconds = (expiredTimeSec - curSeconds).tointeger()
    if (deltaSeconds < 0)
    {
      ::ItemsManager.markInventoryUpdateDelayed()
      return ::loc("items/expired")
    }
    return ::loc("icon/hourglass") + " " + time.hoursToString(time.secondsToHours(deltaSeconds), false, true, true)
  }

  function getExpireAfterActivationText(withTitle = true)
  {
    local res = ""
    if (!expiredTimeAfterActivationH)
      return res

    res = time.hoursToString(expiredTimeAfterActivationH, true, false, true)
    if (withTitle)
      res = ::loc("items/expireTimeAfterActivation") + ::loc("ui/colon") + ::colorize("activeTextColor", res)
    return res
  }

  function getCurExpireTimeText()
  {
    local res = ""
    local active = isActive()
    if (!active)
      res += getExpireAfterActivationText()

    local timeText = getTimeLeftText()
    if (timeText != "")
    {
      local locId = active ? "items/expireTimeLeft" : "items/expireTimeBeforeActivation"
      res += ((res!="") ? "\n" : "") + ::loc(locId) + ::loc("ui/colon") + ::colorize("activeTextColor", timeText)
    }
    return res
  }

  function getTableData()
  {
    return null
  }

  function canStack(item)
  {
    return false
  }

  function updateStackParams(stackParams) {}

  function getContent() { return [] }

  function getStackName(stackParams)
  {
    return getShortDescription()
  }

  function hasLimits()
  {
    return (limitGlobal > 0 || limitPersonalTotal > 0 || limitPersonalAtTime > 0) && !::ItemsManager.ignoreItemLimits
  }

  function forceRefreshLimits()
  {
    if (hasLimits())
      ::g_item_limits.requestLimitsForItem(id, true)
  }

  function getLimitsDescription()
  {
    if (isInventoryItem || !hasLimits())
      return ""

    local limitData = getLimitData()
    local locParams = null
    local textParts = []
    if (limitGlobal > 0)
    {
      locParams = {
        itemsLeft = ::colorize("activeTextColor", (limitGlobal - limitData.countGlobal))
      }
      textParts.push(::loc("items/limitDescription/limitGlobal", locParams))
    }
    if (limitPersonalTotal > 0)
    {
      locParams = {
        itemsPurchased = ::colorize("activeTextColor", limitData.countPersonalTotal)
        itemsTotal = ::colorize("activeTextColor", limitPersonalTotal)
      }
      textParts.push(::loc("items/limitDescription/limitPersonalTotal", locParams))
    }
    if (limitPersonalAtTime > 0 && limitData.countPersonalAtTime >= limitPersonalAtTime)
      textParts.push(::loc("items/limitDescription/limitPersonalAtTime"))
    return ::g_string.implode(textParts, "\n")
  }

  function getLimitsCheckData()
  {
    local data = {
      result = true
      reason = ""
    }
    if (!hasLimits())
      return data

    local limitData = getLimitData()
    foreach (name in ["Global", "PersonalTotal", "PersonalAtTime"])
    {
      local limitName = ::format("limit%s", name)
      local limitValue = ::getTblValue(limitName, this, 0)
      local countName = ::format("count%s", name)
      local countValue = ::getTblValue(countName, limitData, 0)
      if (0 < limitValue && limitValue <= countValue)
      {
        data.result = false
        data.reason = ::loc(::format("items/limitDescription/maxedOut/limit%s", name))
        break
      }
    }
    return data
  }

  function getGlobalLimitText()
  {
    if (limitGlobal == 0)
      return ""

    local limitData = getLimitData()
    if (limitData.countGlobal == -1)
      return ""

    local leftCount = limitGlobal - limitData.countGlobal
    local limitText = ::format("%s/%s", leftCount.tostring(), limitGlobal.tostring())
    local locParams = {
      ticketsLeft = ::colorize("activeTextColor", limitText)
    }
    return ::loc("items/limitDescription/globalLimitText", locParams)
  }

  function isForEvent(checkEconomicName = "")
  {
    return false
  }

  static function isRare() { return false }
  static function getRarity() { return 0 }
  static function getRarityColor() { return "" }
}
