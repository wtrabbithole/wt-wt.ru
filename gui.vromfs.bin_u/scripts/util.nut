local time = require("scripts/time.nut")
local penalty = require("penalty")
local penalties = require("scripts/penitentiary/penalties.nut")

::usageRating_amount <- [0.0003, 0.0005, 0.001, 0.002]
::allowingMultCountry <- [1.5, 2, 2.5, 3, 4, 5]
::allowingMultAircraft <- [1.3, 1.5, 2, 2.5, 3, 4, 5, 10]
::fakeBullets_prefix <- "fake"
const NOTIFY_EXPIRE_PREMIUM_ACCOUNT = 15
::EATT_UNKNOWN <- -1

::current_campaign_id <- null
::current_campaign_mission <- null
::current_wait_screen <- null
::msg_box_selected_elem <- null
::slotbar_oninit <- false

::mp_stat_handler <- null
::statscreen_handler <- null
::tactical_map_handler <- null
::flight_menu_handler <- null
::postfx_settings_handler <- null
::credits_handler <- null
::is_in_leaderboard_menu <- false
::gui_start_logout_scheduled <- false

::delayed_gblk_error_popups <- []

::g_script_reloader.registerPersistentData("util", ::getroottable(),
  ["current_campaign_id", "current_campaign_mission"])

::nbsp <- " " // Non-breaking space character

::dagui_propid.add_name_id("tooltipId")

::cssColorsMapDark <- {
  ["commonTextColor"] = "black",
  ["white"] = "black",
  ["activeTextColor"] = "activeTextColorDark",
  ["unlockActiveColor"] = "activeTextColorDark",
  ["highlightedTextColor"] = "activeTextColorDark",
  ["goodTextColor"] = "goodTextColorDark",
  ["badTextColor"] = "badTextColorDark",
  ["userlogColoredText"] = "userlogColoredTextDark",
  ["fadedTextColor"] = "fadedTextColorDark",
  ["warningTextColor"] = "warningTextColorDark",
  ["currencyGoldColor"] = "currencyGoldColorDark",
  ["currencyWpColor"] = "currencyWpColorDark",
  ["currencyRpColor"] = "currencyRpColorDark",
  ["currencyFreeRpColor"] = "currencyFreeRpColorDark",
  ["hotkeyColor"] = "hotkeyColorDark",
  ["axisSymbolColor"] = "axisSymbolColorDark",
}
::cssColorsMapLigth <- {}
foreach (i, v in ::cssColorsMapDark)
    ::cssColorsMapLigth[v] <- i

::global_max_players_versus <- 64
::global_max_players_coop <- 4

function get_blk_by_path_array(path, blk, defaultValue = null)
{
  local currentBlk = blk
  for (local i = 0; i < path.len(); ++i)
  {
    if (typeof(currentBlk) == "instance" && currentBlk instanceof ::DataBlock)
      currentBlk = currentBlk[path[i]]
    else
      return defaultValue
  }
  return currentBlk
}

function get_blk_value_by_path(blk, path, defVal=null)
{
  if (!blk || !path)
    return defVal

  local nodes = ::split(path, "/")
  local key = nodes.len() ? nodes.pop() : null
  if (!key || !key.len())
    return defVal

  blk = ::get_blk_by_path_array(nodes, blk, defVal)
  if (blk == defVal || !::u.isDataBlock(blk))
    return defVal
  local val = blk[key]
  val = (val!=null && (defVal == null || type(val) == type(defVal))) ? val : defVal
  return val
}

function getFromSettingsBlk(path, defVal=null)
{
  // Important: On production, settings blk does NOT contain all variables from config.blk, use getSystemConfigOption() instead.
  local blk = ::get_settings_blk()
  local val = ::get_blk_value_by_path(blk, path)
  return (val != null) ? val : defVal
}

function isInArray(v, arr)
{
  foreach(i in arr)
    if (v==i)
      return true
  return false
}


function replaceParamsInLocalizedText(localizedString, param)
{
  foreach (field, value in param)
  {
    localizedString = ::stringReplace(localizedString, "{"+field+"}", "" + value)

    if (!::u.isInteger(value) && !::u.isInt64(value))
      continue
    local startToken = "{"+field+"="
    local start = 0
    while (true)
    {
      start = localizedString.find(startToken, start)
      if (start == null)
        break
      local end = localizedString.find("}", start)
      if (end == null)
        break
      local pluralForms = localizedString.slice(start + startToken.len(), end)
      local plurals = ::split(pluralForms, "/")
      local idx = ::g_language.getPluralNounFormIdx(value)
      local form = plurals.len() ? plurals[clamp(idx, 0, plurals.len() - 1)] : ""
      localizedString = localizedString.slice(0, start) + form + localizedString.slice(end + 1)
      start += form.len() + 1
    }
  }
  return localizedString
}

function locOrStrip(text)
{
  return (text.len() && text.slice(0,1)!="#")? ::g_string.stripTags(text) : text
}

function get_gamepad_specific_localization(locId)
{
  if (!::show_console_buttons)
    return ::loc(locId)

  return ::loc(locId + "/gamepad_specific", locId)
}
::cross_call_api.get_gamepad_specific_localization <- ::get_gamepad_specific_localization


function locEnding(locId, ending, defValue = null)
{
  local res = ::loc(locId + ending, "")
  if (res == "" && ending!="")
    res = ::loc(locId, defValue)
  return res
}

function getCompoundedText(firstPart, secondPart, color)
{
  return firstPart + colorize(color, secondPart)
}

function colorize(color, text)
{
  text = text.tostring()
  if (!color.len() || !text.len())
    return text

  local firstSymbol = color.slice(0, 1)
  if (firstSymbol != "@" && firstSymbol != "#")
    color = "@" + color
  return ::format("<color=%s>%s</color>", color, text)
}

function get_filtered_aircrafts_list(team)
{
  local tags = ::aircrafts_filter_tags
  local arr = []
  foreach(unit in ::all_units)
  {
    local isNotFound = false
    for (local j = 0; j < tags.len(); j++)
      if (::find_in_array(unit.tags, tags[j]) < 0)
      {
        isNotFound = true
        break
      }

    if (!isNotFound)
      arr.append(unit.name)
  }

  return arr
}

function getAircraftByName(name)
{
  return ::getTblValue(name, ::all_units)
}


::current_wait_screen_txt <- ""
function show_wait_screen(txt)
{
  dagor.debug("GuiManager: show_wait_screen "+txt)
  if (::checkObj(::current_wait_screen))
  {
    if (::current_wait_screen_txt == txt)
      return dagor.debug("already have this screen, just ignore")

    dagor.debug("wait screen already exist, remove old one.")
    ::current_wait_screen.getScene().destroyElement(::current_wait_screen)
    ::current_wait_screen = null
    ::reset_msg_box_check_anim_time()
  }

  local guiScene = ::get_main_gui_scene()
  if (guiScene == null)
    return dagor.debug("guiScene == null")

  local needAnim = ::need_new_msg_box_anim()
  ::current_wait_screen = guiScene.loadModal("", "gui/waitBox.blk", needAnim ? "massTransp" : "div", null)
  if (!::checkObj(::current_wait_screen))
    return dagor.debug("Error: failed to create wait screen")

  local obj = ::current_wait_screen.findObject("wait_screen_msg")
  if (!::checkObj(obj))
    return dagor.debug("Error: failed to find wait_screen_msg")

  obj.setValue(::loc(txt))
  ::current_wait_screen_txt = txt
  ::broadcastEvent("WaitBoxCreated")
}

function close_wait_screen()
{
  dagor.debug("close_wait_screen")
  if (!::checkObj(::current_wait_screen))
    return

  local guiScene = ::current_wait_screen.getScene()
  guiScene.destroyElement(::current_wait_screen)
  ::current_wait_screen = null
  ::reset_msg_box_check_anim_time()
  ::broadcastEvent("ModalWndDestroy")

  guiScene.performDelayed(getroottable(), ::update_msg_boxes)
}

function on_lost_controller()
{
  ::add_msg_box("cannot_session", ::loc("pl1/lostController"), [["ok", function() {}]], "ok")
}

function on_cannot_create_session()
{
  ::add_msg_box("cannot_session", ::loc("NET_CANNOT_CREATE_SESSION"), [["ok", function() {}]], "ok")
}

::in_on_lost_psn <- false

// leaved for future ps3/ps4 realisation
function on_lost_psn()
{
  dagor.debug("on_lost_psn")
  local guiScene = ::get_gui_scene()
  local handler = ::current_base_gui_handler
  if (handler == null)
    return

  ::remove_scene_box("connection_failed")

  if (guiScene["list_no_sessions_create"] != null)
  {
    ::remove_scene_box("list_no_sessions_create")
  }
  if (guiScene["psn_room_create_error"] != null)
  {
    ::remove_scene_box("psn_room_create_error")
  }

  if (!::isInMenu())
  {
    ::gui_start_logout_scheduled <- true
    ::destroy_session_scripted()
    ::quit_to_debriefing()
    ::interrupt_multiplayer(true)
  }
  else
  {
    ::in_on_lost_psn = true
    ::add_msg_box("lost_live", ::loc("yn1/disconnection/psn"), [["ok",
        function()
        {
          ::in_on_lost_psn = false
          ::destroy_session_scripted()
          ::gui_start_logout()
        }
        ]], "ok")
  }
}

function check_logout_scheduled()
{
  if (::gui_start_logout_scheduled)
  {
    ::gui_start_logout_scheduled <- false
    on_lost_psn()
  }
}

function get_options_mode(game_mode)
{
  switch (game_mode)
  {
    case GM_CAMPAIGN: return OPTIONS_MODE_CAMPAIGN;
    case GM_TRAINING: return OPTIONS_MODE_TRAINING;
    case GM_TEST_FLIGHT: return OPTIONS_MODE_TRAINING;
    case GM_SINGLE_MISSION: return OPTIONS_MODE_SINGLE_MISSION;
    case GM_DYNAMIC: return OPTIONS_MODE_DYNAMIC;
    case GM_BUILDER: return OPTIONS_MODE_DYNAMIC;
    case GM_EVENT: return OPTIONS_MODE_EVENT;
    case GM_USER_MISSION: return OPTIONS_MODE_USER_MISSION;
    case GM_TEAMBATTLE: return OPTIONS_MODE_MP_TEAMBATTLE;
    case GM_DOMINATION: return OPTIONS_MODE_MP_DOMINATION;
    case GM_SKIRMISH: return OPTIONS_MODE_MP_SKIRMISH;
    case GM_TOURNAMENT: return OPTIONS_MODE_MP_TOURNAMENT;
    default: return 0;
  }
}

function restart_current_mission()
{
  ::set_gui_options_mode(::get_options_mode(::get_game_mode()))
  ::restart_mission()
}

function build_menu_blk(menu_items, default_text_prefix = "#mainmenu/btn", is_flight_menu = false)
{
  local result = ""
  foreach (idx, item in menu_items)
  {
    local itemView = {}
    itemView.isFlightMenu <- is_flight_menu
    itemView.name <- ::u.isString(item) ? item : ::getTblValue("name", item, "")
    itemView.buttonId <- "btn_" + itemView.name.tolower()
    itemView.isFocus <- idx == 0
    itemView.isInactive <- false
    itemView.buttonText <- default_text_prefix + itemView.name
    itemView.onClick <- "on" + itemView.name
    itemView.brBefore <- false
    itemView.brAfter <- false
    itemView.timer <- null

    if (::u.isTable(item))
    {
      itemView = ::combine_tables(item, itemView)
      if (itemView.isInactive)
        itemView.onClick = "onInactiveItem"
    }

    result += ::handyman.renderCached("gui/menuButton", itemView)
  }
  return result
}

function is_online_available()
{
  return ::is_connected_to_matching()
}

function close_tactical_map()
{
  if (::tactical_map_handler != null)
    ::tactical_map_handler.onCancel(null)
}

function fill_weapons_list_tooltips(listObj, optionsList)
{
  local types = [::USEROPT_WEAPONS, ::USEROPT_ENEMY_WEAPONS]
  foreach (option in optionsList)
  {
    if (!isInArray(option.type, types))
      continue;

    local weaponsObj = listObj.findObject(option.id);
    if (!weaponsObj)
      continue;
    if (!("hints" in option))
      continue;
    if (weaponsObj.childrenCount() != option.hints.len())
      continue;
    for (local i = 0; i < weaponsObj.childrenCount(); i++)
    {
      local w = weaponsObj.getChild(i);
      w.tooltip = option.hints[i];
    }
    local value = weaponsObj.getValue();
    if (value >=0 && value < option.hints.len())
      weaponsObj.tooltip = option.hints[value];
  }
}

function set_current_campaign(id)
{
  ::current_campaign_id = id
}

::last_mb <- 0

function gui_msg_nobuttons_show(text)
{
  ::last_mb ++;
  add_msg_box("msg_nobuttons" + ::last_mb, text, null, null)
}

function gui_msg_nobuttons_hide()
{
  remove_scene_box("msg_nobuttons" + ::last_mb)
}

function gui_msg_okbox(key, ptr)
{
  add_msg_box("msg_okbox", ::loc(key),
  [
    ["ok", (@(ptr) function() {::ps3_mb_cb(0, ptr); })(ptr)],
  ], "ok")
}

function preload_ingame_scenes()
{
  ::mp_stat_handler = null
  ::tactical_map_handler = null
  ::flight_menu_handler = null
  ::postfx_settings_handler = null

  ::handlersManager.clearScene()
  ::handlersManager.loadHandler(::gui_handlers.Hud)

  require("scripts/chat/mpChatModel.nut").init()
}


function have_active_bonuses_by_effect_type(effectType, personal = false)
{
  return ::ItemsManager.hasActiveBoosters(effectType, personal)
    || (personal
        && (::get_cyber_cafe_bonus_by_effect_type(effectType) > 0.0
            || ::get_squad_bonus_for_same_cyber_cafe(effectType)))
}

function get_squad_bonus_for_same_cyber_cafe(effectType, num = -1)
{
  if (num < 0)
    num = ::g_squad_manager.getSameCyberCafeMembersNum()
  local cyberCafeBonusesTable = ::calc_boost_for_squads_members_from_same_cyber_cafe(num)
  local value = ::getTblValue(effectType.abbreviation, cyberCafeBonusesTable, 0.0)
  return value
}

function get_cyber_cafe_bonus_by_effect_type(effectType, cyberCafeLevel = -1)
{
  if (cyberCafeLevel < 0)
    cyberCafeLevel = ::get_cyber_cafe_level()
  local cyberCafeBonusesTable = ::calc_boost_for_cyber_cafe(cyberCafeLevel)
  local value = ::getTblValue(effectType.abbreviation, cyberCafeBonusesTable, 0.0)
  return value
}

function get_current_bonuses_text(effectType)
{
  local havePremium = ::havePremium()
  local tooltipText = []

  if (havePremium)
  {
    local rate = ""
    if (effectType == ::BoosterEffectType.WP)
    {
      local blk = ::get_warpoints_blk()
      rate = "+" + ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText((blk.wpMultiplier || 1.0) - 1.0)
      rate = ::getWpPriceText(::colorize("activeTextColor", rate), true)
    }
    else if (effectType == ::BoosterEffectType.RP)
    {
      local blk = ::get_ranks_blk()
      rate = "+" + ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText((blk.xpMultiplier|| 1.0) - 1.0)
      rate = ::getRpPriceText(::colorize("activeTextColor", rate), true)
    }
    tooltipText.append(::loc("mainmenu/activePremium") + ::loc("ui/colon") + rate)
  }

  local value = ::get_cyber_cafe_bonus_by_effect_type(effectType)
  if (value > 0.0)
  {
    value = ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(value)
    value = effectType.getText(::colorize("activeTextColor", value), true)
    tooltipText.append(::loc("mainmenu/bonusCyberCafe") + ::loc("ui/colon") + value)
  }

  local value = ::get_squad_bonus_for_same_cyber_cafe(effectType)
  if (value > 0.0)
  {
    value = ::g_measure_type.PERCENT_FLOAT.getMeasureUnitsText(value)
    value = effectType.getText(::colorize("activeTextColor", value), true)
    tooltipText.append(::loc("item/FakeBoosterForNetCafeLevel/squad", {num = ::g_squad_manager.getSameCyberCafeMembersNum()}) + ::loc("ui/colon") + value)
  }

  local boostersArray = ::ItemsManager.getActiveBoostersArray(effectType)
  local boostersDescription = ::ItemsManager.getActiveBoostersDescription(boostersArray, effectType)
  if (boostersDescription != "")
    tooltipText.append((havePremium? "\n" : "") + boostersDescription)

  if (::u.isEmpty(tooltipText))
    return ""

  return ::g_string.implode(tooltipText, "\n")
}

function add_bg_task_cb(taskId, actionFunc, handler = null)
{
  local taskCallback = ::Callback((@(actionFunc, handler) function(result = ::YU2_OK) {
    ::call_for_handler(handler, actionFunc)
  })(actionFunc, handler), handler)
  ::g_tasker.addTask(taskId, null, taskCallback, taskCallback)
}

function havePremium()
{
  return entitlement_expires_in("PremiumAccount") > 0
}

function get_mission_desc_text(missionBlk)
{
  local gt = ::get_game_type()
  local gm = ::get_game_type()
  local descrAdd = ""

  local sm_location = missionBlk.getStr("locationName",
                            ::map_to_location(missionBlk.getStr("level", "")))
  if (sm_location != "")
    descrAdd += (::loc("options/location") + ::loc("ui/colon") + ::loc("location/" + sm_location))

  local sm_time = missionBlk.getStr("time", missionBlk.getStr("environment", ""))
  if (sm_time != "")
    descrAdd += (descrAdd != "" ? "; " : "") + ::get_mission_time_text(sm_time)

  local sm_weather = missionBlk.getStr("weather", "")
  if (sm_weather != "")
    descrAdd += (descrAdd != "" ? "; " : "") + ::loc("options/weather" + sm_weather)

  local aircraft = missionBlk.getStr("player_class", "")
  if (aircraft != "")
  {
    local sm_aircraft = ::loc("options/aircraft") + ::loc("ui/colon") +
      getUnitName(aircraft) + "; " +
      ::getWeaponNameText(aircraft, null, missionBlk.getStr("player_weapons", ""), ", ")

    descrAdd += "\n" + sm_aircraft
  }

  if (missionBlk.getStr("recommendedPlayers","") != "")
    descrAdd += ("\n" + ::format(::loc("players_recommended"), missionBlk.getStr("recommendedPlayers","1-4")) + "\n")

  return descrAdd
}

g_cached_files_table <- {}

function cached_is_existing_image(fn, assertText = null)
{
  if (is_gui_webcache_enabled()) // images always "exist" when gui webcache enabled
    return true;

  if (!(fn in g_cached_files_table))
  {
    g_cached_files_table[fn] <- is_existing_file(fn, false)
    if (!g_cached_files_table[fn] && assertText)
      ::dagor.assertf(false, ::format(assertText, fn))
  }
  return g_cached_files_table[fn]
}

function getCountryByAircraftName(airName) //used in code
{
  local country = ::getShopCountry(airName)
  local cPrefixLen = "country_".len()
  if (country.len() > cPrefixLen)
    return country.slice(cPrefixLen)
  return ""
}

function getShopCountry(airName)
{
  local air = ::getAircraftByName(airName)
  if (air && ("shopCountry" in air))
    return air.shopCountry
  return ""
}

function countMeasure(unitNo, value, separator = " - ", addMeasureUnits = true, forceMaxPrecise = false)
{
  local type = ::get_option_unit_type(unitNo)
  local unit = null
  foreach(u in ::measure_units[unitNo])
    if (u.name == type)
      unit = u

  if (!unit) return ""

  if (typeof(value) != "array")
    value = [value]
  local maxValue = null
  foreach (val in value)
    if (!maxValue || maxValue < val)
      maxValue = val
  local roundValue = !forceMaxPrecise && (unit.roundAfter.y > 0 && (maxValue * unit.koef) > unit.roundAfter.x)
  local result = ""
  foreach (idx, val in value)
  {
    val = val * unit.koef
    if (idx > 0)
      result += separator
    if (roundValue)
      result += format("%d", ((val / unit.roundAfter.y + 0.5).tointeger() * unit.roundAfter.y).tointeger())
    else
    {
      local roundPrecision = unit.round == 0 ? 1 : ::pow(0.1, unit.round)
      result += ::round_by_value(val, roundPrecision)
    }
  }
  if (addMeasureUnits)
    result += " " + ::loc("measureUnits/" + unit.name)
  return result
}

function isInArrayRecursive(v, arr)
{
  foreach(i in arr)
    if (v==i)
      return true
    else
      if (typeof(i)=="array" && ::isInArrayRecursive(v, i))
        return true
  return false
}

function showBtn(id, status, scene=null)
{
  local obj = ::checkObj(scene) ? scene.findObject(id) : ::get_cur_gui_scene()[id]
  return ::show_obj(obj, status)
}

function enableBtnTable(obj, table, setInactive = false)
{
  if(!::checkObj(obj))
    return

  foreach(id, status in table)
  {
    local idObj = obj.findObject(id)
    if (::checkObj(idObj))
    {
      idObj.enable(status)
      if (setInactive)
        idObj.inactive = status? "no" : "yes"
    }
  }
}

function showBtnTable(obj, table)
{
  if (!::checkObj(obj))
    return

  foreach(id, status in table)
    ::showBtn(id, status, obj)
}

have_received_news <- false
function update_news()
{
  /*
  if (have_received_news)
  {
    local guiScene = ::get_gui_scene()
    if (guiScene == null)
      return
    if (guiScene["mainmenu-news"] != null)
      guiScene.replaceContent("mainmenu-news", "gui/news.blk", null)
  }
  */
}

function on_news_loaded()
{
  have_received_news <- true
  update_news()
}

function show_title_logo(show, scene = null, logoHeight = "", name_id = "id_full_title")
{
  local guiScene = ::get_cur_gui_scene()
  local pic = null
  pic = scene? scene.findObject("titleLogo") : guiScene["titleLogo"]
  if(logoHeight == "")
  {
    local root = guiScene.getRoot()
    if(root)
    {
      local rootSize = root.getSize()
      local scrn_tgt = ::min(0.75*rootSize[0], rootSize[1])
      logoHeight = min(max(((scrn_tgt + 200) / 400).tointeger() * 32, 64), 128)
    }
  }

  if(::checkObj(pic))
  {
    local imagePath = "ui/" + ::loc(name_id) + logoHeight
    if (!::cached_is_existing_image(imagePath + ".ddsx", "not found image by path %s"))
      imagePath = "ui/title" + logoHeight

    pic["background-image"] = imagePath
    pic.show(show)
    return true
  }
  return false
}

function getRatioText(ratio)
{
  if (ratio <= 0)
    return ""
  return format("max-height:t='%fw'; max-width:t='%fh';", 1.0/ratio, ratio)
}

function getAmountAndMaxAmountText(amount, maxAmount, showMaxAmount = false)
{
  local amountText = ""
  if (maxAmount > 1 || showMaxAmount)
    amountText = amount.tostring() + (showMaxAmount && maxAmount > 1 ? "/" + maxAmount : "")
  return amountText;
}

function is_game_mode_with_spendable_weapons()
{
  local mode = ::get_mp_mode();
  return mode == ::GM_DOMINATION || mode == ::GM_TOURNAMENT;
}

class ::secondsUpdater //for info which require update each second
{
  timer = 0.0
  updateFunc = null
  params = null
  nestObj = null
  timerObj = null
  destroyTimerObjOnFinish = false

  static function getUpdaterByNestObj(nestObj)
  {
    local userData = nestObj.getUserData()
    if (::u.isInstance(userData) && userData instanceof ::secondsUpdater)
      return userData

    local timerObj = nestObj.findObject(getTimerObjIdByNestObj(nestObj))
    if (timerObj == null)
      return null

    userData = timerObj.getUserData()
    if (::u.isInstance(userData) && userData instanceof ::secondsUpdater)
      return userData

    return null
  }

  function constructor(_nestObj, _updateFunc, useNestAsTimerObj = true, _params = {})
  {
    if (!_updateFunc)
      return ::dagor.assertf(false, "Error: no updateFunc in seconds updater.")

    nestObj    = _nestObj
    updateFunc = _updateFunc
    params     = _params

    local lastUpdaterByNestObject = getUpdaterByNestObj(_nestObj)
    if (lastUpdaterByNestObject != null)
      lastUpdaterByNestObject.remove()

    if (updateFunc(nestObj, params))
      return

    timerObj = useNestAsTimerObj ? nestObj : createTimerObj(nestObj)
    if (!timerObj)
      return

    destroyTimerObjOnFinish = !useNestAsTimerObj
    timerObj.timer_handler_func = "onUpdate"
    timerObj.timer_interval_msec = "1000"
    timerObj.setUserData(this)
  }

  function createTimerObj(nestObj)
  {
    local blkText = "dummy {id:t = '" + getTimerObjIdByNestObj(nestObj) + "' behavior:t = 'Timer' }"
    nestObj.getScene().appendWithBlk(nestObj, blkText, null)
    local index = nestObj.childrenCount() - 1
    local resObj = index >= 0 ? nestObj.getChild(index) : null
    if (resObj && resObj.tag == "dummy")
      return resObj
    return null
  }

  function onUpdate(obj, dt)
  {
    if (updateFunc(nestObj, params))
      remove()
  }

  function remove()
  {
    ::remove_seconds_updater(timerObj)
    if (destroyTimerObjOnFinish && ::checkObj(timerObj))
      timerObj.getScene().destroyElement(timerObj)
  }

  function getTimerObjIdByNestObj(nestObj)
  {
    return "seconds_updater_" + nestObj.id
  }
}

function remove_seconds_updater(obj)
{
  if (::checkObj(obj))
    obj.setUserData(null)
}

function getTextByModes(textFunc, separator = " / ")
{
  local text = ""
  foreach(m in ::domination_modes)
    if (::get_show_mode_info(m.modeId))
      text += ((text!="")? separator : "") + textFunc(m)
  return text
}

::skip_crew_unlock_assert <- false
function setCrewUnlockTime(obj, air)
{
  if(!::checkObj(obj))
    return

  ::secondsUpdater(obj, (@(air) function(obj, params) {
    ::crews_list = ::get_crew_info()
    local crew = air && ::getCrewByAir(air)
    local lockTime = ::getTblValue("lockedTillSec", crew, 0)
    local show = lockTime > 0 && ::isInMenu()
    if(show)
    {
      local waitTime = lockTime - ::get_charserver_time_sec()
      show = waitTime > 0

      local tObj = obj.findObject("time")
      if(show && ::checkObj(tObj))
      {
        local wpBlk = ::get_warpoints_blk()
        if (wpBlk && wpBlk.lockTimeMaxLimitSec && waitTime > wpBlk.lockTimeMaxLimitSec)
        {
          waitTime = wpBlk.lockTimeMaxLimitSec
          ::dagor.debug("crew.lockedTillSec " + lockTime)
          ::dagor.debug("::get_charserver_time_sec() " + ::get_charserver_time_sec())
          if (!::skip_crew_unlock_assert)
            ::debugTableData(::get_crew_info())
          ::dagor.assertf(::skip_crew_unlock_assert, "Too big locked crew wait time")
          ::skip_crew_unlock_assert = true
        }
        local timeStr = time.secondsToString(waitTime)
        tObj.setValue(timeStr)

        local showButtons = ::has_feature("EarlyExitCrewUnlock")
        if (showButtons)
        {
          ::placePriceTextToButton(obj, "btn_unlock_crew", ::loc("mainmenu/btn_crew_unlock"), ::shop_get_unlock_crew_cost(crew.id), 0)
          ::placePriceTextToButton(obj, "btn_unlock_crew_gold", ::loc("mainmenu/btn_crew_unlock"), 0, ::shop_get_unlock_crew_cost_gold(crew.id))
        }
        ::showBtn("btn_unlock_crew", showButtons && !!::shop_get_unlock_crew_cost(crew.id), obj)
        ::showBtn("btn_unlock_crew_gold", showButtons && !!::shop_get_unlock_crew_cost_gold(crew.id), obj)
      }
    }
    obj.show(show)
    if (!show && ::getTblValue("wasShown", params, false))
      obj.getScene().performDelayed(this, function() { ::reinitAllSlotbars() })
    params.wasShown <- show
    return !show
  })(air))
}

function fillCountryInfo(scene, country, expChange=0, showMedals = false, profileData=null)
{
  if (!scene) return
  local rank = ::get_player_rank_by_country(country, profileData)

  local obj = scene.findObject("rankName")
  if (obj) obj.setValue((country!="")? ::loc("mainmenu/rank/"+country) : ::loc("mainmenu/rank"))
  obj = scene.findObject("rank")
  if (obj) obj.setValue(rank.tostring())
  obj = scene.findObject("rankIcon")
  if (obj) obj["background-image"] = (country!="")? ::get_country_icon(country) : "#ui/gameuiskin#prestige0"
}

function countCountryMedals(country, profileData=null)
{
  local total = 0
  local medalsList = null
  if (profileData && ("unlocks" in profileData) && ("medal" in profileData.unlocks))
    medalsList = profileData.unlocks.medal

  local unlocks = ::g_unlocks.getUnlocksByType("medal")
  foreach(id, cb in unlocks)
  {
    local unlockCountry = cb.getStr("country","")
    if (unlockCountry == country)
    {
      if ((!profileData && ::is_unlocked_scripted(::UNLOCKABLE_MEDAL, id))
          || (medalsList && (id in medalsList) && medalsList[id] > 0))
        total++
    }
  }
  return total
}

function set_menu_title(text, scene, name="gc_title")
{
  if (text == null ||
    !::checkObj(scene))
    return

  local textObj = scene.findObject(name)
  if (::checkObj(textObj))
    textObj.setValue(text.tostring())
}

function buildNavBarButton(name, hotkey, enable = true)
{
  return format("Button_text { id:t = 'btn_%s'; " +
                            "text:t = '#mainmenu/btn%s'; " +
                            "_on_click:t = 'on%s'; " +
                            "enable:t='%s'; " +
                            "btnName:t='%s'; " +
                            "ButtonImg {} " +
                          "}\n",
                 name.tolower(), name, name,
                 enable? "yes" : "no", hotkey
               )
}


function stringReplace(str, replstr, value)
{
  local findex = 0;
  local s = str;

  while(true)
  {
    findex = s.find(replstr, findex);
    if(findex!=null)
    {
      s = s.slice(0, findex) + value + s.slice(findex + replstr.len());
      findex += value.len();
    } else
      break;
  }
  return s;
}

function getRangeString(val1, val2, formatStr = "%s")
{
  val1 = val1.tostring()
  val2 = val2.tostring()
  return (val1 == val2) ? ::format(formatStr, val1) : ::format(formatStr, val1) + ::loc("ui/mdash") + ::format(formatStr, val2)
}

function getRangeTextByPoint2(val, itemFormatStr = "%s", rangeFormatStr = "%s", romanNumerals = false)
{
  if (!(type(val) == "instance" && (val instanceof ::Point2)) && !(type(val) == "table"))
    return ""

  local a = romanNumerals ? ::get_roman_numeral(val.x) : val.x.tostring()
  local b = romanNumerals ? ::get_roman_numeral(val.y) : val.y.tostring()
  local range = ::getRangeString(a, b, itemFormatStr)
  return ::format(rangeFormatStr, range)
}

function getVerticalText(text)
{
  local res = ""
  local total = ::utf8(text).charCount()
  for(local i = 0; i < total; i++)
  {
    local nextChar = ::utf8(text).slice(i, i + 1)
    if (nextChar == "\t")
      continue
    res += (res.len() ? "\n" : "") + nextChar
  }
  return res
}

::last_update_entitlements_time <- ::dagor.getCurTime()
function get_update_entitlements_timeout_msec()
{
  return ::last_update_entitlements_time - ::dagor.getCurTime() + 20000
}

function update_entitlements_limited()
{
  if (!::is_online_available())
    return -1
  if (::get_update_entitlements_timeout_msec() < 0)
  {
    ::last_update_entitlements_time = ::dagor.getCurTime()
    return ::update_entitlements()
  }
  return -1
}

//remove
function old_check_balance_msgBox(cost, costGold=0, afterCheck = null)
{
  return ::check_balance_msgBox(::Cost(cost, costGold), afterCheck)
}

function check_balance_msgBox(cost, afterCheck = null, silent = false)
{
  if (cost.isZero())
    return true

  local balance = ::get_gui_balance()
  local text = null
  local isGoldNotEnough = false
  if (cost.wp > 0 && balance.wp < cost.wp)
    text = ::loc("not_enough_warpoints")
  if (cost.gold > 0 && balance.gold < cost.gold)
  {
    text = ::loc("not_enough_gold")
    isGoldNotEnough = true
    ::update_entitlements_limited()
  }

  if (!text)
    return true
  if (silent)
    return false

  local cancelBtnText = ::isInMenu()? "cancel" : "ok"
  local defButton = cancelBtnText
  local buttons = [[cancelBtnText, (@(afterCheck) function() {if (afterCheck) afterCheck ();})(afterCheck) ]]
  local shopType = ""
  if (isGoldNotEnough && ::has_feature("EnableGoldPurchase"))
    shopType = "eagles"
  else if (!isGoldNotEnough && ::has_feature("SpendGold"))
    shopType = "warpoints"

  if (::isInMenu() && shopType != "")
  {
    local purchaseBtn = "#mainmenu/btnBuy"
    defButton = purchaseBtn
    buttons.insert(0, [purchaseBtn, (@(shopType, afterCheck) function() {
        ::gui_modal_onlineShop(null, shopType, afterCheck)
      })(shopType, afterCheck)
    ])
  }

  ::scene_msg_box("no_money", null, text, buttons, defButton)
  return false
}

//need to remove
function getPriceText(wp, gold=0, colored = true, showWp=false, showGold=false)
{
  local text = ""
  if (gold!=0 || showGold)
    text += gold + ::loc(colored? "gold/short/colored" : "gold/short")
  if (wp!=0 || showWp)
    text += ((text=="")? "" : ", ") + wp + ::loc(colored? "warpoints/short/colored" : "warpoints/short")
  return text
}

function getPriceAccordingToPlayersCurrency(wpCurrency, eaglesCurrency, colored = true)
{
  local cost = ::Cost(wpCurrency, eaglesCurrency)
  if (colored)
    return cost.getTextAccordingToBalance()
  return cost.getUncoloredText()
}

function getWpPriceText(wp, colored=false)
{
  return getPriceText(wp, 0, colored, true)
}

function getGpPriceText(gold, colored=false)
{
  return getPriceText(0, gold, colored, false, true)
}

//need to remove
function getRpPriceText(rp, colored=false)
{
  if (rp == 0)
    return ""
  return rp.tostring() + ::loc("currency/researchPoints/sign" + (colored? "/colored" : ""))
}

function get_crew_sp_text(sp, showEmpty = true)
{
  if (!showEmpty && sp == 0)
    return ""
  return sp.tostring() + ::loc("currency/skillPoints/sign/colored")
}

function get_flush_exp_text(exp_value)
{
  if (exp_value == null || exp_value < 0)
    return ""
  local rpPriceText = exp_value.tostring() + ::loc("currency/researchPoints/sign/colored")
  local coloredPriceText = ::colorTextByValues(rpPriceText, exp_value, 0)
  return ::format(::loc("mainmenu/availableFreeExpForNewResearch"), coloredPriceText)
}

function getFreeRpPriceText(frp, colored=false)
{
  if (frp == 0)
    return ""
  return frp.tostring() + ::loc("currency/freeResearchPoints/sign" + (colored? "/colored" : ""))
}

function getCrewSpText(sp, colored=true)
{
  if (sp == 0)
    return ""
  return sp + ::loc("currency/skillPoints/sign" + (colored? "/colored" : ""))
}

function colorTextByValues(text, val1, val2, useNeutral = true, useGood = true)
{
  local color = ""
  if (val1 >= val2)
  {
    if (val1 == val2 && useNeutral)
      color = "activeTextColor"
    else if (useGood)
      color = "goodTextColor"
  }
  else
    color = "badTextColor"

  if (color == "")
    return text

  return ::format("<color=@%s>%s</color>", color, text)
}

function getObjIdByPrefix(obj, prefix, idProp = "id")
{
  if (!obj) return null
  local id = obj[idProp]
  if (!id) return null

  return ::g_string.cutPrefix(id, prefix)
}

function getTooltipObjId(obj)
{
  return obj.tooltipId || ::getObjIdByPrefix(obj, "tooltip_")
}

function getYumPriceByLoc(price)
{
  local loc = ::loc("yum/price_scale", "")
  if (loc!="")
  {
    local scale = loc.tofloat()
    return scale*price
  }
  return price
}

::is_hangar_controls_enabled <- false
function enableHangarControls(value, save=true)
{
  ::hangar_enable_controls(value)
  if (save)
    ::is_hangar_controls_enabled <- value
}
function restoreHangarControls()
{
  ::hangar_enable_controls(::is_hangar_controls_enabled)
}

function getStrSymbol(str, i)
{
  if (i < str.len())
    return str.slice(i, i+1)
  return null
}

function validate_email(no_dump_email)
{
  if (!no_dump_email.find("@"))
  {
    //dlog("not found @")
    return null
  }
  //remove spaces
  while(no_dump_email.slice(0,1)==" ")
    no_dump_email = no_dump_email.slice(1)
  while(no_dump_email.slice(no_dump_email.len()-1,no_dump_email.len())==" ")
    no_dump_email = no_dump_email.slice(0, no_dump_email.len()-1)

  local parts = []
  local curPart = ""
  local addCurPart = (@(parts) function(curPart) {
    if (curPart=="")
    {
      //dlog("wrong . or @ place")
      return false
    }
    parts.append(curPart)
    return true
  })(parts)

  local specSym = ". \"(),:;<>@[]\\" //" // Fixes syntax highlighting.
  local atFound = false
  local strOpened = null

  for(local i=0; i<no_dump_email.len(); i++)
  {
    local sym = no_dump_email.slice(i, i+1)
    if (specSym.find(sym)==null)
    {
      curPart += sym
      continue
    }

    if (strOpened)
    {
      if (strOpened=="\\\"" && sym=="\\" && getStrSymbol(no_dump_email, i+1)=="\"")
      {
        curPart+=strOpened
        i++
        strOpened=null
        continue
      }
      if (strOpened==sym)
      {
        local nextSym = getStrSymbol(no_dump_email, i+1)
        if (nextSym=="@" || nextSym=="." || nextSym==",")
        {
          curPart+=sym
          strOpened=null
          continue
        } else
        {
          //dlog("quoted strings must be dot separated, or the only element making up the local-part")
          return null
        }
      }
      if (sym=="\\")
      {
        local nextSym = getStrSymbol(no_dump_email, i+1)
        if (nextSym==" " || nextSym=="\"" || nextSym=="\\")
        {
          curPart+=sym+nextSym
          i++
          continue
        }
      }
      if (sym==" " || sym=="\"" || sym=="\\")
      {
        //dlog("spaces, quotes, and backslashes may only exist when within quoted strings and preceded by a slash")
        return null
      }

      curPart+=sym
      continue
    }

    if (sym=="\\" && !atFound)  //string Insertion
    {
      local nextSym = getStrSymbol(no_dump_email, i+1)
      if (nextSym=="\"")
      {
        strOpened="\\\""
        curPart+=strOpened
        i++
      } else
      {
        //dlog("invalid \\")
        return null
      }
    } else
    if (sym=="\"" && !atFound)
    {
      if (curPart=="")
      {
        strOpened="\""
        curPart+=strOpened
      } else
      {
        //dlog("quoted strings must be dot separated, or the only element making up the local-part")
        return null
      }
    } else
    if (sym=="@")
    {
      if (atFound)
      {
        //dlog("double @")
        return null
      }
      if (addCurPart(curPart))
      {
        curPart=""
        parts.append("@")
        atFound=true
      } else
        return null
    } else
    if (sym=="." || sym==",") //replace , by . to avoid some typing errors
    {
      if (addCurPart(curPart))
        curPart=""
      else
        return null
    } else
    if (sym=="(") //comments
    {
      local endComment = no_dump_email.find(")", i+1)
      if (endComment==null)
      {
        //dlog("not closed comment")
        return null
      }
      i = endComment
    } else
    {
      /*
      if (atFound)
        dlog("incorrect symbols in domain name")
      else
        dlog("incorrect symbols in local part outside quotation marks")
      */
      return null
    }
  }
  if (strOpened)
  {
    //dlog("not closed quoters")
    return null
  }
  if (!addCurPart(curPart))
    return null
  if (!atFound)
  {
    //dlog("not found correct @")
    return null
  }

  local res = ""
  local needPoint = false
  foreach(idx, p in parts)
    if (p=="@")
    {
      res+=p
      needPoint=false
    } else
    {
      res += (needPoint? ".":"") + p
      needPoint=true
    }
  return res
}

function array_to_blk(arr, id)
{
  local blk = ::DataBlock()
  if (arr)
    foreach (v in arr)
      blk[id] <- v
  return blk
}

function blk_to_array(blk, id)
{
  return blk % id
}

function buildTableFromBlk(blk)
{
  if (!blk)
    return {}
  local res = {}
  for (local i = 0; i < blk.paramCount(); i++)
    ::buildTableFromBlk_AddElement(res, blk.getParamName(i) || "", blk.getParamValue(i))
  for (local i = 0; i < blk.blockCount(); i++)
  {
    local block = blk.getBlock(i)
    local blockTable = ::buildTableFromBlk(block)
    ::buildTableFromBlk_AddElement(res, block.getBlockName() || "", blockTable)
  }
  return res
}

function build_blk_from_container(container, arrayKey = "array")
{
  local blk = ::DataBlock()
  local isContainerArray = ::u.isArray(container)

  local addValue = ::assign_value_to_blk
  if (isContainerArray)
    addValue = ::create_new_pair_key_value_to_blk

  foreach(key, value in container)
  {
    local newValue = value
    local index = isContainerArray? arrayKey : key.tostring()
    if (::u.isTable(value) || ::u.isArray(value))
      newValue = ::build_blk_from_container(value, arrayKey)

    addValue(blk, index, newValue)
  }

  return blk
}

function create_new_pair_key_value_to_blk(blk, index, value)
{
  /*Known feature - cannot create a pair, if index is used for other type
   i.e. ["string", 1, 2, 3, "string"] in this case will be ("string", "string") result
   on other case [1, 2, 3, "string"] will be (1, 2, 3) result. */

  blk[index] <- value
}

function assign_value_to_blk(blk, index, value)
{
  blk[index] = value
}

/**
 * Adds value to table that may already
 * have some value with the same key.
 */
function buildTableFromBlk_AddElement(table, elementKey, elementValue)
{
  if (!(elementKey in table))
    table[elementKey] <- elementValue
  else if (typeof(table[elementKey]) == "array")
    table[elementKey].push(elementValue)
  else
    table[elementKey] <- [table[elementKey], elementValue]
}

function buildTableRow(rowName, rowData, even=null, trParams="", tablePad="@tblPad")
{
  //tablePad not using, but passed through many calls of this function
  local view = {
    row_id = rowName
    even = even
    trParams = trParams
    cell = []
  }

  foreach(idx, cell in rowData)
  {
    local haveParams = typeof cell == "table"
    local config = {
      params = haveParams
      display = ::getTblValue("hide", cell, true)? "show" : "hide"
      id = ::getTblValue("id", cell, "td_" + idx)
      width = ::getTblValue("width", cell)
      tdalign = ::getTblValue("tdAlign", cell)
      tooltip = ::getTblValue("tooltip", cell)
      callback = ::getTblValue("callback", cell)
      active = ::getTblValue("active", cell, false)
      cellType = ::getTblValue("cellType", cell)
      rawParam = ::getTblValue("rawParam", cell, "")
      needText = ::getTblValue("needText", cell, true)
      textType = ::getTblValue("textType", cell, "activeText")
      text = haveParams? ::getTblValue("text", cell, "") : cell.tostring()
      textRawParam = ::getTblValue("textRawParam", cell, "")
      imageType = ::getTblValue("imageType", cell, "cardImg")
      image = ::getTblValue("image", cell)
      imageRawParams = ::getTblValue("imageRawParams", cell)
      fontIconType = ::getTblValue("fontIconType", cell, "fontIcon20")
      fontIcon = ::getTblValue("fontIcon", cell)
    }

    view.cell.append(config)
  }

  return ::handyman.renderCached("gui/commonParts/tableRow", view)
}

function buildTableRowNoPad(rowName, rowData, even=null, trParams="")
{
  return buildTableRow(rowName, rowData, even, trParams, "0")
}

function get_text_urls_data(text)
{
  if (!text.len())
    return null

  local urls = []
  local start = 0
  local startText = "<url="
  local urlEndText = ">"
  local endText = "</url>"
  do {
    start = text.find(startText, start)
    if (start == null)
      break
    local urlEnd = text.find(urlEndText, start + startText.len())
    if (!urlEnd)
      break
    local end = text.find(endText, urlEnd)
    if (!end)
      break

    urls.append({
      url = text.slice(start + startText.len(), urlEnd)
      text = text.slice(urlEnd + urlEndText.len(), end)
    })
    text = text.slice(0, start) + text.slice(end + endText.len())
  } while (start != null && start < text.len())

  if (!urls.len())
    return null
  return { text = text, urls = urls }
}

function openPlayerLbRclickMenu(nick, handler)
{
  local isMe = nick == ::my_user_name
  local uid = ::getPlayerUid(nick)
  local isFriend = uid!=null && ::isPlayerInFriendsGroup(uid)
  local isBlock = uid!=null && ::isPlayerInContacts(uid, ::EPL_BLOCKLIST)

  local menu = {
    actions = [
      {
        text = ::loc("contacts/message")
        show = !isMe
        action = (@(nick, handler) function() { ::openChatPrivate(nick, handler) })(nick, handler)
      }
      {
        text = ::loc("mainmenu/btnUserCard")
        action = (@(nick, handler) function() { ::gui_modal_userCard({ name = nick }) })(nick, handler)
      }

      {
        text = ::loc("contacts/friendlist/add")
        show = !isMe && !isFriend && !isBlock
        action = (@(nick, handler) function() { ::editContactMsgBox({name = nick}, ::EPL_FRIENDLIST, true, handler) })(nick, handler)
      }
      {
        text = ::loc("contacts/friendlist/remove")
        show = isFriend
        action = (@(nick, handler) function() { ::editContactMsgBox({name = nick}, ::EPL_FRIENDLIST, false, handler) })(nick, handler)
      }
      {
        text = ::loc("contacts/blacklist/add")
        show = !isMe && !isFriend && !isBlock
        action = (@(nick, handler) function() { ::editContactMsgBox({name = nick}, ::EPL_BLOCKLIST, true, handler) })(nick, handler)
      }
      {
        text = ::loc("contacts/blacklist/remove")
        show = isBlock
        action = (@(nick, handler) function() { ::editContactMsgBox({name = nick}, ::EPL_BLOCKLIST, false, handler) })(nick, handler)
      }
    ]
  }

  ::gui_right_click_menu(menu, handler)
}

function invoke_multi_array(multiArray, invokeCallback)
{
  ::_invoke_multi_array(multiArray, [], 0, invokeCallback)
}

function _invoke_multi_array(multiArray, currentArray, currentIndex, invokeCallback)
{
  if (currentIndex == multiArray.len())
  {
    invokeCallback(currentArray)
    return
  }
  if (typeof(multiArray[currentIndex]) == "array")
  {
    foreach (name in multiArray[currentIndex])
    {
      currentArray.push(name)
      ::_invoke_multi_array(multiArray, currentArray, currentIndex + 1, invokeCallback)
      currentArray.pop()
    }
  }
  else
  {
    currentArray.push(multiArray[currentIndex])
    ::_invoke_multi_array(multiArray, currentArray, currentIndex + 1, invokeCallback)
    currentArray.pop()
  }
}

function showCurBonus(obj, value, tooltipLocName="", isDiscount=true, fullUpdate=false, tooltip = null)
{
  if (!::checkObj(obj))
    return

  local text = ""

  if ((isDiscount && value>0) || (!isDiscount && value!=1))
  {
    text = isDiscount? "-"+value+"%" : "x" + ::roundToDigits(value, 2)
    if (!tooltip && tooltipLocName!="")
    {
      local prefix = isDiscount? "discount/" : "bonus/"
      tooltip = format(::loc(prefix + tooltipLocName + "/tooltip"), value.tostring())
    }
  }

  if (text!="")
  {
    obj.setValue(text)
    if (tooltip)
      obj.tooltip = tooltip
  } else
    if (fullUpdate)
      obj.setValue("")
}

function addBonusToObj(handler, obj, value, tooltipLocName="", isDiscount=true, type="old")
{
  if (!::checkObj(obj) || value < 2) return

  local guiScene = obj.getScene()
  local text = ""
  local id = ""
  local tooltip = ""
  text = isDiscount? "-" + value + "%" : "x" + ::roundToDigits(value, 2)
  if(tooltipLocName != "")
  {
    local prefix = isDiscount? "discount/" : "bonus/"
    id = isDiscount? "discount" : "bonus"
    tooltip = ::format(::loc(prefix + tooltipLocName + "/tooltip"), value.tostring())
  }
  local discountData = ::format("discount{id:t='%s'; type:t='%s'; tooltip:t='%s'; text:t='%s';}", id, type, tooltip, text)

  guiScene.appendWithBlk(obj, discountData, handler)
}

function showBonus(obj, name, tooltipLocId=null, fullUpdate=false, discTbl = null)
{
  if (!obj) return

  if (!discTbl)
    discTbl = ::discounts

  if (name in discTbl)
    ::showCurBonus(obj, discTbl[name], name, true, fullUpdate)
  else
    if (name in ::event_muls)
      ::showCurBonus(obj, ::event_muls[name], name, false, fullUpdate)
    else
      if (fullUpdate)
        ::hideBonus(obj)
}

function showBonusByTbl(obj, name, discTbl)
{
  showBonus(obj, name, null, false, discTbl)
}

function hideBonus(obj)
{
  if (::checkObj(obj))
    obj.setValue("")
}

function showAirExpWpBonus(obj, airName, showExp = true, showWp = true)
{
  if (!obj) return

  local exp, wp = 1.0
  if (typeof(airName)=="string")
  {
    exp = showExp? ::wp_shop_get_aircraft_xp_rate(airName) : 1.0
    wp = showWp? ::wp_shop_get_aircraft_wp_rate(airName) : 1.0
  } else
    foreach(a in airName)
    {
      local aexp = showExp? ::wp_shop_get_aircraft_xp_rate(a) : 1.0
      if (aexp > exp) exp = aexp
      local awp = showWp? ::wp_shop_get_aircraft_wp_rate(a) : 1.0
      if (awp > wp) wp = awp
    }

  local bonusData = getBonus(exp, wp, "item", "Aircraft", airName)

  foreach (name, result in bonusData)
    obj[name] = result
}

function showCountryBonus(obj, country)
{
  if(!checkObj(obj))
    return


  local exp = ::shop_get_first_win_xp_rate(country)
  local wp = ::shop_get_first_win_wp_rate(country)

  local bonusData = getBonus(exp, wp, "country")

  foreach (name, result in bonusData)
    obj[name] = result
}

function getBonus(exp, wp, imgType, placeType="", airName="")
{
  local imgColor = ""
  if(exp > 1.0)
    imgColor = (wp > 1.0)? "wp_exp": "exp"
  else
    imgColor = (wp > 1.0)? "wp" : ""

  exp = ::roundToDigits(exp, 2)
  wp = ::roundToDigits(wp, 2)

  local multiplier = exp > wp?  exp : wp
  local image = getBonusImage(imgType, multiplier, airName==""? "country": "air")

  local tooltipText = ""
  local locEnd = (typeof(airName)=="string")? "/tooltip" : "/group/tooltip"
  if(imgColor != "")
  {
    tooltipText += exp <= 1.0? "" : format(::loc("bonus/" + (imgColor=="wp_exp"? "exp" : imgColor) + imgType + placeType + "Mul" + locEnd), "x" + exp)
    if(wp > 1)
      tooltipText += ((tooltipText=="")? "":"\n") + format(::loc("bonus/" + (imgColor=="wp_exp"? "wp" : imgColor) + imgType + placeType + "Mul" + locEnd),"x" + wp)
  }

  local data = {
                 bonusType = imgColor
                 tooltip = tooltipText
               }
  data["background-image"] <- image

  return data
}

function getBonusImage(type, multiplier, useBy)
{
  if(type != "item" && type != "country" || multiplier == 1.0)
    return ""

  local allowingMult = useBy=="country"? ::allowingMultCountry : ::allowingMultAircraft

  multiplier = ::find_max_lower_value(multiplier, allowingMult)
  if (multiplier == null)
    return ""

  multiplier = ::stringReplace(multiplier.tostring(), ".", "_")
  return ("#ui/gameuiskin#" + type + "_bonus_mult_" + multiplier)
}

function find_max_lower_value(val, list)
{
  local res = null
  local found = false
  foreach(v in list)
  {
    if (v == val)
      return v

    if (v < val)
    {
      if (!found || v > res)
        res = v
      found = true
      continue
    }
    //v > val
    if (!found && (res == null || v < res))
      res = v
  }
  return res
}

function buildBonusText(value, endingText)
{
  if (!value || value <= 0)
    return ""
  return "+" + value + endingText
}

function checkObj(obj)
{
  return obj!=null && obj.isValid()
}

function checkDataBlock(block)
{
  return block!=null && typeof(block)=="instance" && block instanceof ::DataBlock
}

function clearBorderSymbols(value, symList = [" "])
{
  while(value!="" && ::isInArray(value.slice(0,1), symList))
    value = value.slice(1)
  while(value!="" && ::isInArray(value.slice(value.len()-1,value.len()), symList))
    value = value.slice(0, value.len()-1)
  return value
}

function get_mission_name(missionId, config, locNameKey = "locName")
{
  local locNameValue = getTblValue(locNameKey, config, null)
  if (locNameValue && locNameValue.len())
    return ::get_locId_name(config, locNameKey)

  return ::loc("missions/" + missionId)
}

function get_current_mission_name()
{
  local misBlk = ::DataBlock()
  ::get_current_mission_desc(misBlk)
  return misBlk.name
}

function loc_current_operation_name()
{
  local misBlk = ::DataBlock()
  ::get_current_mission_desc(misBlk)

  local customRules = ::getTblValue("customRules", misBlk)
  if (!customRules)
    return ""

  local operationMap = ::getTblValue("operationMap", customRules)
  if (!operationMap)
    return ""

  return ::loc("worldWar/map/" + operationMap)
}

function loc_current_mission_name()
{
  local misBlk = ::DataBlock()
  ::get_current_mission_desc(misBlk)
  local ret = ""
  if ("locName" in misBlk && misBlk.locName.len() > 0)
    ret = ::get_locId_name(misBlk, "locName")
  else if ("loc_name" in misBlk && misBlk.loc_name != "")
    ret = ::loc("missions/" + misBlk.loc_name, "")
  if (ret == "")
    ret = get_combine_loc_name_mission(misBlk)
  if (::get_game_type() & ::GT_VERSUS)
  {
    if (misBlk.maxRespawns == 1)
      ret = ret + " " + ::loc("template/noRespawns")
    else if ((misBlk.maxRespawns != null) && (misBlk.maxRespawns > 1))
      ret = ret + " " +
        ::loc("template/limitedRespawns/num/plural", { num = misBlk.maxRespawns })
  }
  return ret
}

function get_combine_loc_name_mission(missionInfo)
{
  local getVal = function(info, val, defVal = "")
  {
    if (val in info)
      return info[val]
    return defVal
  }

  local locName = ""
  if ("locName" in missionInfo && missionInfo.locName.len() > 0)
    locName = ::get_locId_name(missionInfo, "locName")
  else
    locName = ::loc("missions/" + getVal(missionInfo, "name"), "")
  if (locName == "" && getVal(missionInfo, "postfix") != "")
  {
    local missionName = getVal(missionInfo, "name")
    local missionPostfix = getVal(missionInfo, "postfix")
    if (missionName.find(missionPostfix))
    {
      local name = missionName.slice(0, missionName.find(missionPostfix))
      locName = "[" + ::loc("missions/" + missionPostfix) + "] " + ::loc("missions/" + name)
    }
  }
  //we dont have lang and postfix
  if (!locName.len())
    locName = "missions/" + getVal(missionInfo, "name")
  return locName
}

function loc_current_mission_desc()
{
  local misBlk = ::DataBlock()
  ::get_current_mission_desc(misBlk)

  local locDesc = ""
  if ("locDesc" in misBlk && misBlk.locDesc.len() > 0)
    locDesc = ::get_locId_name(misBlk, "locDesc")
  else
  {
    local missionLocName = misBlk.name
    if ("loc_name" in misBlk && misBlk.loc_name != "")
      missionLocName = misBlk.loc_name
    locDesc = ::loc("missions/" + missionLocName + "/desc", "")
  }
  if (::get_game_type() & ::GT_VERSUS)
  {
    if (misBlk.maxRespawns == 1)
    {
      if (::get_game_mode()!=::GM_DOMINATION)
        locDesc = locDesc + "\n\n" + ::loc("template/noRespawns/desc")
    } else if ((misBlk.maxRespawns != null) && (misBlk.maxRespawns > 1))
      locDesc = locDesc + "\n\n" + ::loc("template/limitedRespawns/desc")
  }
  return locDesc
}


function json_escape_string( arg )
{
  if ( "string" != typeof arg )
    return ""

  local result = ""
  foreach( ch in arg )
    switch( ch )
    {
      case '\"':
        result += "\\\"";
        break;
      case '\\':
        result += "\\\\";
        break;
      case '\n':
        result += "\\n";
        break;
      case '\r':
        result += "\\r";
        break;
      default:
        if ( ch < ' ' )
          result += ::format("\\u%04X", ch );
        else
          result += ch.tochar();
        break;
    }

  return result
}


function json_reduce(array, kernel)
{
  if (array == null)
    return  null
  local len = array.len()
  if (len == 0)
    return  null
  if (len == 1)
    return  array[0]
  local head = kernel(array[0], array[1])
  if (len == 2)
    return  head
  local result = [head]
  result.extend(array.slice(2))
  return  ::json_reduce(result, kernel)
}

function json_join(delim, str_array)
{
  return ::json_reduce(str_array, (@(delim) function(prev, next) { return prev + delim + next })(delim))
}

function save_to_json(obj)
{
  local save_array = function(arr)
  {
    local content = []
    foreach (v in arr)
      content.push(save_to_json(v))

    content = ::json_join(",", content)
    if (content == null)
      content = ""
    return  "[" + content + "]"
  }.bindenv(this)

  local save_table = function(table)
  {
    local content = []
    foreach (key, val in table)
      content.push(::format("\"%s\": %s", json_escape_string(key.tostring()), save_to_json(val)))

    content = ::json_join(",", content)
    if (content == null)
      content = ""
    return  "{" + content + "}"
  }.bindenv(this)

  switch (typeof obj)
  {
    case  "array":
      return  save_array(obj)
    case  "table":
      return  save_table(obj)
    case  "string":
      return  "\"" + json_escape_string(obj.tostring()) + "\""
    case  "integer":
      return  obj.tostring()
    case  "int64":
      return  obj.tostring()
    case  "bool":
      return  obj.tostring()
    case  "float":
      return  obj.tostring()
    default:
      return  ("tostring" in obj) ? "\"" + json_escape_string(obj.tostring()) + "\"" : "null"
  }
}

function get_country_by_team(team_index)
{
  local countries = null
  if (::mission_settings && ::mission_settings.layout)
    countries = ::get_mission_team_countries(::mission_settings.layout)
  return ::getTblValue(team_index, countries) || ""
}


::roman_numerals <- ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
                         "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX"]

::get_roman_numeral_lookup <- [
  "","I","II","III","IV","V","VI","VII","VIII","IX",
  "","X","XX","XXX","XL","L","LX","LXX","LXXX","XC",
  "","C","CC","CCC","CD","D","DC","DCC","DCCC","CM",
]
::max_roman_digit <- 3

//Function from http://blog.stevenlevithan.com/archives/javascript-roman-numeral-converter
function get_roman_numeral(num)
{
  if (!::is_numeric(num) || num < 0)
  {
    ::script_net_assert_once("get_roman_numeral", "get_roman_numeral(" + num + ")")
    return ""
  }

  num = num.tointeger()
  if (num >= 4000)
    return num.tostring()

  local thousands = ""
  for (local n = 0; n < num / 1000; n++)
    thousands += "M"

  local roman = ""
  local i = -1
  while (num > 0 && i++ < ::max_roman_digit)
  {
    local digit = num % 10
    num = num / 10
    roman = ::getTblValue(digit + (i * 10), ::get_roman_numeral_lookup, "") + roman
  }
  return thousands + roman
}


function increment_parameter(object, parameter)
{
  if (!(parameter in object))
    object[parameter] <- 0;
  object[parameter]++;
}

function get_number_of_units_by_years(country)
{
  local result = {}
  for (local year = ::unit_year_selection_min; year <= ::unit_year_selection_max; year++)
  {
    result["year" + year] <- 0
    result["beforeyear" + year] <- 0
  }

  foreach (air in ::all_units)
  {
    if (::get_es_unit_type(air) != ::ES_UNIT_TYPE_AIRCRAFT)
      continue
    if (!("tags" in air) || !air.tags)
      continue;
    if (air.shopCountry != country)
      continue;

    local maxYear = 0
    for (local year = ::unit_year_selection_min; year <= ::unit_year_selection_max; year++)
    {
      local parameter = "year" + year;
      foreach(tag in air.tags)
        if (tag == parameter)
        {
          result[parameter]++
          maxYear = ::max(year, maxYear)
        }
    }
    if (maxYear)
      for (local year = maxYear + 1; year <= ::unit_year_selection_max; year++)
        result["beforeyear" + year]++
  }
  return result;
}

function scene_objects_under_cursor()
{
  local db = ::DataBlock();
  ::get_scene_objects_under_cursor(db);
  //TODO:
}


function isProductionCircuit()
{
  return ::get_cur_circuit_name().find("production") != null
}

function generatePaginator(nest_obj, handler, cur_page, last_page, my_page = null, show_last_page = false, hasSimpleNavButtons = false)
{
  if(!::checkObj(nest_obj))
    return

  local guiScene = nest_obj.getScene()
  local paginatorTpl = "gui/paginator/paginator"
  local buttonsMid = ""
  local numButtonText = "button { to_page:t='%s'; text:t='%s'; %s on_click:t='goToPage'; underline{}}"
  local numPageText = "activeText{ text:t='%s'; %s}"
  local paginatorObj = nest_obj.findObject("paginator_container")

  local paginatorMarkUpData = ::handyman.renderCached(paginatorTpl, {hasSimpleNavButtons = hasSimpleNavButtons})
  if(!::checkObj(paginatorObj))
  {
    paginatorObj = guiScene.createElement(nest_obj, "paginator", handler)
    guiScene.replaceContentFromText(paginatorObj, paginatorMarkUpData, paginatorMarkUpData.len(), handler)
  }
  else
  {
    paginatorObj.show(true)
    paginatorObj.enable(true)
  }

  //if by some mistake cur_page will be a float, - here can be a freeze on mac,
  //because of (cur_page - 1 <= i) can become wrong result
  cur_page = cur_page.tointeger()
  //number of last wisible page
  local lastShowPage = show_last_page ? last_page : min(max(cur_page + 1, 2), last_page)
  if (my_page != null && my_page > lastShowPage && my_page <= last_page)
    lastShowPage = my_page

  for (local i = 0; i <= lastShowPage; i++)
  {
    if (i == cur_page)
      buttonsMid += ::format(numPageText, (i + 1).tostring(), (i == my_page ? "mainPlayer:t='yes';" : ""))
    else if ((cur_page - 1 <= i && i <= cur_page + 1)       //around current page
             || (i == my_page)                              //equal my page
             || (i < 3)                                     //always show first 2 entrys
             || (show_last_page && i == lastShowPage))      //show last entry if show_last_page
      buttonsMid += ::format(numButtonText, i.tostring(), (i + 1).tostring(), (i == my_page ? "mainPlayer:t='yes';" : ""))
    else
    {
      buttonsMid += ::format(numPageText, "...", "")
      if (my_page != null && i < my_page && (my_page < cur_page || i > cur_page))
        i = my_page - 1
      else if (i < cur_page)
        i = cur_page - 2
      else if (show_last_page)
        i = lastShowPage - 1
    }
  }

  guiScene.replaceContentFromText(paginatorObj.findObject("paginator_page_holder"), buttonsMid, buttonsMid.len(), handler)
  local nextObj = paginatorObj.findObject("pag_next_page")
  nextObj.show(last_page > cur_page)
  nextObj.to_page = min(last_page, cur_page + 1).tostring()
  local prevObj = paginatorObj.findObject("pag_prew_page")
  prevObj.show(cur_page > 0)
  prevObj.to_page = max(0, cur_page - 1).tostring()
}

function hidePaginator(nestObj)
{
  local paginatorObj = nestObj.findObject("paginator_container")
  if(!paginatorObj)
    return
  paginatorObj.show(false)
  paginatorObj.enable(false)
}

function on_have_to_start_chard_op(message)
{
//  dlog("GP: on have to start char op message! = " +message)
  dagor.debug("on_have_to_start_chard_op "+message)

  if (message == "sync_clan_vs_profile")
  {
    local taskId = ::clan_request_sync_profile()
    ::add_bg_task_cb(taskId, function(){
      ::getMyClanData(true)
      update_gamercards()
    })
  }
  else if (message == "clan_info_reload")
  {
    ::getMyClanData(true)
    local myClanId = ::clan_get_my_clan_id()
    if(myClanId == "-1")
      ::sync_handler_simulate_request(message)
  }
  else if (message == "profile_reload")
  {
    local oldPenaltyStatus = penalty.getPenaltyStatus()
    local taskId = ::chard_request_profile()
    ::add_bg_task_cb(taskId, (@(oldPenaltyStatus) function() {
      local  newPenaltyStatus = penalty.getPenaltyStatus()
      if (newPenaltyStatus.status != oldPenaltyStatus.status || newPenaltyStatus.duration != oldPenaltyStatus.duration)
        ::broadcastEvent("PlayerPenaltyStatusChanged", {status = newPenaltyStatus.status})
    })(oldPenaltyStatus))
  }
}

function onUpdateProfile(taskId, action, transactionType = ::EATT_UNKNOWN) //code callback on profile update
{
  ::broadcastEvent("ProfileUpdated", { taskId = taskId, action = action, transactionType = transactionType })

  if (!::g_login.isLoggedIn())
    return
  ::update_gamercards()
  penalties.showBannedStatusMsgBox(true)
}

function getValueForMode(optionsMode, type)
{
  local mainOptionsMode = ::get_gui_options_mode()
  ::set_gui_options_mode(optionsMode)
  local value = get_option(type)
  value = value.values[value.value]
  ::set_gui_options_mode(mainOptionsMode)
  return value
}

function startCreateWndByGamemode(handler, obj)
{
  if("stopSearch" in handler)
    handler.stopSearch = false;
  local gm = ::match_search_gm
  if (gm == ::GM_EVENT)
    ::gui_start_briefing()
  else if (gm == ::GM_DYNAMIC)
  {
    ::mission_settings.coop = true
    ::gui_start_dynamic_layouts()
  }
  else if (gm == ::GM_BUILDER)
  {
    ::mission_settings.coop = true
    ::gui_start_builder()
  }
  else if (gm == ::GM_SINGLE_MISSION)
    ::gui_start_singleMissions()
  else if (gm == ::GM_USER_MISSION)
    ::gui_start_userMissions()
  else if (gm == ::GM_SKIRMISH)
    ::gui_create_skirmish()
  else if (gm == ::GM_DOMINATION || gm == ::GM_TOURNAMENT)
    gui_start_mislist()
  else //any coop - create dyncampaign
  {
    ::mission_settings.coop = true
    ::gui_start_dynamic_layouts()
  }
  //may be not actual with current hndler managment system
  //handler.guiScene.initCursor("gui/cursor.blk", "normal")
  ::update_gamercards()
}

function checkAndCreateGamemodeWnd(handler, gm)
{
  if (!::check_gamemode_pkg(gm))
    return

  handler.checkedNewFlight((@(handler, gm) function() {
    local tbl = ::build_check_table(null, gm)
    tbl.silent <- false
    if (::checkAllowed.bindenv(handler)(tbl))
    {
      ::match_search_gm = gm
      ::startCreateWndByGamemode(handler, null)
    }
  })(handler, gm))
}

function setDoubleTextToButton(nestObj, firstBtnId, firstText, secondText = null)
{
  if (!::checkObj(nestObj) || firstBtnId == "")
    return

  if (!secondText)
    secondText = firstText

  local secondBtnId = firstBtnId + "_text"
  local fObj = nestObj.findObject(firstBtnId)
  if(!::checkObj(fObj))
    return
  fObj.setValue(firstText)
  local sObj = fObj.findObject(secondBtnId)
  if(!::checkObj(sObj))
    return
  sObj.setValue(secondText)
}

function set_double_text_to_button(nestObj, btnId, coloredText)
{
  ::setDoubleTextToButton(nestObj, btnId, ::g_dagui_utils.removeTextareaTags(coloredText), coloredText)
}

//instead of wpCost you can use direc Cost  (instance of money)

/**
 * placePriceTextToButton(nestObj, btnId, localizedText, wpCost (int), goldCost (int))
 * placePriceTextToButton(nestObj, btnId, localizedText, cost (Cost) )
 */
function placePriceTextToButton(nestObj, btnId, localizedText, arg1=0, arg2=0)
{
  local cost = ::u.isMoney(arg1) ? arg1 : ::Cost(arg1, arg2)
  local textFormat = "%s" + (cost.isZero() ? "" : " (%s)")
  local priceText = ::format(textFormat, localizedText, cost.getUncoloredText())
  local priceTextColored = ::format(textFormat, localizedText, cost.getTextAccordingToBalance())
  ::setDoubleTextToButton(nestObj, btnId, priceText, priceTextColored)
}

function switch_profile_country(country)
{
  if (country == ::get_profile_info().country)
    return

  ::set_profile_country(country)
  ::g_squad_utils.updateMyCountryData()
  ::broadcastEvent("CountryChanged")
}

function set_help_text_on_loading(nestObj = null)
{
  if (!::checkObj(nestObj))
    return

  local text = ::show_console_buttons? ::loc("loading/help_consoleTip") : ::loc("loading/help_tip01")
  nestObj.setValue(text)
}

function setVersionText(scene=null)
{
  local verObj = scene ? scene.findObject("version_text") : ::get_cur_gui_scene()["version_text"]
  if(::checkObj(verObj))
    verObj.setValue(::format(::loc("mainmenu/version"), ::get_game_version_str()))
}

function flushExcessExpToUnit(unit)
{
  local blk = ::DataBlock()
  blk.setStr("unit", unit)

  return ::char_send_blk("cln_move_exp_to_unit", blk)
}

function flushExcessExpToModule(unit, module)
{
  local blk = ::DataBlock()
  blk.setStr("unit", unit)
  blk.setStr("mod", module)

  return ::char_send_blk("cln_move_exp_to_module", blk)
}

function buySchemeForUnit(unit)
{
  local blk = ::DataBlock()
  blk.setStr("unit", unit)

  return ::char_send_blk("cln_buy_scheme", blk)
}

/**
 * Set val to slot, specified by path.
 * Checks for identity before save.
 * If value in specified slot was changed returns true. Otherwise return false.
 */
function set_blk_value_by_path(blk, path, val)
{
  if (!blk || !path)
    return

  local nodes = ::split(path, "/")
  local key = nodes.len() ? nodes.pop() : null

  if (!key || !key.len())
    return

  foreach (dir in nodes)
    blk = blk.addBlock(dir)

  //If current value is equal to existent in DataBlock don't override it
  if (::u.isEqual(blk[key], val))
    return false

  //Remove DataBlock slot if it contains an instance or if it has different type
  //from new value
  local destType = type(blk[key])
  if (destType == "instance")
    blk[key] <- null
  else if (blk[key] != null && destType != type(val))
    blk[key] = null

  if (::isInArray(type(val), [ "string", "bool", "float", "integer", "int64", "instance", "null"]))
    blk[key] = val
  else if (::u.isTable(val))
  {
    blk = blk.addBlock(key)
    foreach(k,v in val)
      ::set_blk_value_by_path(blk, k, v)
  }
  else
  {
    ::dagor.assertf(false, "Data type not suitable for writing to blk: " + type(val))
    return false
  }

  return true
}

function get_config_blk_paths()
{
  // On PS4 path is "/app0/config.blk", but it is read-only.
  return {
    read  = (::is_platform_pc) ? ::get_config_name() : null
    write = (::is_platform_pc) ? ::get_config_name() : null
  }
}

function getSystemConfigOption(path, defVal=null)
{
  local filename = ::get_config_blk_paths().read
  if (!filename) return defVal
  local blk = ::DataBlock(filename)
  local val = ::get_blk_value_by_path(blk, path)
  return (val != null) ? val : defVal
}

function setSystemConfigOption(path, val)
{
  local filename = ::get_config_blk_paths().write
  if (!filename) return
  local blk = ::DataBlock(filename)
  if (::set_blk_value_by_path(blk, path, val))
    blk.saveToTextFile(filename)
}

function quit_and_run_cmd(cmd)
{
  ::direct_launch(cmd); //FIXME: mac???
  ::exit_game();
}


function getEnumValName(strEnumName, value, skipSynonyms=false)
{
  ::dagor.assertf(typeof(strEnumName) == "string", "strEnumName must be enum name as a string")
  local constants = getconsttable()
  local enumTable = (strEnumName in constants) ? constants[strEnumName] : {}
  local name = ""
  foreach (constName, constVal in enumTable)
    if (constVal == value)
    {
      name += (name.len() ? " || " : "") + format("%s.%s", strEnumName, constName)
      if (skipSynonyms) break
    }
  return name
}

function check_feature_tanks()
{
  return ::has_feature("Tanks")
}

function get_bit_value_by_array(selValues, values)
{
  local res = 0
  foreach(i, val in values)
    if (::isInArray(val, selValues))
      res = res | (1 << i)
  return res
}

function get_array_by_bit_value(bitValue, values)
{
  local res = []
  foreach(i, val in values)
    if (bitValue & (1 << i))
      res.append(val)
  return res
}

function call_for_handler(handler, func)
{
  if (!func)
    return
  if (handler)
    return func.call(handler)
  return func()
}

function is_vendor_tencent()
{
  return ::get_current_language() == "HChinese" || ::use_tencent_login() //we need to check language too early when get_language from profile not work
}

function is_vietnamese_version()
{
  return ::get_current_language() == "Vietnamese" || ::use_fpt_login() //we need to check language too early when get_language from profile not work
}

function is_platform_shield_tv()
{
  return ::getFromSettingsBlk("deviceType", "") == "shieldTv"
}

function is_worldwar_enabled()
{
  return ::has_feature("WorldWar") && ("g_world_war" in ::getroottable())
}

function init_use_touchscreen()
{
  if (::is_platform_shield_tv())
    return false
  return "is_thouchscreen_enabled" in getroottable() ? ::is_thouchscreen_enabled() : false
}


function check_tanks_available(silent = false)
{
  if (::is_platform_pc && "is_tanks_allowed" in getroottable() && !::is_tanks_allowed())
  {
    if (!silent)
      ::showInfoMsgBox(::loc("mainmenu/graphics_card_does_not_support_tank"), "graphics_card_does_not_support_tanks")
    return false
  }
  return true
}

function check_image_exist(img, assertText = null)
{
  if (img == "")
    return true

  img = regexp2("\\?P1$").replace("", img)
  img = regexp2("\\?x1ac$").replace("", img)

  if (regexp2("^#[^\\s]+#[^\\s]").match(img)) //skin
  {
    local skinName = regexp2("^#|#[^\\s]+").replace("", img)
    return ::cached_is_existing_image(skinName + ".ta.bin", assertText)
  }

  img = regexp2("^#").replace("", img)
  if (regexp2("[^\\s].jpg$").match(img))
    return ::cached_is_existing_image(img, assertText)

  return ::cached_is_existing_image(img + ".ddsx", assertText)
}

function check_blk_images(blk, assertText = null)
{
  foreach(tag in ["background-image", "foreground-image"])
    foreach(img in (blk % tag))
      if (typeof(img) == "string")
        if (!::check_image_exist(img, assertText))
          return false

  local totalBlocks = blk.blockCount()
  for(local i = 0; i < totalBlocks; i++)
    if (!::check_blk_images(blk.getBlock(i), assertText))
      return false
  return true
}


function find_nearest(val, arrayOfVal)
{
  if (arrayOfVal.len() == 0)
    return -1;

  local bestIdx = 0;
  local bestDist = fabs(arrayOfVal[0] - val);
  for (local i = 1; i < arrayOfVal.len(); i++)
  {
    local dist = fabs(arrayOfVal[i] - val);
    if (dist < bestDist)
    {
      bestDist = dist;
      bestIdx = i;
    }
  }

  return bestIdx;
}


function check_blk_images_by_file(fileName)
{
  local blk = ::DataBlock()
  if (!blk.load(fileName))
  {
    ::dagor.assertf(false, "Error: cant load loading bg: " + fileName)
    return false
  }
  return ::check_blk_images(blk, "Error: cant load image %s for " + fileName)
}

function combine_tables(primaryTable, secondaryTable)
{
  local primTable = clone primaryTable

  if (secondaryTable.len() > 0)
    foreach(name, value in secondaryTable)
      if (!(name in primTable))
        primTable[name] <- value

  return primTable
}

function checkRemnantPremiumAccount()
{
  if (!::has_feature("EnablePremiumPurchase") ||
      !::has_feature("SpendGold"))
    return

  local currDays = time.getDaysByTime(::get_utc_time())
  local expire = entitlement_expires_in("PremiumAccount")
  if (expire > 0)
    ::saveLocalByAccount("premium/lastDayHavePremium", currDays)
  if (expire >= NOTIFY_EXPIRE_PREMIUM_ACCOUNT)
    return

  local lastDaysReminder = ::loadLocalByAccount("premium/lastDayBuyPremiumReminder", 0)
  if (lastDaysReminder == currDays)
    return

  local lastDaysHavePremium = ::loadLocalByAccount("premium/lastDayHavePremium", 0)
  local msgText = ""
  if (expire > 0)
    msgText = ::loc("msgbox/ending_premium_account")
  else if (lastDaysHavePremium != 0)
  {
    local deltaDaysReminder = currDays - lastDaysReminder
    local deltaDaysHavePremium = currDays - lastDaysHavePremium
    local gmBlk = ::get_game_settings_blk()
    local daysCounter = gmBlk && gmBlk.reminderBuyPremiumDays || 7
    if (2 * deltaDaysReminder >= deltaDaysHavePremium || deltaDaysReminder >= daysCounter)
      msgText = ::loc("msgbox/ended_premium_account")
  }

  if (msgText != "")
  {
    ::saveLocalByAccount("premium/lastDayBuyPremiumReminder", currDays)
    ::scene_msg_box("no_premium", null,  msgText,
          [["ok", function (){ ::gui_modal_onlineShop(null, "premium") }],
          ["cancel", function () {} ]], "ok",
          {saved = true})
  }
}

::informTexQualityRestrictedDone <- false
function informTexQualityRestricted()
{
  if (::informTexQualityRestrictedDone)
    return
  local message = ::loc("msgbox/graphicsOptionValueReduced/lowVideoMemory", {
    name =  ::colorize("userlogColoredText", ::loc("options/texQuality"))
    value = ::colorize("userlogColoredText", ::loc("options/quality_medium"))
  })
  ::showInfoMsgBox(message, "sysopt_tex_quality_restricted")
  ::informTexQualityRestrictedDone = true
}

function get_localized_text_with_abbreviation(locId)
{
  if (!locId || (!("getLocTextForLang" in ::dagor)))
    return {}

  local locBlk = ::DataBlock()
  ::get_localization_blk_copy(locBlk)

  if (!locBlk || (!("abbreviation_languages_table" in locBlk)))
    return {}

  local abbreviationsList = locBlk.abbreviation_languages_table
  if (::target_platform in abbreviationsList)
    abbreviationsList = abbreviationsList[::target_platform]

  local output = {}
  for (local i = 0; i < abbreviationsList.paramCount(); i++)
  {
    local param = abbreviationsList.getParamValue(i)
    if (typeof(param) != "string")
      continue

    local abbrevName = abbreviationsList.getParamName(i)
    local text = ::dagor.getLocTextForLang(locId, param)
    if (text == null)
    {
      ::dagor.debug("Error: not found localized text for locId = '" + locId + "', lang = '" + param + "'")
      continue
    }

    output[abbrevName] <- text
  }

  return output
}

function is_myself_anyof_moderators()
{
  return ::is_myself_moderator() || ::is_myself_grand_moderator() || ::is_myself_chat_moderator()
}

function unlockCrew(crewId, byGold)
{
  local blk = ::DataBlock()
  blk.setInt("crew", crewId)
  blk.setBool("gold", byGold)

  return ::char_send_blk("cln_unlock_crew", blk)
}

function statsd_counter(metric, value = 1)
{
  if ("statsd_report" in getroottable())
    ::statsd_report("counter", "sq." + metric, value)
}

function get_navigation_images_text(cur, total)
{
  local res = ""
  if (total > 1)
  {
    local type = null
    if (cur > 0)
      type = (cur < total - 1)? "all" : "left"
    else
      type = (cur < total - 1)? "right" : null
    if (type)
      res += "navImgStyle:t='" + type + "'; "
  }
  if (cur > 0)
    res += "navigationImage{ type:t='left' } "
  if (cur < total - 1)
    res += "navigationImage{ type:t='right' } "
  return res
}

//
// Server message
//

::server_message_text <- ""
::server_message_end_time <- 0

function show_aas_notify(text, timeseconds)
{
  ::server_message_text = ::loc(text)
  ::server_message_end_time = ::dagor.getCurTime() + timeseconds * 1000
  ::broadcastEvent("ServerMessage")
  ::update_gamercards()
}

function server_message_update_scene(scene)
{
  if (!::checkObj(scene))
    return false

  local serverMessageObject = scene.findObject("server_message")
  if (!::checkObj(serverMessageObject))
    return false

  local text = ""
  if (::dagor.getCurTime() < ::server_message_end_time)
    text = server_message_text

  serverMessageObject.setValue(text)
  return text != ""
}

/**
 * Unlike Squirrel's "tolower()" this function properly
 * handles lowering case of russian characters.
 *
 * @param str String to work with.
 * @return Same string with all characters in lower case.
 */
function english_russian_to_lower_case(str)
{
  return utf8(str).strtr(::alphabet.upper, ::alphabet.lower)
}

/**
 * Removes the first element from an array and returns that element.
 *
 * @param arr Array to perform operation with.
 * @return The first element (of any data type) in an array.
 */
function array_shift(arr)
{
  if (arr.len() == 0)
    return null
  local res = arr[0]
  for (local i = 0; i < arr.len() - 1; ++i)
    arr[i] = arr[i + 1]
  arr.pop()
  return res
}

/**
 * Adds one or more elements to the beginning of an array and
 * returns the new length of the array. The other elements in
 * the array are moved from their original position, i, to i+1.
 *
 * @param arr Array to perform operation with.
 * @param ... One or more numbers, elements, or variables to
 *            be inserted at the beginning of the array.
 * @return An integer representing the new length of the array.
 */
function array_unshift(arr, ...)
{
  local oldLen = arr.len()
  for (local i = vargv.len() - 1; i >= 0; --i)
    arr.push(null)
  for (local i = oldLen - 1; i >= 0; --i)
    arr[i + vargv.len()] = arr[i]
  for (local i = vargv.len() - 1; i >= 0; --i)
    arr[i] = vargv[i]
  return arr.len()
}

function is_numeric(value)
{
  local t = typeof value
  return t == "integer" || t == "float" || t == "int64"
}

function getArrayFromInt(intNum)
{
  local array = []
  do {
    local div = intNum % 10
    array.append(div)
    intNum = ::floor(intNum/10)
  } while(intNum != 0)

  array.reverse()
  return array
}

function to_integer_safe(value, defValue = 0, needAssert = true)
{
  if (!::is_numeric(value)
    && (!::u.isString(value) || !::g_string.isStringFloat(value)))
  {
    if (needAssert)
      ::script_net_assert_once("to_int_safe", "can't convert '"+value+"' to integer")
    return defValue
  }
  return value.tointeger()
}

function to_float_safe(value, defValue = 0, needAssert = true)
{
  if (!::is_numeric(value)
    && (!::u.isString(value) || !::g_string.isStringFloat(value)))
  {
    if (needAssert)
      ::script_net_assert_once("to_float_safe", "can't convert '"+value+"' to float")
    return defValue
  }
  return value.tofloat()
}

/**
 * Uses gui scene if specified scene is not valid.
 * Returns null if object was found but is not valid.
 */
function get_object_from_scene(name, scene = null)
{
  local obj
  if (::checkObj(scene))
    obj = scene.findObject(name)
  else
  {
    local guiScene = ::get_cur_gui_scene()
    if (guiScene != null)
      obj = guiScene[name]
  }
  return ::checkObj(obj) ? obj : null
}

const PASSWORD_SYMBOLS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
function gen_rnd_password(charsAmount)
{
  local res = ""
  local total = PASSWORD_SYMBOLS.len()
  for(local i = 0; i < charsAmount; i++)
    res += PASSWORD_SYMBOLS[::math.rnd() % total].tochar()
  return res
}

function assembleBlueprints()
{

  return ::char_send_action_and_load_profile("cln_assemble_blueprints")
}

function sellBlueprints(uid, count)
{
  local blk = ::DataBlock()
  blk.setStr("uid", uid)
  blk.setInt("count", count)
  return ::char_send_blk("cln_sell_blueprints", blk)
}

function inherit_table(parent_table, child_table)
{
  return ::u.extend(::u.copy(parent_table), child_table)
}

/** Triggered from C++ when in-game cursor visibility toggles. */
function on_changed_cursor_visibility(old_value)
{
  ::broadcastEvent("ChangedCursorVisibility", {
    oldValue = old_value
    newValue = ::is_cursor_visible_in_gui()
  })
}

function char_convert_blueprints(type)
{
  local blk = ::DataBlock()
  blk.setStr("type", type)
  return ::char_send_blk("cln_convert_blueprints", blk)
}

function is_mode_with_friendly_units(gt = null)
{
  if (gt == null)
    gt = ::get_game_type()
  return !!(gt & ::GT_RACE) || !(gt & (::GT_FFA_DEATHMATCH | ::GT_FFA))
}

function is_mode_with_teams(gt = null)
{
  if (gt == null)
    gt = ::get_game_type()
  return !(gt & (::GT_FFA_DEATHMATCH | ::GT_FFA))
}
::cross_call_api.is_mode_with_teams <- ::is_mode_with_teams


function is_team_friendly(teamId)
{
  return ::is_mode_with_teams() &&
    teamId == ::get_player_army_for_hud()
}

function get_team_color(teamId)
{
  return is_team_friendly(teamId) ? "hudColorBlue" : "hudColorRed"
}

function get_mplayer_color(player)
{
  return !player ? "" :
    player.isLocal ? "hudColorHero" :
    player.isInHeroSquad ? "hudColorSquad" :
    ::get_team_color(player.team)
}

function build_mplayer_name(player, colored = true, withClanTag = true, withUnit = false, unitNameLoc = "")
{
  if (!player)
    return ""

  local clanTag = withClanTag ? player.clanTag : ""
  local name = ::g_string.implode([clanTag, player.name], " ")

  if (withUnit)
  {
    if (unitNameLoc == "")
    {
      local unitId = player.aircraftName
      if (unitId != "")
        unitNameLoc = ::loc(unitId + "_1")
    }
    if (unitNameLoc != "")
      name += ::loc("ui/parentheses/space", {text = unitNameLoc})
  }

  return colored ? ::colorize(::get_mplayer_color(player), name) : name
}

function is_multiplayer()
{
  return ::is_mplayer_host() || ::is_mplayer_peer()
}

function show_gblk_error_popup(type, path)
{
  if (!::g_login.isLoggedIn())
  {
    ::delayed_gblk_error_popups.append({ type = type, path = path })
    return
  }

  local title = ::loc("gblk/saveError/title")
  local msg = ::loc(::format("gblk/saveError/text/%d", type), {path=path})
  ::g_popups.add(title, msg, null, [{id="copy_button",
                              text=::loc("gblk/saveError/copy"),
                              func=(@(msg) function() {::copy_to_clipboard(msg)})(msg)}])
}

function pop_gblk_error_popups()
{
  if (!::g_login.isLoggedIn())
    return

  local total = ::delayed_gblk_error_popups.len()
  for(local i = 0; i < total; i++)
  {
    local data = ::delayed_gblk_error_popups[i]
    ::show_gblk_error_popup(data.type, data.path)
  }
  ::delayed_gblk_error_popups.clear()
}

function get_dagui_obj_aabb(obj)
{
  if (!::checkObj(obj))
    return null

  local size = obj.getSize()
  if (size[0] < 0)
    return null  //not inited
  return {
    size = size
    pos = obj.getPosRC()
    visible = obj.isVisible()
  }
}

::_net_asserts_list <- []
function script_net_assert_once(id, msg)
{
  if (::isInArray(id, _net_asserts_list))
    return dagor.debug(msg)

  _net_asserts_list.append(id)
  return script_net_assert(msg)
}

function assertf_once(id, msg)
{
  if (::isInArray(id, _net_asserts_list))
    return dagor.debug(msg)
  _net_asserts_list.append(id)
  return ::dagor.assertf(false, msg)
}

function get_object_value(parentObj, id, defValue = null)
{
  if (!::checkObj(parentObj))
    return defValue

  local obj = parentObj.findObject(id)
  if (::checkObj(obj))
    return obj.getValue()

  return defValue
}

function destroy_session_scripted()
{
  local needEvent = ::is_mplayer_peer()
  ::destroy_session()
  if (needEvent)
    ::broadcastEvent("SessionDestroyed")
}

function show_not_available_msg_box()
{
  ::showInfoMsgBox(::loc("msgbox/notAvailbleYet"), "not_available", true)
}

function is_hangar_blur_available()
{
  return ("enable_dof" in ::getroottable())
}

function hangar_blur(enable, params = null)
{
  if (!::is_hangar_blur_available())
    return
  if (enable)
  {
    ::enable_dof(::getTblValue("nearFrom",   params, 1000000), // meters
                 ::getTblValue("nearTo",     params, 0), // meters
                 ::getTblValue("nearEffect", params, 1), // 0..1
                 ::getTblValue("farFrom",    params, 0), // meters
                 ::getTblValue("farTo",      params, 0), // meters
                 ::getTblValue("farEffect",  params, 0)) // 0..1
  }
  else
    ::disable_dof()
}
