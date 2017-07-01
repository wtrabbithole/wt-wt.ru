class SlotbarPresetsTutorial
{
  /** Total maximum times to show this tutorial. */
  static MAX_TUTORIALS = 3

  /**
   * Not showing tutorial for game mode if user played
   * it more than specified amount of times.
   */
  static MAX_PLAYS_FOR_GAME_MODE = 5

  // These parameters must be set from outside.
  currentCountry = null
  currentHandler = null
  onComplete = null
  preset = null // Preset to select.

  currentGameModeId = null

  // Slotbar
  presetsList = null
  presetSlotbarIndex = -1

  // Window
  chooseSlotbarPresetHandler = null
  chooseSlotbarPresetIndex = -1

  // Unit select
  crewIdInCountry = -1 // Slotbar-index of unit to select.

  currentTutorial = null

  /**
   * Returns false if tutorial was skipped due to some error.
   */
  function startTutorial()
  {
    currentGameModeId = ::game_mode_manager.getCurrentGameModeId()
    if (preset == null)
      return false
    local currentPresetIndex = ::getTblValue(currentCountry, ::slotbarPresets.selected, -1)
    if (currentPresetIndex == getPresetIndex(preset))
      return startUnitSelectStep()
    presetsList = currentHandler.getSlotbarPresetsList()
    if (presetsList == null)
      return false
    local presetObj = presetsList.getListChildByPreset(preset)
    local steps
    if (presetObj != null) // Preset is in slotbar presets list.
    {
      presetSlotbarIndex = ::getTblValue(preset, presetsList.listIndexByPreset, -1)
      if (presetSlotbarIndex == -1)
        return false
      steps = [{
        obj = [presetObj]
        text = createMessage_selectPreset()
        actionType = tutorAction.OBJ_CLICK
        accessKey = "J:X"
        cb = ::Callback(onSlotbarPresetSelect, this)
        keepEnv = true
      }]
    }
    else
    {
      local presetsButtonObj = presetsList.getPresetsButtonObj()
      if (presetsButtonObj == null)
        return false
      steps = [{
        obj = [presetsButtonObj]
        text = ::loc("slotbarPresetsTutorial/openWindow")
        actionType = tutorAction.OBJ_CLICK
        accessKey = "J:X"
        cb = ::Callback(onChooseSlotbarPresetWnd_Open, this)
        keepEnv = true
      }]
    }
    currentTutorial = ::gui_modal_tutor(steps, currentHandler, true)

    // Increment tutorial counter.
    ::saveLocalByAccount("tutor/slotbar_presets_tutorial_counter", getCounter() + 1)

    return true
  }

  function onSlotbarPresetSelect()
  {
    if (checkCurrentTutorialCanceled())
      return
    ::add_event_listener("SlotbarPresetLoaded", onEventSlotbarPresetLoaded, this)
    local listObj = presetsList.getListObj()
    if (listObj != null)
      listObj.setValue(presetSlotbarIndex)
  }

  function onChooseSlotbarPresetWnd_Open()
  {
    if (checkCurrentTutorialCanceled())
      return
    chooseSlotbarPresetHandler = ::gui_choose_slotbar_preset(currentHandler)
    chooseSlotbarPresetIndex = ::find_in_array(::slotbarPresets.presets[currentCountry], preset)
    if (chooseSlotbarPresetIndex == -1)
      return
    local itemsListObj = chooseSlotbarPresetHandler.scene.findObject("items_list")
    local presetObj = itemsListObj.getChild(chooseSlotbarPresetIndex)
    if (!::checkObj(presetObj))
      return
    local applyButtonObj = chooseSlotbarPresetHandler.scene.findObject("btn_preset_load")
    if (!::checkObj(applyButtonObj))
      return
    local steps = [{
      obj = [presetObj]
      text = createMessage_selectPreset()
      actionType = tutorAction.OBJ_CLICK
      accessKey = "J:X"
      cb = ::Callback(onChooseSlotbarPresetWnd_Select, this)
      keepEnv = true
    } {
      obj = [applyButtonObj]
      text = ::loc("slotbarPresetsTutorial/pressApplyButton")
      actionType = tutorAction.OBJ_CLICK
      accessKey = "J:X"
      cb = ::Callback(onChooseSlotbarPresetWnd_Apply, this)
      keepEnv = true
    }]
    currentTutorial = ::gui_modal_tutor(steps, currentHandler, true)
  }

  function onChooseSlotbarPresetWnd_Select()
  {
    if (checkCurrentTutorialCanceled(false))
      return
    local itemsListObj = chooseSlotbarPresetHandler.scene.findObject("items_list")
    itemsListObj.setValue(chooseSlotbarPresetIndex)
    chooseSlotbarPresetHandler.onItemSelect(null)
  }

  function onChooseSlotbarPresetWnd_Apply()
  {
    if (checkCurrentTutorialCanceled())
      return
    ::add_event_listener("SlotbarPresetLoaded", onEventSlotbarPresetLoaded, this)
    chooseSlotbarPresetHandler.onBtnPresetLoad(null)
  }

  function onEventSlotbarPresetLoaded(params)
  {
    if (checkCurrentTutorialCanceled())
      return
    ::remove_event_listeners_by_env("SlotbarPresetLoaded", this)

    // Switching preset causes game mode to switch as well.
    // So we need to restore it to it's previous value.
    ::game_mode_manager.setCurrentGameModeById(currentGameModeId)

    // This update shows player that preset was
    // actually changed behind tutorial dim.
    ::top_menu_handler.reinitSlotbarAction()

    if (!startUnitSelectStep())
      startPressToBattleButtonStep()
  }

  function onStartPress()
  {
    if (checkCurrentTutorialCanceled())
      return
    ::instant_domination_handler.onStart()
    if (onComplete != null)
      onComplete({ result = "success" })
  }

  function createMessage_selectPreset()
  {
    local currentGameMode = ::game_mode_manager.getCurrentGameMode()
    if (currentGameMode == null)
      return ""
    local unitTypes = ::getTblValue("unitTypes", currentGameMode, null)
    local unitType = ::getTblValue(0, unitTypes)
    local unitTypeLocId = "options/chooseUnitsType/" +
      (unitType == ::ES_UNIT_TYPE_AIRCRAFT ? "aircraft" : "tank")
    return ::loc("slotbarPresetsTutorial/selectPreset", { unitType = ::loc(unitTypeLocId) })
  }

  function createMessage_pressToBattleButton()
  {
    local currentGameMode = ::game_mode_manager.getCurrentGameMode()
    if (currentGameMode == null)
      return ""
    return ::loc("slotbarPresetsTutorial/pressToBattleButton", { gameModeName = currentGameMode.text })
  }

  function getPresetIndex(preset)
  {
    local presets = ::getTblValue(currentCountry, ::slotbarPresets.presets, null)
    return ::find_in_array(presets, preset, -1)
  }

  /**
   * This subtutorial for selecting allowed unit within selected preset.
   * Returns false if tutorial was skipped for some reason.
   */
  function startUnitSelectStep()
  {
    if (::game_mode_manager.isUnitAllowedForGameMode(::show_aircraft))
      return false
    local currentPreset = ::slotbarPresets.getCurrentPreset(currentCountry)
    if (currentPreset == null)
      return false
    local index = getAllowedUnitIndexByPreset(currentPreset)
    local crews = ::getTblValue("crews", currentPreset, null)
    local crewId = ::getTblValue(index, crews, -1)
    if (crewId == -1)
      return false
    local crew = ::get_crew_by_id(crewId)
    crewIdInCountry = ::getTblValue("idInCountry", crew, -1)
    if (crewIdInCountry == -1)
      return false

    // ID for DaGUI object in slotbar related to allowed unit. (e.g. "slot_2_1")
    local slotId = ::format("slot_%s_%s", currentHandler.getCurSlotCountryId().tostring(), crewIdInCountry.tostring())

    local slotObj = currentHandler.getSlotbarScene().findObject(slotId)
    local steps = [{
      obj = [slotObj]
      text = ::loc("slotbarPresetsTutorial/selectUnit")
      actionType = tutorAction.OBJ_CLICK
      accessKey = "J:X"
      cb = ::Callback(onUnitSelect, this)
      keepEnv = true
    }]
    currentTutorial = ::gui_modal_tutor(steps, ::instant_domination_handler, true)
    return true
  }

  function onUnitSelect()
  {
    if (checkCurrentTutorialCanceled())
      return
    currentHandler.selectCrew(crewIdInCountry)
    startPressToBattleButtonStep()
  }

  /**
   * Returns -1 if no such unit found.
   */
  function getAllowedUnitIndexByPreset(preset)
  {
    local units = ::getTblValue("units", preset, null)
    if (units == null)
      return -1
    for (local i = 0; i < units.len(); ++i)
    {
      local unit = ::getAircraftByName(units[i])
      if (::game_mode_manager.isUnitAllowedForGameMode(unit))
        return i
    }
    return -1
  }

  function startPressToBattleButtonStep()
  {
    if (checkCurrentTutorialCanceled())
      return
    local objs = [
      ::top_menu_handler.scene.findObject("to_battle_button"),
      ::top_menu_handler.getObj("to_battle_console_image")
    ]
    local steps = [{
      obj = [objs]
      text = createMessage_pressToBattleButton()
      actionType = tutorAction.OBJ_CLICK
      accessKey = "J:X"
      cb = ::Callback(onStartPress, this)
    }]
    currentTutorial = ::gui_modal_tutor(steps, ::instant_domination_handler, true)
  }

  /**
   * Returns true and calls onComplete callback if
   * currentTutorial was canceled.
   * @params removeCurrentTutorial Should be 'true'
   * only for final tutorial step callbacks and 'false'
   * for intermediate states.
   */
  function checkCurrentTutorialCanceled(removeCurrentTutorial = true)
  {
    local canceled = ::getTblValue("canceled", currentTutorial, false)
    if (removeCurrentTutorial)
      currentTutorial = null
    if (canceled)
    {
      if (onComplete != null)
        onComplete({ result = "canceled" })
      return true
    }
    return false
  }

  static function getCounter()
  {
    return ::loadLocalByAccount("tutor/slotbar_presets_tutorial_counter", 0)
  }
}
