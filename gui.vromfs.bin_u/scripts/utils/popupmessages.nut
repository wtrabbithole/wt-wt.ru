local time = require("scripts/time.nut")
local platformModule = require("scripts/clientState/platform.nut")
local promoConditions = require("scripts/promo/promoConditions.nut")

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
  local t = stringDate ? time.getTimestampFromStringUtc(stringDate) : -1
  return t >= 0 ? t : defaultValue
}


function g_popup_msg::ps4ActivityFeedFromPopup(blk)
{
  if (blk.ps4ActivityFeedType != "update")
    return null

  local ver = split(::get_game_version_str(), ".")
  local feed = {
    config = {
      locId = "major_update"
      subType = ps4_activity_feed.MAJOR_UPDATE
    }
    params = {
      blkParamName = "MAJOR_UPDATE"
      imgSuffix = "_" + ver[0] + "_" + ver[1]
      forceLogo = true
      captions = { en = blk.name }
      condensedCaptions = { en = blk.name }
    }
  }

  foreach(name, val in blk)
  {
    if (::g_string.startsWith(name, "name_"))
    {
      local lang = name.slice(5)
      feed.params.captions[lang] <- val
      feed.params.condensedCaptions[lang] <- val
    }
  }

  return feed
}

function g_popup_msg::verifyPopupBlk(blk, hasModalObject, needDisplayCheck = true)
{
  local popupId = blk.getBlockName()

  if (needDisplayCheck)
  {
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

    if (blk.pollId && ::g_webpoll.isPollVoted(blk.pollId))
      return null

    local viewType = blk.viewType || POPUP_VIEW_TYPES.NEVER
    local viewDay = ::loadLocalByAccount("popup/" + (blk.saveId ?? popupId), 0)
    local canShow = (viewType == POPUP_VIEW_TYPES.EVERY_SESSION)
                    || (viewType == POPUP_VIEW_TYPES.ONCE && !viewDay)
                    || (viewType == POPUP_VIEW_TYPES.EVERY_DAY && viewDay < days)
    if (!canShow || !promoConditions.isVisibleByConditions(blk))
    {
      passedPopups[popupId] <- true
      return null
    }

    local secs = ::get_charserver_time_sec()
    if (getTimeIntByString(blk.startTime, 0) > secs)
      return null

    if (getTimeIntByString(blk.endTime, 2114380800) < secs)
    {
      passedPopups[popupId] <- true
      return null
    }
  }

  local localizedTbl = {name = platformModule.getPlayerName(::my_user_name), uid = ::my_user_id_str}
  local popupTable = { name = "" }
  foreach (key in ["name", "desc", "link", "linkText", "actionText"])
  {
    local text = ::g_language.getLocTextFromConfig(blk, key, "")
    if (text != "")
      popupTable[key] <- text.subst(localizedTbl)
  }
  popupTable.popupImage <- ::g_language.getLocTextFromConfig(blk, "image", "")
  popupTable.ratioHeight <- blk.imageRatio || null
  popupTable.forceExternalBrowser <- blk.forceExternalBrowser || false
  popupTable.action <- blk.action

  if (blk.pollId)
    popupTable.pollId <- blk.pollId

  local ps4ActivityFeedData = ps4ActivityFeedFromPopup(blk)
  if (ps4ActivityFeedData)
    popupTable.ps4ActivityFeedData <- ps4ActivityFeedData

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
      ::showUnlockWnd(popupConfig)
      ::saveLocalByAccount("popup/" + (popupBlk.saveId ?? popupId), days)
      result = true
    }
  }
  return result
}

function g_popup_msg::showPopupDebug(dbgId)
{
  local popupsBlk = ::get_gui_regional_blk().popupItems
  if (!::u.isDataBlock(popupsBlk))
  {
    dlog("POPUP ERROR: No popupItems in gui_regional_blk")
    return false
  }

  for (local i = 0; i < popupsBlk.blockCount(); i++)
  {
    local popupBlk = popupsBlk.getBlock(i)
    local popupId = popupBlk.getBlockName()
    if (popupId != dbgId)
      continue

    local popupConfig = verifyPopupBlk(popupBlk, false, false)
    ::showUnlockWnd(popupConfig)
    return true
  }
  dlog("POPUP ERROR: Not found " + dbgId)
  return false
}

::g_script_reloader.registerPersistentDataFromRoot("g_popup_msg")
