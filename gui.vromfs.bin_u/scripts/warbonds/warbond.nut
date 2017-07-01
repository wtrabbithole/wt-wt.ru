class ::Warbond
{
  id = ""
  listId = ""
  fontIcon = "currency/warbond"

  blkListPath = ""
  isListValid = false
  awardsList = null

  expiredTime = -1 //time to which you can spend warbonds
  canEarnTime = -1 //time to witch you can earn warbonds. (time to witch isCurrent will be true)

  updateRequested = false //warbond will be full reloaded after request complete

  constructor(wbId, wbListId)
  {
    id = wbId
    listId = wbListId
    blkListPath = "warbonds/" + id + "/" + listId

    awardsList = []

    local pBlk = ::get_price_blk()
    local listBlk = ::get_blk_value_by_path(pBlk, blkListPath)
    if (!::u.isDataBlock(listBlk))
      return

    fontIcon = ::g_warbonds.getWarbondFontIcon(id, listId)

    expiredTime = listBlk.expiredTime || -1
    canEarnTime = listBlk.endTime || -1
  }

  function getFullId()
  {
    return id + ::g_warbonds.FULL_ID_SEPARATOR + listId
  }

  function isCurrent() //warbond than can be received right now
  {
    return ::get_warbond_curr_stage_name(id) == listId
  }

  function isVisible()
  {
    return isCurrent() || getBalance() > 0
  }

  function validateList()
  {
    if (isListValid)
      return

    isListValid = true
    awardsList.clear()

    local pBlk = ::get_price_blk()
    local config = ::get_blk_value_by_path(pBlk, blkListPath + "/shop")
    if (!::u.isDataBlock(config))
      return

    local total = config.blockCount()
    for(local i = 0; i < total; i++)
      awardsList.append(::WarbondAward(this, config.getBlock(i), i))
  }

  function getAwardsList()
  {
    validateList()
    return awardsList
  }

  function getAwardById(awardId)
  {
    local idx = ::to_integer_safe(awardId, -1)
    return ::getTblValue(idx, getAwardsList())
  }

  function getPriceText(amount, needShowZero = false, needColorByBalance = true)
  {
    if (!amount && !needShowZero)
      return ""

    local res = amount
    if (needColorByBalance && amount > getBalance())
      res = ::colorize("badTextColor", res)
    return res + ::loc(fontIcon)
  }

  function getBalance()
  {
    return ::get_warbonds_count(id, listId)
  }

  function getBalanceText()
  {
    return getPriceText(getBalance(), true, false)
  }

  function getExpiredTimeLeft()
  {
    return expiredTime > 0 ? expiredTime - ::get_charserver_time_sec() : 0
  }

  function getCanEarnTimeLeft()
  {
    return canEarnTime > 0 ? canEarnTime - ::get_charserver_time_sec() : 0
  }

  function getChangeStateTimeLeft()
  {
    local res = isCurrent() ? getCanEarnTimeLeft() : getExpiredTimeLeft()
    if (res < 0) //invalid warbond - need price update
    {
      ::configs.PRICE.update(null, null, false, !updateRequested) //forceUpdate request only once
      updateRequested = true
    }
    return res
  }
}