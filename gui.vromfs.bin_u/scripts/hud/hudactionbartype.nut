::g_hud_action_bar_type <- {
  types = []
}

function g_hud_action_bar_type::_getName(data = null)
{
  return _name
}

function g_hud_action_bar_type::_getIcon(data = null)
{
  return _icon
}

function g_hud_action_bar_type::_getTitle(data = null)
{
  return _title
}

function g_hud_action_bar_type::_getTooltipText(data = null)
{
  return ::loc("actionBarItem/" + getName(data))
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
  isForWheelMenu = false

  _name = ""
  _icon = ""
  _title = ""

  getName = ::g_hud_action_bar_type._getName
  getIcon = ::g_hud_action_bar_type._getIcon
  getTitle = ::g_hud_action_bar_type._getTitle
  getTooltipText = ::g_hud_action_bar_type._getTooltipText
}

::g_enum_utils.addTypesByGlobalName("g_hud_action_bar_type", {
  UNKNOWN = {
    _name = "unknown"
  }

  BULLET = {
    code = ::EII_BULLET
    _name = "bullet"
  }

  ARTILLERY_TARGET = {
    code = ::EII_ARTILLERY_TARGET
    _name = "artillery_target"
    isForWheelMenu = true
    _icon = "#ui/gameuiskin#artillery_fire"
    _title = ::loc("hotkeys/ID_ACTION_BAR_ITEM_5")
  }

  EXTINGUISHER = {
    code = ::EII_EXTINGUISHER
    _name = "extinguisher"
    _icon = "#ui/gameuiskin#extinguisher"
    _title = ::loc("hotkeys/ID_ACTION_BAR_ITEM_6")
  }

  TOOLKIT = {
    code = ::EII_TOOLKIT
    _name = "toolkit"
    _icon = "#ui/gameuiskin#tank_tool_kit"
    _title = ::loc("hints/toolkit")
  }

  MEDICALKIT = {
    code = ::EII_MEDICALKIT
    isForWheelMenu = true
    _name = "medicalkit"
    _icon = "#ui/gameuiskin#tank_medkit"
    _title = ::loc("hints/tank_medkit")

    getIcon = function (data = null)
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
    isForWheelMenu = true

    getName = function (data = null)
    {
      if (::u.isString(data))
        return _name + "_" + data
      return ""
    }

    getIcon = function (data = null)
    {
      // Data is expected to be "bomber", "attacker" or "fighter".
      if (::u.isString(data))
        return ::format("#ui/gameuiskin#%s_streak", data)
      return ""
    }

    getTitle = function (data = null)
    {
      if (data == "bomber")
        return ::loc("hotkeys/ID_ACTION_BAR_ITEM_9")
      if (data == "attacker")
        return ::loc("hotkeys/ID_ACTION_BAR_ITEM_8")
      if (data == "fighter")
        return ::loc("hotkeys/ID_ACTION_BAR_ITEM_7")
      return ""
    }
  }

  WINCH = {
    code = ::EII_WINCH
    backgroundImage = "#ui/gameuiskin#winch_request"
    isForWheelMenu = true
    _name = "winch"
    _icon = "#ui/gameuiskin#winch_request"
    _title = ::loc("hints/winch_request")
  }

  WINCH_DETACH = {
    code = ::EII_WINCH_DETACH
    backgroundImage = "#ui/gameuiskin#winch_request_off"
    isForWheelMenu = true
    _name = "winch_detach"
    _icon = "#ui/gameuiskin#winch_request_off"
    _title = ::loc("hints/winch_detach")
  }

  WINCH_ATTACH = {
    code = ::EII_WINCH_ATTACH
    backgroundImage = "#ui/gameuiskin#winch_request_deploy"
    isForWheelMenu = true
    _name = "winch_attach"
    _icon = "#ui/gameuiskin#winch_request_deploy"
    _title = ::loc("hints/winch_use")
  }
})

function g_hud_action_bar_type::getTypeByCode(code)
{
  return ::g_enum_utils.getCachedType(
    "code", code,
    ::g_hud_action_bar_type_cache.byCode,
    ::g_hud_action_bar_type,
    ::g_hud_action_bar_type.UNKNOWN)
}

::g_hud_action_bar_type_cache <- {
  byCode = {}
}
