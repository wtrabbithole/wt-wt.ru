local globalBattlesListData = require("scripts/worldWar/operations/model/wwGlobalBattlesList.nut")
local WwGlobalBattle = require("scripts/worldWar/operations/model/wwGlobalBattle.nut")

class ::gui_handlers.WwGlobalBattlesModal extends ::gui_handlers.WwBattleDescription
{
  battlesList = null
  operationBattle = null

  static function open(battle = null)
  {
    if (!battle || !battle.isValid())
      battle = WwGlobalBattle()

    ::handlersManager.loadHandler(::gui_handlers.WwGlobalBattlesModal, {
        curBattleInList = battle
        operationBattle = ::WwBattle()
      })
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

  function updateWindow()
  {
    currViewMode = getViewMode()
    updateViewMode()
    updateDescription()
    updateQueueInfoPanel()
    updateSlotbar()
    updateButtons()
  }

  function updateSlotbar()
  {
    local availableUnits = []
    if (operationBattle.isValid())
    {
      local playerTeam = operationBattle.getTeamBySide(getPlayerSide())
      availableUnits = operationBattle.getTeamRemainUnits(playerTeam)
    }
    createSlotbar(
      {
        availableUnits = availableUnits
        showTopPanel = false
        gameModeName = curBattleInList.getLocName()
        showEmptySlot = true
        showPresetsPanel = true
      }
    )
  }

  function onItemSelect()
  {
    refreshSelBattle()
    local cb = ::Callback(function() {
      operationBattle = ::g_world_war.getBattleById(curBattleInList.id)
      updateBattleSquadListData()
      updateWindow()
    }, this)

    if (curBattleInList.isValid())
      ::g_world_war.updateOperationPreviewAndDo(curBattleInList.operationId, cb, true)
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

  function onEventSquadDataUpdated(params)
  {
  }

  function reinitBattlesBySelectedCountry()
  {
    setFilteredBattles()
    curBattleInList = getBattleById(curBattleInList.id)
    reinitBattlesList()
  }

  function setFilteredBattles()
  {
    battlesList = globalBattlesListData.getList().filter
      (@(idx, battle) battle.hasSideCountry(::get_profile_info().country))
  }

  function getBattleById(battleId)
  {
    return ::u.search(battlesList, @(battle) battle.id == battleId)
      || WwGlobalBattle()
  }

  function getPlayerSide()
  {
    return curBattleInList.getSideByCountry(::get_profile_info().country)
  }

  function updateBattleStatus(battleView)
  {
  }
}
