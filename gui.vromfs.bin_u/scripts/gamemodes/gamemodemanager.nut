enum RB_GM_TYPE
{
  EVENT
  CUSTOM  //custom button, lead to other window
}

::featured_modes <- [
  {
    modeId = "world_war_featured_game_mode"
    text = function() { return ::loc("mainmenu/btnWorldwar") }
    textDescription = function() {
                        if (::g_world_war.lastPlayedOperationId)
                        {
                          local operation = ::g_ww_global_status.getOperationById(::g_world_war.lastPlayedOperationId)
                          if (!::u.isEmpty(operation))
                            return operation.getMapText()
                        }

                        return null
                      }
    startFunction = function() { ::g_world_war.openMainWnd() }
    isWide = true
    image = function() {
        local operation = ::g_ww_global_status.getOperationById(::g_world_war.lastPlayedOperationId)
        if (!::u.isEmpty(operation))
          return "#ui/images/game_modes_tiles/worldwar_active_wide.jpg?P1"
        else
          return "#ui/images/game_modes_tiles/worldwar_live_wide.jpg?P1"
      }
    videoPreview = null
    isVisible = function() { return ::is_worldwar_enabled() }
    hasNewIconWidget = true
  }
  {
    /*events*/
    modeId = "tournaments_and_event_featured_game_mode"
    text = function ()
    {
      local activeEventsNum = ::events.getEventsVisibleInEventsWindowCount()
      if (activeEventsNum <= 0)
        return ::loc("mainmenu/events/eventlist_btn_no_active_events")
      else
        return ::loc("mainmenu/btnTournamentsAndEvents")

    }
    textDescription = function() { return null }
    startFunction = function ()
    {
      ::gui_start_modal_events()
    }
    isWide = false
    image = function ()
    {
      return "#ui/images/game_modes_tiles/events_" + (isWide ? "wide" : "thin") + ".jpg?P1"
    }
    videoPreview = null
    isVisible = function ()
    {
      return ::has_feature("Events") && ::events.getEventsVisibleInEventsWindowCount() > 0
    }
    hasNewIconWidget = false
  }
  {
    /*custom battles*/
    modeId = "custom_battles_featured_game_mode"
    startFunction = function ()
    {
      ::gui_start_skirmish()
    }
    text = function ()
    {
      return ::loc("mainmenu/btnSkirmish")
    }
    textDescription = function() { return null }
    isWide = false
    image = function ()
    {
      return "#ui/images/game_modes_tiles/custom_battles_" + (isWide ? "wide" : "thin") + ".jpg?P1"
    }
    videoPreview = null
    isVisible = function ()
    {
      return !::is_me_newbie() && ::is_custom_battles_enabled()
    }
    hasNewIconWidget = false
    newIconWidgetId = ""
  }
  //{
    /*dynamic campaign*/
  //}
  //{
    /*single missions*/
  //}
]

::custom_game_modes_battles <- [
  {
    id = "custom_mode_fullreal"
    difficulty = ::g_difficulty.SIMULATOR
    image = "#ui/images/game_modes_tiles/mixed_event_02_wide.jpg?P1"
    type = ::g_event_display_type.RANDOM_BATTLE
    displayWide = true
    onBattleButtonClick = function() {
      local curUnit = ::get_cur_slotbar_unit()
      local chapter = ::events.chapters.getChapter("simulation_battles")
      local chapterEvents = chapter? chapter.getEvents() : []

      local openEventId = null
      if (chapterEvents.len())
      {
        local lastPlayedEventId = ::events.getLastPlayedEvent()?.name
        local lastPlayedEventRelevance = ::isInArray(lastPlayedEventId, chapterEvents) ?
          ::events.checkUnitRelevanceForEvent(lastPlayedEventId, curUnit) : UnitRelevance.NONE
        local relevanceList = ::u.map(chapterEvents, function(id) {
          return { eventId = id, relevance = ::events.checkUnitRelevanceForEvent(id, curUnit) }
        })
        relevanceList.sort(@(a,b) b.relevance <=> a.relevance || a.eventId <=> b.eventId)
        openEventId = lastPlayedEventRelevance >= relevanceList[0].relevance ?
          lastPlayedEventId : relevanceList[0].eventId
      }
      ::gui_start_modal_events({ event = openEventId })
    }
    inactiveColor = function() {
      local chapter = ::events.chapters.getChapter("simulation_battles")
      return !chapter || chapter.isEmpty()
    }
    isVisible = function() {
      return ::has_feature("AllModesInRandomBattles")
             && ::g_difficulty.SIMULATOR.isAvailable(::GM_DOMINATION)
             && !::is_me_newbie()
    }
    getTooltipText = function() { return ::loc("simulator_battles/desc") }
  }
]

::game_mode_select_partitions_data <- [
  {
    diffCode = ::DIFFICULTY_ARCADE
    forClan = false
    skipFeatured = true
    skipEnableOnDebug = true
  }
  {
    diffCode = ::DIFFICULTY_REALISTIC
    forClan = false
    skipFeatured = true
    skipEnableOnDebug = true
  }
  {
    diffCode = ::DIFFICULTY_HARDCORE
    forClan = false
    skipFeatured = true
    skipEnableOnDebug = true
  }
  {
    diffCode = -1
    forClan = true
    skipFeatured = true
    skipEnableOnDebug = true
  }
]

/**
 * Game mode manager incapsulates working
 * with current game mode id and game modes data.
 *
 * Game mode data has following structure:
 * {
 *   id       - string id (eventId for events or id for domination modes)
 *   source   - link to dominationModes item or event
 *   type     - event or dominationModes item
 *   locId    - localization to show in list
 *   modeIdx  - index in ::dominationModes array
 *   diffCode - difficulty code (0, 1, 2...) or -1 if code is invalid
 * }
 *
 * Setting new game mode will cause manager
 * to broadcast "CurrentGameModeIdChanged" event.
 *
 * Manager updates game modes array when (game) events
 * and player stats data is updated.
 */
class GameModeManager
{
  queueMask = QUEUE_TYPE_BIT.DOMINATION | QUEUE_TYPE_BIT.NEWBIE
  SEEN_MODES_SAVE_PATH = "seen/gameModes"

  defaultSeenGameModeIDs = ["air_arcade",
                           "air_realistic",
                           "tank_event_in_random_battles_arcade",
                           "tank_event_in_random_battles_historical",
                           "clan_battles_1_e",
                           "clan_battles_2_e",
                           "custom_mode_fullreal"]

  /**
   * Constructor. Subscribes manager to events that
   * require it to update.
   */
  function constructor()
  {
    ::add_event_listener("EventsDataUpdated", _onEventsDataUpdated.bindenv(this))
    ::add_event_listener("MyStatsUpdated", _onMyStatsUpdated.bindenv(this))
    ::add_event_listener("UnitTypeChosen", _onUnitTypeChosen.bindenv(this))
    ::add_event_listener("GameLocalizationChanged", _onGameLocalizationChanged.bindenv(this))
    ::add_event_listener("CrewTakeUnit", _onEventCrewTakeUnit.bindenv(this))
    ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)

    foreach (idx, id in defaultSeenGameModeIDs)
      defaultSeenGameModeIDs[idx] = getGameModeItemId(id)
  }

  /**
   * Updates current game mode id and game modes array.
   */
  function updateManager()
  {
    _updateGameModes()
    initShowingGameModesSeen()
    _updateCurrentGameModeId()
  }

  //
  // Current game mode ID
  //

  /**
   * Current game mode id getter.
   */
  function getCurrentGameModeId()
  {
    return _currentGameModeId
  }

  /**
   * Sets current game mode by id
   * and saves it in user account.
   */
  function setCurrentGameModeById(id)
  {
    _setCurrentGameModeId(id, true)
  }

  /**
   * Sets current game mode by index
   * and saves it in user account.
   */
  function setCurrentGameModeByIndex(index)
  {
    if (0 <= index || index < _gameModes.len())
    {
      local gameMode = _gameModes[index]
      _setCurrentGameModeId(gameMode.id, true)
    }
  }

  //
  // Game modes
  //

  /**
   * Returns current game mode data.
   */
  function getCurrentGameMode()
  {
    return ::getTblValue(_currentGameModeId, _gameModeById, null)
  }

  /**
   * Returns game mode data by id.
   */
  function getGameModeById(id)
  {
    return ::getTblValue(id, _gameModeById, null)
  }

  /**
   * Game modes retrieve method.
   * @param unitType Optional parameter providing method with unit type filter.
   *                 Parameter will be ignored if it set to ::ES_UNIT_TYPE_INVALID.
   * @param filterFunc Optional filter function with game mode as parameter and
   *                   boolean return type.
   * @return Returns array with available game modes.
   */
  function getGameModes(unitType = ::ES_UNIT_TYPE_INVALID, filterFunc = null)
  {
    if (unitType == ::ES_UNIT_TYPE_INVALID && filterFunc == null)
      return _gameModes
    local gameModes = []
    foreach (gameMode in _gameModes)
    {
      if (filterFunc != null && !filterFunc(gameMode))
        continue
      if (unitType != ::ES_UNIT_TYPE_INVALID && !::isInArray(unitType, gameMode.unitTypes))
        continue
      gameModes.push(gameMode)
    }
    return gameModes
  }

  /**
   * Returns game mode by unit type and (optionaly) difficulty.
   * @param unitType Unit type for game mode.
   * @param diffCode Requires game mode to be with specific difficulty.
   *                 Not applied if parameter is below zero and game mode
   *                 with lowest difficulty will be returned.
   * @param excludeClanGameModes Clan game mode will be skipped during search.
   * @return Null if game mode not found.
   */
  function getGameModeByUnitType(unitType, diffCode = -1, excludeClanGameModes = false)
  {
    local bestGameMode
    foreach (gameMode in _gameModes)
    {
      if (gameMode.displayType != ::g_event_display_type.RANDOM_BATTLE)
        continue
      local checkedUnitTypes = (gameMode?.reqUnitTypes && gameMode.reqUnitTypes.len() > 0)
        ? gameMode.reqUnitTypes
        : gameMode.unitTypes
      if (!::isInArray(unitType, checkedUnitTypes))
        continue
      if (excludeClanGameModes && gameMode.forClan)
        continue
      if (diffCode < 0)
      {
        if (bestGameMode == null || gameMode.diffCode < bestGameMode.diffCode)
          bestGameMode = gameMode
      }
      else if (gameMode.diffCode == diffCode)
      {
        bestGameMode = gameMode
        break
      }
    }
    return bestGameMode
  }

  function getUnitEconomicRankByGameMode(gameMode, unit)
  {
    if (gameMode.type == RB_GM_TYPE.EVENT)
      return ::events.getUnitEconomicRankByEvent(gameMode.getEvent(), unit)
    return unit.getEconomicRank(gameMode.ediff)
  }

  /**
   * Function checks if unit suitable for specified game mode.
   * @param gameMode Gets current game mode if not speficied.
   */
  function isUnitAllowedForGameMode(unit, gameMode = null)
  {
    if (!unit)
      return false
    if (gameMode == null)
      gameMode = getCurrentGameMode()
    if (!gameMode)
      return false
    return gameMode.type != RB_GM_TYPE.EVENT || ::events.isUnitAllowedForEvent(gameMode.getEvent(), unit)
  }

  /**
   * Returns true if preset has at least
   * one unit allowed for speficied game mode.
   * @param gameMode Gets current game mode if not speficied.
   */
  function isPresetValidForGameMode(preset, gameMode = null)
  {
    local unitNames = ::getTblValue("units", preset, null)
    if (unitNames == null)
      return false
    if (gameMode == null)
      gameMode = getCurrentGameMode()
    foreach (unitName in unitNames)
    {
      local unit = ::getAircraftByName(unitName)
      if (isUnitAllowedForGameMode(unit, gameMode))
        return true
    }
    return false
  }

  function findPresetValidForCurrentGameMode(countryId)
  {
    local presets = ::getTblValue(countryId, ::slotbarPresets.presets, null)
    if (presets == null)
      return null
    foreach (preset in presets)
    {
      if (isPresetValidForGameMode(preset))
        return preset
    }
    return null
  }

  /**
   * Attempts to determine current game mode id
   * based on local profile data, current unit, etc...
   * @param ignoreLocalProfile This flag disables attempts to retrieve
   *                           id from local profile.
   * @param preferredDiffCode If specified this difficulty will have highest priority.
   */
  function findCurrentGameModeId(ignoreLocalProfile = false, preferredDiffCode = -1)
  {
    //Step 0. Check current queue for gamemode.
    local queue = ::queues.findQueue(null, queueMask, true)
    if (queue && (queue.name in _gameModeById))
      return queue.name

    local idFromAccount = null
    local unitType = ::ES_UNIT_TYPE_INVALID
    if (!ignoreLocalProfile)
    {
      // Step 1. Attempting to retrieve current game mode id from account.
      idFromAccount = ::loadLocalByAccount("selected_random_battle", null)
      if (idFromAccount in _gameModeById)
        return idFromAccount

      // Step 2. Player's newbie event is may be not longer available.
      //         Attempting to get event with same unit type.
      unitType = ::my_stats.getUnitTypeByNewbieEventId(idFromAccount)
      if (unitType != ::ES_UNIT_TYPE_INVALID)
      {
        local gameMode = null
        if (preferredDiffCode != -1)
          gameMode = getGameModeByUnitType(unitType, preferredDiffCode, true)
        if (gameMode == null)
          gameMode = getGameModeByUnitType(unitType, -1, true)
        if (gameMode != null)
          return gameMode.id
      }
    }

    // Step 4. Attempting to retrieve current game mode id from newbie event.
    local event = ::my_stats.getNextNewbieEvent(null, null, false)
    local idFromEvent = ::getTblValue("name", event, null)
    if (idFromEvent in _gameModeById)
      return idFromEvent

    // Step 5. Attempting to get unit type from currently selected unit.
    local unit = ::get_cur_slotbar_unit()
    if (unitType == ::ES_UNIT_TYPE_INVALID && unit != null)
        unitType = ::get_es_unit_type(unit)

    // Step 6. Newbie event not found. If player is newbie and he has
    //         valid unit type we select easiest game mode.
    local firstUnitType = ::get_first_chosen_unit_type(::ES_UNIT_TYPE_INVALID)
    if (unitType == ::ES_UNIT_TYPE_INVALID
        && firstUnitType != ::ES_UNIT_TYPE_INVALID
        && ::my_stats.isMeNewbie())
      unitType = firstUnitType

    // Step 8. We have unit type. Selecting easiest game mode.
    local gameModeByUnitType = null
    if (preferredDiffCode != -1)
      gameModeByUnitType = getGameModeByUnitType(unitType, preferredDiffCode, true)
    if (gameModeByUnitType == null)
      gameModeByUnitType = getGameModeByUnitType(unitType, -1, true)
    local idFromUnitType = gameModeByUnitType != null ? gameModeByUnitType.id : null
    if (idFromUnitType != null)
      return idFromUnitType

    // Step 9. Player does not have valid unit type.
    //         Selecting any or nothing.
    if (_gameModes.len() > 0)
      return _gameModes[0].id

    // Step 10. Nothing found.
    return null
  }

  /**
   * Returns index of current game
   * mode in game modes array.
   */
  function getCurrentGameModeIndex()
  {
    return ::find_in_array(_gameModes, getCurrentGameMode(), 0)
  }

  //
  // Private
  //

  _currentGameModeId = null
  _gameModeById = {}
  _gameModes = []

  seenShowingGameModesInited = false
  isSeenByGameModeId = {}

  function _setCurrentGameModeId(id, save)
  {
    if (_currentGameModeId == id || !::events.eventsLoaded)
      return

    _currentGameModeId = id
    if (save)
    {
      ::saveLocalByAccount("selected_random_battle", _currentGameModeId)
    }
    ::broadcastEvent("CurrentGameModeIdChanged")
  }

  function _clearGameModes()
  {
    _gameModes = []
    _gameModeById = {}
  }

  function _appendGameMode(gameMode)
  {
    _gameModeById[gameMode.id] <- gameMode
    _gameModes.push(gameMode)
    return gameMode
  }

  function _createEventGameMode(event)
  {
    local isForClan = ::events.isEventForClan(event)
    if (isForClan && !::has_feature("Clans"))
      return

    local gameMode = {
      id = event.name
      source = event
      eventForSquad = null
      type = RB_GM_TYPE.EVENT
      text = ::events.getEventNameText(event)
      diffCode = ::events.getEventDiffCode(event)
      ediff = ::events.getEDiffByEvent(event)
      image = ::events.getEventTileImageName(event, ::events.isEventDisplayWide(event))
      videoPreview = ::has_feature("VideoPreview") ? ::events.getEventPreviewVideoName(event, ::events.isEventDisplayWide(event)) : null
      displayType = ::events.getEventDisplayType(event)
      forClan = isForClan
      countries = ::events.getAvailableCountriesByEvent(event)
      displayWide = ::events.isEventDisplayWide(event)
      enableOnDebug = ::events.isEventEnableOnDebug(event)

      getEvent = function() { return (::g_squad_manager.isNotAloneOnline() && eventForSquad) || source }
      getTooltipText = function()
      {
        local event = getEvent()
        return event ? ::events.getEventDescriptionText(event, null, true) : ""
      }
    }
    gameMode.unitTypes <- _getUnitTypesByGameMode(gameMode, false)
    local reqUnitTypes = _getUnitTypesByGameMode(gameMode, false, true)
    gameMode.reqUnitTypes <- reqUnitTypes
    local inactiveColor = !::events.checkEventFeature(event, true)

    if (!inactiveColor)
      foreach(type in reqUnitTypes)
      {
        inactiveColor = !::g_unit_type.getByEsUnitType(type).isAvailable()
        if (inactiveColor)
          break
      }
    gameMode.inactiveColor <- inactiveColor
    return _appendGameMode(gameMode)
  }

  function _createCustomGameMode(gm)
  {
    local gameMode = {
      id = gm.id
      source = null
      type = RB_GM_TYPE.CUSTOM
      text = gm.difficulty.getLocName()
      diffCode = gm.difficulty.diffCode
      ediff = gm.difficulty.getEdiff()
      image = gm.image
      linkIcon = ::getTblValue("linkIcon", gm, false)
      videoPreview = null
      displayType = gm.type
      forClan = false
      countries = []
      displayWide = gm.displayWide
      enableOnDebug = false
      onBattleButtonClick = ::getTblValue("onBattleButtonClick", gm)
      inactiveColor = ::getTblValue("inactiveColor", gm, function() { return false })()
      unitTypes = [::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_TANK]

      getEvent = function() { return null }
      getTooltipText = ::getTblValue("getTooltipText", gm, function() { return "" })
    }
    return _appendGameMode(gameMode)
  }

  function _updateGameModes()
  {
    _clearGameModes()

    local newbieGmByUnitType = {}
    foreach (unitType in ::g_unit_type.types)
    {
      local event = ::my_stats.getNextNewbieEvent(null, unitType.esUnitType, false)
      if (event)
        newbieGmByUnitType[unitType.esUnitType] <- _createEventGameMode(event)
    }

    for (local idx = 0; idx < ::custom_game_modes_battles.len(); idx++)
    {
      local dm = ::custom_game_modes_battles[idx]
      if (!("isVisible" in dm) || dm.isVisible())
            _createCustomGameMode(dm)
    }

    foreach (eventId in ::events.getEventsForGcDrawer())
    {
      local event = ::events.getEvent(eventId)
      local skip = false
      foreach (unitType, newbieGm in newbieGmByUnitType)
        if (::events.isUnitTypeAvailable(event, unitType)
            && ::events.isUnitTypeRequired(event, unitType, true))
        {
          if (::events.getEventDiffCode(event) == newbieGm.diffCode)
            newbieGm.eventForSquad = event
          skip = true
          break
        }
      if (!skip)
        _createEventGameMode(event)
    }

    ::broadcastEvent("GameModesUpdated")
  }

  function _updateCurrentGameModeId()
  {
    local currentGameModeId = findCurrentGameModeId()
    if (currentGameModeId != null)
    {
      // This activates saving to profile on first update after profile loaded.
      local save = _currentGameModeId == null && ::events.eventsLoaded
      _setCurrentGameModeId(currentGameModeId, save)
    }
  }

  function _getUnitTypesByGameMode(gameMode,isOnlyAvailable = true, needReqUnitType = false)
  {
    if (!gameMode)
      return []

    local filteredUnitTypes = ::u.filter(::g_unit_type.types,
      @(unitType) isOnlyAvailable ? unitType.isAvailable() : unitType)
    if (gameMode.type != RB_GM_TYPE.EVENT)
      return ::u.map(filteredUnitTypes, @(unitType) unitType.esUnitType)

    local event = gameMode.getEvent()
    return ::u.map(
      ::u.filter(filteredUnitTypes,
        @(unitType) needReqUnitType ? ::events.isUnitTypeRequired(event, unitType.esUnitType)
          : ::events.isUnitTypeAvailable(event, unitType.esUnitType)
      ),
      @(unitType) unitType.esUnitType)
  }

  function getGameModesPartitions()
  {
    local partitions = []
    foreach (partitionData in ::game_mode_select_partitions_data)
    {
      local partition = {
        separator = partitionData.forClan
        gameModes = ::game_mode_manager.getGameModes(
          ::ES_UNIT_TYPE_INVALID,
          (@(partitionData) function (gameMode) {
            local checkForClan = gameMode.forClan == partitionData.forClan
            local checkDiffCode = partitionData.diffCode == -1 || gameMode.diffCode == partitionData.diffCode
            local checkSkipFeatured = !partitionData.skipFeatured || gameMode.displayType != ::g_event_display_type.FEATURED
            local isPVEBattle = gameMode.displayType == ::g_event_display_type.PVE_BATTLE
            local checkSkipEnableOnDebug = !partitionData.skipEnableOnDebug || !gameMode.enableOnDebug
            return checkForClan && checkDiffCode && checkSkipFeatured && checkSkipEnableOnDebug && !isPVEBattle
          })(partitionData)
        )
      }
      // If diff code is not provided
      // sort game modes by difficulty.
      if (partitionData.diffCode == -1)
      {
        partition.gameModes.sort(function (gm1, gm2) {
          return ::events.diffCodeCompare(gm1.diffCode, gm2.diffCode)
        })
      }
      partitions.push(partition)
    }
    return partitions
  }

  function getFeaturedGameModes()
  {
    return getGameModes(::ES_UNIT_TYPE_INVALID, function (gameMode) {
      return gameMode.displayType == ::g_event_display_type.FEATURED && !gameMode.enableOnDebug
    })
  }

  function getDebugGameModes()
  {
    return getGameModes(::ES_UNIT_TYPE_INVALID, function (gameMode) {
      return gameMode.enableOnDebug
    })
  }

  function getPveBattlesGameModes()
  {
    return getGameModes(::ES_UNIT_TYPE_INVALID, function (gameMode) {
      return gameMode.displayType == ::g_event_display_type.PVE_BATTLE && !gameMode.enableOnDebug
    })
  }

  function getGameModeItemId(gameModeId)
  {
    return "game_mode_item_" + gameModeId
  }

//------------- <New Icon Widget> ----------------------
  function initShowingGameModesSeen()
  {
    if (seenShowingGameModesInited)
      return true

    if (!::g_login.isLoggedIn())
      return false

    local blk = ::loadLocalByAccount(SEEN_MODES_SAVE_PATH, ::DataBlock())
    for (local i = 0; i < blk.paramCount(); i++)
    {
      local id = blk.getParamName(i)
      isSeenByGameModeId[id] <- blk.getParamValue(i)
    }

    foreach (gmId in defaultSeenGameModeIDs)
      if (!(gmId in isSeenByGameModeId))
        isSeenByGameModeId[gmId] <- true

    seenShowingGameModesInited = true

    ::broadcastEvent("ShowingGameModesUpdated")

    return true
  }

  function markShowingGameModeAsSeen(gameModeId)
  {
    isSeenByGameModeId[gameModeId] <- true
    saveSeenGameModes()
    ::broadcastEvent("ShowingGameModesUpdated")
  }

  function getUnseenGameModeCount()
  {
    local unseenGameModesCount = 0
    foreach(gameMode in getAllVisibleGameModes())
      if (!isSeen(getGameModeItemId(gameMode.id)))
        unseenGameModesCount++

    foreach (mode in ::featured_modes)
      if (mode.hasNewIconWidget && mode.isVisible() && !isSeen(getGameModeItemId(mode.modeId)))
        unseenGameModesCount++

    return unseenGameModesCount
  }

  function isSeen(gameModeId)
  {
    return ::getTblValue(gameModeId, isSeenByGameModeId, false)
  }

  function saveSeenGameModes()
  {
    if (!seenShowingGameModesInited)
      return //data not loaded yet

    local blk = ::DataBlock()
    foreach(gameMode in getAllVisibleGameModes())
    {
      local id = getGameModeItemId(gameMode.id)
      if (id in isSeenByGameModeId)
        blk[id] = isSeenByGameModeId[id]
    }

    foreach (mode in ::featured_modes)
    {
      local id = getGameModeItemId(mode.modeId)
      if (id in isSeenByGameModeId)
        blk[id] = isSeenByGameModeId[id]
    }

    ::saveLocalByAccount(SEEN_MODES_SAVE_PATH, blk)
  }

  function getAllVisibleGameModes()
  {
    local gameModePartitions = ::game_mode_manager.getGameModesPartitions()
    local gameModes = []
    foreach(partition in gameModePartitions)
      gameModes.extend(partition.gameModes)

    gameModes.extend(getPveBattlesGameModes())
    gameModes.extend(getFeaturedGameModes())
    gameModes.extend(getDebugGameModes())
    return gameModes
  }

//------------- </New Icon Widget> ----------------------

  function _onEventsDataUpdated(params)
  {
    updateManager()
  }

  function _onMyStatsUpdated(params)
  {
    updateManager()
  }

  function _onUnitTypeChosen(params)
  {
    updateManager()
  }

  function _onGameLocalizationChanged(params)
  {
    updateManager()
  }

  function _onEventCrewTakeUnit(params)
  {
    updateManager()
  }

  function onEventQueueChangeState(queue)
  {
    if (::queues.checkQueueType(queue, queueMask) && ::queues.isQueueActive(queue))
      _updateCurrentGameModeId()
  }

  function onEventSignOut(p)
  {
    _currentGameModeId = null
    _gameModeById.clear()
    _gameModes.clear()
  }
}

::game_mode_manager <- GameModeManager()
