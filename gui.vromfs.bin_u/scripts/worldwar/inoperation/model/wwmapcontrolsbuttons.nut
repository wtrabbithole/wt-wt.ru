local enums = ::require("sqStdlibs/helpers/enums.nut")

global enum WW_MAP_CONSPLE_SHORTCUTS
{
  LMB_IMITATION = "RT"
  MOVE = "A"
  ENTRENCH = "RB"
  STOP = "Y"
  PREPARE_FIRE = "LB"
}

::g_ww_map_controls_buttons <- {
  types = []
  cache = {}
  selectedObjectCode = mapObjectSelect.NONE
}

::g_ww_map_controls_buttons.template <- {
  funcName = null
  shortcut = null
  keyboardShortcut = ""
  getActionName = @() ""
  getKeyboardShortcut = @() ::show_console_buttons
    ? ""
    : ::loc("ui/parentheses/space", { text = keyboardShortcut})
  text = @() $"{getActionName()}{getKeyboardShortcut()}"
  isHidden = @() true
  isEnabled = @() !::g_world_war.isCurrentOperationFinished()
}

enums.addTypesByGlobalName("g_ww_map_controls_buttons",
{
  MOVE = {
    id = "army_move_button"
    funcName = "onArmyMove"
    shortcut = WW_MAP_CONSPLE_SHORTCUTS.MOVE
    text = function () {
      if (::g_ww_map_controls_buttons.selectedObjectCode == mapObjectSelect.AIRFIELD)
        return ::loc("worldWar/armyFlyOut")
      if (::g_ww_map_controls_buttons.selectedObjectCode == mapObjectSelect.REINFORCEMENT)
        return ::loc("worldWar/armyDeploy")

      return ::loc("worldWar/armyMove")
    }
    isHidden = @() !::show_console_buttons
  }
  ENTRENCH = {
    id = "army_entrench_button"
    funcName = "onArmyEntrench"
    shortcut = WW_MAP_CONSPLE_SHORTCUTS.ENTRENCH
    keyboardShortcut = "E"
    style = "accessKey:'J:RB | E';"
    getActionName = @() ::loc("worldWar/armyEntrench")
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
    shortcut = WW_MAP_CONSPLE_SHORTCUTS.STOP
    keyboardShortcut = "S"
    style = "accessKey:'J:Y | S';"
    getActionName = @() ::loc("worldWar/armyStop")
    isHidden = @() ::ww_get_selected_armies_names().len() == 0
  }

  PREPARE_FIRE = {
    id = "army_prepare_fire_button"
    funcName = "onArtilleryArmyPrepareToFire"
    shortcut = WW_MAP_CONSPLE_SHORTCUTS.PREPARE_FIRE
    keyboardShortcut = "A"
    style = "accessKey:'J:LB | A';"
    getActionName = @() ::ww_artillery_strike_mode_on()
      ? ::loc("worldWar/armyCancel")
      : ::loc("worldWar/armyFire")
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
  }
}, null, "name")

g_ww_map_controls_buttons.setSelectedObjectCode <- function setSelectedObjectCode(code)
{
  selectedObjectCode = code
}
