local enums = ::require("std/enums.nut")
local time = require("scripts/time.nut")


::g_hud_action_bar_type <- {
  types = []

  cache = { byCode = {} }
}

::g_hud_action_bar_type.template <- {
  code = -1
  backgroundImage = ""

  /**
   * For all items, which should be grouped
   * as stricks this field is true, even if
   * this item is not a kill streak reward.
   *
   * In present design this field is true for
   * artillery and special unit.
   */
  isForWheelMenu = @() false

  _name = ""
  _icon = ""
  _title = ""
  needAnimOnIncrementCount = false

  getName        = @(killStreakTag = null) _name
  getIcon        = @(killStreakTag = null) _icon
  getTitle       = @(killStreakTag = null) _title
  getTooltipText = function(actionItem = null)
  {
    local res = ::loc("actionBarItem/" + getName(::getTblValue("killStreakTag", actionItem)))
    local cooldownTime = ::getTblValue("cooldownTime", actionItem)
    if (cooldownTime)
      res += "\n" + ::loc("shop/reloadTime") + time.secondsToString(cooldownTime, true, true)
    return res
  }

  getShortcut = function(actionItem = null, unit = null)
  {
    if (!unit)
      unit = ::getAircraftByName(::get_action_bar_unit_name())
    local shortcutIdx = actionItem?.shortcutIdx ?? ::get_action_shortcut_index_by_type(code)
    if (shortcutIdx < 0)
      return null

    if (::is_submarine(unit))
      return "ID_SUBMARINE_ACTION_BAR_ITEM_" + (shortcutIdx + 1)
    if (::isShip(unit))
      return "ID_SHIP_ACTION_BAR_ITEM_" + (shortcutIdx + 1)
    return "ID_ACTION_BAR_ITEM_" + (shortcutIdx + 1)
  }

  getVisualShortcut = function(actionItem = null, unit = null)
  {
    if (!isForWheelMenu() || !::is_xinput_device())
      return getShortcut(actionItem, unit)

    if (!unit)
      unit = ::getAircraftByName(::get_action_bar_unit_name())
    if (::is_submarine(unit))
      return "ID_SUBMARINE_KILLSTREAK_WHEEL_MENU"
    if (::isShip(unit))
      return "ID_SHIP_KILLSTREAK_WHEEL_MENU"
    return "ID_KILLSTREAK_WHEEL_MENU"
  }
}

enums.addTypesByGlobalName("g_hud_action_bar_type", {
  UNKNOWN = {
    _name = "unknown"
  }

  BULLET = {
    code = ::EII_BULLET
    _name = "bullet"
    needAnimOnIncrementCount = true
  }

  TORPEDO = {
    code = ::EII_TORPEDO
    _name = "torpedo"
    _icon = "#ui/gameuiskin#torpedo"
    getShortcut = @(actionItem, unit = null)
      ::is_submarine(unit) ? "ID_SUBMARINE_WEAPON_TORPEDOES" : "ID_SHIP_WEAPON_TORPEDOES"
  }

  DEPTH_CHARGE = {
    code = ::EII_DEPTH_CHARGE
    _name = "depth_charge"
    _icon = "#ui/gameuiskin#depth_charge"
    getShortcut = @(actionItem, unit = null)
      ::is_submarine(unit) ? "ID_SUBMARINE_WEAPON_DEPTH_CHARGE" : "ID_SHIP_WEAPON_DEPTH_CHARGE"
    getIcon = function(killStreakTag = null)
    {
      local unit = ::getAircraftByName(::get_action_bar_unit_name())
      return ::is_minelayer(unit) ? "#ui/gameuiskin#naval_mine" : _icon
    }
  }

  ROCKET = {
    code = ::EII_ROCKET
    _name = "rocket"
    _icon = "#ui/gameuiskin#rocket"
    getShortcut = function(actionItem, unit = null)
    {
      if (::is_helicopter(unit))
        return "ID_ROCKETS_HELICOPTER"
      if (::is_submarine(unit))
        return "ID_SUBMARINE_WEAPON_ROCKETS"
      if (::isShip(unit))
        return "ID_SHIP_WEAPON_ROCKETS"
      if (::isTank(unit))
        return "ID_FIRE_GM_SPECIAL_GUN"
      return "ID_ROCKETS"
    }
  }

  SMOKE_GRENADE = {
    code = ::EII_SMOKE_GRENADE
    _name = "smoke_screen"
    isForWheelMenu = @() true
    _icon = "#ui/gameuiskin#smoke_screen"
    _title = ::loc("hotkeys/ID_SMOKE_SCREEN")
    getShortcut = @(actionItem, unit = null) "ID_SMOKE_SCREEN"
  }

  SMOKE_SCREEN = {
    code = ::EII_SMOKE_SCREEN
    _name = "engine_smoke_screen_system"
    isForWheelMenu = @() true
    _icon = "#ui/gameuiskin#engine_smoke_screen_system"
    _title = ::loc("hotkeys/ID_SMOKE_SCREEN_GENERATOR")
    getShortcut = function(actionItem, unit = null)
    {
      if (::is_submarine(unit))
        return "ID_SUBMARINE_ACOUSTIC_COUNTERMEASURES"
      if (::isShip(unit))
        return "ID_SHIP_SMOKE_SCREEN_GENERATOR"
      return "ID_SMOKE_SCREEN_GENERATOR"
    }
    getIcon = @(killStreakTag = null)
      ::is_submarine(::getAircraftByName(::get_action_bar_unit_name())) ? "#ui/gameuiskin#acoustic_countermeasures" : _icon
    getTitle = @(killStreakTag = null)
      ::is_submarine(::getAircraftByName(::get_action_bar_unit_name()))
        ? ::loc("hotkeys/ID_SUBMARINE_ACOUSTIC_COUNTERMEASURES")
        : _title
    getName = @(killStreakTag = null)
      ::is_submarine(::getAircraftByName(::get_action_bar_unit_name()))
        ? "acoustic_countermeasure"
        : _name
  }

  SCOUT = {
    code = ::EII_SCOUT
    isForWheelMenu = @() true
    _name = "scout_active"
    _icon = "#ui/gameuiskin#scouting"
    _title = ::loc("hotkeys/ID_SCOUT")
    getShortcut = @(actionItem, unit = null) "ID_SCOUT"
  }

  SONAR = {
    code = ::EII_SUBMARINE_SONAR
    isForWheelMenu = @() true
    _name = "sonar_active"
    _icon = "#ui/gameuiskin#sonar_indicator"
    _title = ::loc("hotkeys/ID_SUBMARINE_SWITCH_ACTIVE_SONAR")
    getShortcut = @(actionItem, unit = null) "ID_SUBMARINE_SWITCH_ACTIVE_SONAR"
  }

  TORPEDO_SENSOR = {
    code = ::EII_TORPEDO_SENSOR
    isForWheelMenu = @() true
    _name = "torpedo_sensor"
    _icon = "#ui/gameuiskin#torpedo_active_sonar"
    _title = ::loc("hotkeys/ID_SUBMARINE_WEAPON_TOGGLE_ACTIVE_SENSOR")
    getShortcut = @(actionItem, unit = null) "ID_SUBMARINE_WEAPON_TOGGLE_ACTIVE_SENSOR"
  }

  ARTILLERY_TARGET = {
    code = ::EII_ARTILLERY_TARGET
    _name = "artillery_target"
    isForWheelMenu = @() true
    _icon = "#ui/gameuiskin#artillery_fire"
    _title = ::loc("hotkeys/ID_ACTION_BAR_ITEM_5")
    needAnimOnIncrementCount = true
    getIcon = function (killStreakTag = null)
    {
      local mis = ::get_current_mission_info_cached()
      return mis && mis.useCustomSuperArtillery ? "#ui/gameuiskin#artillery_fire_on_target" : "#ui/gameuiskin#artillery_fire"
    }
  }

  EXTINGUISHER = {
    code = ::EII_EXTINGUISHER
    isForWheelMenu = @() ::isShip(::getAircraftByName(::get_action_bar_unit_name()))
    _name = "extinguisher"
    _icon = "#ui/gameuiskin#extinguisher"
    _title = ::loc("hotkeys/ID_ACTION_BAR_ITEM_6")
    needAnimOnIncrementCount = true
    getIcon = @(killStreakTag = null)
      ::isShip(::getAircraftByName(::get_action_bar_unit_name())) ? "#ui/gameuiskin#manual_ship_extinguisher" : "#ui/gameuiskin#extinguisher"
  }

  TOOLKIT = {
    code = ::EII_TOOLKIT
    isForWheelMenu = @() ::isShip(::getAircraftByName(::get_action_bar_unit_name()))
    _name = "toolkit"
    _icon = "#ui/gameuiskin#tank_tool_kit"
    _title = ::loc("hotkeys/ID_SHIP_ACTION_BAR_ITEM_11")
    getIcon = @(killStreakTag = null)
      ::isShip(::getAircraftByName(::get_action_bar_unit_name())) ? "#ui/gameuiskin#ship_tool_kit" : "#ui/gameuiskin#tank_tool_kit"
  }

  MEDICALKIT = {
    code = ::EII_MEDICALKIT
    isForWheelMenu = @() true
    _name = "medicalkit"
    _icon = "#ui/gameuiskin#tank_medkit"
    _title = ::loc("hints/tank_medkit")
    needAnimOnIncrementCount = true

    getIcon = function (killStreakTag = null)
    {
      local unit = ::getAircraftByName(::get_action_bar_unit_name())
      local mod = ::getModificationByName(unit, "tank_medical_kit")
      return mod?.image ?? ""
    }
  }

  ANTI_AIR_TARGET = {
    code = ::EII_ANTI_AIR_TARGET
    _name = "anti_air_target"
    _icon = "" //"#ui/gameuiskin#anti_air_target" //there is no such icon now
                                                  //commented for avoid crash
    _title = "" //::loc("encyclopedia/anti_air")
  }

  SPECIAL_UNIT = {
    code = ::EII_SPECIAL_UNIT
    _name = "special_unit"
    isForWheelMenu = @() true

    getName = function (killStreakTag = null)
    {
      if (::u.isString(killStreakTag))
        return _name + "_" + killStreakTag
      return ""
    }

    getIcon = function (killStreakTag = null)
    {
      // killStreakTag is expected to be "bomber", "attacker" or "fighter".
      if (::u.isString(killStreakTag))
        return ::format("#ui/gameuiskin#%s_streak", killStreakTag)
      return ""
    }

    getTitle = function (killStreakTag = null)
    {
      if (killStreakTag == "bomber")
        return ::loc("hotkeys/ID_ACTION_BAR_ITEM_9")
      if (killStreakTag == "attacker")
        return ::loc("hotkeys/ID_ACTION_BAR_ITEM_8")
      if (killStreakTag == "fighter")
        return ::loc("hotkeys/ID_ACTION_BAR_ITEM_7")
      return ""
    }
  }

  WINCH = {
    code = ::EII_WINCH
    backgroundImage = "#ui/gameuiskin#winch_request"
    isForWheelMenu = @() true
    _name = "winch"
    _icon = "#ui/gameuiskin#winch_request"
    _title = ::loc("hints/winch_request")
  }

  WINCH_DETACH = {
    code = ::EII_WINCH_DETACH
    backgroundImage = "#ui/gameuiskin#winch_request_off"
    isForWheelMenu = @() true
    _name = "winch_detach"
    _icon = "#ui/gameuiskin#winch_request_off"
    _title = ::loc("hints/winch_detach")
  }

  WINCH_ATTACH = {
    code = ::EII_WINCH_ATTACH
    backgroundImage = "#ui/gameuiskin#winch_request_deploy"
    isForWheelMenu = @() true
    _name = "winch_attach"
    _icon = "#ui/gameuiskin#winch_request_deploy"
    _title = ::loc("hints/winch_use")
  }

  REPAIR_BREACHES = {
    code = ::EII_REPAIR_BREACHES
    isForWheelMenu = @() true
    _name = "repair_breaches"
    _icon = "#ui/gameuiskin#unwatering"
    _title = ::loc("hotkeys/ID_REPAIR_BREACHES")
    getShortcut = @(actionItem, unit = null)
      ::is_submarine(unit) ? "ID_SUBMARINE_REPAIR_BREACHES" : "ID_REPAIR_BREACHES"
  }

  SHIP_CURRENT_TRIGGER_GROUP = {
    code = ::EII_SHIP_CURRENT_TRIGGER_GROUP
    _name = "ship_current_trigger_group"
    getShortcut = @(...) null
    getIcon = function (killStreakTag = null) {
      local currentTrigger = ::get_current_trigger_group()
      switch (currentTrigger)
      {
        case TRIGGER_GROUP_PRIMARY:
          return "!ui/gameuiskin#artillery_weapon_state_indicator"
        case TRIGGER_GROUP_SECONDARY:
          return "!ui/gameuiskin#artillery_secondary_weapon_state_indicator"
        case TRIGGER_GROUP_MACHINE_GUN:
          return "!ui/gameuiskin#machine_gun_weapon_state_indicator"
        default:
          return "!ui/gameuiskin#artillery_weapon_state_indicator"
      }
    }
  }
})

function g_hud_action_bar_type::getTypeByCode(code)
{
  return enums.getCachedType("code", code, cache.byCode, this, UNKNOWN)
}

function g_hud_action_bar_type::getByActionItem(actionItem)
{
  return getTypeByCode(actionItem.type)
}
