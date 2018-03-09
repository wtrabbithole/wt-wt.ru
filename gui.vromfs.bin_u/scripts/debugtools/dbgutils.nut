::callstack <- dagor.debug_dump_stack

function reload()
{
  return ::g_script_reloader.reload(::reload_main_script_module)
}

function get_stack_string(level = 2)
{
  return ::toString(getstackinfos(level), 2)
}

function print_func_and_enum_state_string(enumString, currentState)
{
  dlog(::getstackinfos(2).func + " " + ::getEnumValName(enumString, currentState))
}

function charAddAllItems(count = 1)
{
  local params = {
    items = ::ItemsManager.getItemsList()
    currentIndex = 0
    count = count
  }
  ::_charAddAllItemsHelper(params)
}

function _charAddAllItemsHelper(params)
{
  if (params.currentIndex >= params.items.len())
    return
  local item = params.items[params.currentIndex]
  local blk = ::DataBlock()
  blk.setStr("what", "addItem")
  blk.setStr("item", item.id)
  blk.addInt("howmuch", params.count);
  local taskId = ::char_send_blk("dev_hack", blk)
  if (taskId == -1)
    return
  ::add_bg_task_cb(taskId, (@(params) function () {
    ++params.currentIndex
    if ((params.currentIndex == params.items.len() ||
         params.currentIndex % 10 == 0) &&
         params.currentIndex != 0)
      ::dlog(::format("Adding items: %d/%d", params.currentIndex, params.items.len()))
    _charAddAllItemsHelper(params)
  })(params))
}

//must to be switched on before we get to debrifing.
//but after it you can restart derifing with full recalc by usual reload()
function switch_on_debug_debriefing_recount()
{
  if ("_stat_get_exp" in ::getroottable())
    return

  ::_stat_get_exp <- ::stat_get_exp
  ::_stat_get_exp_cache <- null
  ::stat_get_exp <- function()
  {
    ::_stat_get_exp_cache = ::_stat_get_exp() || ::_stat_get_exp_cache
    return ::_stat_get_exp_cache
  }
}

function debug_reload_and_restart_debriefing()
{
  local rows = ::debriefing_rows
  local result = ::debriefing_result
  ::reload()

  local recountFunc = ::gather_debriefing_result
  local canRecount = "_stat_get_exp" in ::getroottable()
  if (!canRecount)
  {
    ::gather_debriefing_result = function() {}
    ::debriefing_rows = rows
    ::debriefing_result = result
  }

  gui_start_debriefingFull()

  if (!canRecount)
    ::gather_debriefing_result = recountFunc
}

function debug_debriefing_unlocks(unlocksAmount = 5)
{
  ::gui_start_debriefingFull({ debugUnlocks = unlocksAmount })
}

function debug_get_every_day_login_award_userlog(skip = 0, launchWindow = true)
{
  local total = get_user_logs_count()
  for (local i = total-1; i > 0; i--)
  {
    local blk = ::DataBlock()
    ::get_user_log_blk_body(i, blk)

    if (blk.type == ::EULT_CHARD_AWARD && ::getTblValue("rewardType", blk.body, "") == "EveryDayLoginAward")
    {
      if (skip > 0)
      {
        skip--
        continue
      }

      if (launchWindow)
        ::gui_start_show_login_award(blk)
      else
      {
        dlog("PRINT EVERY DAY LOGIN AWARD")
        ::debugTableData(blk)
      }
      return
    }
  }
  dlog("!!!! NOT FOUND ANY EVERY DAY LOGIN AWARD")
}

function debug_debriefing_result_dump_save(filename = "debriefing_results_dump.blk")
{
  if (!::debriefing_result || ::dbg_dump.isLoaded())
    return "IGNORED: No debriefing_result, or dump is loaded."

  local list = [
    { id = "stat_get_exp", value = ::getTblValue("expDump", ::debriefing_result, {}) }
    "get_game_type"
    "get_game_mode"
    "get_current_mission_info_cached"
    { id = "_fake_get_current_mission_desc", value = function() { local b = ::DataBlock(); ::get_current_mission_desc(b); return b } }
    { id = "_fake_mplayers_list", value = ::getTblValue("mplayers_list", ::debriefing_result, []) }
    { id = "dynamic_apply_status", value = ::dynamic_result }
    { id = "get_mission_status", value = ::getTblValue("isSucceed", ::debriefing_result) ? ::MISSION_STATUS_SUCCESS : ::MISSION_STATUS_RUNNING }
    { id = "get_mission_restore_type", value = ::getTblValue("restoreType", ::debriefing_result, 0) }
    { id = "get_local_player_country", value = ::getTblValue("country", ::debriefing_result, "") }
    { id = "get_mp_session_id", value = ::getTblValue("sessionId", ::debriefing_result, ::get_mp_session_id()) }
    { id = "get_mp_tbl_teams", value = ::getTblValue("mpTblTeams", ::debriefing_result, ::get_mp_tbl_teams()) }
    { id = "_fake_sessionlobby_unit_type_mask", value = ::debriefing_result?.unitTypesMask }
    { id = "stat_get_benchmark", value = ::getTblValue("benchmark", ::debriefing_result, ::stat_get_benchmark()) }
    { id = "get_race_winners_count", value = ::getTblValue("numberOfWinningPlaces", ::debriefing_result, 0) }
    { id = "get_race_best_lap_time", value = ::getTblValueByPath("exp.ptmBestLap", ::debriefing_result, -1) }
    { id = "get_race_lap_times", value = ::getTblValueByPath("exp.ptmLapTimesArray", ::debriefing_result, []) }
    { id = "get_mp_local_team", value = ::debriefing_result?.localTeam ?? ::get_mp_local_team() }
    { id = "get_player_army_for_hud", value = ::debriefing_result?.friendlyTeam ?? ::get_player_army_for_hud() }
    { id = "_fake_sessionlobby_settings", value = ::SessionLobby.settings }
    "LAST_SESSION_DEBUG_INFO"
    "get_mission_mode"
    "get_mission_difficulty_int"
    "get_premium_reward_wp"
    "get_premium_reward_xp"
    "is_replay_turned_on"
    "is_replay_present"
    "is_replay_saved"
    "is_worldwar_enabled"
    "ww_is_operation_loaded"
    "ww_get_operation_id"
    "ww_get_operation_winner"
    "ww_get_player_side"
    "havePremium"
    "shop_get_countries_list_with_autoset_units"
    "shop_get_units_list_with_autoset_modules"
    { id = "abandoned_researched_items_for_session", value = [] }
    { id = "get_gamechat_log_text", value = ::getTblValue("chatLog", ::debriefing_result, "") }
    { id = "is_multiplayer", value = ::getTblValue("isMp", ::debriefing_result, false) }
    { id = "_fake_battlelog", value = ::HudBattleLog.battleLog }
    { id = "_fake_userlogs", value = ::getTblValue("roomUserlogs", ::debriefing_result, []) }
    { id = "get_user_logs_count", value = ::getTblValue("roomUserlogs", ::debriefing_result, []).len() }
  ]

  local units = []
  local mods  = []
  local exp = ::getTblValue("expDump", ::debriefing_result, {})
  foreach (ut in ::g_unit_type.types)
  {
    local unitId = ::getTblValue("investUnitName" + ut.name, exp, "")
    if (unitId != "")
      units.append([ unitId ])
  }
  foreach (unitId, data in ::getTblValue("aircrafts", exp, {}))
  {
    if (!::getAircraftByName(unitId))
      continue
    units.append([ unitId ])
    local modId = ::getTblValue("investModuleName", data, "")
    if (modId != "")
      mods.append([ unitId, modId ])
  }
  foreach (tbl in ::shop_get_countries_list_with_autoset_units())
  {
    local unitId = ::getTblValue("unit", tbl, "")
    local unit = ::getAircraftByName(unitId)
    local args = [ ::getUnitCountry(unit), ::get_es_unit_type(unit) ]
    foreach (id in [ "shop_get_researchable_unit_name", "shop_get_country_excess_exp" ])
      list.append({ id = id, args = args })
    units.append([ unitId ])
  }
  foreach (tbl in ::shop_get_units_list_with_autoset_modules())
    mods.append([ ::getTblValue("name", tbl, ""), ::getTblValue("mod", tbl, "") ])
  foreach (args in units)
    foreach (id in [ "shop_is_player_has_unit", "shop_is_aircraft_purchased", "shop_unit_research_status",
      "shop_get_researchable_module_name", "shop_get_unit_exp", "shop_get_unit_excess_exp",
      "shop_is_unit_rented", "rented_units_get_expired_time_sec" ])
        list.append({ id = id, args = args })
  foreach (args in mods)
    foreach (id in [ "shop_is_modification_enabled", "shop_is_modification_purchased",
      "shop_get_module_research_status", "shop_get_module_exp" ])
        list.append({ id = id, args = args })

  ::dbg_dump.save(filename, list)
  return "Debriefing result saved to " + filename
}

function debug_debriefing_result_dump_load(filename = "debriefing_results_dump.blk")
{
  if (!::dbg_dump.load(filename))
    return "File not found: " + filename

  ::dbg_dump.loadFuncs({
    is_user_log_for_current_room = function(idx) { return true }
    get_user_log_blk_body = function(idx, outBlk) { outBlk.setFrom(::getTblValue(idx, ::_fake_userlogs, ::DataBlock())) }
    get_user_log_time = function(idx) { return ::get_local_time() }
    disable_user_log_entry = function(idx) {}
    autosave_replay = @() null
    on_save_replay = @(fn) true
    is_era_available = function(...) { return true }
    get_current_mission_desc = function(outBlk) {
      local src = ::getTblValue("_fake_get_current_mission_desc", ::getroottable(), ::get_current_mission_info_cached())
      outBlk.setFrom(src)
    }
    get_mplayers_list = function(team, full) {
      local res = []
      foreach (v in ::_fake_mplayers_list)
        if (team == ::GET_MPLAYERS_LIST || v.team == team)
          res.append(v)
      return (res)
    }
    get_local_mplayer = function() {
      foreach (v in ::_fake_mplayers_list)
        if (v.isLocal)
          return v
      return ::dbg_dump.getOriginal("get_local_mplayer")()
    }
    is_unlocked = function(unlockType, unlockId) {
      foreach (log in _fake_userlogs)
        if (::getTblValueByPath("body.unlockId", log) == unlockId)
          return true
      return ::dbg_dump.getOriginal("is_unlocked")(unlockType, unlockId)
    }
  }, false)

  ::SessionLobby.settings = ::_fake_sessionlobby_settings
  ::SessionLobby.getUnitTypesMask = @() ::getroottable()?._fake_sessionlobby_unit_type_mask ?? 0
  ::HudBattleLog.battleLog = ::_fake_battlelog

  local _is_in_flight = ::is_in_flight
  ::is_in_flight = function() { return true }
  ::g_mis_custom_state.isCurRulesValid = false
  ::g_mis_custom_state.getCurMissionRules()
  ::is_in_flight = _is_in_flight

  ::gui_start_debriefingFull()
  ::checkNonApprovedResearches(true, true)
  ::go_debriefing_next_func = function() { ::dbg_dump.unload(); ::gui_start_mainmenu() }
  ::broadcastEvent("SessionDestroyed")
  return "Debriefing result loaded from " + filename
}

function debug_dump_inventory_save(filename = "debug_dump_inventory.blk")
{
  local inventoryClient = require("scripts/inventory/inventoryClient.nut")
  ::dbg_dump.save(filename, [
    { id = "_inventoryClient_items",    value = inventoryClient.items }
    { id = "_inventoryClient_itemdefs", value = inventoryClient.itemdefs }
  ])
  return "Saved " + filename
}

function debug_dump_inventory_load(filename = "debug_dump_inventory.blk")
{
  if (!::dbg_dump.load(filename))
    return "File not found: " + filename
  ::dbg_dump.loadFuncs({
    inventory = { request  = @(...) null }
  }, false)
  local inventoryClient = require("scripts/inventory/inventoryClient.nut")
  inventoryClient.itemdefs = ::_inventoryClient_itemdefs
  inventoryClient.items    = ::_inventoryClient_items
  ::broadcastEvent("ItemDefChanged")
  ::broadcastEvent("ExtInventoryChanged")
  return "Loaded " + filename
}

function show_hotas_window_image()
{
  ::gui_start_image_wnd(::loc("thrustmaster_tflight_hotas_4_controls_image", ""), 1.41)
}

function debug_export_unit_weapons_descriptions()
{
  _debug_export_unit_weapons_descriptions_impl(::DataBlock())
}

function _debug_export_unit_weapons_descriptions_impl(resBlk, idx = 0)
{
  local wpCost = ::get_wpcost_blk()
  for(local i = idx; i < wpCost.blockCount(); i++)
  {
    if (!(i % 10) && i != idx) //avoid freeze
    {
      dlog("GP: " + i + " done.")
      ::get_gui_scene().performDelayed(this, (@(resBlk, i) function() {
        ::_debug_export_unit_weapons_descriptions_impl(resBlk, i)
      })(resBlk, i))
      return
    }

    local uBlk = wpCost.getBlock(i)
    local unit = ::getAircraftByName(uBlk.getBlockName())
    if (!unit)
      continue

    local blk = ::DataBlock()
    foreach(weapon in unit.weapons)
      if (!::isWeaponAux(weapon))
      {
        blk[weapon.name + "_short"] <- ::getWeaponNameText(unit, false, weapon.name, ", ")
        local rowsList = ::split(::getWeaponInfoText(unit, false, weapon.name), "\n")
        foreach(row in rowsList)
          blk[weapon.name] <- row
        local rowsList = ::split(::getWeaponInfoText(unit, false, weapon.name, "\n", INFO_DETAIL.EXTENDED), "\n")
        foreach(row in rowsList)
          blk[weapon.name + "_extended"] <- row
        local rowsList = ::split(::getWeaponInfoText(unit, null, weapon.name, "\n", INFO_DETAIL.FULL), "\n")
        foreach(row in rowsList)
          blk[weapon.name + "_full"] <- row
      }

    resBlk[unit.name] <- blk
  }

  local filePath = "export/unitsWeaponry.blk"
  ::dd_mkpath(filePath)
  resBlk.saveToTextFile(filePath)
}

function dbg_ww_destroy_cur_operation()
{
  if (!::ww_is_operation_loaded())
    return ::dlog("No operation loaded!")

  local blk = ::DataBlock()
  blk.operationId = ::ww_get_operation_id().tointeger()
  blk.status = 3 //ES_FAILED
  ::g_tasker.charSimpleAction("adm_ww_set_operation_status", blk, { showProgressBox = true },
                              function() {
                                ::dlog("success")
                                ::g_world_war.stopWar()
                                ::g_ww_global_status.refreshData(0)
                              },
                              function() { ::dlog("Do you have admin rights? ") }
                             )
}

function gui_do_debug_unlock()
{
  ::debug_unlock_all();
  ::is_debug_mode_enabled = true
  ::update_all_units();
  ::add_warpoints(500000, false);
}

function dbg_loading_brief(missionName = "malta_ship_mission", slidesAmount = 0)
{
  local missionBlk = ::get_meta_mission_info_by_name(missionName)
  if (!::u.isDataBlock(missionBlk))
    return dlog("Not found mission " + missionName)

  local filePath = missionBlk.mis_file
  local fullBlk = filePath && ::DataBlock(filePath)
  if (!::u.isDataBlock(fullBlk))
    return dlog("Not found mission blk " + filePath)

  local briefing = fullBlk.mission_settings && fullBlk.mission_settings.briefing
  if (!::u.isDataBlock(briefing) || !briefing.blockCount())
    return dlog("Mission does not have briefing")

  local briefingClone = ::DataBlock()
  if (slidesAmount <= 0)
    briefingClone.setFrom(briefing)
  else
  {
    local slidesLeft = slidesAmount
    local parts = briefing % "part"
    local partsClone = []
    for(local i = parts.len()-1; i >= 0; i--)
    {
      local part = parts[i]
      local partClone = ::DataBlock()
      local slides = part % "slide"
      if (slides.len() <= slidesLeft)
      {
        partClone.setFrom(part)
        slidesLeft -= slides.len()
      }
      else
        for(local j = slides.len()-slidesLeft; j < slides.len(); j++)
        {
          local slide = slides[j]
          local slideClone = ::DataBlock()
          slideClone.setFrom(slide)
          partClone["slide"] <- slideClone
          slidesLeft--
        }

      partsClone.insert(0, partClone)
      if (slidesLeft <= 0)
        break
    }

    foreach(part in partsClone)
      briefingClone["part"] <- part
  }

  ::handlersManager.loadHandler(::gui_handlers.LoadingBrief, { briefing = briefingClone })
}

function dbg_ps4updater_open(isProd = false)
{
  local restoreData = {
    ps4_start_updater = ps4_start_updater
    ps4_stop_updater = ps4_stop_updater
  }

  ps4_stop_updater <- (@(restoreData) function() {
    foreach(name, func in restoreData)
      getroottable()[name] = func
  })(restoreData)

  local updaterData = {
                        handler = null
                        callback = null
                        eta_sec = 100000
                        percent = 0
                        onUpdate = function(obj = null, dt = null)
                        {
                          eta_sec -= 100
                          if(handler.stage == -1)
                            callback.call(handler, ::UPDATER_CB_STAGE, ::UPDATER_DOWNLOADING, 0, 0)
                          if(percent < 100)
                            percent += 0.1
                          callback.call(handler, ::UPDATER_CB_PROGRESS, percent, ::math.frnd() * 112048 + 1360000, eta_sec)
                        }
                      }

  ps4_start_updater <- (@(updaterData) function(configPath, handler, updaterCallback) {
    updaterData.handler = handler
    updaterData.callback = updaterCallback

    local fooTimerObj = "dummy { id:t = 'debug_loading_timer'; behavior:t = 'Timer'; timer_handler_func:t = 'onUpdate' }"
    handler.guiScene.appendWithBlk(handler.scene, fooTimerObj, null)
    local curTimerObj = handler.scene.findObject("debug_loading_timer")
    curTimerObj.setUserData(updaterData)
  })(updaterData)

  ::gui_start_modal_wnd(::gui_handlers.PS4UpdaterModal,
  {
    configPath = isProd ? "/app0/ps4/updater.blk" : "/app0/ps4/updater_dev.blk"
  })

  ::dbg_ps4updater_close <- (@(updaterData) function() {
    if( ! updaterData || ! updaterData.handler || ! updaterData.callback)
      return
    updaterData.callback.call(updaterData.handler, ::UPDATER_CB_FINISH, 0, 0, 0)
  })(updaterData)
}

function debug_show_units_by_loc_name(unitLocName, needIncludeNotInShop = false)
{
  local units = ::find_units_by_loc_name(unitLocName, true, needIncludeNotInShop)
  units.sort(function(a, b) { return a.name == b.name ? 0 : a.name < b.name ? -1 : 1 })

  local res = ::u.map(units, function(unit) {
    local locName = ::getUnitName(unit)
    local army = unit.unitType.getArmyLocName()
    local country = ::loc(::getUnitCountry(unit))
    local rank = ::get_roman_numeral(::getUnitRank(unit))
    local prem = (::isUnitSpecial(unit) || ::isUnitGift(unit)) ? ::loc("shop/premiumVehicle/short") : ""
    local hidden = !unit.isInShop ? ::loc("controls/NA") : ::is_unit_visible_in_shop(unit) ? "" : ::loc("worldWar/hided_logs")
    return unit.name + "; \"" + locName + "\" (" + ::g_string.implode([ army, country, rank, prem, hidden ], ", ") + ")"
  })

  foreach (line in res)
    dlog(line)
  return res.len()
}

function debug_show_unit(unitId)
{
  local unit = ::getAircraftByName(unitId)
  if (!unit)
    return "Not found"
  ::show_aircraft = unit
  ::gui_start_decals()
  return "Done"
}

function debug_change_language(isNext = true)
{
  local list = ::g_language.getGameLocalizationInfo()
  local curLang = ::get_current_language()
  local curIdx = ::u.searchIndex(list, @(l) l.id == curLang, 0)
  local newIdx = curIdx + (isNext ? 1 : -1 + list.len())
  local newLang = list[newIdx % list.len()]
  ::g_language.setGameLocalization(newLang.id, true, false)
  dlog("Set language: " + newLang.id)
}

function debug_multiply_color(colorStr, multiplier)
{
  local res = ::g_dagui_utils.multiplyDaguiColorStr(colorStr, multiplier)
  ::copy_to_clipboard(res)
  return res
}

function debug_get_last_userlogs(num = 1)
{
  local total = ::get_user_logs_count()
  local array = []
  for (local i = total - 1; i > (total - num - 1); i--)
  {
    local blk = ::DataBlock()
    ::get_user_log_blk_body(i, blk)
    ::dlog("print userlog " + ::getLogNameByType(blk.type) + " " + blk.id)
    ::debugTableData(blk)
    array.append(blk)
  }
  return array
}

function to_pixels(value)
{
  return ::g_dagui_utils.toPixels(::get_cur_gui_scene(), value)
}

function debug_reset_unseen()
{
  ::require("scripts/seen/seenList.nut").clearAllSeenData()
}