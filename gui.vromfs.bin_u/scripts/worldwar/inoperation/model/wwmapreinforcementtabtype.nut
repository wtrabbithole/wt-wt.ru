::g_ww_map_reinforcement_tab_type <- {
  types = []
  cache = {
    byCode = {}
  }
}


::g_ww_map_reinforcement_tab_type.template <- {
  getHandler = function (placeObj) { return null }
  hasTabAlert = @() false
  isTabAlertVisible = @() false
  getTabTextPostfix = function() { return "" }
}


::g_enum_utils.addTypesByGlobalName("g_ww_map_reinforcement_tab_type", {
  UNKNOWN = {
    code = -1
  }


  COMMANDERS = {
    code = 0
    tabId = "commanders_block"
    tabIcon = "worldWar/iconCommander"
    tabText = "worldwar/commanders"
    getHandler = function (placeObj) {
      return ::handlersManager.loadHandler(
        ::gui_handlers.WwCommanders,
        { scene = placeObj }
      )
    }
  }


  REINFORCEMENT = {
    code = 1
    tabId = "reinforcements_block"
    tabIcon = "worldWar/iconReinforcement"
    tabText = "worldWar/Reinforcements"
    hasTabAlert = @() true
    isTabAlertVisible = @() ::g_world_war.getMyReadyReinforcementsArray().len() > 0
    getTabTextPostfix = function() {
      local availReinf = ::g_world_war.getMyReadyReinforcementsArray().len()
      if (availReinf > 0)
        return ::loc("ui/parentheses/space", {text = availReinf})
      return ""
    }
    getHandler = function (placeObj)
    {
      return ::handlersManager.loadHandler(
        ::gui_handlers.WwReinforcements,
        { scene = placeObj }
      )
    }
  }


  AIRFIELDS = {
    code = 2
    tabId = "airfields_block"
    tabIcon = "worldwar/iconAir"
    tabText = "worldWar/airfieldsList"
    getHandler = function (placeObj) {
      return ::handlersManager.loadHandler(
        ::gui_handlers.WwAirfieldsList,
        {
          scene = placeObj
          side = ::ww_get_player_side()
        }
      )
    }
  }


  ARMIES = {
    code = 3
    tabId = "armies_block"
    tabIcon = "worldWar/iconArmy"
    tabText = "worldWar/armies"
    getTabTextPostfix = function() {
      local idleArmies = ::getTblValue(WW_ARMY_ACTION_STATUS.IDLE, ::g_operations.getArmiesCache(), {})
      local commonCount = ::getTblValue("common", idleArmies, []).len()
      local surroundedCount = ::getTblValue("surrounded", idleArmies, []).len()

      local countText = commonCount.tostring()
      if (surroundedCount > 0)
        countText += "+" + ::colorize("armySurroundedColor", surroundedCount)

      return ::loc("ui/parentheses/space", { text = countText })
    }
    getHandler = function (placeObj) {
      return ::handlersManager.loadHandler(
        ::gui_handlers.WwArmiesList,
        {
          scene = placeObj
        }
      )
    }
  }
}, null, "name")


function g_ww_map_reinforcement_tab_type::getTypeByCode(code)
{
  return ::g_enum_utils.getCachedType(
    "code",
    code,
    cache.byCode,
    this,
    UNKNOWN
  )
}
