local crossplayModule = require("scripts/social/crossplay.nut")

class ::gui_handlers.GameModeSelect extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  focusArray = ["general_game_modes", "featured_game_modes", "debug_game_modes"]
  valueByGameModeId = {}
  gameModeIdByValue = {}
  restoreFromModal = false
  newIconWidgetsByGameModeID = null

  static basePanelConfig = [
    ::ES_UNIT_TYPE_AIRCRAFT,
    ::ES_UNIT_TYPE_TANK,
    ::ES_UNIT_TYPE_SHIP
  ]

  function initScreen()
  {
    newIconWidgetsByGameModeID = {}
  }

  function getShowGameModeSelect() { return scene.isVisible() }
  function setShowGameModeSelect(value)
  {
    checkedCrewAirChange(
      function() {
        if (value)
          goForwardIfOnline(_setShowGameModeSelectEnabled.bindenv(this), false, true)
        else
          _setShowGameModeSelect(false)
      },
    null)
  }

  function _setShowGameModeSelectEnabled()
  {
    _setShowGameModeSelect(true)
  }

  function _setShowGameModeSelect(value)
  {
    if (!::checkObj(scene) || scene.isVisible() == value)
      return
    if (value)
      updateContent()
    local id = this.scene.id
    local params = {
      target = this.scene
      visible = value
      isBlockOtherRestoreFocus = value
    }
    ::broadcastEvent("RequestToggleVisibility", params)
  }

  function updateContent()
  {
    local view = {
      categories = [
        {
          separator = false
          id = "general_game_modes"
          onActivate = "onGeneralGameModeActivate"
          onSetFocus = "onGameModeSelectFocus"
          modes = createGameModesView()
          blackBackground = true
          onSelectOption = {
            onSelect = "onGameModeGamepadSelect"
          }
          textWhenEmpty = "#mainmenu/gamemodesNotLoaded/desc"
        }
        {
          separator = true
          id = "featured_game_modes"
          onActivate = "onFeaturedGameModeActivate"
          onSetFocus = "onGameModeSelectFocus"
          modes = createFeaturedModesView()
          blackBackground = false
          onSelectOption = null
        }
        {
          separator = false
          id = "debug_game_modes"
          onActivate = "onGeneralGameModeActivate"
          onSetFocus = "onGameModeSelectFocus"
          modes = createDebugGameModesView()
          blackBackground = true
          onSelectOption = {
            onSelect = "onGameModeGamepadSelect"
          }
        }
      ]
    }

    // Removing empty categories
    for (local i = view.categories.len() - 1; i >= 0; --i)
      if (view.categories[i].modes.len() == 0)
      {
        local cat = view.categories.remove(i)
        local headerText = ::getTblValue("textWhenEmpty", cat)
        if (headerText)
          view.categoriesHeaderText <- headerText
      }

    local blk = ::handyman.renderCached(("gui/gameModeSelect/gameModeSelect"), view)
    guiScene.replaceContentFromText(scene, blk, blk.len(), this)

    local featuredGameModesObject = getObj("featured_game_modes")
    if (featuredGameModesObject != null)
      featuredGameModesObject.enable(featuredGameModesObject.childrenCount() > 0)

    registerNewIconWidgets()
    updateClusters()
    updateButtons()
    updateEventDescriptionConsoleButton(::game_mode_manager.getCurrentGameMode())
  }

  function registerNewIconWidgets()
  {
    foreach (gameMode in ::game_mode_manager.getAllVisibleGameModes())
    {
      local modePlateId = ::game_mode_manager.getGameModeItemId(gameMode.id)
      local widgetObj = scene.findObject(getWidgetId(modePlateId))
      if (!::check_obj(widgetObj))
        continue

      local widget = NewIconWidget(guiScene, widgetObj)
      newIconWidgetsByGameModeID[modePlateId] <- widget
      widget.setWidgetVisible(!::game_mode_manager.isSeen(modePlateId))
    }

    foreach (mode in ::featured_modes)
    {
      if (!mode.hasNewIconWidget)
        continue

      local modePlateId = ::game_mode_manager.getGameModeItemId(mode.modeId)
      local widgetObj = scene.findObject(getWidgetId(modePlateId))
      if (!::check_obj(widgetObj))
        continue

      local widget = NewIconWidget(guiScene, widgetObj)
      newIconWidgetsByGameModeID[modePlateId] <- widget
      widget.setWidgetVisible(!::game_mode_manager.isSeen(modePlateId))
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
    gameModeViews.sort(function(a, b) {
      foreach(unitType in ::g_unit_type.types)
      {
        if(b.isWide != a.isWide)
          return b.isWide <=> a.isWide
        local isAContainsType = a.gameMode.unitTypes.find(unitType.esUnitType) >= 0
        local isBContainsType = b.gameMode.unitTypes.find(unitType.esUnitType) >= 0
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
        hasContent = true
        id = id
        text  = mode.text
        textDescription = mode.textDescription
        value = idx
        hasCountries = false
        isWide = mode.isWide
        image = mode.image()
        checkBox = false
        linkIcon = true
        isFeatured = true
        onClick = "onFeaturedModeSelect"
        onHover = "markGameModeSeen"
        separator = false
        showEventDescription = false
        newIconWidgetId = getWidgetId(id)
        newIconWidgetContent = newIconWidgetContent
      })
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
    saveValuesByGameModeId(gameModesView)
    return gameModesView
  }

  function createGameModeView(gameMode, separator = false, isNarrow = false)
  {
    if (gameMode == null)
      return {
        hasContent = false
        separator = separator
        isNarrow = isNarrow
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

    return {
      hasContent = true
      id = id
      text = gameMode.text
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
      separator = separator
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
    }
  }

  function getCrossPlayRestrictionTooltipText(event)
  {
    if (!::is_platform_xboxone || isEventXboxOnlyAllowed(event))
      return null

    if (crossplayModule.isCrossPlayEnabled())
      return ::loc("xbox/crossPlayEnabled")

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
        @(idx, esUType) ::isInArray(esUType, esUnitTypesFilter))) == esUnitType)
  }

  function saveValuesByGameModeId(gameModesView)
  {
    local valueCounter = 0
    foreach (gameModeView in gameModesView)
    {
      if (gameModeView.separator)
        ++valueCounter
      local gameMode = ::getTblValue("gameMode", gameModeView, null)
      if (gameMode != null)
      {
        valueByGameModeId[gameMode.id] <- valueCounter
        gameModeIdByValue[valueCounter] <- gameMode.id
      }
      ++valueCounter
    }
  }

  function getGameModeByCondition(gameModes, conditionFunc)
  {
    return ::u.search(gameModes, conditionFunc)
  }

  function goBack()
  {
    setShowGameModeSelect(false)
  }

  function onGameModeSelect(obj)
  {
    markGameModeSeen(obj)
    local gameMode = ::game_mode_manager.getGameModeById(obj.value)
    if (gameMode.diffCode == ::DIFFICULTY_HARDCORE &&
        !::check_package_and_ask_download("pkg_main"))
      return

    local event = getGameModeEvent(gameMode)
    if (!isCrossPlayEventAvailable(event))
    {
      ::g_popups.add(null, ::loc("xbox/actionNotAvailableCrossNetwork"))
      return
    }

    performGameModeSelect(gameMode)
  }

  function performGameModeSelect(gameMode)
  {
    if (gameMode.displayType.showInEventsWindow)
      ::gui_start_modal_events({ event = gameMode.id })
    else
      ::game_mode_manager.setCurrentGameModeById(gameMode.id, true)

    goBack()
  }

  function markGameModeSeen(obj)
  {
    if (::game_mode_manager.isSeen(obj.id))
      return

    local widget = ::getTblValue(obj.id, newIconWidgetsByGameModeID)
    if (!widget)
      return

    ::game_mode_manager.markShowingGameModeAsSeen(obj.id)
    widget.setWidgetVisible(false)
  }

  function onGameModeGamepadSelect(obj)
  {
    local gameModeId = ::getTblValue(obj.getValue(), gameModeIdByValue)
    local gameMode = ::game_mode_manager.getGameModeById(gameModeId)
    updateEventDescriptionConsoleButton(gameMode)
  }

  function onFeaturedModeSelect(obj)
  {
    markGameModeSeen(obj)
    goBack()
    ::featured_modes[obj.value.tointeger()].startFunction()
  }

  function onEventCurrentGameModeIdChanged(params)
  {
    if (scene.isVisible())
      updateContent()
  }

  function onEventGameModesUpdated(params)
  {
    if (scene.isVisible())
      updateContent()
  }

  function onOpenClusterSelect(obj)
  {
    if (!::handlersManager.isHandlerValid(::instant_domination_handler))
      return

    ::queues.checkAndStart(
      ::Callback(function() {
         restoreFromModal = true
         ::gui_handlers.ClusterSelect.open(obj, "top") }, this),
      null,
      "isCanChangeCluster")
  }

  function onEventClusterChange(params)
  {
    updateClusters()
  }

  function updateClusters()
  {
    local obj = scene.findObject("cluster_select_button")
    if (obj != null)
      ::show_selected_clusters(obj)
  }

  function onEventGamercardDrawerOpened(params)
  {
    local target = params.target
    if (target != null && target.id == scene.id)
      updateSelection()
  }

  /**
   * This method tries to set focues either on
   * main game modes group or on clan battle group.
   */
  function updateSelection()
  {
    local currentGameMode = ::game_mode_manager.getCurrentGameMode()
    if (currentGameMode == null)
      return

    local curGameModeObj = scene.findObject("game_mode_item_" + currentGameMode.id)
    if (!::check_obj(curGameModeObj))
      return

    local gameModesObject = curGameModeObj.getParent()

    local value = ::getTblValue(currentGameMode.id, valueByGameModeId, 0)
    gameModesObject.select()
    gameModesObject.setValue(value)

    // This call restores focus array index that could've
    // lost on return from some other modal window.
    checkCurrentFocusItem(gameModesObject)
  }

  /* override */ function wrapNextSelect(obj = null, dir = 0)
  {
    local id = obj != null ? ::getTblValue("id", obj, "") : ""
    local index = ::find_in_array(focusArray, id)
    if (index == 0 && dir == -1 || index == focusArray.len() - 1 && dir == 1)
      return
    base.wrapNextSelect(obj, dir)
  }

  function onClusterSelectActivate(obj)
  {
    local value = obj.getValue()
    local childObj = (value >= 0 && value < obj.childrenCount()) ? obj.getChild(value) : null
    if (::checkObj(childObj))
      onOpenClusterSelect(childObj)
  }

  function onGeneralGameModeActivate(obj)
  {
    local value = obj.getValue()
    local childObj = (value >= 0 && value < obj.childrenCount()) ? obj.getChild(value) : null
    if (::checkObj(childObj))
      onGameModeSelect(childObj)
  }

  function onFeaturedGameModeActivate(obj)
  {
    local value = obj.getValue()
    local childObj = (value >= 0 && value < obj.childrenCount()) ? obj.getChild(value) : null
    if (::checkObj(childObj))
      onActivateConsoleButton(childObj)
  }

  function onGameModeSelectFocus(obj)
  {
    // This is a legal workaround for game mode
    // select window not opening sometimes.
    if (!getShowGameModeSelect() || !isSceneActiveNoModals())
      return

    guiScene.performDelayed(this, function() {
      if (!isSceneActiveNoModals())
        return

      local hasFocusedObject = false
      foreach (id in focusArray)
      {
        local object = getObj(id)
        if (object != null && object.isFocused())
        {
          hasFocusedObject = true
          break
        }
      }

      if (!hasFocusedObject)
        if (restoreFromModal)
        {
          local modesObj = scene.findObject("general_game_modes")
          if (::check_obj(modesObj))
            modesObj.select()
          restoreFromModal = false //!!FIXME: no need to trick topmenu here.
                                   //Need to create gcDrawer as subhandler of top menu
                                   //and resolve restore focus in topmenu correct.
                                   // or make this window modal.
        }
        else
          setShowGameModeSelect(false)
    })
  }

  function getGameModeEvent(gameModeTbl)
  {
    return ("getEvent" in gameModeTbl) ? gameModeTbl.getEvent() : null
  }

  function onEventDescription(obj)
  {
    local gameModeId = ""
    if (obj.id == "event_description_console_button")
    {
      if (!getEventDescriptionConsoleButtonActive())
        return
      local gameModesObject = getObj("general_game_modes")
      if (!::checkObj(gameModesObject))
        return
      local value = gameModesObject.getValue()
      gameModeId = ::getTblValue(value, gameModeIdByValue)
    }
    else
      gameModeId = obj.value

    local gameMode = ::game_mode_manager.getGameModeById(gameModeId)
    local event = getGameModeEvent(gameMode)
    if (event != null)
    {
      restoreFromModal = true
      ::events.openEventInfo(event)
    }
  }

  _eventDescriptionConsoleButtonActive = false
  function getEventDescriptionConsoleButtonActive() { return _eventDescriptionConsoleButtonActive }
  function setEventDescriptionConsoleButtonActive(value)
  {
    if (_eventDescriptionConsoleButtonActive == value)
      return
    _eventDescriptionConsoleButtonActive = value
    local obj = scene.findObject("event_description_console_button")
    if (!::checkObj(obj))
      return
    obj.show(value)
    obj.enable(value)
  }

  function updateEventDescriptionConsoleButton(gameMode)
  {
    setEventDescriptionConsoleButtonActive(gameMode != null && gameMode.forClan && ::show_console_buttons)
  }

  function onFocusItemSelected(obj)
  {
    base.onFocusItemSelected(obj)

    if (obj.id != "general_game_modes")
      setEventDescriptionConsoleButtonActive(false)
    local gameModeId = ::getTblValue(obj.getValue(), gameModeIdByValue)
    local gameMode = ::game_mode_manager.getGameModeById(gameModeId)
    updateEventDescriptionConsoleButton(gameMode)
  }

  function getFeaturedGameModesObj()
  {
    local obj = scene.findObject("featured_game_modes")
    return ::checkObj(obj) ? obj : null
  }

  function getDebugGameModesObj()
  {
    local obj = scene.findObject("debug_game_modes")
    return ::checkObj(obj) ? obj : null
  }

  function onActivateConsoleButton(obj)
  {
    local value = getGameModesObjValue("featured_game_modes")
    if (value != -1)
    {
      local childObj = getFeaturedGameModesObj().getChild(value)

      // Name can be "onGameModeSelect" or "onFeaturedModeSelect".
      local onClickCallbackName = ::getTblValue("on_click", childObj)

      local onClickCallback = ::getTblValue(onClickCallbackName, this, null)
      if (onClickCallback)
        guiScene.performDelayed(this, function()
        {
          if (isValid())
            onClickCallback(childObj)
        })
      return
    }
    value = getGameModesObjValue("debug_game_modes")
    if (value != -1)
    {
      guiScene.performDelayed(this, function()
      {
        if (isValid())
          onGameModeSelect(getDebugGameModesObj().getChild(value))
      })
      return
    }
  }

  function getGameModesObjValue(gameModesId)
  {
    local gameModesObj = scene.findObject(gameModesId)
    if (!::checkObj(gameModesObj))
      return -1
    if (!gameModesObj.isFocused())
      return -1
    local value = gameModesObj.getValue()
    if (value < 0 || value >= gameModesObj.childrenCount())
      return -1
    return value
  }

  function onEventWWLoadOperation(p) { doWhenActiveOnce("updateContent") }
  function onEventWWStopWorldWar(p) { doWhenActiveOnce("updateContent") }
  function onEventWWGlobalStatusChanged(p) { doWhenActiveOnce("updateContent") }
  function onEventXboxSystemUIReturn(p) { doWhenActiveOnce("updateContent") }

  function updateButtons()
  {
    ::showBtn("wiki_link", ::has_feature("AllowExternalLink") && !::is_vendor_tencent(), scene)
  }
}
