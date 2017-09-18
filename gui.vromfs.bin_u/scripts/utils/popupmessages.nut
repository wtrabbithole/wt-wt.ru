local time = require("scripts/time.nut")


enum POPUP_VIEW_TYPES {
  NEVER = "never"
  EVERY_SESSION = "every_session"
  EVERY_DAY = "every_day"
  ONCE = "once"
}

::g_popup_msg <- {
  [PERSISTENT_DATA_PARAMS] = ["passedPopups"]

  passedPopups = {}
  days = 0
}

function getTimeIntByString(stringDate, defaultValue = 0)
{
  local timeTbl = stringDate && time.getTimeFromStringUtc(stringDate)
  if (!timeTbl)
    return defaultValue

  return ::get_t_from_utc_time(timeTbl)
}

function g_popup_msg::verifyPopupBlk(blk, hasModalObject)
{
  local popupId = blk.getBlockName()
  if (popupId in passedPopups)
    return null

  if (hasModalObject && !blk.getBool("showOverModalObject", false))
    return null

  if (blk.reqFeature && !::has_feature(blk.reqFeature))
    return null

  if (blk.reqUnlock && !::is_unlocked_scripted(-1, blk.reqUnlock))
    return null

  if (!::g_partner_unlocks.isPartnerUnlockAvailable(blk.partnerUnlock, blk.partnerUnlockDurationMin))
    return null

  if (!::g_language.isAvailableForCurLang(blk))
    return null

  local viewType = blk.viewType || POPUP_VIEW_TYPES.NEVER
  local viewDay = ::loadLocalByAccount("popup/" + popupId, 0)
  local canShow = viewType == POPUP_VIEW_TYPES.EVERY_SESSION ||
                  viewType == POPUP_VIEW_TYPES.ONCE && !viewDay ||
                  viewType == POPUP_VIEW_TYPES.EVERY_DAY && viewDay < days
  if (!canShow)
  {
    passedPopups[popupId] <- true
    return null
  }

  local secs = ::get_t_from_utc_time(::get_local_time())
  if (getTimeIntByString(blk.startTime, 0) > secs)
    return null

  if (getTimeIntByString(blk.endTime, 2114380800) < secs)
  {
    passedPopups[popupId] <- true
    return null
  }

  local localizedTbl = {name = ::my_user_name, uid = ::my_user_id_str}
  local popupTable = { name = "" }
  foreach (key in ["name", "desc", "link", "linkText"])
  {
    local text = ::g_language.getLocTextFromConfig(blk, key, "")
    if (text != "")
      popupTable[key] <- ::replaceParamsInLocalizedText(text, localizedTbl)
  }
  popupTable.popupImage <- ::g_language.getLocTextFromConfig(blk, "image", "")
  popupTable.ratioHeight <- blk.imageRatio || null

  return popupTable
}

function g_popup_msg::showPopupWndIfNeed(hasModalObject)
{
  days = time.getUtcDays()
  if (!::get_gui_regional_blk())
    return false

  local popupsBlk = ::get_gui_regional_blk().popupItems
  if (!::u.isDataBlock(popupsBlk))
    return false

  local result = false
  for(local i = 0; i < popupsBlk.blockCount(); i++)
  {
    local popupBlk = popupsBlk.getBlock(i)
    local popupId = popupBlk.getBlockName()
    local popupConfig = verifyPopupBlk(popupBlk, hasModalObject)
    if (popupConfig)
    {
      passedPopups[popupId] <- true
      popupConfig["type"] <- "regionalPromoPopup"
      showUnlockWnd(popupConfig)
      ::saveLocalByAccount("popup/" + popupId, days)
      result = true
    }
  }
  return result
}

::g_script_reloader.registerPersistentDataFromRoot("g_popup_msg")
