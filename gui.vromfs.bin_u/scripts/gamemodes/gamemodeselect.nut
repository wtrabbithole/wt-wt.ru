local mapPreferencesModal = require("scripts/missions/mapPreferencesModal.nut")
local mapPreferencesParams = require("scripts/missions/mapPreferencesParams.nut")
local clustersModule = require("scripts/clusterSelect.nut")
local crossplayModule = require("scripts/social/crossplay.nut")
local u = ::require("sqStdLibs/helpers/u.nut")
local Callback = require("sqStdLibs/helpers/callback.nut").Callback

::dagui_propid.add_name_id("modeId")

class ::gui_handlers.GameModeSelect extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneTplName = "gui/gameModeSelect/gameModeSelect"
  shouldBlurSceneBg = true
  backSceneFunc = @() ::gui_start_mainmenu()
  needAnimatedSwitchScene = false

  restoreFromModal = false
  newIconWidgetsByGameModeID = {}
  gameModesWithTimer = {}

  filledGameModes = []

  categories = [
    {
      id = "general_game_modes"
      separator = false
      modesGenFunc = "createGameModesView"
      textWhenEmpty = "#mainmenu/gamemodesNotLoaded/desc"
    }
    {
      id = "featured_game_modes"
      separator = true
      modesGenFunc = "createFeaturedModesView"
    }
    {
      id = "debug_game_modes"
      separator = false
      modesGenFunc = "createDebugGameModesView"
    }
  ]

  static basePanelConfig = [
    ::ES_UNIT_TYPE_AIRCRAFT,
    ::ES_UNIT_TYPE_TANK,
    ::ES_UNIT_TYPE_SHIP
  ]

  static function open()
  {
    ::gui_start_modal_wnd(::gui_handlers.GameModeSelect)
  }

  function getSceneTplView()
  {
    return { categories = categories }
  }

  function initScreen()
  {
    updateContent()
  }

  function fillModesList()
  {
    filledGameModes.clear()

    foreach (cat in categories)
    {
      local modes = this[cat.modesGenFunc]()
      if (modes.len() == 0)
      {
        filledGameModes.append({
          isEmpty = true
          textWhenEmpty = cat?.textWhenEmpty || ""
          isMode = false
        })
        continue
      }

      if (cat?.separator)
        filledGameModes.append({ separator = true, isMode = false })
      filledGameModes.extend(modes)
    }

    local placeObj = scene.findObject("general_game_modes")
    if (!::check_obj(placeObj))
      return

    local data = ::handyman.renderCached("gui/gameModeSelect/gameModeBlock", { block = filledGameModes })
    guiScene.replaceContentFromText(placeObj, data, data.len(), this)

    setGameModesTimer()
  }

  function updateContent()
  {
    gameModesWithTimer.clear()
    newIconWidgetsByGameModeID.clear()

    fillModesList()

    registerNewIconWidgets()
    updateClusters()
    updateButtons()
    updateEventDescriptionConsoleButton(::game_mode_manager.getCurrentGameMode())

    updateSelection()
  }

  function updateSelection()
  {
    local curGM = ::game_mode_manager.getCurrentGameMode()
    if (curGM == null)
      return

    local curGameModeObj = scene.findObject("general_game_modes")
    if (!::check_obj(curGameModeObj))
      return

    local index = filledGameModes.searchindex(@(gm) gm.isMode && gm?.hasContent && gm.modeId == curGM.id) ?? 0
    curGameModeObj.setValue(index)
    curGameModeObj.select()
  }

  function registerNewIconWidgets()
  {
    foreach (gameMode in filledGameModes)
    {
      if (!gameMode.isMode || !gameMode?.hasContent)
        continue

      local widgetObj = scene.findObject(getWidgetId(gameMode.id))
      if (!::check_obj(widgetObj))
        continue

      local widget = NewIconWidget(guiScene, widgetObj)
      newIconWidgetsByGameModeID[gameMode.id] <- widget
      widget.setWidgetVisible(!::game_mode_manager.isSeen(gameMode.id))
    }
  }

  function createFeaturedModesView()
  {
    local view = []
    view.extend(getViewArray(::game_mode_manager.getPveBattlesGameModes()))
    view.extend(getViewArray(::game_mode_manager.getFeaturedGameModes()))
    view.extend(createFeaturedLinksView())
    view.extend(getViewArray(::game_mode_manager.getClanBattlesGameModes()))
    return view
  }

  function getViewArray(gameModesArray)
  {
    local view = []
    // First go all wide featured game modes then - non-wide.
    local numNonWideGameModes = 0
    foreach (isWide in [true, false])
    {
      while (true)
      {
        local gameMode = getGameModeByCondition(gameModesArray, @(gameMode) gameMode.displayWide == isWide)
        if (gameMode == null)
          break
        if (!isWide)
          ++numNonWideGameModes
        local index = ::find_in_array(gameModesArray, gameMode)
        gameModesArray.remove(index)
        view.push(createGameModeView(gameMode))
      }
    }
    sortByUnitType(view)
    // Putting a dummy block to show featured links in one line.
    if ((numNonWideGameModes & 1) == 1)
      view.push(createGameModeView(null))
    return view
  }

  function sortByUnitType(gameModeViews)
  {
    gameModeViews.sort(function(a, b) { // warning disable: -return-different-types
      foreach(unitType in ::g_unit_type.types)
      {
        if(b.isWide != a.isWide)
          return b.isWide <=> a.isWide
        local isAContainsType = a.gameMode.unitTypes.find(unitType.esUnitType) != null
        local isBContainsType = b.gameMode.unitTypes.find(unitType.esUnitType) != null
        if( ! isAContainsType && ! isBContainsType)
          continue
        return isBContainsType <=> isAContainsType
        || b.gameMode.unitTypes.len() <=> a.gameMode.unitTypes.len()
      }
      return 0
    })
  }

  function createDebugGameModesView()
  {
    local view = []
    local debugGameModes = ::game_mode_manager.getDebugGameModes()
    foreach (gameMode in debugGameModes)
      view.push(createGameModeView(gameMode))
    return view
  }

  function createFeaturedLinksView()
  {
    local res = []
    foreach (idx, mode in ::featured_modes)
    {
      if (!mode.isVisible())
        continue

      local id = ::game_mode_manager.getGameModeItemId(mode.modeId)
      local hasNewIconWidget = mode.hasNewIconWidget && !::game_mode_manager.isSeen(id)
      local newIconWidgetContent = hasNewIconWidget? NewIconWidget.createLayout() : null

      res.append({
        id = id
        modeId = mode.modeId
        hasContent = true
        isMode = true
        text  = mode.text
        textDescription = mode.textDescription
        value = mode.modeId
        hasCountries = false
        isWide = mode.isWide
        image = mode.image()
        gameMode = mode
        checkBox = false
        linkIcon = true
        isFeatured = true
        onClick = "onGameModeSelect"
        onHover = "markGameModeSeen"
        showEventDescription = false
        newIconWidgetId = getWidgetId(id)
        newIconWidgetContent = newIconWidgetContent
      })
      if (mode?.updateByTimeFunc)
        gameModesWithTimer[id] <- mode.updateByTimeFunc
    }
    return res
  }

  function createGameModesView()
  {
    local gameModesView = []
    local partitions = ::game_mode_manager.getGameModesPartitions()
    foreach (partition in partitions)
    {
      local partitionView = createGameModesPartitionView(partition)
      if (partitionView)
        gameModesView.extend(partitionView)
    }
    return gameModesView
  }

  function createGameModeView(gameMode, separator = false, isNarrow = false)
  {
    if (gameMode == null)
      return {
        hasContent = false
        isNarrow = isNarrow
        isMode = true
      }

    local countries = createGameModeCountriesView(gameMode)
    local isLink = gameMode.displayType.showInEventsWindow
    local event = getGameModeEvent(gameMode)
    local trophyName = ::events.getEventPVETrophyName(event)

    local id = ::game_mode_manager.getGameModeItemId(gameMode.id)
    local hasNewIconWidget = !::game_mode_manager.isSeen(id)
    local newIconWidgetContent = hasNewIconWidget? NewIconWidget.createLayout() : null
    local crossPlayRestricted = !isCrossPlayEventAvailable(event)
    local crossplayTooltip = getCrossPlayRestrictionTooltipText(event)
    if (gameMode?.updateByTimeFunc)
      gameModesWithTimer[id] <- mode.updateByTimeFunc

    return {
      id = id
      modeId = gameMode.id
      hasContent = true
      isMode = true
      text = gameMode.text
      getEvent = gameMode?.getEvent
      textDescription = ::getTblValue("textDescription", gameMode, null)
      tooltip = gameMode.getTooltipText()
      value = gameMode.id
      hasCountries = countries.len() != 0
      countries = countries
      isCurrentGameMode = gameMode.id == ::game_mode_manager.getCurrentGameModeId()
      isWide = gameMode.displayWide
      isNarrow = isNarrow
      image = gameMode.image
      videoPreview = gameMode.videoPreview
      checkBox = !isLink
      linkIcon = isLink
      newIconWidgetId = getWidgetId(id)
      newIconWidgetContent = newIconWidgetContent
      isFeatured = true
      onClick = "onGameModeSelect"
      onHover = "markGameModeSeen"
      // Used to easily backtrack corresponding game mode.
      gameMode = gameMode
      eventDescriptionValue = gameMode.id
      inactiveColor = ::getTblValue("inactiveColor", gameMode, crossPlayRestricted)
      crossPlayRestricted = crossPlayRestricted
      crossplayTooltip = crossplayTooltip
      isCrossPlayRequired = crossplayTooltip != null
      showEventDescription = !isLink && ::events.isEventNeedInfoButton(event)
      eventTrophyImage = getTrophyMarkUpData(trophyName)
      isTrophyRecieved = trophyName == ""? false : !::can_receive_pve_trophy(-1, trophyName)
      mapPreferences = isShowMapPreferences(gameMode?.getEvent())
      prefTitle = mapPreferencesParams.getPrefTitle(gameMode?.getEvent())
    }
  }

  function getCrossPlayRestrictionTooltipText(event)
  {
    if (!::is_platform_xboxone) //No need tooltip on other platforms
      return null

    //Always send to other platform if enabled
    //Need to notify about it
    if (crossplayModule.isCrossPlayEnabled())
      return ::loc("xbox/crossPlayEnabled")

    //If only xbox - no need to notify
    if (isEventXboxOnlyAllowed(event))
      return null

    //Notify that crossplay is strongly required
    return ::loc("xbox/crossPlayRequired")
  }

  function isEventXboxOnlyAllowed(event)
  {
    return ::events.isEventXboxOnlyAllowed(event)
  }

  function isCrossPlayEventAvailable(event)
  {
    return crossplayModule.isCrossPlayEnabled() || isEventXboxOnlyAllowed(event)
  }

  function getWidgetId(gameModeId)
  {
    return gameModeId + "_widget"
  }

  function getTrophyMarkUpData(trophyName)
  {
    if (::u.isEmpty(trophyName))
      return null

    local trophyItem = ::ItemsManager.findItemById(trophyName, itemType.TROPHY)
    if (!trophyItem)
      return null

    return trophyItem.getNameMarkup(0, false)
  }

  function createGameModeCountriesView(gameMode)
  {
    local res = []
    local countries = gameMode.countries
    if (!countries.len() || countries.len() >= ::g_crews_list.get().len())
      return res

    local needShowLocked = false
    if (countries.len() >= 0.7 * ::g_crews_list.get().len())
    {
      local lockedCountries = []
      foreach(countryData in ::g_crews_list.get())
      {
        local country = countryData.country
        if (::is_country_visible(country) && !::isInArray(country, countries))
          lockedCountries.append(country)
      }

      needShowLocked = true
      countries = lockedCountries
    }

    foreach (country in countries)
      res.append({ img = ::get_country_icon(country, false, needShowLocked) })
    return res
  }

  function createGameModesPartitionView(partition)
  {
    if (partition.gameModes.len() == 0)
      return null

    local gameModes = partition.gameModes
    local needEmptyGameModeBlocks = !!::u.search(gameModes, @(gm) !gm.displayWide)
    local view = []
    foreach (idx, esUnitType in basePanelConfig)
    {
      local gameMode = chooseGameModeEsUnitType(gameModes, esUnitType, basePanelConfig)
      if (gameMode)
        view.push(createGameModeView(gameMode, false, true))
      else if (needEmptyGameModeBlocks)
        view.push(createGameModeView(null, false, true))
    }

    return view
  }

  /**
   * Find appropriate game mode from array and returns it.
   * If game mode is not null, it will be removed from array.
   */
  function chooseGameModeEsUnitType(gameModes, esUnitType, esUnitTypesFilter)
  {
    return getGameModeByCondition(gameModes,
      @(gameMode) u.max(::game_mode_manager.getRequiredUnitTypes(gameMode).filter(
        @(esUType) ::isInArray(esUType, esUnitTypesFilter))) == esUnitType)
  }

  function getGameModeByCondition(gameModes, conditionFunc)
  {
    return ::u.search(gameModes, conditionFunc)
  }

  function onGameModeSelect(obj)
  {
    markGameModeSeen(obj)
    local gameModeView = u.search(filledGameModes, @(gm) gm.isMode && gm?.hasContent && gm.modeId == obj.value)
    performGameModeSelect(gameModeView.gameMode)
  }

  function performGameModeSelect(gameMode)
  {
    if (gameMode?.diffCode == ::DIFFICULTY_HARDCORE &&
        !::check_package_and_ask_download("pkg_main"))
      return

    local event = getGameModeEvent(gameMode)
    if (event && !isCrossPlayEventAvailable(event))
    {
      ::showInfoMsgBox(::loc("xbox/actionNotAvailableCrossNetworkPlay"))
      return
    }

    goBack()

    if ("startFunction" in gameMode)
      gameMode.startFunction()
    else if (gameMode?.displayType?.showInEventsWindow)
      ::gui_start_modal_events({ event = event?.name })
    else
      ::game_mode_manager.setCurrentGameModeById(gameMode.modeId, true)
  }

  function markGameModeSeen(obj)
  {
    if (!obj?.id || ::game_mode_manager.isSeen(obj.id))
      return

    local widget = ::getTblValue(obj.id, newIconWidgetsByGameModeID)
    if (!widget)
      return

    ::game_mode_manager.markShowingGameModeAsSeen(obj.id)
    widget.setWidgetVisible(false)
  }

  function onGameModeGamepadSelect(obj)
  {
    local val = obj.getValue()
    if (val < 0 || val >= obj.childrenCount())
      return

    local gmView = filledGameModes[val]
    local modeObj = scene.findObject(gmView.id)

    markGameModeSeen(modeObj)
    updateEventDescriptionConsoleButton(gmView.gameMode)
  }

  function onOpenClusterSelect(obj)
  {
    clustersModule.createClusterSelectMenu(obj)
  }

  function onEventClusterChange(params)
  {
    updateClusters()
  }

  function updateClusters()
  {
    clustersModule.updateClusters(scene.findObject("cluster_select_button_text"))
  }

  function onClusterSelectActivate(obj)
  {
    local value = obj.getValue()
    local childObj = (value >= 0 && value < obj.childrenCount()) ? obj.getChild(value) : null
    if (::checkObj(childObj))
      onOpenClusterSelect(childObj)
  }

  function onGameModeActivate(obj)
  {
    local value = obj.getValue()
    local gameModeView = filledGameModes[value]

    performGameModeSelect(gameModeView.gameMode)
  }

  function getGameModeEvent(gameModeTbl)
  {
    return ("getEvent" in gameModeTbl) ? gameModeTbl.getEvent() : null
  }

  function onEventDescription(obj)
  {
    openEventDescription(::game_mode_manager.getGameModeById(obj.value))
  }

  function onGamepadEventDescription(obj)
  {
    local gameModesObject = getObj("general_game_modes")
    if (!::checkObj(gameModesObject))
      return

    local value = gameModesObject.getValue()
    if (value < 0)
      return

    openEventDescription(filledGameModes[value].gameMode)
  }

  function openEventDescription(gameMode)
  {
    local event = getGameModeEvent(gameMode)
    if (event != null)
    {
      restoreFromModal = true
      ::events.openEventInfo(event)
    }
  }

  function updateEventDescriptionConsoleButton(gameMode)
  {
    showSceneBtn("event_description_console_button", gameMode != null && gameMode?.forClan && ::show_console_buttons)
    ::showBtn("map_preferences_console_button",
      isShowMapPreferences(gameMode?.getEvent()) && ::show_console_buttons, scene)

    local prefObj = scene.findObject("map_preferences_console_button")
    if(!::check_obj(prefObj))
      return

    prefObj.setValue(mapPreferencesParams.getPrefTitle(gameMode?.getEvent()))
    prefObj.modeId = gameMode?.id
  }

  function onEventCurrentGameModeIdChanged(p) { updateContent() }
  function onEventGameModesUpdated(p) { updateContent() }
  function onEventWWLoadOperation(p) { updateContent() }
  function onEventWWStopWorldWar(p) { updateContent() }
  function onEventWWGlobalStatusChanged(p) { updateContent() }
  function onEventXboxSystemUIReturn(p) { updateContent() }

  function updateButtons()
  {
    ::showBtn("wiki_link", ::has_feature("AllowExternalLink") && !::is_vendor_tencent(), scene)
  }

  function setGameModesTimer()
  {
    local timerObj = scene.findObject("game_modes_timer")
    if (::check_obj(timerObj))
      timerObj.setUserData(gameModesWithTimer.len()? this : null)
  }

  function onTimerUpdate(obj, dt)
  {
    foreach (gameModeId, updateFunc in gameModesWithTimer)
    {
      updateFunc(scene, gameModeId)
    }
  }

  function isShowMapPreferences(curEvent)
  {
    return ::has_feature("MapPreferences") && !::is_me_newbie()
      && mapPreferencesParams.hasPreferences(curEvent)
      && ((curEvent?.maxDislikedMissions ?? 0) > 0 || (curEvent?.maxBannedMissions ?? 0) > 0)
  }

  function onMapPreferences(obj)
  {
    local curEvent = obj?.modeId != null
      ? ::game_mode_manager.getGameModeById(obj.modeId)?.getEvent()
      : ::game_mode_manager.getCurrentGameMode()?.getEvent()
    ::g_squad_utils.checkSquadUnreadyAndDo(
      Callback(@() mapPreferencesModal.open({curEvent = curEvent}), this),
      null, shouldCheckCrewsReady)
  }
}
