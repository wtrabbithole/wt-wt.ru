local globalBattlesListData = require("scripts/worldWar/operations/model/wwGlobalBattlesList.nut")
local WwGlobalBattle = require("scripts/worldWar/operations/model/wwGlobalBattle.nut")

const WW_GLOBAL_BATTLES_FILTER_ID = "worldWar/ww_global_battles_filter"

class ::gui_handlers.WwGlobalBattlesModal extends ::gui_handlers.WwBattleDescription
{
  hasSquadsInviteButton = false
  hasBattleFilter = true
  battlesList = null
  operationBattle = null
  isBattleInited = false

  static battlesFilters = [
    {
      value = UNAVAILABLE_BATTLES_CATEGORIES.NO_AVAILABLE_UNITS
      textLocId = "worldwar/battle/filter/show_if_no_avaliable_units"
    },
    {
      value = UNAVAILABLE_BATTLES_CATEGORIES.NO_FREE_SPACE
      textLocId = "worldwar/battle/filter/show_if_no_space"
    },
    {
      value = UNAVAILABLE_BATTLES_CATEGORIES.IS_UNBALANCED
      textLocId = "worldwar/battle/filter/show_unbalanced"
    },
    {
      value = UNAVAILABLE_BATTLES_CATEGORIES.LOCK_BY_TIMER
      textLocId = "worldwar/battle/filter/show_if_lock_by_timer"
    }
  ]

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

    ::checkNonApprovedResearches(true, true)
  }

  function updateBattlesFilter()
  {
    // tointeger() needs because it saves as boolean before
    filterMask = ::loadLocalByAccount(WW_GLOBAL_BATTLES_FILTER_ID, 0).tointeger()
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
    updateSlotbar()
    updateButtons()
    updateDurationTimer()
    isBattleInited = true
  }

  function getTitleText()
  {
    return ::loc("worldwar/global_battle/title", {country = ::loc(::get_profile_country_sq())})
  }

  function updateSlotbar()
  {
    local side = getPlayerSide()
    local availableUnits = []
    if (operationBattle.isValid())
    {
      local playerTeam = operationBattle.getTeamBySide(side)
      availableUnits = operationBattle.getTeamRemainUnits(playerTeam)
    }
    local operationUnits = ::g_world_war.getAllOperationUnitsBySide(side)
    createSlotbar(
      {
        customCountry = ::get_profile_country_sq()
        availableUnits = availableUnits
        showTopPanel = false
        gameModeName = getGameModeNameText()
        showEmptySlot = true
        needPresetsPanel = true
        shouldCheckCrewsReady = true
        customUnitsList = operationUnits
        customUnitsListName = getCustomUnitsListNameText()
      }
    )
  }

  function onItemSelect(isForceUpdate = false)
  {
    refreshSelBattle()
    local cb = ::Callback(function() {
      local newOperationBattle = ::g_world_war.getBattleById(curBattleInList.id)
      local isBattleEqual = operationBattle.isEqual(newOperationBattle)
      operationBattle = newOperationBattle

      if (currViewMode == WW_BATTLE_VIEW_MODES.QUEUE_INFO)
        return

      updateBattleSquadListData()
      if (!isBattleInited || !isBattleEqual)
        updateWindow()
    }, this)

    if (curBattleInList.isValid())
    {
      if (isForceUpdate)
      {
        updateDescription()
        updateButtons()
      }
      ::g_world_war.updateOperationPreviewAndDo(curBattleInList.operationId, cb)
    }
    else
      cb()
  }

  function getOperationBackground()
  {
    return WW_OPERATION_DEFAULT_BG_IMAGE
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

    local countriesInfo = getActiveCountriesData()

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

  function getActiveCountriesData()
  {
    local countriesData = {}
    foreach (country in ::shopCountriesList)
    {
      local globalBattlesList = globalBattlesListData.getList().filter(@(idx, battle)
        battle.hasSideCountry(country) && battle.isOperationMapAvaliable())

      local battlesNumber = globalBattlesList.len()
      if (battlesNumber)
        countriesData[country] <- battlesNumber
    }

    return countriesData
  }

  function onEventCountryChanged(p)
  {
    guiScene.performDelayed(this, function() {
      updateBattlesWithFilter(true)
    })
  }

  function updateBattlesWithFilter(isForceUpdate = false)
  {
    setFilteredBattles()
    curBattleInList = getBattleById(curBattleInList.id)
    reinitBattlesList(isForceUpdate)
  }

  function onOpenBattlesFilters(obj)
  {
    local unitAvailability = ::g_world_war.getSetting("checkUnitAvailability",
      WW_BATTLE_UNITS_REQUIREMENTS.BATTLE_UNITS)

    local curFilterMask = filterMask
    local battlesFiltersView = ::u.map(battlesFilters,
      @(filterData) {
        selected = filterData.value & curFilterMask
        show = filterData.value != UNAVAILABLE_BATTLES_CATEGORIES.NO_AVAILABLE_UNITS ||
               unitAvailability != WW_BATTLE_UNITS_REQUIREMENTS.NO_REQUIREMENTS
        text = ::loc(filterData.textLocId)
      })

    ::gui_start_multi_select_menu({
      list = battlesFiltersView
      align = "top"
      alignObj = scene.findObject("btn_battles_filters")
      sndSwitchOn = "check"
      sndSwitchOff = "uncheck"
      onChangeValuesBitMaskCb = function(selBitMask) {
        filterMask = selBitMask
        ::saveLocalByAccount(WW_GLOBAL_BATTLES_FILTER_ID, filterMask)
        updateBattlesWithFilter()
      }.bindenv(this)
    })
  }

  function setFilteredBattles()
  {
    local country = ::get_profile_country_sq()

    battlesList = globalBattlesListData.getList().filter(@(idx, battle)
      battle.hasSideCountry(country) && battle.isOperationMapAvaliable())

    if (currViewMode != WW_BATTLE_VIEW_MODES.BATTLE_LIST)
      return

    battlesList = battlesList.filter(
      function(idx, battle) {
        return isMatchFilterMask(battle, country)
      }.bindenv(this))
  }

  function battlesSort(battleA, battleB)
  {
    return battleB.isConfirmed <=> battleA.isConfirmed
        || battleA.sortTimeFactor <=> battleB.sortTimeFactor
        || battleB.sortFullnessFactor <=> battleA.sortFullnessFactor
  }

  function getBattleById(battleId)
  {
    return ::u.search(battlesList, @(battle) battle.id == battleId)
      || WwGlobalBattle()
  }

  function getPlayerSide(battle = null)
  {
    if (!battle)
      battle = curBattleInList

    return battle.getSideByCountry(::get_profile_country_sq())
  }

  function getEmptyBattle()
  {
    return WwGlobalBattle()
  }

  function fillOperationInfoText()
  {
    local operationInfoTextObj = scene.findObject("operation_info_text")
    if (!::check_obj(operationInfoTextObj))
      return

    local operation = ::g_ww_global_status.getOperationById(curBattleInList.getOperationId())
    if (!operation)
      return

    operationInfoTextObj.setValue(operation.getNameText())
  }

  function updateNoAvailableBattleInfo()
  {
  }
}
