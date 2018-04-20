enum SEL_UNIT_BUTTON {
  EMPTY_CREW
  SHOP
  SHOW_MORE
}

const MIN_NON_EMPTY_SLOTS_IN_COUNTRY = 1

function gui_start_select_unit(crew, slotbar)
{
  if (!::SessionLobby.canChangeCrewUnits())
    return
  if (!::CrewTakeUnitProcess.safeInterrupt())
    return

  local slotbarObj = slotbar.scene
  local slotObj = ::get_slot_obj(slotbarObj, crew.idCountry, crew.idInCountry)
  if (!::check_obj(slotObj))
    return

  local params = {
    countryId = crew.idCountry,
    idInCountry = crew.idInCountry,
    config = slotbar,
    slotObj = slotObj,
    slotbarWeak = slotbar,
    crew = crew
  }
  ::handlersManager.destroyPrevHandlerAndLoadNew(::gui_handlers.SelectUnit, params)
}

class ::gui_handlers.SelectUnit extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/slotbar/slotbarChooseAircraft.blk"
  slotbarWeak = null

  countryId = -1
  idInCountry = -1
  crew = null

  config = null //same as slotbarParams in BaseGuiHandlerWT
  slotObj = null
  curClonObj = null

  unitsList = null
  totalUsableUnits = 0
  isFocusOnUnitsList = true

  wasReinited = false

  filterOptionsList = [
    ::USEROPT_BIT_CHOOSE_UNITS_TYPE,
    ::USEROPT_BIT_CHOOSE_UNITS_RANK,
    ::USEROPT_BIT_CHOOSE_UNITS_OTHER,
    ::USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_GAME_MODE,
    ::USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_CUSTOM_LIST
  ]

  curOptionsMasks = null //[]
  optionsMaskByUnits = null //{}
  isEmptyOptionsList = true
  legendData = null //[]

  slotsPerPage = 9 //check css
  firstPageSlots = 20
  curVisibleSlots = 0

  showMoreObj = null

  function initScreen()
  {
    curOptionsMasks = []
    optionsMaskByUnits = {}
    legendData = []
    if (slotbarWeak)
      slotbarWeak = slotbarWeak.weakref() //we are miss weakref on assigning from params table

    guiScene.applyPendingChanges(false) //to apply slotbar scroll before calculating positions

    local tdObj = slotObj.getParent()
    local tdPos = tdObj.getPosRC()

    ::gui_handlers.ActionsList.removeActionsListFromObject(tdObj)

    local tdClone = tdObj.getClone(scene, slotbarWeak)
    tdClone.pos = tdPos[0] + ", " + tdPos[1]
    tdClone["class"] = "slotbarClone"
    curClonObj = tdClone

    local curUnitCloneObj = ::get_slot_obj(tdClone, countryId, idInCountry)
    local crewUnitId = ::getTblValue("aircraft", crew, "")
     ::fill_unit_item_timers(curUnitCloneObj, ::getAircraftByName(crewUnitId))
    ::gui_handlers.ActionsList.switchActionsListVisibility(curUnitCloneObj)

    scene.findObject("tablePlace").pos = tdPos[0] + ", " + tdPos[1]

    local needEmptyCrewButton = initAvailableUnitsArray()
    if (unitsList.len() == 0)
      return goBack()

    curVisibleSlots = firstPageSlots

    showSceneBtn("btn_emptyCrew", needEmptyCrewButton)
    initChooseUnitsOptions()
    fillChooseUnitsOptions()
    fillLegendData()
    fillUnitsList()
    updateUnitsList()
    setFocus(true)
    updateOptionShowUnsupportedForCustomList()
  }

  function reinitScreen(params = {})
  {
    if (::check_obj(curClonObj))
      curClonObj.getScene().destroyElement(curClonObj)
    setParams(params)
    initScreen()
    wasReinited = true
  }

  function fillLegendData()
  {
    legendData.clear()
    foreach (specType in ::g_crew_spec_type.types)
      if (specType != ::g_crew_spec_type.UNKNOWN)
        addLegendData(specType.specName, specType.trainedIcon, ::loc("crew/trained") + ::loc("ui/colon") + specType.getName())
    addLegendData("warningIcon", "#ui/gameuiskin#new_icon", "#mainmenu/selectCrew/haveMoreQualified/tooltip")
  }

  function fillLegend()
  {
    local legendNest = scene.findObject("legend_nest")
    local legendView = {
      header = ::loc("mainmenu/legend")
      haveLegend = legendData.len() > 0,
      legendData = legendData
    }
    local markup = ::handyman.renderCached("gui/slotbar/legend_block", legendView)
    guiScene.replaceContentFromText(legendNest, markup, markup.len(), this)
  }

  function getUsingUnitsArray()
  {
    local array = []
    foreach(idx, crew in ::g_crews_list.get()[countryId].crews)
      if (idx != idInCountry && ("aircraft" in crew))
        array.append(crew.aircraft)

    return array
  }

  function initAvailableUnitsArray()
  {
    local country = ::g_crews_list.get()[countryId].country
    local busyUnits = getUsingUnitsArray()

    local unitsArray = []
    foreach(unit in ::all_units)
      if (!::isInArray(unit.name, busyUnits) && unit.canAssignToCrew(country))
         unitsArray.append(unit)


    unitsList = []

    if (slotbarWeak?.ownerWeak?.canShowShop && slotbarWeak.ownerWeak.canShowShop())
      unitsList.append(SEL_UNIT_BUTTON.SHOP)

    local needEmptyCrewButton = ("aircraft" in crew && busyUnits.len() >= MIN_NON_EMPTY_SLOTS_IN_COUNTRY)
    if (needEmptyCrewButton)
      unitsList.append(SEL_UNIT_BUTTON.EMPTY_CREW)

    unitsArray = sortUnitsList(unitsArray)
    unitsList.extend(unitsArray)
    unitsList.append(SEL_UNIT_BUTTON.SHOW_MORE)

    return needEmptyCrewButton
  }

  function sortUnitsList(units)
  {
    local ediff = getCurrentEdiff()
    local trained = ::getTblValue("trainedSpec", crew, {})
    local getSortSpecialization = @(unit) unit.name in trained ? trained[unit.name]
                                          : unit.trainCost ? -1
                                          : 0

    local unitsSortArr = units.map(@(unit)
      {
        economicRank = unit.getEconomicRank(ediff)
        isDefaultAircraft = ::is_default_aircraft(unit.name)
        sortSpecialization = getSortSpecialization(unit)
        unit = unit
      }
    )

    unitsSortArr.sort(@(a, b)
         a.economicRank <=> b.economicRank
      || b.isDefaultAircraft <=> a.isDefaultAircraft
      || a.sortSpecialization <=> b.sortSpecialization
      || a.unit.rank <=> b.unit.rank
      || a.unit.name <=> b.unit.name
    )

    return unitsSortArr.map(@(unit) unit.unit)
  }

  function addLegendData(id, imagePath, locId)
  {
    foreach(data in legendData)
      if (id == data.id)
        return

    legendData.append({
      id = id,
      imagePath = imagePath,
      locId = locId
    })
  }

  function haveMoreQualifiedCrew(unit)
  {
    local bestIdx = ::g_crew.getBestTrainedCrewIdxForUnit(unit, false, crew)
    return bestIdx >= 0 && bestIdx != crew.idInCountry
  }

  getTextSlotMarkup = @(id, text) ::build_aircraft_item(id, null, { emptyText = text })

  function fillUnitsList()
  {
    local data = ""
    totalUsableUnits = 0
    foreach(idx, unit in unitsList)
    {
      local rowData = "td {}"
      if (!::u.isInteger(unit))
        totalUsableUnits++
      else if (unit == SEL_UNIT_BUTTON.SHOP)
        rowData = getTextSlotMarkup("shop_item", "#mainmenu/btnShop")
      else if (unit == SEL_UNIT_BUTTON.EMPTY_CREW)
        rowData = getTextSlotMarkup("empty_air", "#shop/emptyCrew")
      else if (unit == SEL_UNIT_BUTTON.SHOW_MORE)
        rowData = getTextSlotMarkup("show_more", "#mainmenu/showMore")
      data += "tr { " +rowData+ " }\n"
    }

    local tblObj = scene.findObject("airs_table")
    tblObj.alwaysShowBorder = "yes"
    guiScene.replaceContentFromText(tblObj, data, data.len(), this)

    showMoreObj = tblObj.findObject("td_show_more")
  }

  function onEmptyCrew()
  {
    trainSlotAircraft(null)
  }

  function onDoneSlotChoose(obj)
  {
    local row = ::to_integer_safe(obj.cur_row, -1)
    if (row < 0)
      return

    local unit = unitsList[row]
    if (unit == SEL_UNIT_BUTTON.SHOP)
      return goToShop()
    if (unit == SEL_UNIT_BUTTON.EMPTY_CREW)
      return trainSlotAircraft(null) //empty slot
    if (unit == SEL_UNIT_BUTTON.SHOW_MORE)
    {
      curVisibleSlots += slotsPerPage - 1 //need to all new slots be visible and current button also
      updateUnitsList()
      return
    }

    if (::g_crew.getCrewUnit(crew) == unit)
      return goBack()

    if (haveMoreQualifiedCrew(unit))
      return ::gui_start_selecting_crew({
          unit = unit,
          unitObj = scene.findObject(unit.name),
          takeCrewIdInCountry = crew.idInCountry,
          messageText = ::loc("mainmenu/selectCrew/haveMoreQualified"),
          afterSuccessFunc = ::Callback(goBack, this)
        })

    trainSlotAircraft(unit)
  }

  function goToShop()
  {
    goBack()
    if (slotbarWeak?.ownerWeak?.openShop)
    {
      local unit = ::g_crew.getCrewUnit(crew)
      slotbarWeak.ownerWeak.openShop(unit?.unitType)
    }
  }

  function trainSlotAircraft(unit)
  {
    ::CrewTakeUnitProcess(crew, unit, ::Callback(onTakeProcessFinish, this))
  }

  function onTakeProcessFinish(isSuccess)
  {
    goBack()
  }

  function initChooseUnitsOptions()
  {
    curOptionsMasks.clear()
    optionsMaskByUnits.clear()

    local trained = ::getTblValue("trainedSpec", crew, {})
    foreach(unit in unitsList)
    {
      if (!::u.isUnit(unit))
        continue

      local masks = []
      masks.append( 1 << unit.esUnitType )
      masks.append( 1 << (unit.rank - 1) )
      masks.append( (unit.name in trained ? 0 : unit.trainCost) ? 2 : 1 )
      masks.append( ::is_unit_enabled_for_slotbar(unit, config) ? 2 : 1 )
      masks.append( ::isUnitInCustomList(unit, config) ? 2 : 1 )

      optionsMaskByUnits[unit.name] <- masks
      for (local i = 0; i < masks.len(); i++)
        if (curOptionsMasks.len() > i)
          curOptionsMasks[i] = curOptionsMasks[i] | masks[i]
        else
          curOptionsMasks.append(masks[i])
    }
  }

  function fillChooseUnitsOptions()
  {
    local locParams = {
      gameModeName = ::colorize("hotkeyColor", getGameModeNameFromParams(config))
      customListName = ::colorize("hotkeyColor", getCustomListNameFromParams(config))
    }

    local objOptionsNest = scene.findObject("choose_options_nest")
    if ( !::checkObj(objOptionsNest) )
      return

    isEmptyOptionsList = true
    local view = { rows = [] }
    foreach (idx, userOpt in filterOptionsList)
    {
      local maskOption = ::get_option(userOpt)
      local singleOption = ::getTblValue("singleOption", maskOption, false)
      if (singleOption)
      {
        // All bits but first are set to 1.
        maskOption.value = maskOption.value | ~1
        ::set_option(userOpt, maskOption.value)
      }
      local maskStorage = getTblValue(idx, curOptionsMasks, 0)
      if ((maskOption.value & maskStorage) == 0)
      {
        maskOption.value = maskStorage
        ::set_option(userOpt, maskOption.value)
      }
      local hideTitle = ::getTblValue("hideTitle", maskOption, false)
      local row = {
        option_title = hideTitle ? "" : ::loc( maskOption.hint )
        option_id = maskOption.id
        option_idx = idx
        option_uid = userOpt
        option_value = maskOption.value
        nums = []
      }
      row.cb <- maskOption?.cb

      local countVisibleOptions = 0
      foreach (idxItem, text in maskOption.items)
      {
        local optionVisible = ( (1 << idxItem) & maskStorage ) != 0
        if (optionVisible)
          countVisibleOptions++
        local name = text
        if (::g_string.startsWith(name, "#"))
          name = name.slice(1)
        name = ::loc(name, locParams)
        row.nums.append({
          option_name = name,
          visible = optionVisible && (!singleOption || idxItem == 0)
        })
      }
      if (countVisibleOptions > 1 || singleOption)
        view.rows.append(row)
      if (countVisibleOptions > 1)
        isEmptyOptionsList = false
    }

    local markup = ::handyman.renderCached(("gui/slotbar/choose_units_filter"), view)
    guiScene.replaceContentFromText(objOptionsNest, markup, markup.len(), this)

    objOptionsNest.show(!isEmptyOptionsList)
    scene.findObject("choose_options_header").show( !isEmptyOptionsList)

    fillLegend()

    local objChoosePopupMenu = scene.findObject("choose_popup_menu")
    if ( !::checkObj(objChoosePopupMenu) )
      return

    objChoosePopupMenu.findObject("choose_options_nest")
    guiScene.setUpdatesEnabled(true, true)

    local sizeChoosePopupMenu = objChoosePopupMenu.getSize()
    local scrWidth = ::screen_width()
    objChoosePopupMenu.side = ((objChoosePopupMenu.getPosRC()[0] + sizeChoosePopupMenu[0]) > scrWidth) ? "left" : "right"
  }

  function getGameModeNameFromParams(params)
  {
    //same order as in is_unit_enabled_for_slotbar
    local event = ::events.getEvent(params?.eventId)
    if (!event && params?.roomCreationContext)
      event = params.roomCreationContext.mGameMode
    if (event)
      return ::events.getEventNameText(event)

    if (params?.gameModeName)
      return params.gameModeName

    if (::SessionLobby.isInRoom())
      return ::SessionLobby.getMissionNameLoc()

    return ::getTblValue("text", ::game_mode_manager.getCurrentGameMode(), "")
  }

  function getCustomListNameFromParams(params)
  {
    return params?.customUnitsListName ?? ""
  }

  function getCurrentEdiff()
  {
    if (config?.getEdiffFunc)
      return config.getEdiffFunc()
    if (slotbarWeak)
      return slotbarWeak.getCurrentEdiff()
    return ::get_current_ediff()
  }

  function onSelectedOptionChooseUnsapportedUnit(obj)
  {
    onSelectedOptionChooseUnit(obj)
    updateOptionShowUnsupportedForCustomList()
  }

  function onSelectedOptionChooseUnit(obj)
  {
    if (!checkObj(obj) || !obj.idx)
      return

    local maskOptions = getTblValue(obj.idx.tointeger(), curOptionsMasks, null)
    if (!maskOptions)
      return

    local oldOption = ::get_option((obj.uid).tointeger())
    local value = (oldOption.value.tointeger() & (~maskOptions)) | (obj.getValue() & maskOptions)
    ::set_option((obj.uid).tointeger(), value)
    curVisibleSlots = firstPageSlots
    updateUnitsList()
  }

  function updateOptionShowUnsupportedForCustomList()
  {
    local modeOption = ::get_option(::USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_GAME_MODE)
    local customOption = ::get_option(::USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_CUSTOM_LIST)

    local customOptionObj = scene.findObject(customOption.id)
    if (!::check_obj(customOptionObj))
      return

    local isModeOptionChecked = modeOption.value & 1
    if (!isModeOptionChecked)
    {
      local idx = filterOptionsList.find(::USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_GAME_MODE)
      local maskOptions = curOptionsMasks?[idx]
      if (maskOptions)
        customOptionObj.setValue(modeOption.value - (modeOption.value & (~maskOptions)))
    }
    customOptionObj.show(isModeOptionChecked)
  }

  function showUnitSlot(objSlot, unit, isVisible)
  {
    objSlot.show(isVisible)
    objSlot.inactive = isVisible ? "no" : "yes"
    if (!isVisible || objSlot.childrenCount())
      return

    local isTrained = (unit.name in crew?.trainedSpec) || unit.trainCost == 0
    local isEnabled = ::is_unit_enabled_for_slotbar(unit, config)

    local unitItemParams = {
      status = !isEnabled ? "disabled"
        : isTrained ? "mounted"
        : "canBuy"
      showWarningIcon = haveMoreQualifiedCrew(unit)
      showBR = ::has_feature("SlotbarShowBattleRating")
      getEdiffFunc = getCurrentEdiff.bindenv(this)
      fullBlock = false
    }

    if (!isTrained)
      unitItemParams.overlayPrice <- unit.trainCost

    local specType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unit)
    if (specType != ::g_crew_spec_type.UNKNOWN)
      unitItemParams.specType <- specType

    local id = unit.name
    local markup = ::build_aircraft_item(id, unit, unitItemParams)
    guiScene.replaceContentFromText(objSlot, markup, markup.len(), this)
    ::fill_unit_item_timers(objSlot.findObject(id), unit, unitItemParams)
  }

  function updateUnitsList()
  {
    if (!::checkObj(scene))
      return

    guiScene.setUpdatesEnabled(false, false)
    local optionMasks = []
    foreach (userOpt in filterOptionsList)
      optionMasks.append(::get_option(userOpt).value)

    local tblObj = scene.findObject("airs_table")
    local total = tblObj.childrenCount()
    local lenghtOptions = optionMasks.len()
    local selected = 0
    local crewUnitId = ::getTblValue("aircraft", crew, "")

    local visibleAmount = 0
    local isFirstPage = curVisibleSlots == firstPageSlots
    local firstHiddenUnit = null
    local firstHiddenUnitObj = null
    local needShowMoreButton = false

    for (local i = 0; i < total; i++)
    {
      local objSlot = tblObj.getChild(i).getChild(0)
      if (!objSlot)
        continue
      local unit = unitsList?[i]
      if (!::u.isUnit(unit))
        continue

      local masksUnit = optionsMaskByUnits?[unit.name]
      local isVisible = true
      if (masksUnit)
        for (local i = 0; i < lenghtOptions; i++)
          if ( (masksUnit[i] & optionMasks[i]) == 0 )
            isVisible = false

      if (isVisible)
      {
        isVisible = ++visibleAmount <= curVisibleSlots
        if (!isVisible)
          if (visibleAmount == curVisibleSlots)
          {
            firstHiddenUnit = unit
            firstHiddenUnitObj = objSlot
          } else
            needShowMoreButton = true
      }

      showUnitSlot(objSlot, unit, isVisible)

      if (isVisible
        && (!isFirstPage || unit.name == crewUnitId || !selected)) //on not first page always select last visible unit
        selected = i
    }

    if (!needShowMoreButton && firstHiddenUnit)
      showUnitSlot(firstHiddenUnitObj, firstHiddenUnit, true)
    if (showMoreObj)
    {
      showMoreObj.show(needShowMoreButton)
      showMoreObj.inactive = needShowMoreButton ? "no" : "yes"
      if (!isFirstPage && needShowMoreButton)
        selected = total - 1
    }

    scene.findObject("filtered_units_text").setValue(
      ::loc("mainmenu/filteredUnits", {
        total = totalUsableUnits
        filtered = ::colorize("activeTextColor", visibleAmount)
      }))

    guiScene.setUpdatesEnabled(true, true)
    if (selected != 0)
      ::gui_bhv.columnNavigator.selectCell(tblObj, selected, 0, false, false, false)
  }

  function canFocusOptions()
  {
    return !isEmptyOptionsList
  }

  function setFocus(needFocusUnitsList)
  {
    isFocusOnUnitsList = !canFocusOptions() || needFocusUnitsList
    local objId = isFocusOnUnitsList ? "airs_table" : "choose_options_nest"
    scene.findObject(objId).select()
    updateOptionsHint()
  }

  function onToggleChooseOptions()
  {
    if (canFocusOptions())
      setFocus(!isFocusOnUnitsList)
  }

  function updateOptionsHint()
  {
    local show = canFocusOptions() && ::show_console_buttons
    local obj = showSceneBtn("filter_options_hint", show)
    if (show)
    {
      local hintId = isFocusOnUnitsList ? "filter_option/change_filter_options" : "filter_option/return_to_units_list"
      obj.setValue(::loc(hintId))
    }
  }

  function onSlotChooseLeft(obj)  { onSlotChooseSideAir(-1) }
  function onSlotChooseRight(obj) { onSlotChooseSideAir(1) }

  function onSlotChooseSideAir(dir)
  {
    wasReinited = false
    if (slotbarWeak)
      slotbarWeak.nextSlot(dir)
    if (!wasReinited)
      goBack()
  }

  function onEventSetInQueue(params)
  {
    goBack()
  }
}
