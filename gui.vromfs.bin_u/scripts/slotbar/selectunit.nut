::filter_options_list <- [
  ::USEROPT_BIT_CHOOSE_UNITS_TYPE,
  ::USEROPT_BIT_CHOOSE_UNITS_RANK,
  ::USEROPT_BIT_CHOOSE_UNITS_OTHER,
  ::USEROPT_BIT_CHOOSE_UNITS_SHOW_UNSUPPORTED_FOR_GAME_MODE
]

::filter_options_mask_storage <- []
::options_filter_choose_units <- {
  maskUnits = {},
  legendData = [], //format: {id = "..{id}..", imagePath = "..{fullPath}..", locId = "..{locId}.." }
  isEmptyOptionsList = true
}

const MIN_NON_EMPTY_SLOTS_IN_COUNTRY = 1

function gui_start_select_unit(countryId, idInCountry, handler, config = null)
{
  if (!::SessionLobby.canChangeCrewUnits())
    return
  if (!::CrewTakeUnitProcess.safeInterrupt())
    return

  local slotbarObj = ::get_slotbar_obj(handler, handler.slotbarScene)
  local slotObj = ::get_slot_obj(slotbarObj, countryId, idInCountry)
  if (!::checkObj(slotObj))
  {
    handler.guiScene.performDelayed(handler, function() {
      ::reinitAllSlotbars()
    })
    return
  }

  local crew = ::getSlotItem(countryId, idInCountry)
  if (!crew)
    return

  local params = {
    countryId = countryId,
    idInCountry = idInCountry,
    config = config || {},
    slotObj = slotObj,
    ownerWeak = handler,
    crew = crew
  }
  ::handlersManager.destroyPrevHandlerAndLoadNew(::gui_handlers.SelectUnit, params)
}

class ::gui_handlers.SelectUnit extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/slotbar/slotbarChooseAircraft.blk"
  ownerWeak = null

  countryId = -1
  idInCountry = -1
  crew = null

  config = null //same as slotbarParams in BaseGuiHandlerWT
  slotObj = null

  unitsList = null
  isFocusOnUnitsList = true

  wasReinited = false

  function initScreen()
  {
    guiScene.applyPendingChanges(false) //to apply slotbar scroll before calculating positions

    if (ownerWeak)
      ownerWeak = ownerWeak.weakref() //we are miss weakref on assigning from params table

    local tdObj = slotObj.getParent()
    local tdPos = tdObj.getPosRC()

    ::gui_handlers.ActionsList.removeActionsListFromObject(tdObj)

    local tdClone = tdObj.getClone(scene, this)
    tdClone.pos = tdPos[0] + ", " + tdPos[1]
    tdClone["class"] = "slotbarClone"

    local curUnitCloneObj = ::get_slot_obj(tdClone, countryId, idInCountry)
    local crewUnitId = ::getTblValue("aircraft", crew, "")
     ::fill_unit_item_timers(curUnitCloneObj, ::getAircraftByName(crewUnitId))
    ::gui_handlers.ActionsList.switchActionsListVisibility(curUnitCloneObj)

    scene.findObject("tablePlace").pos = tdPos[0] + ", " + tdPos[1]

    local needEmptyCrewButton = initAvailableUnitsArray()
    if (unitsList.len() == 0)
      return goBack()

    showSceneBtn("btn_emptyCrew", needEmptyCrewButton)
    fillLegendData()
    fillUnitsList()
  }

  function reinitScreen(params = {})
  {
    setParams(params)
    initScreen()
    wasReinited = true
  }

  function fillLegendData()
  {
    ::options_filter_choose_units.legendData = []
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
      haveLegend = ::options_filter_choose_units.legendData.len() > 0,
      legendData = ::options_filter_choose_units.legendData
    }
    local markup = ::handyman.renderCached("gui/slotbar/legend_block", legendView)
    guiScene.replaceContentFromText(legendNest, markup, markup.len(), this)
  }

  function getUsingUnitsArray()
  {
    local array = []
    foreach(idx, crew in ::crews_list[countryId].crews)
      if (idx != idInCountry && ("aircraft" in crew))
        array.append(crew.aircraft)

    return array
  }

  function initAvailableUnitsArray()
  {
    local country = ::crews_list[countryId].country
    local busyUnits = getUsingUnitsArray()

    local unitsArray = []
    foreach(unit in ::all_units)
      if (!::isInArray(unit.name, busyUnits)
           && ::getUnitCountry(unit) == country
           && unit.isUsable()
           && ::is_unit_visible_in_shop(unit)
           && (!::isTank(unit) || ::check_feature_tanks())
         )
         unitsArray.append(unit)


    unitsList = []

    if (ownerWeak && "canShowShop" in ownerWeak && ownerWeak.canShowShop())
      unitsList.append(null)

    local needEmptyCrewButton = ("aircraft" in crew && busyUnits.len() >= MIN_NON_EMPTY_SLOTS_IN_COUNTRY)
    if (needEmptyCrewButton)
      unitsList.append("") //empty crew

    unitsList.extend(unitsArray)
    sortUnitsList(unitsList)

    return needEmptyCrewButton
  }

  function sortUnitsList(units)
  {
    local ediff = getCurrentEdiff()
    local trained = ::getTblValue("trainedSpec", crew, {})
    local getSortSpecialization = @(unit) unit.name in trained ? trained[unit.name]
                                          : unit.trainCost ? -1
                                          : 0
    units.sort(function(a, b)
    {
      if (!a || !b)
        return a <=> b
      if (!::u.isTable(a) || !::u.isTable(b))
        return ::u.isTable(a) <=> ::u.isTable(b)

      return (::get_unit_economic_rank_by_ediff(ediff, a)
            <=> ::get_unit_economic_rank_by_ediff(ediff, b))
        || ::is_default_aircraft(b.name) <=> ::is_default_aircraft(a.name)
        || getSortSpecialization(a) <=> getSortSpecialization(b)
        || a.rank <=> b.rank
        || a.name <=> b.name
    })
  }

  function resetFilterData()
  {
    ::filter_options_mask_storage = []
    ::options_filter_choose_units.maskUnits = {}
  }

  function addLegendData(id, imagePath, locId)
  {
    foreach(data in ::options_filter_choose_units.legendData)
      if (id == data.id)
        return

    ::options_filter_choose_units.legendData.append({
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

  function fillUnitsList()
  {
    local data = ""
    local selected = 0
    local crewUnitId = ::getTblValue("aircraft", crew, "")
    local trained = ::getTblValue("trainedSpec", crew, {})
    local unitItems = []

    resetFilterData()

    foreach(idx, unit in unitsList)
    {
      local rowData = ""
      if (!unit)
        rowData = ::build_aircraft_item("shop_item", null, { emptyText = "#mainmenu/btnShop" })
      else if (::u.isString(unit))
        rowData = ::build_aircraft_item("empty_air", null, { emptyText = "#shop/emptyCrew" })
      else
      {
        local disabled = !::is_unit_enabled_for_slotbar(unit, config)
        local price = ::Cost(unit.name in trained? 0 : unit.trainCost)

        local craftItemParams = {
          status = disabled ? "disabled" : (price.isZero() ? "mounted" : "canBuy")
          showWarningIcon = haveMoreQualifiedCrew(unit)
          showBR = ::has_feature("SlotbarShowBattleRating")
          getEdiffFunc = getCurrentEdiff.bindenv(this)
        }

        if (!price.isZero())
          craftItemParams.overlayPrice <- price.wp

        local specType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unit)
        if (specType != ::g_crew_spec_type.UNKNOWN)
          craftItemParams.specType <- specType

        rowData = ::build_aircraft_item(unit.name, unit, craftItemParams)
        unitItems.append({ id = unit.name, unit = unit, params = craftItemParams })
        if (unit.name == crewUnitId)
          selected = idx

        local air = ::getAircraftByName(unit.name)
        local masks = []
        masks.append( 1 << ::get_es_unit_type(air) )
        masks.append( 1 << (air.rank - 1) )
        masks.append( price.isZero() ? 1 : 2 )
        masks.append( disabled ? 1 : 2 )

        ::options_filter_choose_units.maskUnits[air.name] <- masks
        for (local i = 0; i < masks.len(); i++)
          if (::filter_options_mask_storage.len() > i)
            ::filter_options_mask_storage[i] = ::filter_options_mask_storage[i] | masks[i]
          else
            ::filter_options_mask_storage.append(masks[i])
      }
      data += "tr { " +rowData+ " }\n"
    }

    local tblObj = scene.findObject("airs_table")
    tblObj.alwaysShowBorder = "yes"
    guiScene.replaceContentFromText(tblObj, data, data.len(), this)
    foreach (unitItem in unitItems)
      ::fill_unit_item_timers(tblObj.findObject(unitItem.id), unitItem.unit, unitItem.params)

    initChooseUnitsOptions()
    if (selected!=0)
      ::gui_bhv.columnNavigator.selectCell(tblObj, selected, 0, false, false, false)
    setFocus(true)
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
    if (!unit) //valid null element
      return goToShop()

    if (::u.isString(unit))
      return trainSlotAircraft(null) //empty slot

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
    ::broadcastEvent("OpenShop", {unitType = "aircraft" in crew ?
                                    ::get_es_unit_type(::getAircraftByName(crew.aircraft))
                                    : null})
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
    local locParams = {
      gameModeName = ::colorize("hotkeyColor", getGameModeNameFromParams(config))
    }

    local objOptionsNest = scene.findObject("choose_options_nest")
    if ( !::checkObj(objOptionsNest) )
      return

    local view = {
      rows = (@(locParams) function() {
        local res = []
        ::options_filter_choose_units.isEmptyOptionsList = true
        foreach (idx, userOpt in ::filter_options_list)
        {
          local maskOption = ::get_option(userOpt)
          local singleOption = ::getTblValue("singleOption", maskOption, false)
          if (singleOption)
          {
            // All bits but first are set to 1.
            maskOption.value = maskOption.value | ~1
            ::set_option(userOpt, maskOption.value)
          }
          local maskStorage = getTblValue(idx, ::filter_options_mask_storage, 0)
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
            res.append(row)
          if (countVisibleOptions > 1)
            ::options_filter_choose_units.isEmptyOptionsList = false
        }
        return res
      })(locParams)
    }
    local markup = ::handyman.renderCached(("gui/slotbar/choose_units_filter"), view)
    guiScene.replaceContentFromText(objOptionsNest, markup, markup.len(), this)

    objOptionsNest.show(!::options_filter_choose_units.isEmptyOptionsList)
    scene.findObject("choose_options_header").show( !::options_filter_choose_units.isEmptyOptionsList)

    fillLegend()

    local objChoosePopupMenu = scene.findObject("choose_popup_menu")
    if ( !::checkObj(objChoosePopupMenu) )
      return

    objChoosePopupMenu.findObject("choose_options_nest")
    guiScene.setUpdatesEnabled(true, true)

    local sizeChoosePopupMenu = objChoosePopupMenu.getSize()
    local scrWidth = ::screen_width()
    objChoosePopupMenu.side = ((objChoosePopupMenu.getPosRC()[0] + sizeChoosePopupMenu[0]) > scrWidth) ? "left" : "right"

    updateCrewUnitsList()
  }

  function getGameModeNameFromParams(params)
  {
    //same order as in is_unit_enabled_for_slotbar
    local eventId = ::getTblValue("eventId", params, null)
    local event = eventId && ::events.getEvent(eventId)
    if (!event && "roomCreationContext" in params)
      event = params.roomCreationContext.mGameMode
    if (event)
      return ::events.getEventNameText(event)

    if ("gameModeName" in params)
      return params.gameModeName

    if (::SessionLobby.isInRoom())
      return ::SessionLobby.getMissionNameLoc()

    return ::getTblValue("text", ::game_mode_manager.getCurrentGameMode(), "")
  }

  function getCurrentEdiff()
  {
    if ("getEdiffFunc" in config)
      return config.getEdiffFunc()
    if (ownerWeak)
      return ownerWeak.getCurrentEdiff()
    return ::get_current_ediff()
  }

  function onSelectedOptionChooseUnit(obj)
  {
    if (!checkObj(obj) || !obj.idx)
      return

    local maskOptions = getTblValue(obj.idx.tointeger(), ::filter_options_mask_storage, null)
    if (!maskOptions)
      return

    local oldOption = ::get_option((obj.uid).tointeger())
    local value = (oldOption.value.tointeger() & (~maskOptions)) + obj.getValue()
    ::set_option((obj.uid).tointeger(), value)
    updateCrewUnitsList()
  }

  function updateCrewUnitsList()
  {
    if (!::checkObj(scene))
      return

    local optionMasks = []
    foreach (userOpt in ::filter_options_list)
      optionMasks.append(::get_option(userOpt).value)

    local tblObj = scene.findObject("airs_table")
    local total = tblObj.childrenCount()
    local lenghtOptions = optionMasks.len()
    for (local i = 0; i < total; i++)
    {
      local objSlot = tblObj.getChild(i).getChild(0)
      if ( !objSlot && objSlot.id )
        continue
      local masksUnit = null
      local nameUnit = objSlot.id.slice(3)
      if (nameUnit in ::options_filter_choose_units.maskUnits)
        masksUnit = ::options_filter_choose_units.maskUnits[ nameUnit ]
      local visible = true
      if (masksUnit)
        for (local i = 0; i < lenghtOptions; i++)
          if ( (masksUnit[i]&optionMasks[i]) == 0 )
            visible = false
      objSlot.show(visible)
      objSlot.inactive = (visible ? "no" : "yes")
    }
  }

  function canFocusOptions()
  {
    return !::options_filter_choose_units.isEmptyOptionsList
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
    if (ownerWeak)
      ::nextSlotbarAir(ownerWeak.slotbarScene, countryId, dir)
    if (!wasReinited)
      goBack()
  }

  function onEventSetInQueue(params)
  {
    goBack()
  }
}
