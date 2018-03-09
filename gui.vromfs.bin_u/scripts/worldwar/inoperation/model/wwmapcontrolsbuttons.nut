local enums = ::require("std/enums.nut")

::g_ww_map_controls_buttons <- {
  types = []
  cache = {}
  selectedObjectCode = mapObjectSelect.NONE
}

::g_ww_map_controls_buttons.template <- {
  funcName = null
  shortcut = null
  actionName = ""
  text = function () {
      local text = actionName
      if (!::show_console_buttons)
      {
        local shortcutText = ::u.isFunction(shortcut) ? shortcut() : shortcut
        text += ::loc("ui/parentheses/space", {text = shortcutText})
      }
      return text
    }
  isHidden = function() { return true }
  isEnabled = function() { return true }
}

enums.addTypesByGlobalName("g_ww_map_controls_buttons",
{
  MOVE = {
    id = "army_move_button"
    funcName = "onArmyMove"
    shortcut = "A"
    text = function () {
      if (::g_ww_map_controls_buttons.selectedObjectCode == mapObjectSelect.AIRFIELD)
        return ::loc("worldWar/armyFlyOut")
      if (::g_ww_map_controls_buttons.selectedObjectCode == mapObjectSelect.REINFORCEMENT)
        return ::loc("worldWar/armyDeploy")

      return ::loc("worldWar/armyMove")
    }
    isHidden = function () {
      return !::show_console_buttons
    }
    isEnabled = function () {
      return !::g_world_war.isCurrentOperationFinished()
    }
  }
  ENTRENCH = {
    id = "army_entrench_button"
    funcName = "onArmyEntrench"
    shortcut = "RB"
    style = "accessKey:'J:RB | E';"
    text = function () { return ::loc("worldWar/armyEntrench") + (::show_console_buttons ? "" : " (E)")}
    isHidden = function () {
      local armiesNames = ::ww_get_selected_armies_names()
      if (!armiesNames.len())
        return true

      foreach (armyName in armiesNames)
      {
        local army = ::g_world_war.getArmyByName(armyName)
        local unitType = army.getUnitType()
        if (::g_ww_unit_type.isGround(unitType) ||
            ::g_ww_unit_type.isInfantry(unitType))
          return false
      }

      return true
    }
    isEnabled = function() {
      if (!::g_world_war.isCurrentOperationFinished())
        foreach (army in ::g_world_war.getSelectedArmies())
          if (!army.isEntrenched())
            return true

      return false
    }
  }

  STOP = {
    id = "army_stop_button"
    funcName = "onArmyStop"
    shortcut = "Y"
    style = "accessKey:'J:Y | S';"
    text = function () { return ::loc("worldWar/armyStop") + (::show_console_buttons ? "" : " (S)")}
    isHidden = function () {
      return ::ww_get_selected_armies_names().len() == 0
    }
    isEnabled = function () {
      return !::g_world_war.isCurrentOperationFinished()
    }
  }

  PREPARE_FIRE = {
    id = "army_prepare_fire_button"
    funcName = "onArtilleryArmyPrepareToFire"
    shortcut = "LB"
    style = "accessKey:'J:LB | A';"
    text = function () {
      if (::ww_artillery_strike_mode_on())
        return ::loc("worldWar/armyCancel") + (::show_console_buttons ? "" : " (A)")
      else
        return ::loc("worldWar/armyFire") + (::show_console_buttons ? "" : " (A)")
    }
    isHidden = function () {
      local armiesNames = ::ww_get_selected_armies_names()
      if (!armiesNames.len())
        return true

      foreach (armyName in armiesNames)
      {
        local army = ::g_world_war.getArmyByName(armyName)
        local unitType = army.getUnitType()
        if (::g_ww_unit_type.isArtillery(unitType))
          return false
      }

      return true
    }
    isEnabled = function () {
      return !::g_world_war.isCurrentOperationFinished()
    }
  }
}, null, "name")

function g_ww_map_controls_buttons::setSelectedObjectCode(code)
{
  selectedObjectCode = code
}
