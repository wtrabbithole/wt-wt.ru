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
  needUpdatePrefixWidth = false
  minCountBattlesInList = 100
  needFullUpdateList = true
  multiSelectHandlerWeak = null

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
    },
    {
      value = UNAVAILABLE_BATTLES_CATEGORIES.NOT_STARTED
      textLocId = "worldwar/battle/filter/show_not_started"
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
    globalBattlesListData.requestList()
    base.initScreen()

    ::checkNonApprovedResearches(true)
  }

  function updateBattlesFilter()
  {
    // tointeger() needs because it saves as boolean before
    filterMask = ::loadLocalByAccount(WW_GLOBAL_BATTLES_FILTER_ID, 0).tointeger()
  }

  function getSceneTplView()
  {
    return {
      hasRefreshButton = true
    }
  }

  function onUpdate(obj, dt)
  {
    refreshList()
  }

  function onRefresh()
  {
    refreshList(true)
  }

  function goBack()
  {
    ::ww_stop_preview()
    base.goBack()
  }

  function refreshList(isForce = false)
  {
    requestQueuesData()
    globalBattlesListData.requestList()

    if (!isForce)
      return

    needFullUpdateList = true
  }

  function onEventWWUpdateGlobalBattles(p)
  {
    updateForceSelectedBattle()
    reinitBattlesList()
  }

  function onEventWWUpdateWWQueues(params)
  {
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
    local availableUnits = {}
    local operationUnits = {}
    if (operationBattle.isValid())
      foreach (side in ::g_world_war.getSidesOrder(curBattleInList))
      {
        local playerTeam = operationBattle.getTeamBySide(side)
        availableUnits = availableUnits.__merge(operationBattle.getTeamRemainUnits(playerTeam))
        operationUnits = availableUnits.__merge(::g_world_war.getAllOperationUnitsBySide(side))
      }

    createSlotbar(
      {
        customCountry = ::get_profile_country_sq()
        availableUnits = availableUnits.len() ? availableUnits : null
        gameModeName = getGameModeNameText()
        showEmptySlot = true
        needPresetsPanel = true
        shouldCheckCrewsReady = true
        customUnitsList = operationUnits.len() ? operationUnits : null
        customUnitsListName = getCustomUnitsListNameText()
      }
    )
  }

  function updateSelectedItem(isForceUpdate = false)
  {
    refreshSelBattle()
    local cb = ::Callback(function() {
      local newOperationBattle = ::g_world_war.getBattleById(curBattleInList.id)
      if (!newOperationBattle.isValid() || newOperationBattle.isStale())
      {
        newOperationBattle = clone curBattleInList
        newOperationBattle.setStatus(::EBS_FINISHED)
      }
      local isBattleEqual = operationBattle.isEqual(newOperationBattle)
      operationBattle = newOperationBattle

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
    return "#ui/images/worldwar_window_bg_image_all_battles"
  }

  function getSelectedBattlePrefixText(battleData)
  {
    return ""
  }

  function createBattleListMap()
  {
    setFilteredBattles()
    if (needFullUpdateList || curBattleListMap.len() <= 0)
    {
      needFullUpdateList = false
      local battles = clone battlesList
      battles.sort(battlesSort)
      return battles
    }

    local battleListMap = clone curBattleListMap
    foreach(idx, battle in battleListMap)
    {
      local newBattle = getBattleById(battle.id, false)
      if (newBattle.isValid())
      {
        battleListMap[idx] = newBattle
        continue
      }

      if (battle.isFinished())
        continue

      newBattle.setFromBattle(battle)
      newBattle.setStatus(::EBS_FINISHED)
      battleListMap[idx] = newBattle
    }

    return battleListMap
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
    local globalBattlesList = globalBattlesListData.getList().filter(@(idx, battle)
      battle.isOperationMapAvaliable())
    foreach (country in ::shopCountriesList)
    {
      local battlesListByCountry = globalBattlesList.filter(
      function(idx, battle) {
        return battle.hasSideCountry(country) && isMatchFilterMask(battle, country)
      }.bindenv(this))

      local battlesNumber = battlesListByCountry.len()
      if (battlesNumber)
        countriesData[country] <- battlesNumber
    }

    return countriesData
  }

  function onEventCountryChanged(p)
  {
    guiScene.performDelayed(this, function() {
      needFullUpdateList = true
      reinitBattlesList(true)
      updateTitle()
    })
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

     local applyFilter = ::Callback(function(selBitMask)
       {
         filterMask = selBitMask
         ::saveLocalByAccount(WW_GLOBAL_BATTLES_FILTER_ID, filterMask)
         reinitBattlesList(true)
         refreshList(true)
       }, this)

    local handler = ::handlersManager.loadHandler(::gui_handlers.MultiSelectMenu,{
      list = battlesFiltersView
      align = "top"
      alignObj = scene.findObject("btn_battles_filters")
      sndSwitchOn = "check"
      sndSwitchOff = "uncheck"
      onChangeValuesBitMaskCb = function(selBitMask) {
        if (!(UNAVAILABLE_BATTLES_CATEGORIES.NOT_STARTED & filterMask)
          && (UNAVAILABLE_BATTLES_CATEGORIES.NOT_STARTED & selBitMask))
          msgBox("showNotStarted", ::loc("worldwar/showNotStarted/msgBox"),
            [["yes", @() applyFilter(selBitMask) ],
             ["no", function()
               {
                 if (!multiSelectHandlerWeak)
                   return

                 local multiSelectObj = multiSelectHandlerWeak.scene.findObject("multi_select")
                 if (::check_obj(multiSelectObj))
                   multiSelectObj.setValue(filterMask)
               }]],
            "no")
        else
          applyFilter(selBitMask)
      }.bindenv(this)
    })
    multiSelectHandlerWeak = handler.weakref()
  }

  function setFilteredBattles()
  {
    local country = ::get_profile_country_sq()

    battlesList = globalBattlesListData.getList().filter(@(idx, battle)
      battle.hasSideCountry(country) && battle.isOperationMapAvaliable()
      && battle.hasAvailableUnits())

    if (currViewMode != WW_BATTLE_VIEW_MODES.BATTLE_LIST)
      return

    battlesList = battlesList.filter(
      function(idx, battle) {
        return isMatchFilterMask(battle, country)
      }.bindenv(this))
  }

  function battlesSort(battleA, battleB)
  {
    return battleB.isConfirmed() <=> battleA.isConfirmed()
      || battleA.sortTimeFactor <=> battleB.sortTimeFactor
      || battleB.sortFullnessFactor <=> battleA.sortFullnessFactor
  }

  function getBattleById(battleId, searchInCurList = true)
  {
    return ::u.search(battlesList, @(battle) battle.id == battleId)
      ?? (searchInCurList
        ? (::u.search(curBattleListMap, @(battle) battle.id == battleId) ?? WwGlobalBattle())
        : WwGlobalBattle())
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
