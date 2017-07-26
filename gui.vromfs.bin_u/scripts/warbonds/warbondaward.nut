class ::WarbondAward
{
  idx = 0
  awardType = ::g_wb_award_type[::EWBAT_INVALID]
  warbondWeak = null
  blk = null
  maxBoughtCount = 0

  //special params for award view
  needAllBoughtIcon = true

  constructor(warbond, awardBlk, idxInWbList)
  {
    idx = idxInWbList
    warbondWeak = warbond.weakref()
    blk = ::DataBlock()
    blk.setFrom(awardBlk)
    awardType = ::g_wb_award_type.getTypeByBlk(blk)
    maxBoughtCount = awardType.getMaxBoughtCount(blk)
  }

  function isValid()
  {
    return warbondWeak != null
  }

  function getFullId()
  {
    if (!warbondWeak)
      return ""
    return warbondWeak.getFullId() + ::g_warbonds.FULL_ID_SEPARATOR + idx
  }

  function getLayeredImage()
  {
    return awardType.getLayeredImage(blk)
  }

  function getDescriptionImage()
  {
    return awardType.getDescriptionImage(blk)
  }

  function getCost()
  {
    return blk.cost || 0
  }

  function getCostText()
  {
    if (!warbondWeak)
      return ""
    return warbondWeak.getPriceText(getCost())
  }

  function canBuy()
  {
    if (!isValid())
      return false
    return (maxBoughtCount <= 0
            || maxBoughtCount > awardType.getBoughtCount(warbondWeak, blk))
  }

  function getBuyText(isShort = true)
  {
    local res = ::loc("mainmenu/btnBuy")
    if (isShort)
      return res

    local cost = getCost()
    local costText = warbondWeak ? warbondWeak.getPriceText(cost) : cost
    return res + ((costText == "")? "" : ::loc("ui/parentheses/space", { text = costText }))
  }

  function buy()
  {
    if (!isValid())
      return
    if (!canBuy())
      return ::showInfoMsgBox(::loc("warbond/msg/alreadyBoughtMax",
                                    { purchase = ::colorize("userlogColoredText", getNameText()) }))

    local costWb = getCost()
    local balanceWb = warbondWeak.getBalance()
    if (costWb > balanceWb)
      return ::showInfoMsgBox(::loc("not_enough_currency",
                                    { currency = warbondWeak.getPriceText(costWb - balanceWb, true, false) }))


    local msgText = ::loc("onlineShop/needMoneyQuestion",
                          { purchase = ::colorize("userlogColoredText", getNameText()),
                            cost = ::colorize("activeTextColor", getCostText())
                          })

    ::scene_msg_box("purchase_ask", null, msgText,
      [
        ["purchase", ::Callback(_buy, this) ],
        ["cancel", function() {} ]
      ],
      "purchase",
      { cancel_fn = function() {} }
    )
  }

  function _buy()
  {
    if (!isValid())
      return

    local taskId = awardType.requestBuy(warbondWeak, blk)
    local cb = ::Callback(onBought, this)
    ::g_tasker.addTask(taskId, {showProgressBox = true}, cb)
  }

  function onBought()
  {
    ::update_gamercards()
    ::broadcastEvent("WarbondAwardBought", { award = this })
  }

  function isAllBought()
  {
    return maxBoughtCount > 0 && awardType.getBoughtCount(warbondWeak, blk) >= maxBoughtCount
  }

  function getAvailableAmountText()
  {
    if (maxBoughtCount <= 0 || !isValid())
      return ""

    local leftAmount = maxBoughtCount - awardType.getBoughtCount(warbondWeak, blk)
    if (leftAmount <= 0)
      return ::colorize("warningTextColor", ::loc("warbond/alreadyBoughtMax"))
    if (!awardType.showAvailableAmount)
      return ""
    return ::loc("warbond/availableForPurchase") + ::loc("ui/colon") + leftAmount
  }

  function addAmountTextToDesc(desc)
  {
    return ::implode([getAvailableAmountText(), desc], "\n\n")
  }

  function fillItemDesc(descObj, handler)
  {
    local item = awardType.getDescItem(blk)
    if (!item)
      return false

    ::ItemsManager.fillItemDescr(item, descObj, handler, true, true,
                                 { descModifyFunc = addAmountTextToDesc.bindenv(this) })
    return true
  }

  function getDescText()
  {
    return addAmountTextToDesc(awardType.getDescText(blk))
  }

  function hasCommonDesc() { return awardType.hasCommonDesc }
  function getNameText()   { return awardType.getNameText(blk) }

  /******************* params override to use in item.tpl ***********************************/
  function modActionName() { return canBuy() ? getBuyText(true) : null }
  function price() { return getCostText() }
  function contentIconData() { return awardType.getContentIconData(blk) }
  function tooltipId() { return awardType.getTooltipId(blk) }
  function amount() { return blk.amount }
  function itemIndex() { return getFullId() }
  function headerText() { return awardType.getIconHeaderText(blk) }
  /************************** end of params override ****************************************/
}