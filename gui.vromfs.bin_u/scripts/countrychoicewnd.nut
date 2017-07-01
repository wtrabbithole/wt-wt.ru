enum CChoiceState {
  UNIT_TYPE_SELECT
  COUNTRY_SELECT
  APPLY
}

function is_need_first_country_choice()
{
  return ::get_first_chosen_unit_type() == ::ES_UNIT_TYPE_INVALID
         && !::stat_get_value_respawns(0, 1)
         && !::disable_network()
}

function gui_start_countryChoice()
{
  ::handlersManager.loadHandler(::gui_handlers.CountryChoiceHandler)
}

class ::gui_handlers.CountryChoiceHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/countryChoice.blk"
  wndOptionsMode = ::OPTIONS_MODE_GAMEPLAY

  countries = null
  availableCountriesArray = null
  unitTypesList = null

  prevCurtainObj = null
  countriesUnits = {}

  selectedCountry  = null
  selectedUnitType = null
  isFixedUnitType = false
  state = 0

  function initScreen()
  {
    unitTypesList = []
    foreach(unitType in ::g_unit_type.types)
      if (unitType.isAvailableForFirstChoice()
          && ::get_countries_by_unit_type(unitType.esUnitType).len())
        unitTypesList.append(unitType)
    if (!unitTypesList.len())
      return goBack()

    if (unitTypesList.len() == 1)
    {
      selectedUnitType = unitTypesList[0]
      isFixedUnitType = true
    }

    countriesUnits = ::get_unit_types_in_countries()
    countries = ::get_slotbar_countries(true)

    updateState()
  }

  function startNextState()
  {
    state++
    updateState()
  }

  function updateState()
  {
    if (state == CChoiceState.COUNTRY_SELECT)
      createPrefferedUnitTypeCountries()
    else if (state == CChoiceState.UNIT_TYPE_SELECT)
    {
      if (isFixedUnitType)
        startNextState()
      else
        createUnitTypeChoice()
    } else
      applySelection()
    updateButtons()
  }

  function updateButtons()
  {
    showSceneBtn("back_button", !isFixedUnitType && state > 0)
  }

  function checkSelection(country, unitType)
  {
    local availData = get_unit_types_in_countries()
    return ::getTblValue(unitType.esUnitType, ::getTblValue(country, availData), false)
  }

  function applySelection()
  {
    if (!checkSelection(selectedCountry, selectedUnitType))
      return

    ::switch_profile_country(selectedCountry)
    goBack()
    ::saveLocalByAccount(::battle_type_option_name,
       (selectedUnitType == ::g_unit_type.TANK ? BATTLE_TYPES.TANK : BATTLE_TYPES.AIR))
    ::broadcastEvent("UnitTypeChosen")
  }

  function isCountryAvailable(country, unitType)
  {
    if (!unitType.isAvailableForFirstChoice(country))
      return false

    local countryData = ::getTblValue(country, countriesUnits)
    return ::getTblValue(unitType.esUnitType, countryData)
  }

  function createUnitTypeChoice()
  {
    setFrameWidth("2@unitChoiceImageWidth+2@framePadding")

    local view = {
      unitTypeItems = function ()
      {
        local items = []
        foreach(unitType in unitTypesList)
        {
          local countriesList = ""
          foreach(i, country in countries)
          {
            if (!isCountryAvailable(country, unitType))
              continue

            countriesList += (countriesList == "" ? " ":", ") + ::loc("unlockTag/" + country)
          }

          local armyName = unitType.armyId
          local image = ::format("ui/images/first_%s.jpg", armyName)

          items.push({
            backgroundImage = ::format("#%s?P1", image)
            tooltip = ::loc("unit_type") + ::loc("ui/colon") + ::loc("mainmenu/" + armyName)
                    + "\n" + countriesList
            text = ::loc("mainmenu/" + armyName)
            videoPreview = ::has_feature("VideoPreview") ? "video/unitTypePreview/" + armyName + ".ogv" : null
            desription = ::loc(armyName + "/choiseDescription", "")
          })
        }
        return items
      }.bindenv(this)
    }

    local data = ::handyman.renderCached("gui/unitTypeChoice", view)
    if (selectedUnitType == null)
      selectedUnitType = ::g_unit_type.TANK

    fillChoiceScene(data, ::find_in_array(unitTypesList, selectedUnitType, 0), "firstUnit")
  }

  function fillChoiceScene(data, focusItemNum, headerLocId)
  {
    if (data == "")
      return

    local headerObj = scene.findObject("choice_header")
    if (::checkObj(headerObj))
      headerObj.setValue(::loc("mainmenu/" + headerLocId))

    local listObj = scene.findObject("first_choices_block")
    guiScene.replaceContentFromText(listObj, data, data.len(), this)

    local listBoxObj = listObj.getChild(0)
    listBoxObj.select()
    if (focusItemNum != null)
      listBoxObj.setValue(focusItemNum)
  }

  function createPrefferedUnitTypeCountries()
  {
    setFrameWidth("1@countryChoiceImageWidth+2@framePadding")
    local availCountries = selectedUnitType ? ::get_countries_by_unit_type(selectedUnitType.esUnitType) : countries
    for (local i = availCountries.len() - 1; i >= 0; i--)
      if (!isCountryAvailable(availCountries[i], selectedUnitType))
        availCountries.remove(i)

    local data = ""
    local view = {
      countries = (@(availCountries) function () {
        local res = []
        local curArmyName = selectedUnitType ? selectedUnitType.armyId  : ::g_unit_type.AIRCRAFT.armyId
        local notAvailableMsg = ::loc("mainmenu/onlyArmyAvailableForCountry",
                                      { army = ::loc("mainmenu/" + ::g_unit_type.AIRCRAFT.armyId) })
        foreach(country in countries)
        {
          local available = ::isInArray(country, availCountries)
          local armyName = available
                               ? curArmyName
                               : ::g_unit_type.AIRCRAFT.armyId

          local tooltip = ::loc("options/country") +
                          ::loc("ui/colon") +
                          ::loc("unlockTag/" + country)

          local id = country + "_" + armyName
          local image = ::get_country_flag_img("countries_" + id)
          if (image == "")
            image = ::get_country_flag_img("countries_" + country + "_aviation")

          local cData = {
            tooltip = tooltip
            backgroundImage = image
            desription = ::loc(country + "/choiseDescription", "")
          }

          if (!available)
          {
            cData.disabled <- true
            cData.text <- notAvailableMsg
          }

          res.append(cData)
        }
        return res
      })(availCountries).bindenv(this)
    }

    data = ::handyman.renderCached("gui/countryFirstChoiceItem", view)

    if (!availCountries.len())
    {
      local message = ::format("Error: Empty available countries List for userId = %s\nunitType = %s:\ncountries = %s\n%s",
                               ::my_user_id_str,
                               selectedUnitType.name,
                               ::toString(countries),
                               ::toString(::get_unit_types_in_countries(), 2)
                              )
      ::script_net_assert_once("empty countries list", message)
    }
    else if (!::isInArray(selectedCountry, availCountries))
    {
      local rndC = ::math.rnd() % availCountries.len()
      if (::is_vietnamese_version())
        rndC = ::find_in_array(availCountries, "country_ussr", rndC)
      selectedCountry = availCountries[rndC]
    }

    local selectId = ::find_in_array(countries, selectedCountry, 0)
    fillChoiceScene(data, selectId, "firstCountry")
  }

  function onBack()
  {
    if (state <= 0)
      return

    state--
    updateState()
  }

  function onEnterChoice(obj)
  {
    startNextState()
  }

  function onSelectCountry(obj)
  {
    local newCountry = ::getTblValue(obj.getValue(), countries)
    if (newCountry)
      selectedCountry = newCountry
  }

  function onSelectUnitType(obj)
  {
    selectedUnitType = unitTypesList[obj.getValue()]
  }

  /**
   * Creates tasks data with reserve units.
   * @param checkCurrentCrewAircrafts Skips tasks if crew
   *                                  already has proper unit.
   */
  function createReserveTasksData(country, unitType, checkCurrentCrewAircrafts = true, ignoreSlotbarCheck = false)
  {
    local tasksData = []
    if (::crews_list.len()==0)
      ::crews_list = ::get_crew_info()
    local usedUnits = []
    foreach(c in ::crews_list)
    {
      if (c.country != country)
        continue
      foreach(idInCountry, crewBlock in c.crews)
      {
        local unitName = ""
        if (checkCurrentCrewAircrafts)
        {
          local trainedUnit = ::g_crew.getCrewUnit(crewBlock)
          if (trainedUnit && trainedUnit.unitType == unitType)
            unitName = trainedUnit.name
        }
        if (!unitName.len())
          unitName = ::getReserveAircraftName({
            country = country
            unitType = unitType.esUnitType
            ignoreUnits = usedUnits
            ignoreSlotbarCheck = ignoreSlotbarCheck
            preferredCrew = crewBlock
          })

        if (unitName.len())
          usedUnits.append(unitName)
        tasksData.append({crewId = crewBlock.id, airName = unitName})
      }
      break
    }
    return tasksData
  }

  /**
   * Returns collection of items with all data
   * required to create newbie presets.
   * @see ::slotbarPresets.newbieInit(...)
   */
  function createNewbiePresetsData(selectedCountry, selectedUnitType)
  {
    local presetDataItems = []
    local selEsUnitType = ::ES_UNIT_TYPE_INVALID
    foreach (crewData in ::get_crew_info())
    {
      local country = crewData.country
      foreach(unitType in ::g_unit_type.types)
      {
        if (!unitType.isAvailable()
            || !::get_countries_by_unit_type(unitType.esUnitType).len())
          continue

        local tasksData = createReserveTasksData(country, unitType, false, true)
        // Used for not creating empty presets.
        local hasUnits = false
        foreach (taskData in tasksData)
          if (taskData.airName != "")
          {
            hasUnits = true
            break
          }

        presetDataItems.push({
          country = country
          unitType = unitType.esUnitType
          hasUnits = hasUnits
          tasksData = tasksData
        })

        if (hasUnits
            && (unitType == selectedUnitType || selEsUnitType == ::ES_UNIT_TYPE_INVALID))
          selEsUnitType = unitType.esUnitType
      }
    }
    return {
      presetDataItems = presetDataItems
      selectedCountry = selectedCountry
      selectedUnitType = selEsUnitType
    }
  }

  function createBatchRequestByPresetsData(presetsData)
  {
    local requestData = []
    foreach (presetDataItem in presetsData.presetDataItems)
      if (presetDataItem.unitType == presetsData.selectedUnitType)
        foreach (taskData in presetDataItem.tasksData)
          requestData.push(taskData)
    return ::create_batch_train_crew_request_blk(requestData)
  }

  function clnSetStartingInfo(presetsData, onComplete)
  {
    local blk = createBatchRequestByPresetsData(presetsData)
    blk.setStr("country", presetsData.selectedCountry)
    blk.setInt("unitType", presetsData.selectedUnitType)

    foreach(country in countries)
    {
      ::unlockCountry(country, true, false) //now unlock all countries
      blk.unlock <- country
    }

    if (::get_first_chosen_unit_type() == ::ES_UNIT_TYPE_INVALID)
      if (selectedUnitType.firstChosenTypeUnlockName)
        blk.unlock <- selectedUnitType.firstChosenTypeUnlockName

    local taskCallback = ::Callback(onComplete, this)
    local taskId = ::char_send_blk("cln_set_starting_info", blk)
    local taskOptions = {
      showProgressBox = true
      progressBoxDelayedButtons = 90
    }
    ::g_tasker.addTask(taskId, taskOptions, taskCallback)
  }

  function goBack()
  {
    local presetsData = createNewbiePresetsData(selectedCountry, selectedUnitType)
    local handler = this
    clnSetStartingInfo(presetsData, (@(presetsData, handler) function () {
        // This call won't procude any additional char-requests
        // as all units are already set previously as a single
        // batch char request.
        ::slotbarPresets.newbieInit(presetsData)

        ::checkUnlockedCountriesByAirs()
        ::top_menu_handler.reinitSlotbarAction()
        ::broadcastEvent("EventsDataUpdated")
        ::gui_handlers.BaseGuiHandlerWT.goBack.call(handler)
      })(presetsData, handler))
  }

  function afterModalDestroy()
  {
    restoreMainOptions()
    ::crews_list = get_crew_info()
  }

  function setFrameWidth(width)
  {
    local frameObj = scene.findObject("countryChoice-root")
    if (::checkObj(frameObj))
      frameObj.width = width
  }
}
