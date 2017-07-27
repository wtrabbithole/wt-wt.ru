class ::gui_handlers.WwAirfieldFlyOut extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/emptySceneWithGamercard.blk"
  sceneTplName = "gui/worldWar/airfieldFlyOut"

  position = null //receives as Point2()
  armyTargetName = null
  onSuccessfullFlyoutCb = null

  airfield = null

  accessList = null
  unitsList = null

  availableArmiesArray = null

  sendButtonObj = null
  selectedGroupIdx = null
  isMaxChosen = false
  isMaxUniqueUnitsChosen = false
  hasUnitsToFly = false

  static function open(index, position, armyTargetName, onSuccessfullFlyoutCb = null)
  {
    local airfield = ::g_world_war.getAirfieldByIndex(index)
    local availableArmiesArray = ::u.filter(
      airfield.formations,
      function (formation)
      {
        return formation.hasManageAccess()
      }
    )

    if (!availableArmiesArray.len())
      return
    ::handlersManager.loadHandler(
      ::gui_handlers.WwAirfieldFlyOut,
      {
        airfield = airfield,
        availableArmiesArray = availableArmiesArray
        position = position,
        armyTargetName = armyTargetName,
        onSuccessfullFlyoutCb = onSuccessfullFlyoutCb
      }
    )
  }

  function getSceneTplContainerObj() { return scene.findObject("root-box") }

  function getSceneTplView()
  {
    accessList = ::g_world_war.getMyAccessLevelListForCurrentBattle()

    return {
      unitString = getUnitsList()
      headerTabs = getHeaderTabs()
    }
  }

  function getUnitsList()
  {
    local flightTimeFactor = ::g_world_war.getWWConfigurableValue("maxFlightTimeMinutesMul", 1.0)

    unitsList = []
    foreach (airfieldFormation in availableArmiesArray)
      foreach (unit in airfieldFormation.units)
      {
        local maxFlyTime = (unit.getMaxFlyTime() * flightTimeFactor).tointeger()
        local value = 0
        local maxValue = unit.count
        unitsList.append({
          armyGroupIdx = airfieldFormation.getArmyGroupIdx()
          unitName = unit.name
          unitItem = unit.getItemMarkUp(true)
          maxValue = min(airfield.createArmyUnitCountMax, maxValue)
          totalValue = maxValue
          value = value
          maxFlyTime = maxFlyTime
          maxFlyTimeText = getFlyTimeText(maxFlyTime)
          unitWeapon = ::g_world_war.get_last_weapon_preset(unit.name)
          btnOnDec = "onButtonDec"
          btnOnInc = "onButtonInc"
          btnOnMax = "onButtonMax"
          onChangeSliderValue = "onChangeSliderValue"
          needOldSlider = true
          needNewSlider = true
          sliderButton = {
            type = "various"
            showWhenSelected = true
            sliderButtonText = getSliderButtonText(
              value, maxValue)
          }
        })
      }

    return unitsList
  }

  function getFlyTimeText(timeInSeconds)
  {
    return ::hoursToString(::seconds_to_hours(timeInSeconds), false, true) + " " + ::loc("icon/timer")
  }

  function getHeaderTabs()
  {
    local view = { tabs = [] }
    local selectedId = 0
    foreach (idx, airfieldFormation in availableArmiesArray)
    {
      view.tabs.append({
        tabName = airfieldFormation.getClanTag()
        navImagesText = ::get_navigation_images_text(idx, airfield.formations.len())
        selected = false
      })
    }
    if (view.tabs.len() > 0)
      view.tabs[selectedId].selected = true

    return ::handyman.renderCached("gui/frameHeaderTabs", view)
  }

  function getNavbarTplView()
  {
    return {
      right = [
        {
          id = "cant_send_reason"
          textField = true
        },
        {
          id = "send_aircrafts_button"
          funcName = "sendAircrafts"
          text = "#mainmenu/btnSend"
          isToBattle = true
          titleButtonFont = false
          shortcut = "A"
          button = true
          type = "wwArmyFlyOut"
        },
      ]
    }
  }

  function initScreen()
  {
    sendButtonObj = scene.findObject("send_aircrafts_button")
    updateVisibleUnits()

    //--- After all units filled ---
    fillFlyOutDescription()
  }

  function onTabSelect(obj)
  {
    updateVisibleUnits(obj.getValue())
    fillFlyOutDescription()
  }

  function updateVisibleUnits(tabVal = -1)
  {
    if (!availableArmiesArray.len())
      return

    if (tabVal < 0)
    {
      local listObj = scene.findObject("armies_tabs")
      if (::checkObj(listObj))
        tabVal = listObj.getValue()
    }

    if (tabVal < 0)
      tabVal = 0

    selectedGroupIdx = ::getTblValue(tabVal, availableArmiesArray, availableArmiesArray[0]).getArmyGroupIdx()

    hasUnitsToFly = hasEnoughUnitsToFlyOut()
    foreach (idx, unitTable in unitsList)
    {
      local unitSliderObj = showSceneBtn(unitTable.unitName + "_" + unitTable.armyGroupIdx,
        unitTable.armyGroupIdx == selectedGroupIdx)
      setUnitSliderEnable(unitSliderObj, hasUnitsToFly, unitTable)
      fillUnitWeaponPreset(unitTable)
    }

    local selectedUnitsInfo = getSelectedUnitsInfo()
    setupSendButton(selectedUnitsInfo.unitsAmount)
    setupQuantityManageButtons(selectedUnitsInfo, true)
  }

  function setUnitSliderEnable(unitSliderObj, isEnabled, unitTable)
  {
    foreach (buttonId in ["btn_max", "btn_inc", "btn_dec"])
    {
      local buttonObj = unitSliderObj.findObject(buttonId)
      if (!::checkObj(buttonObj))
        return

      if (buttonId != "btn_dec")
        buttonObj.enable(isEnabled)
      else
        buttonObj.enable(isEnabled && unitTable.value > 0)
    }
    unitSliderObj.enable(isEnabled)
  }

  function onChangeSliderValue(sliderObj)
  {
    local value = sliderObj.getValue()
    local unitIndex = getUnitIndex(sliderObj)
    if (unitIndex < 0)
      return

    updateUnitValue(unitIndex, value)
  }

  function getSelectedUnitsInfo()
  {
    local unitsAmount = 0
    local uniqueTypes = {}
    foreach (units in unitsList)
      if (units.armyGroupIdx == selectedGroupIdx)
      {
        unitsAmount += units.value
        if (units.value > 0)
          uniqueTypes[units.unitName] <- true
      }

    return {
      unitsAmount = unitsAmount
      uniqueTypes = uniqueTypes
    }
  }

  function setupSendButton(unitsQty)
  {
    if (!::checkObj(sendButtonObj))
      return

    local min = airfield.createArmyUnitCountMin
    local max = airfield.createArmyUnitCountMax
    local enable = min <= unitsQty && unitsQty <= max
    sendButtonObj.enable(enable)

    local cantSendText = ""
    if (hasUnitsToFly)
    {
      if (min > unitsQty)
        cantSendText = ::loc("worldwar/airfield/min_units_to_send", { min = min })
      else if (max < unitsQty)
        cantSendText = ::loc("worldwar/airfield/max_units_to_send", { max = max })
      else
        cantSendText = getSelectedUnitsFlyTimeText(selectedGroupIdx)
    }

    local cantSendTextObj = scene.findObject("cant_send_reason")
    if (::checkObj(cantSendTextObj))
      cantSendTextObj.setValue(cantSendText)
  }

  function fillFlyOutDescription()
  {
    local topTextObj = scene.findObject("unit_blocks_place_text")
    if (!::checkObj(topTextObj))
      return

    local totalCountText = airfield.createArmyUnitCountMin != airfield.createArmyUnitCountMax ?
        airfield.createArmyUnitCountMin + ::loc("ui/mdash") + airfield.createArmyUnitCountMax
      : airfield.createArmyUnitCountMax.tostring()
    totalCountText = ::colorize("activeTextColor", totalCountText)

    local texts = [
      ::loc("worldwar/airfield/unit_limits", { units = totalCountText })
      ::loc("worldwar/airfield/unit_various_limit", { types = airfield.maxUniqueUnitsOnFlyout })
    ]
    if (!hasUnitsToFly)
      texts.insert(0, ::colorize("warningTextColor", ::loc("worldwar/airfield/not_enough_units_to_send")))

    topTextObj.setValue(::implode(texts, "\n"))
  }

  function hasEnoughUnitsToFlyOut()
  {
    if (!unitsList.len())
      return false

    local unitsQuantity = 0
    foreach (unit in unitsList)
      if (unit.armyGroupIdx == selectedGroupIdx)
        unitsQuantity += unit.maxValue

    return unitsQuantity >= airfield.createArmyUnitCountMin
  }

  function setupQuantityManageButtons(selectedUnitsInfo, forceConfigure = false)
  {
    local maxUniqueUnits = airfield.maxUniqueUnitsOnFlyout
    local wasMaxChosen = isMaxChosen
    local wasMaxUniqueUnitsChosen = isMaxUniqueUnitsChosen

    isMaxChosen = selectedUnitsInfo.unitsAmount >= airfield.createArmyUnitCountMax
    isMaxUniqueUnitsChosen = selectedUnitsInfo.uniqueTypes.len() >= maxUniqueUnits

    if (forceConfigure || wasMaxChosen != isMaxChosen ||
        wasMaxUniqueUnitsChosen != isMaxUniqueUnitsChosen)
      configureMaxUniqueUnitsChosen(selectedUnitsInfo)
  }

  function configureMaxUniqueUnitsChosen(params)
  {
    local blockObj = scene.findObject("unit_blocks_place")
    if (!::checkObj(blockObj))
      return

    foreach (unitTable in unitsList)
      if (unitTable.armyGroupIdx == selectedGroupIdx)
      {
        local unitSliderObj = blockObj.findObject(unitTable.unitName + "_" + unitTable.armyGroupIdx)
        if (!::checkObj(unitSliderObj))
          return

        local isEnabled = unitTable.unitName in params.uniqueTypes || !isMaxUniqueUnitsChosen
        setUnitSliderEnable(unitSliderObj, isEnabled, unitTable)

        if (isMaxChosen)
          foreach (buttonId in ["btn_max", "btn_inc"])
          {
            local buttonObj = unitSliderObj.findObject(buttonId)
            if (::checkObj(buttonObj))
              buttonObj.enable(!isMaxChosen)
          }
      }
  }

  function getUnitIndex(obj)
  {
    local blockObj = obj.getParent()
    local unitName = blockObj.unitName
    local armyGroupIdx = blockObj.armyGroupIdx.tointeger()
    return ::u.searchIndex(unitsList, (@(unitName, armyGroupIdx) function(table) {
        return table.unitName == unitName && table.armyGroupIdx == armyGroupIdx
      })(unitName, armyGroupIdx))
  }

  function updateUnitValue(unitIndex, value)
  {
    local curValue = ::clamp(value, 0, unitsList[unitIndex].maxValue)
    if (curValue == unitsList[unitIndex].value)
      return

    unitsList[unitIndex].value = value
    local selectedUnitsInfo = getSelectedUnitsInfo()
    local unitsQty = selectedUnitsInfo.unitsAmount
    local excess = max(unitsQty - airfield.createArmyUnitCountMax, 0)
    if (excess)
    {
      unitsList[unitIndex].value = value - excess
      unitsQty = airfield.createArmyUnitCountMax
    }

    updateSlider(unitsList[unitIndex])
    setupSendButton(unitsQty)
    setupQuantityManageButtons(selectedUnitsInfo)
  }

  function updateSlider(unitTable)
  {
    local blockObj = scene.findObject(unitTable.unitName + "_" + unitTable.armyGroupIdx)
    if (!::checkObj(blockObj))
      return

    local sliderObj = blockObj.findObject("progress_slider")
    local newProgressOb = sliderObj.findObject("new_progress")
    newProgressOb.setValue(unitTable.value)
    if (sliderObj.getValue() != unitTable.value)
      sliderObj.setValue(unitTable.value)

    local buttonObj = blockObj.findObject("btn_dec")
    if (::checkObj(buttonObj))
      buttonObj.enable(unitTable.value > 0)

    updateSliderText(sliderObj, unitTable)
  }

  function updateSliderText(sliderObj, unitTable)
  {
    local sliderTextObj = sliderObj.findObject("slider_button_text")
    if (::checkObj(sliderTextObj))
      sliderTextObj.setValue(getSliderButtonText(
        unitTable.value, unitTable.totalValue))
  }

  function getSliderButtonText(value, totalValue)
  {
    return ::format("%d/%d", value, totalValue)
  }

  function onButtonDec(obj)
  {
    onButtonChangeValue(obj, -1)
  }

  function onButtonInc(obj)
  {
    onButtonChangeValue(obj, 1)
  }

  function onButtonChangeValue(obj, diff)
  {
    local unitIndex = getUnitIndex(obj)
    if (unitIndex < 0)
      return

    local value = unitsList[unitIndex].value + diff
    updateUnitValue(unitIndex, value)
  }

  function onButtonMax(obj)
  {
    local unitIndex = getUnitIndex(obj)
    if (unitIndex < 0)
      return

    local value = unitsList[unitIndex].maxValue
    updateUnitValue(unitIndex, value)
  }

  function fillUnitWeaponPreset(unitTable)
  {
    local selectedWeaponName = unitTable.unitWeapon
    local unit = ::getAircraftByName(unitTable.unitName)
    local weapon = ::u.search(unit.weapons, (@(selectedWeaponName) function(weapon) {
        return weapon.name == selectedWeaponName
      })(selectedWeaponName))
    if (!weapon)
      return

    local blockObj = scene.findObject(unitTable.unitName + "_" + unitTable.armyGroupIdx)
    if (!::check_obj(blockObj))
      return
    local containerObj = blockObj.findObject("secondary_weapon")
    if (!::check_obj(containerObj))
      return

    local modItemObj = containerObj.findObject(unit.name)
    if (!::check_obj(modItemObj))
      modItemObj = ::weaponVisual.createItem(
        unit.name, weapon, weapon.type, containerObj, this, {
          useGenericTooltip = true
        })

    ::weaponVisual.updateItem(
      unit, weapon, modItemObj, false, this, {
        canShowStatusImage = false
        canShowResearch = false
        canShowPrice = false
        isForceHideAmount = true
        isForceUnlocked = true
        isForceEquipped = true
        useGenericTooltip = true
        hasMenu = true
      })
    modItemObj.pos = "0, 2"

    local centralBlockObj = modItemObj.findObject("centralBlock")
    if (::checkObj(centralBlockObj))
      centralBlockObj.unitName = unitTable.unitName
  }

  function onModItemClick(obj)
  {
    local unit = ::getAircraftByName(obj.unitName)
    local cb = ::Callback(function (unitName, weaponName)
    {
      changeUnitWeapon(unitName, weaponName)
    }, this)
    ::ww_gui_start_choose_unit_weapon(unit, cb, {
        canShowStatusImage = false
        canShowResearch = false
        canShowPrice = false
        isForceHideAmount = true
        isForceUnlocked = true
        isForceEquipped = true
        useGenericTooltip = true
      }, obj, "right")
  }

  function changeUnitWeapon(unitName, weaponName)
  {
    foreach (unitTable in unitsList)
      if (unitTable.armyGroupIdx == selectedGroupIdx && unitTable.unitName == unitName)
      {
        unitTable.unitWeapon = weaponName
        fillUnitWeaponPreset(unitTable)
        break
      }
  }

  function getAvailableGroup(armyGroupIdx)
  {
    local side = ::ww_get_player_side()
    return u.search(airfield.formations, (@(armyGroupIdx, side) function(group)
    {
      return group.owner.armyGroupIdx == armyGroupIdx
             && group.owner.side == side
    })(armyGroupIdx, side))
  }

  function getSelectedUnitsFlyTimeText(armyGroupIdx)
  {
    local minTime = 0
    foreach (idx, units in unitsList)
      if (units.armyGroupIdx == selectedGroupIdx && units.value > 0)
        minTime = minTime <= 0 ? units.maxFlyTime : min(minTime, units.maxFlyTime)

    return ::loc("worldwar/airfield/army_fly_time") + ::loc("ui/colon") + getFlyTimeText(minTime)
  }

  function sendAircrafts()
  {
    local listObj = scene.findObject("armies_tabs")
    if (!::checkObj(listObj))
      return

    local isAircraftsChoosen = false
    local armyGroupIdx = ::getTblValue(listObj.getValue(), availableArmiesArray, -1).getArmyGroupIdx()
    local units = {}
    foreach (idx, unitTable in unitsList)
      if (unitTable.armyGroupIdx == armyGroupIdx)
      {
        isAircraftsChoosen = isAircraftsChoosen || unitTable.value > 0
        units[unitTable.unitName] <- {
          count = unitTable.value
          weapon = unitTable.unitWeapon
        }
      }

    local errorLocId = ""
    if (!isAircraftsChoosen)
      errorLocId = "worldWar/error/noUnitChoosen"

    local group = getAvailableGroup(armyGroupIdx)
    if (!group || !::g_world_war.isGroupAvailable(group, accessList))
      errorLocId = "worldWar/error/uncontrollableArmyGroup"

    if (errorLocId != "")
    {
      ::g_popups.add("", ::loc(errorLocId), null, null, null, "WwFlyoutError")
      return
    }

    local cellIdx = ::ww_get_map_cell_by_coords(position.x, position.y)
    local taskId = ::g_world_war.moveSelectedAircraftsToCell(
      cellIdx, units, group.owner, armyTargetName)
    if (onSuccessfullFlyoutCb)
      ::add_bg_task_cb(taskId, onSuccessfullFlyoutCb)
    goBack()
  }
}
