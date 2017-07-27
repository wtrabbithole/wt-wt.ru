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
      res += "\n" + ::loc("shop/reloadTime") + ::secondsToString(cooldownTime, true, true)
    return res
  }

  getShortcut = function(actionItem, unit = null)
  {
    if (!unit)
      unit = ::get_player_cur_unit()
    local shortcutIdx = ::getTblValue("shortcutIdx", actionItem, actionItem.id) //compatibility with 1.67.2.X
    if (::isShip(unit))
      return "ID_SHIP_ACTION_BAR_ITEM_" + (shortcutIdx + 1)
    return "ID_ACTION_BAR_ITEM_" + (shortcutIdx + 1)
  }

  getVisualShortcut = function(actionItem, unit = null)
  {
    if (!isForWheelMenu() || !::is_xinput_device())
      return getShortcut(actionItem, unit)

    if (!unit)
      unit = ::get_player_cur_unit()
    if (::isShip(unit))
      return "ID_SHIP_KILLSTREAK_WHEEL_MENU"
    return "ID_KILLSTREAK_WHEEL_MENU"
  }
}

::g_enum_utils.addTypesByGlobalName("g_hud_action_bar_type", {
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
    getShortcut = @(actionItem, unit = null) "ID_SHIP_WEAPON_TORPEDOES"
  }

  DEPTH_CHARGE = {
    code = ::EII_DEPTH_CHARGE
    _name = "deapth_charge"
    _icon = "#ui/gameuiskin#depth_charge"
    getShortcut = @(actionItem, unit = null) "ID_SHIP_WEAPON_DEPTH_CHARGE"
  }

  ROCKET = {
    code = ::EII_ROCKET
    _name = "rocket"
    _icon = "#ui/gameuiskin#rocket"
    getShortcut = function(actionItem, unit = null)
    {
      if (::is_helicopter(unit))
        return "ID_ROCKETS_HELICOPTER"
      if (::isShip(unit))
        return "ID_SHIP_WEAPON_ROCKETS"
      if (::isTank(unit))
        return "ID_FIRE_GM_SPECIAL_GUN"
      return "ID_ROCKETS"
    }
  }

  SMOKE_SCREEN = {
    code = ::EII_SMOKE_SCREEN
    _name = "smoke_screen"
    _icon = "#ui/gameuiskin#smoke_screen"
    getShortcut = @(actionItem, unit = null) "ID_SMOKE_SCREEN"
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
    isForWheelMenu = @() ::isShip(::get_player_cur_unit())
    _name = "extinguisher"
    _icon = "#ui/gameuiskin#extinguisher"
    _title = ::loc("hotkeys/ID_ACTION_BAR_ITEM_6")
    needAnimOnIncrementCount = true
  }

  TOOLKIT = {
    code = ::EII_TOOLKIT
    isForWheelMenu = @() ::isShip(::get_player_cur_unit())
    _name = "toolkit"
    _icon = "#ui/gameuiskin#tank_tool_kit"
    _title = ::loc("hotkeys/ID_SHIP_ACTION_BAR_ITEM_11")
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
      local unit = ::get_player_cur_unit()
      local mod = ::getModificationByName(unit, "tank_medical_kit")
      return ::getTblValue("image", mod)
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
    getShortcut = @(actionItem, unit = null) "ID_REPAIR_BREACHES"
  }
})

function g_hud_action_bar_type::getTypeByCode(code)
{
  return ::g_enum_utils.getCachedType("code", code, cache.byCode, this, UNKNOWN)
}

function g_hud_action_bar_type::getByActionItem(actionItem)
{
  return getTypeByCode(actionItem.type)
}
