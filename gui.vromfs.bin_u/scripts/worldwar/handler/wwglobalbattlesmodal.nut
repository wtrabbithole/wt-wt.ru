local globalBattlesListData = require("scripts/worldWar/operations/model/wwGlobalBattlesList.nut")
local WwGlobalBattle = require("scripts/worldWar/operations/model/wwGlobalBattle.nut")

class ::gui_handlers.WwGlobalBattlesModal extends ::gui_handlers.WwBattleDescription
{
  battlesList = null

  static function open(battle = null)
  {
    if (!battle || !battle.isValid())
      battle = WwGlobalBattle()

    ::handlersManager.loadHandler(::gui_handlers.WwGlobalBattlesModal, {battle = battle})
  }

  function initScreen()
  {
    base.initScreen()
    battlesList = []
    globalBattlesListData.requestList()

    local timerObj = scene.findObject("global_battles_update_timer")
    if (::check_obj(timerObj))
      timerObj.setUserData(this)
  }

  function getSceneTplView()
  {
    return { hasUpdateTimer = true }
  }

  function updateBattleSquadListData()
  {
  }

  function onUpdate(obj, dt)
  {
    refreshList()
  }

  function refreshList()
  {
    globalBattlesListData.requestList()
  }

  function onEventWWUpdateGlobalBattles(p)
  {
    reinitBattlesList()
  }

  function getBattleById(battleId)
  {
    return ::u.search(battlesList, @(battle) battle.id == battleId)
      || WwGlobalBattle()
  }

  function updateWindow()
  {
    currViewMode = getViewMode()
    updateViewMode()
    updateDescription()
    updateSlotbar()
  }

  function updateSlotbar()
  {
    createSlotbar(
      {
        showTopPanel = false
        gameModeName = battle.getLocName()
        showEmptySlot = true
        showPresetsPanel = true
      }
    )
  }

  function onItemSelect()
  {
    refreshSelBattle()
    local cb = ::Callback(function() {
      updateBattleSquadListData()
      updateWindow()
    }, this)

    if (battle.isValid())
      ::g_world_war.updateOperationPreviewAndDo(battle.operationId, cb, true)
    else
      cb()
  }

  function getFirstBattleInListMap()
  {
    return battlesList.len() ? battlesList[0] : WwGlobalBattle()
  }

  function createBattleListMap()
  {
    setFilteredBattles()
    local currentBattleListMap = {}
    foreach (idx, battleData in battlesList)
    {
      local armyUnitTypesData = getBattleArmyUnitTypesData(battleData)
      local armyUnitGroupId = armyUnitTypesData.groupId
      if (!(armyUnitGroupId in currentBattleListMap))
        currentBattleListMap[armyUnitGroupId] <- {
          isCollapsed = false
          isInactiveBattles = armyUnitTypesData.isInactiveBattles
          text = armyUnitTypesData.text
          childrenBattles = []
          childrenBattlesIds = []
        }

      local groupBattleList = currentBattleListMap[armyUnitGroupId]
      groupBattleList.childrenBattles.append(battleData)
      groupBattleList.childrenBattlesIds.append(battleData.id)
    }

    return currentBattleListMap
  }

  function getBattleArmyUnitTypesData(battleData)
  {
    return {
      text = ::colorize("@userlogColoredText", ::loc("userlog/page/battle"))
      groupId = "group_total"
      isInactiveBattles = false
    }
  }

  function onEventCountryChanged(p)
  {
    guiScene.performDelayed(this, reinitBattlesBySelectedCountry)
  }

  function reinitBattlesBySelectedCountry()
  {
    setFilteredBattles()
    battle = getBattleById(battle.id)
    reinitBattlesList()
  }

  function setFilteredBattles()
  {
    battlesList = globalBattlesListData.getList().filter
      (@(idx, battle) battle.hasSideCountry(::get_profile_info().country))
  }

  function updateBattleStatus(battleView)
  {
  }
}
