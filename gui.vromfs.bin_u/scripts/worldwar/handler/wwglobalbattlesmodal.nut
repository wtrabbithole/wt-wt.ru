local globalBattlesListData = require("scripts/worldWar/operations/model/wwGlobalBattlesList.nut")
local WwGlobalBattle = require("scripts/worldWar/operations/model/wwGlobalBattle.nut")

const WW_GLOBAL_BATTLES_FILTER_ID = "worldWar/ww_global_battles_filter"

class ::gui_handlers.WwGlobalBattlesModal extends ::gui_handlers.WwBattleDescription
{
  hasSquadsInviteButton = false
  hasBattleFilter = true
  battlesList = null
  operationBattle = null
  filterFlag = 0

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
    battlesList = []

    updateBattlesFilter()
    base.initScreen()
    globalBattlesListData.requestList()

    local timerObj = scene.findObject("global_battles_update_timer")
    if (::check_obj(timerObj))
      timerObj.setUserData(this)
  }

  function updateBattlesFilter()
  {
    filterFlag = ::loadLocalByAccount(WW_GLOBAL_BATTLES_FILTER_ID, false)
    local filterObj = scene.findObject("hide_unavailable_battles")
    if (!::check_obj(filterObj))
      return

    filterObj.setValue(filterFlag)
  }

  function getSceneTplView()
  {
    return { hasUpdateTimer = true }
  }

  function onUpdate(obj, dt)
  {
    refreshList()
  }

  function goBack()
  {
    ::ww_stop_preview()
    base.goBack()
  }

  function refreshList()
  {
    globalBattlesListData.requestList()
  }

  function onEventWWUpdateGlobalBattles(p)
  {
    local wwBattleName = ::g_squad_manager.getWwOperationBattle()
    if (wwBattleName && curBattleInList.id != wwBattleName)
      curBattleInList = getBattleById(wwBattleName)

    reinitBattlesList()
  }

  function updateWindow()
  {
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
        customCountry = ::get_profile_info().country
        availableUnits = availableUnits
        showTopPanel = false
        gameModeName = curBattleInList.getLocName()
        showEmptySlot = true
        needPresetsPanel = true
        beforeCountrySelect = beforeCountrySelect
        shouldCheckCrewsReady = true
      }
    )
  }

  function beforeCountrySelect(onOk, onCancel, countryData)
  {
    if (currViewMode == WW_BATTLE_VIEW_MODES.SQUAD_INFO &&
        countryData.country != ::g_squad_manager.getWwOperationCountry())
    {
      onCancel()
      ::showInfoMsgBox(::loc("worldWar/cantChangeCountryInBattlePrepare"))
      return
    }
    onOk()
  }

  function onItemSelect()
  {
    refreshSelBattle()
    local cb = ::Callback(function() {
      operationBattle = ::g_world_war.getBattleById(curBattleInList.id)

      if (currViewMode == WW_BATTLE_VIEW_MODES.QUEUE_INFO)
        return

      updateBattleSquadListData()
      updateWindow()
    }, this)

    if (curBattleInList.isValid())
    {
      local hasProgressBox = curBattleInList.operationId != ::ww_get_operation_id() ||
                             curBattleInList.id != operationBattle.id
      ::g_world_war.updateOperationPreviewAndDo(curBattleInList.operationId, cb, hasProgressBox)
    }
    else
      cb()
  }

  function getFirstBattleInListMap()
  {
    return battlesList.len() ? battlesList[0] : WwGlobalBattle()
  }

  function getSelectedBattlePrefixText(battleData)
  {
    return ""
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

  function createActiveCountriesInfo()
  {
    local countryListObj = scene.findObject("active_country_info")
    if (!::check_obj(battlesListObj))
      return

    local countriesInfo = globalBattlesListData.getActiveCountriesData()

    local view = { countries = [] }
    foreach (country, data in countriesInfo)
      view.countries.append({
        name = ::loc(country)
        countryIcon = ::get_country_icon(country)
        value = ::loc("worldWar/battles", {number = data})
      })

    local countriesInfoData = ::handyman.renderCached("gui/worldWar/wwActiveCountriesList", view)
    guiScene.replaceContentFromText(countryListObj, countriesInfoData, countriesInfoData.len(), this)

    if (!countriesInfo.len())
    {
      local titleText = countryListObj.findObject("active_countries_text")
      if (::check_obj(titleText))
        titleText.setValue(::loc("worldWar/noParticipatingCountries"))
    }
  }

  function getNoBattlesText()
  {
    return ::loc("worldwar/noActiveGlobalBattlesFullText")
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
    guiScene.performDelayed(this, updateBattlesWithFilter)
  }

  function updateBattlesWithFilter()
  {
    setFilteredBattles()
    curBattleInList = getBattleById(curBattleInList.id)
    reinitBattlesList()
  }

  function onChangeFilter(obj)
  {
    if (obj.getValue() == filterFlag)
      return

    filterFlag = obj.getValue()
    ::saveLocalByAccount(WW_GLOBAL_BATTLES_FILTER_ID, filterFlag)
    updateBattlesWithFilter()
  }

  function setFilteredBattles()
  {
    local country = ::get_profile_info().country

    battlesList = globalBattlesListData.getList().filter
      (@(idx, battle) battle.hasSideCountry(country))

    if (!filterFlag || currViewMode != WW_BATTLE_VIEW_MODES.BATTLE_LIST)
      return

    battlesList = battlesList.filter(@(idx, battle)
      battle.hasUnitsToFight(country))
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
