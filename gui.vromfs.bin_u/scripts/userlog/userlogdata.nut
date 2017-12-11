local time = require("scripts/time.nut")


::shown_userlog_notifications <- []

::g_script_reloader.registerPersistentData("UserlogDataGlobals", ::getroottable(), ["shown_userlog_notifications"])

function getLogNameByType(type)
{
  switch (type)
  {
    case ::EULT_SESSION_START:
      return "session_start"
    case ::EULT_EARLY_SESSION_LEAVE:
      return "early_session_leave"
    case ::EULT_SESSION_RESULT:
      return "session_result"
    case ::EULT_AWARD_FOR_PVE_MODE:
      return "award_for_pve_mode"
    case ::EULT_BUYING_AIRCRAFT:
      return "buy_aircraft"
    case ::EULT_BUYING_WEAPON:
      return "buy_weapon"
    case ::EULT_BUYING_WEAPONS_MULTI:
      return "buy_weapons_auto"
    case ::EULT_BUYING_WEAPON_FAIL:
      return "buy_weapon_failed"
    case ::EULT_REPAIR_AIRCRAFT:
      return "repair_aircraft"
    case ::EULT_REPAIR_AIRCRAFT_MULTI:
      return "repair_aircraft_multi"
    case ::EULT_NEW_RANK:
      return "new_rank"
    case ::EULT_NEW_UNLOCK:
      return "new_unlock"
    case ::EULT_BUYING_SLOT:
      return "buy_slot"
    case ::EULT_TRAINING_AIRCRAFT:
      return "train_aircraft"
    case ::EULT_UPGRADING_CREW:
      return "upgrade_crew"
    case ::EULT_SPECIALIZING_CREW:
      return "specialize_crew"
    case ::EULT_PURCHASINGSKILLPOINTS:
      return "purchase_skillpoints"
    case ::EULT_BUYENTITLEMENT:
      return "buy_entitlement"
    case ::EULT_BUYING_MODIFICATION:
      return "buy_modification"
    case ::EULT_BUYING_SPARE_AIRCRAFT:
      return "buy_spare"
    case ::EULT_CLAN_ACTION:
      return "clan_action"
    case ::EULT_BUYING_UNLOCK:
      return "buy_unlock"
    case ::EULT_CHARD_AWARD:
      return "chard_award"
    case ::EULT_ADMIN_ADD_GOLD:
      return "admin_add_gold"
    case ::EULT_ADMIN_REVERT_GOLD:
      return "admin_revert_gold"
    case ::EULT_BUYING_SCHEME:
      return "buying_scheme"
    case ::EULT_BUYING_MODIFICATION_MULTI:
      return "buy_modification_multi"
    case ::EULT_BUYING_MODIFICATION_FAIL:
      return "buy_modification_fail"
    case ::EULT_OPEN_ALL_IN_TIER:
      return "open_all_in_tier"
    case ::EULT_OPEN_TROPHY:
      return "open_trophy"
    case ::EULT_BUY_ITEM:
      return "buy_item"
    case ::EULT_NEW_ITEM:
      return "new_item"
    case ::EULT_ACTIVATE_ITEM:
      return "activate_item"
    case ::EULT_REMOVE_ITEM:
      return "remove_item"
    case ::EULT_TICKETS_REMINDER:
      return "ticket_reminder"
    case ::EULT_BUY_BATTLE:
      return "buy_battle"
    case ::EULT_CONVERT_EXPERIENCE:
      return "convert_exp"
    case ::EULT_SELL_BLUEPRINT:
      return "sell_blueprint"
    case ::EULT_PUNLOCK_NEW_PROPOSAL:
      return "battle_tasks_new_proposal"
    case ::EULT_PUNLOCK_EXPIRED:
      return "battle_tasks_expired"
    case ::EULT_PUNLOCK_ACCEPT:
      return "battle_tasks_accept"
    case ::EULT_PUNLOCK_CANCELED:
      return "battle_tasks_cancel"
    case ::EULT_PUNLOCK_REROLL_PROPOSAL:
      return "battle_tasks_reroll"
    case ::EULT_PUNLOCK_ACCEPT_MULTI:
      return "battle_tasks_multi_accept"
    case ::EULT_CONVERT_BLUEPRINTS:
      return "convert_blueprint"
    case ::EULT_RENT_UNIT:
      return "rent_unit"
    case ::EULT_RENT_UNIT_EXPIRED:
      return "rent_unit_expired"
    case ::EULT_BUYING_RESOURCE:
      return "buy_resource"
    case ::EULT_EXCHANGE_WARBONDS:
      return "exchange_warbonds"
    case ::EULT_INVITE_TO_TOURNAMENT:
      return "invite_to_tournament"
    case ::EULT_WW_START_OPERATION:
      return "ww_start_operation"
    case ::EULT_WW_CREATE_OPERATION:
      return "ww_create_operation"
  }
  return "unknown"
}

function getClanActionName(type)
{
  switch (type)
  {
    case ::ULC_CREATE:               return "create"
    case ::ULC_DISBAND:              return "disband"

    case ::ULC_REQUEST_MEMBERSHIP:   return "request_membership"
    case ::ULC_CANCEL_MEMBERSHIP:    return "cancel_membership"
    case ::ULC_REJECT_MEMBERSHIP:    return "reject_candidate"
    case ::ULC_ACCEPT_MEMBERSHIP:    return "accept_candidate"

    case ::ULC_DISMISS:              return "dismiss_member"
    case ::ULC_CHANGE_ROLE:          return "change_role"
    case ::ULC_CHANGE_ROLE_AUTO:     return "change_role_auto"
    case ::ULC_LEAVE:                return "leave"
    case ::ULC_DISBANDED_BY_LEADER:  return "disbanded_by_leader"

    case ::ULC_ADD_TO_BLACKLIST:     return "add_to_blacklist"
    case ::ULC_DEL_FROM_BLACKLIST:   return "remove_from_blacklist"
    case ::ULC_CHANGE_CLAN_INFO:     return "clan_info_was_changed"
    case ::ULC_CLAN_INFO_WAS_CHANGED:return "clan_info_was_renamed"
    case ::ULC_DISBANDED_BY_ADMIN:   return "clan_disbanded_by_admin"
    case ::ULC_UPGRADE_CLAN:         return "clan_was_upgraded"
    case ::ULC_UPGRADE_MEMBERS:      return "clan_max_members_count_was_increased"
  }
  return "unknown"
}

function get_userlog_image_item(item, params = {})
{
  local defaultParams = {
    enableBackground = false,
    showAction = false,
    showPrice = false,
    showSellAmount = ::getTblValue("type", params, -1) == ::EULT_BUY_ITEM,
    bigPicture = false
    contentIcon = false
  }

  params = ::combine_tables(params, defaultParams)
  return item ? ::handyman.renderCached(("gui/items/item"), { items = item.getViewData(params)}) : ""
}


function get_link_markup(text, url, acccessKeyName=null)
{
  if (!::u.isString(url) || url.len() == 0 || !::has_feature("AllowExternalLink"))
    return ""
  local btnParams = {
    text = text
    isHyperlink = true
    link = url
  }
  if (acccessKeyName && acccessKeyName.len() > 0)
  {
    btnParams.acccessKeyName <- acccessKeyName
  }
  return ::handyman.renderCached("gui/commonParts/button", btnParams)
}


function check_new_user_logs()
{
  local total = ::get_user_logs_count()
  local newUserlogsArray = []
  for(local i=0; i<total; i++)
  {
    local blk = ::DataBlock()
    ::get_user_log_blk_body(i, blk)
    if (blk.disabled || ::isInArray(blk.type, ::hidden_userlogs))
      continue

    local unlockId = ::getTblValue("unlockId", blk.body)
    if (unlockId != null && !::is_unlock_visible(::g_unlocks.getUnlockById(unlockId)))
    {
      ::disable_user_log_entry(i)
      continue
    }

    newUserlogsArray.append(blk)
  }
  return newUserlogsArray
}

function collectOldNotifications()
{
  local total = get_user_logs_count()
  for(local i = 0; i < total; i++)
  {
    local blk = ::DataBlock()
    ::get_user_log_blk_body(i, blk)
    if (!blk.disabled && checkPopupUserLog(blk)
        && !::isInArray(blk.id, ::shown_userlog_notifications))
      ::shown_userlog_notifications.append(blk.id)
  }
}

function checkPopupUserLog(user_log_blk)
{
  if (user_log_blk == null)
    return false
  foreach (popupItem in ::popup_userlogs)
  {
    if (::u.isTable(popupItem))
    {
      if (popupItem.type != user_log_blk.type)
        continue
      local rewardType = user_log_blk.body.rewardType
      local rewardTypeFilter = popupItem.rewardType
      if (typeof(rewardTypeFilter) == "string" && rewardTypeFilter == rewardType)
        return true
      if (typeof(rewardTypeFilter) == "array" && ::isInArray(rewardType, rewardTypeFilter))
        return true
    }
    else if (popupItem == user_log_blk.type)
      return true
  }
  return false
}

function checkAwardsOnStartFrom()
{
  checkNewNotificationUserlogs(true)
}

function checkNewNotificationUserlogs(onStartAwards = false)
{
  if (::getFromSettingsBlk("debug/skipPopups"))
    return
  if (!::g_login.isLoggedIn())
    return
  local handler = ::handlersManager.getActiveBaseHandler()
  if (!handler)
    return //no need to try do something when no one base handler loaded

  local saveJob = false
  local combinedUnitTiersUserLogs = {}
  local trophyRewardsTable = {}
  local rentsTable = {}
  local ignoreRentItems = []
  local total = get_user_logs_count()
  local unlocksNeedsPopupWnd = false

  for(local i = 0; i < total; i++)
  {
    local blk = ::DataBlock()
    ::get_user_log_blk_body(i, blk)

    if (blk.disabled || ::isInArray(blk.id, ::shown_userlog_notifications))
      continue

    //gamercard popups
    if (checkPopupUserLog(blk))
    {
      if (onStartAwards)
        continue

      local title = ""
      local msg = ""
      local logName = getLogNameByType(blk.type)
      if (blk.type == ::EULT_SESSION_RESULT)
      {
        local mission = ""
        if ("locName" in blk.body && blk.body.locName.len() > 0)
          mission = ::get_locId_name(blk.body, "locName")
        else
          mission = ::loc("missions/" + blk.body.mission)
        local nameLoc = "userlog/"+logName + (blk.body.win? "/win":"/lose")
        msg = format(::loc(nameLoc), mission) //need more info in log, maybe title.
        ::my_stats.markStatsReset()
        if (!::isHandlerInScene(::gui_handlers.DebriefingModal))
          ::checkNonApprovedResearches(true, true)
        ::broadcastEvent("BattleEnded", {eventId = blk.body.eventId})
      }
      else if (blk.type == ::EULT_CHARD_AWARD)
      {
        local rewardType = ::getTblValue("rewardType", blk.body)
        if (rewardType == "WagerWin" ||
            rewardType == "WagerFail" ||
            rewardType == "WagerStageWin" ||
            rewardType == "WagerStageFail")
        {
          local itemId = ::getTblValue("id", blk.body)
          local item = ::ItemsManager.findItemById(itemId)
          if (item != null)
          {
            msg = ::isInArray(rewardType, ["WagerStageWin", "WagerStageFail"])
              ? ::loc("userlog/" + rewardType) + ::loc("ui/colon") + ::colorize("userlogColoredText", item.getName())
              : ::loc("userlog/" + rewardType, {wagerName = ::colorize("userlogColoredText", item.getName())})
          }
        }
        else
          continue
      }
      else if (blk.type == ::EULT_EXCHANGE_WARBONDS)
      {
        local awardBlk = blk.body.award
        if (awardBlk)
        {
          local priceText = ::g_warbonds.getWarbondPriceText(
                              blk.body.warbond || "",
                              blk.body.stage || "",
                              awardBlk.cost || ""
                            )
          local awardType = ::g_wb_award_type.getTypeByBlk(awardBlk)
          msg = awardType.getUserlogBuyText(awardBlk, priceText)
          if (awardType.id == ::EWBAT_BATTLE_TASK && awardType.canBuy(awardBlk))
            ::broadcastEvent("BattleTasksIncomeUpdate")
        }
      }
      else
        msg = ::loc("userlog/" + logName)
      ::g_popups.add(title, msg)
      ::shown_userlog_notifications.append(blk.id)
      /*---^^^^---show notifications---^^^^---*/
    }

    if (!::isInMenu()) //other notifications only in the menu
      continue

    local markDisabled = false
    if (blk.type == ::EULT_NEW_UNLOCK)
    {
      if (!blk.body || !blk.body.unlockId)
        continue

      if (blk.body.unlockType == ::UNLOCKABLE_TITLE && !onStartAwards)
        ::my_stats.markStatsReset()

      if (blk.body.unlockType == ::UNLOCKABLE_CHALLENGE)
      {
        local unlock = ::g_unlocks.getUnlockById(blk.body.unlockId)
        if (unlock.showAsBattleTask)
          ::broadcastEvent("PersonalUnlocksRequestUpdate")
      }

      if ((! ::is_unlock_need_popup(blk.body.unlockId)
          && ! ::is_unlock_need_popup_in_menu(blk.body.unlockId))
        || ::isHandlerInScene(::gui_handlers.DebriefingModal))
        continue

      if (::is_unlock_need_popup_in_menu(blk.body.unlockId))
      {
        // if new unlock passes 'is_unlock_need_popup_in_menu'
        // we need to check if there is Popup Dialog
        // needed to be shown by this unlock
        // (check is at verifyPopupBlk)
        ::shown_userlog_notifications.append(blk.id)
        unlocksNeedsPopupWnd = true
        continue
      }

      local unlock = {}
      foreach(name, value in blk.body)
        unlock[name] <- value

      local config = ::build_log_unlock_data(unlock)
      config.disableLogId <- blk.id
      ::showUnlockWnd(config)
      ::shown_userlog_notifications.append(blk.id)
      continue
    }
    else if (blk.type == ::EULT_RENT_UNIT || blk.type == ::EULT_RENT_UNIT_EXPIRED)
    {
      local logTypeName = ::getLogNameByType(blk.type)
      local logName = ::getTblValue("rentContinue", blk.body, false)? "rent_unit_extended" : logTypeName
      local unitName = ::getTblValue("unit", blk.body)
      local unit = ::getAircraftByName(unitName)
      local config = {
        unitName = unitName
        name = ::loc("mainmenu/rent/" + logName)
        desc = ::loc("userlog/" + logName, {unitName = ::getUnitName(unit, false)})
        descAlign = "center"
        popupImage = ""
        disableLogId = blk.id
      }

      if (blk.type == ::EULT_RENT_UNIT)
      {
        config.desc += "\n"

        local rentTimeHours = time.secondsToHours(::getTblValue("rentTimeLeftSec", blk.body, 0))
        local timeText = ::colorize("userlogColoredText", time.hoursToString(rentTimeHours))
        config.desc += ::loc("mainmenu/rent/rentTimeSec", {time = timeText})

        config.desc = ::colorize("activeTextColor", config.desc)
      }

      rentsTable[unitName + "_" + logTypeName] <- config
      markDisabled = true
    }
    else if (blk.type == ::EULT_OPEN_ALL_IN_TIER)
    {
      if (onStartAwards)
        continue
      ::combineUserLogs(combinedUnitTiersUserLogs, blk, "unit", ["expToInvUnit", "expToExcess"])
      markDisabled = true
    }
    else if (blk.type == ::EULT_OPEN_TROPHY
             && !::getTblValue("everyDayLoginAward", blk.body, false))
    {
      if ("rentedUnit" in blk.body)
        ignoreRentItems.append(blk.body.rentedUnit + "_" + ::getLogNameByType(::EULT_RENT_UNIT))

      if (onStartAwards)
        continue

      local key = blk.body.id + "" + ::getTblValue("parentTrophyRandId", blk.body, "")
      if (!(key in trophyRewardsTable))
        trophyRewardsTable[key] <- []

      trophyRewardsTable[key].append(buildTableFromBlk(blk.body))
      markDisabled = true
    }
    else if (blk.type == ::EULT_CHARD_AWARD
             && ::getTblValue("rewardType", blk.body, "") == "EveryDayLoginAward"
             && !::is_me_newbie())
    {
      handler.doWhenActive((@(blk) function() {::gui_start_show_login_award(blk)})(blk))
      markDisabled = true
    }
    else if (blk.type == ::EULT_PUNLOCK_NEW_PROPOSAL)
    {
      ::broadcastEvent("BattleTasksIncomeUpdate")
      markDisabled = true
    }

    if (markDisabled)
    {
      if (::disable_user_log_entry(i))
        saveJob = true
      ::shown_userlog_notifications.append(blk.id)
    }
  }

  if(unlocksNeedsPopupWnd)
    handler.doWhenActive( (@(handler) function() { ::g_popup_msg.showPopupWndIfNeed(handler) })(handler))

  if (saveJob)
  {
    dagor.debug("checkNewNotificationUserlogs - needSave")
    ::save_online_job()
  }

  if (trophyRewardsTable.len() > 0)
  {
    if (onStartAwards)
      handler.doWhenActive((@(trophyRewardsTable) function() { ::gui_start_open_trophy(trophyRewardsTable) })(trophyRewardsTable))
    else
      ::gui_start_open_trophy(trophyRewardsTable)
  }

  foreach(key, config in rentsTable)
    if (!::isInArray(key, ignoreRentItems))
    {
      if (onStartAwards)
        handler.doWhenActive((@(config) function() {::showUnlockWnd(config)})(config))
      else
        ::showUnlockWnd(config)
    }

  if (handler)
    foreach(name, table in combinedUnitTiersUserLogs)
    {
      if (onStartAwards)
        handler.doWhenActive((@(table) function() {::gui_start_mod_tier_researched(table)})(table))
      else
        ::gui_start_mod_tier_researched(table)
    }
}

function combineUserLogs(currentData, newUserLog, combineKey = null, sumParamsArray = [])
{
  local body = newUserLog.body
  if (!body)
    return

  if (combineKey)
    combineKey = body[combineKey]

  if (!combineKey)
    combineKey = newUserLog.id

  if (!(combineKey in currentData))
    currentData[combineKey] <- {}

  foreach(param, value in body)
  {
    local haveParam = ::getTblValue(param, currentData[combineKey])
    if (!haveParam)
      currentData[combineKey][param] <- [value]
    else if (::isInArray(param, sumParamsArray))
      currentData[combineKey][param][0] += value
    else if (!::isInArray(value, currentData[combineKey][param]))
      currentData[combineKey][param].append(value)
  }
}

function checkCountry(country, assertText, country_0_available = false)
{
  if (!country || country=="")
    return false
  if (country == "country_0")
    return country_0_available
  if (::isInArray(country, ::shopCountriesList))
    return true
  return false
}

/**
 * Function runs over all userlogs and collects all userLog items,
 * which satisfies filters conditions.
 *
 * @param filter (table) - filters. May contain conditions:
 *   show (array) - array of userlog type IDs (starts from EULT) which should
 *                  be included to result.
 *   hide (array) - array of userlog type IDs (starts from EULT) which should
 *                  be excluded from result.
 *   currentRoomOnly (boolean) - include only userlogs related to current
 *                               game session. Mainly for debriefing.
 *   unlocks (array) - array of unlock type IDs.
 *   filters (table) - any custom key -> value pairs to filter userlogs
 *   disableVisible (boolean) - marks all related userlogs as seen
 */
function isUserlogVisible(blk, filter, idx)
{
  if (blk.type == null)
    return false
  if (("show" in filter) && !::isInArray(blk.type, filter.show))
    return false
  if (("hide" in filter) && ::isInArray(blk.type, filter.hide))
    return false
  if (("checkFunc" in filter) && !filter.checkFunc(blk))
    return false
  if (::getTblValue("currentRoomOnly", filter, false) && !::is_user_log_for_current_room(idx))
    return false
  return true
}

function getUserLogsList(filter)
{
  local logs = [];
  local total = ::get_user_logs_count()
  local needSave = false

  /**
   * If statick tournament reward exist in log, writes it to logs root
   */
  local grabStatickReward = function (reward, log)
  {
    if (reward.awardType == "base_win_award")
    {
      log.baseTournamentWp <- ::getTblValue("wp", reward, 0)
      log.baseTournamentGold <- ::getTblValue("gold", reward, 0)
      return true
    }
    return false
  }

  for(local i = total - 1; i >= 0; i--)
  {
    local blk = ::DataBlock()
    ::get_user_log_blk_body(i, blk)

    if (!::isUserlogVisible(blk, filter, i))
      continue

    local isUnlockTypeNotSuitable = "unlockType" in blk.body
                                    && (blk.body.unlockType == ::UNLOCKABLE_TROPHY_PSN
                                        || ("unlocks" in filter) && !::isInArray(blk.body.unlockType, filter.unlocks))

    local unlock = ::g_unlocks.getUnlockById(::getTblValue("unlockId", blk.body))
    local hideUnlockById = unlock != null && !::is_unlock_visible(unlock)

    if (isUnlockTypeNotSuitable || hideUnlockById)
      continue

    local log = {
      idx = i
      type = blk.type
      time = get_user_log_time(i)
      enabled = !blk.disabled
      roomId = blk.roomId
    }

    for (local i = 0, c = blk.body.paramCount(); i < c; i++)
    {
      local key = blk.body.getParamName(i)
      if (key in log)
        key = "body_" + key
      log[key] <- blk.body.getParamValue(i)
    }
    for (local i = 0, c = blk.body.blockCount(); i < c; i++)
    {
      local block = blk.body.getBlock(i)
      local name = block.getBlockName()

      //can be 2 aircrafts with the same name (cant foreach)
      //trophyMultiAward logs have spare in body too. they no need strange format hacks.
      if (name == "aircrafts"
          || (name == "spare" && !::PrizesView.isPrizeMultiAward(blk.body)))
      {
        (name in log) || (log[name] <- [])
        for (local j = 0; j < block.paramCount(); j++)
          log[name].append({name = block.getParamName(j), value = block.getParamValue(j)})
      }
      else if (name == "rewardTS")
      {
        local reward = ::buildTableFromBlk(block)
        if (!grabStatickReward(reward, log))
        {
          (name in log) || (log[name] <- [])
          log[name].append(reward)
        }
      }
      else if (block instanceof ::DataBlock)
        log[name] <- ::buildTableFromBlk(block)
    }

    local skip = false
    if ("filters" in filter)
      foreach(f, values in filter.filters)
        if (!::isInArray((f in log)? log[f] : null, values))
        {
          skip = true
          break
        }

    if (skip)
      continue

    logs.append(log)

    if ("disableVisible" in filter && filter.disableVisible)
    {
      if (::disable_user_log_entry(i))
        needSave = true
    }
  }

  if (needSave)
  {
    dagor.debug("getUserLogsList - needSave")
    ::save_online_job()
  }
  return logs;
}

function get_decorator_unlock(resourceId, resourceType)
{
  local unlock = ::create_default_unlock_data()
  local decoratorType = null
  unlock.id = resourceId
  decoratorType = ::g_decorator_type.getTypeByResourceType(resourceType)
  if (decoratorType != ::g_decorator_type.UNKNOWN)
  {
    unlock.name = decoratorType.getLocName(unlock.id, true)
    unlock.desc = decoratorType.getLocDesc(unlock.id)
    unlock.image = decoratorType.userlogPurchaseIcon

    local decorator = ::g_decorator.getDecorator(unlock.id, decoratorType)
    if (decorator && !::is_in_loading_screen())
    {
      unlock.descrImage <- decoratorType.getImage(decorator)
      unlock.descrImageRatio <- decoratorType.getRatio(decorator)
      unlock.descrImageSize <- decoratorType.getImageSize(decorator)
    }
  }

  return unlock
}
