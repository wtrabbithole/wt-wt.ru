local time = require("scripts/time.nut")


class ::gui_handlers.WwAirfieldFlyOut extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/emptySceneWithGamercard.blk"
  sceneTplName = "gui/worldWar/airfieldFlyOut"

  position = null //receives as Point2()
  armyTargetName = null
  onSuccessfullFlyoutCb = null

  airfield = null
  currentOperation = null

  accessList = null
  unitsList = null

  availableArmiesArray = null

  sendButtonObj = null
  selectedGroupIdx = null
  selectedGroupFlyArmies = 0
  isArmyComboValue = false

  maxChoosenUnitsMask = WW_UNIT_CLASS.NONE //bitMask

  hasUnitsToFly = false
  prevSelectedUnitsMask = WW_UNIT_CLASS.NONE

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
    currentOperation = ::g_operations.getCurrentOperation()

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
        local unitClass = unit.getUnitClass()
        local maxFlyTime = (unit.getMaxFlyTime() * flightTimeFactor).tointeger()
        local value = 0
        local maxValue = unit.count
        local maxUnitClassValue = getUnitClassMaxValue(unitClass)
        unitsList.append({
          unitClassText = null
          armyGroupIdx = airfieldFormation.getArmyGroupIdx()
          unitName = unit.name
          unitItem = unit.getItemMarkUp(true)
          unitClass = unitClass
          maxValue = ::min(maxUnitClassValue, maxValue)
          maxUnitClassValue = maxUnitClassValue
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

    unitsList.sort(
      function(a, b) {
        return (a.unitClass == WW_UNIT_CLASS.BOMBER) <=> (b.unitClass == WW_UNIT_CLASS.BOMBER)
               || a.totalValue <=> b.totalValue
      })

    local newClass = null
    foreach (idx, unitTable in unitsList)
    {
      if (newClass == unitTable.unitClass)
        continue

      newClass = unitTable.unitClass
      unitsList[idx].unitClassText = ::WwUnit.getUnitClassText(unitTable.unitClass)
    }

    return unitsList
  }

  function getFlyTimeText(timeInSeconds)
  {
    return time.hoursToString(time.secondsToHours(timeInSeconds), false, true) + " " + ::loc("icon/timer")
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
    fillArmyLimitDescription()
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
    selectedGroupFlyArmies = calcSelectedGroupAirArmiesNumber()

    hasUnitsToFly = hasEnoughUnitsToFlyOut()

    local selUnitsInfo = getSelectedUnitsInfo()
    foreach (idx, unitTable in unitsList)
    {
      local unitSliderObj = showSceneBtn(unitTable.unitName + "_" + unitTable.armyGroupIdx,
        unitTable.armyGroupIdx == selectedGroupIdx)

      setUnitSliderEnable(unitSliderObj, selUnitsInfo, unitTable)
      fillUnitWeaponPreset(unitTable)
    }

    setupSendButton()
  }

  function canSendToFlyMoreArmy()
  {
    return selectedGroupFlyArmies < currentOperation.getGroupAirArmiesLimit()
  }

  function calcSelectedGroupAirArmiesNumber()
  {
    local armyCount = ::g_operations.getAirArmiesNumberByGroupIdx(selectedGroupIdx)
    for (local idx = 0; idx < ::g_world_war.getAirfieldsCount(); idx++)
    {
      local airfield = ::g_world_war.getAirfieldByIndex(idx)
      armyCount += airfield.getCooldownArmiesNumberByGroupIdx(selectedGroupIdx)
    }

    return armyCount
  }

  function setUnitSliderEnable(unitSliderObj, selUnitsInfo, unitTable)
  {
    local unitsArray = getReqDataFromSelectedUnitsInfo(selUnitsInfo, unitTable.unitClass, "names", [])
    local isReachedMaxUnitsLimit = isMaxUnitsNumSet(selUnitsInfo)

    local isSetSomeUnits = ::isInArray(unitTable.unitName, unitsArray)

    local isEnabled = hasUnitsToFly
                      && (isSetSomeUnits
                          || (::number_of_set_bits(maxChoosenUnitsMask) <= 1 && !isReachedMaxUnitsLimit)
                      )

    foreach (buttonId in ["btn_max", "btn_inc", "btn_dec"])
    {
      local buttonObj = unitSliderObj.findObject(buttonId)
      if (!::checkObj(buttonObj))
        return

      if (buttonId != "btn_dec")
        buttonObj.enable(isEnabled && (maxChoosenUnitsMask & unitTable.unitClass) == 0)
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
    local selUnitsInfo = {
      selectedUnitsMask = WW_UNIT_CLASS.NONE
      classes = {}
    }

    foreach (unitTable in unitsList)
      if (unitTable.armyGroupIdx == selectedGroupIdx)
      {
        local utClass = unitTable.unitClass
        if (!(utClass in selUnitsInfo.classes))
        {
          selUnitsInfo.classes[utClass] <- {
            amount = 0
            names = []
          }
        }

        if (unitTable.value > 0)
        {
          selUnitsInfo.classes[utClass].amount += unitTable.value
          selUnitsInfo.classes[utClass].names.append(unitTable.unitName)
          selUnitsInfo.selectedUnitsMask = selUnitsInfo.selectedUnitsMask |
                                           utClass | WW_UNIT_CLASS.FIGHTER
        }
      }

    return selUnitsInfo
  }

  function getReqDataFromSelectedUnitsInfo(selUnitsInfo, unitClass, param, defValue)
  {
    if (unitClass in selUnitsInfo.classes)
      return selUnitsInfo.classes[unitClass][param]
    return defValue
  }

  function setupSendButton()
  {
    if (!::checkObj(sendButtonObj))
      return

    local selUnitsInfo = getSelectedUnitsInfo()
    local unitsFightersQty = getReqDataFromSelectedUnitsInfo(selUnitsInfo, WW_UNIT_CLASS.FIGHTER, "amount", 0)
    local unitsBombersQty = getReqDataFromSelectedUnitsInfo(selUnitsInfo, WW_UNIT_CLASS.BOMBER, "amount", 0)

    local isEnable = !!selUnitsInfo.selectedUnitsMask
    foreach (unitClass, cl in selUnitsInfo.classes)
    {
      local range = currentOperation.getQuantityToFlyOut(unitClass, selUnitsInfo.selectedUnitsMask)
      local clamped = ::clamp(cl.amount, range.x, range.y)
      isEnable = isEnable && clamped == cl.amount
    }

    local canSendArmy = canSendToFlyMoreArmy()
    sendButtonObj.enable(isEnable && canSendArmy)

    local cantSendText = ""
    if (!canSendArmy)
      cantSendText = ::loc("worldwar/reached_air_armies_limit")
    else if (hasUnitsToFly)
      cantSendText = isEnable ? getSelectedUnitsFlyTimeText(selectedGroupIdx) :
        ::loc("worldwar/airfield/army_not_equipped")

    local cantSendTextObj = scene.findObject("cant_send_reason")
    if (::checkObj(cantSendTextObj))
      cantSendTextObj.setValue(cantSendText)
  }

  function getFlyOutConditionText(unitClass, icon, range, curr)
  {
    local text = ::colorize((curr >= range.x && curr <= range.y) ?
      "goodTextColor" : "badTextColor", curr + " " + icon)

    local classText = ::WwUnit.getUnitClassText(unitClass)
    if (range.x == range.y)
      return ::loc("worldwar/airfield/" + classText + "/number_conditions", {numb = range.y, curr = text})

    return ::loc("worldwar/airfield/" + classText + "/limits_conditions", {min = range.x, max = range.y, curr = text})
  }

  function fillArmyLimitDescription()
  {
    local textObj = scene.findObject("armies_limit_text")
    if (!::checkObj(textObj))
      return

    textObj.setValue(::loc("worldwar/group_air_armies_limit",
      { cur = selectedGroupFlyArmies,
        max = currentOperation.getGroupAirArmiesLimit() }))
  }

  function fillFlyOutDescription()
  {
    local topTextObj = scene.findObject("unit_fly_conditions_text")
    if (!::checkObj(topTextObj))
      return

    local text = []
    local selUnitsInfo = getSelectedUnitsInfo()

    foreach (mask, bitsList in currentOperation.getUnitsFlyoutRange())
    {
      local bitsTexts = []
      foreach (bit, range in bitsList)
      {
        if (::u.isEqual(range, ::Point2(0,0)))
          continue

        bitsTexts.append(getUnitTypeRequirementText(bit, selUnitsInfo, mask))
      }
      text.append(::g_string.implode(bitsTexts, " + "))
    }

    topTextObj.setValue(::g_string.implode(text, "\n" + ::loc("worldwar/airfield/conditions_separator") + "\n"))

    local conditionsTextObj = scene.findObject("unit_fly_conditions_title")
    if (::check_obj(conditionsTextObj))
    {
      local conditionsText = ::loc("worldwar/airfield/unit_fly_conditions")
      if (!hasUnitsToFly)
        conditionsText = ::colorize("warningTextColor", ::loc("worldwar/airfield/not_enough_units_to_send") + " " + conditionsText)
      else if (isMaxUnitsNumSet(selUnitsInfo))
        conditionsText += ::loc("ui/parentheses/space",
          { text = ::colorize("white", ::loc("worldwar/airfield/unit_various_limit", { types = currentOperation.maxUniqueUnitsOnFlyout })) })

      conditionsText += ::loc("ui/colon")
      conditionsTextObj.setValue(conditionsText)
    }
  }

  function getUnitTypeRequirementText(unitClass, selUnitsInfo, unitsMask)
  {
    local iconAir = ::loc("worldwar/iconAir")
    local unitsQty = getReqDataFromSelectedUnitsInfo(selUnitsInfo, unitClass, "amount", 0)
    local classQt = currentOperation.getQuantityToFlyOut(unitClass, unitsMask)

    local color = (selUnitsInfo.selectedUnitsMask == unitsMask) ? "activeTextColor" : "fadedTextColor"

    return ::colorize(color, getFlyOutConditionText(unitClass,
      iconAir, classQt, unitsQty))
  }

  function hasEnoughUnitsToFlyOut()
  {
    if (!unitsList.len())
      return false

    local classesMaxAmount = {}
    foreach (unitTable in unitsList)
      if (unitTable.armyGroupIdx == selectedGroupIdx)
      {
        if (!(unitTable.unitClass in classesMaxAmount))
          classesMaxAmount[unitTable.unitClass] <- 0
        classesMaxAmount[unitTable.unitClass] += unitTable.maxValue
      }

    foreach (mask, range in currentOperation.getUnitsFlyoutRange())
    {
      local hasEnough = false
      foreach (unitClass, maxAmount in classesMaxAmount)
      {
        local unitRange = currentOperation.getQuantityToFlyOut(unitClass, mask)
        if (unitRange.y < 0)
          continue

        hasEnough = maxAmount >= unitRange.x
        if (!hasEnough)
          break
      }

      if (hasEnough)
        return true
    }

    return false
  }

  function isMaxUnitsNumSet(selUnitsInfo)
  {
    local totalUnitsLen = 0
    foreach (cl in selUnitsInfo.classes)
      totalUnitsLen += cl.names.len()

    return totalUnitsLen >= currentOperation.maxUniqueUnitsOnFlyout
  }

  function setupQuantityManageButtons(selectedUnitsInfo, unitTable)
  {
    local unitsClassMaxValue = unitTable.maxUnitClassValue

    local amount = getReqDataFromSelectedUnitsInfo(selectedUnitsInfo, unitTable.unitClass, "amount", 0)
    local isMaxSelUnitsSet = amount >= unitsClassMaxValue && amount > 0

    local prevMaxChoosenUnitsMask = maxChoosenUnitsMask
    maxChoosenUnitsMask = ::change_bit_mask(maxChoosenUnitsMask, unitTable.unitClass, isMaxSelUnitsSet? 1 : 0)

    if (maxChoosenUnitsMask != prevMaxChoosenUnitsMask || isMaxUnitsNumSet(selectedUnitsInfo))
      configureMaxUniqueUnitsChosen(selectedUnitsInfo)
  }

  function configureMaxUniqueUnitsChosen(selUnitsInfo)
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

        setUnitSliderEnable(unitSliderObj, selUnitsInfo, unitTable)
      }
  }

  function getUnitIndex(obj)
  {
    local blockObj = obj.getParent()
    local unitName = blockObj.unitName
    local armyGroupIdx = blockObj.armyGroupIdx.tointeger()
    return ::u.searchIndex(unitsList, (@(unitName, armyGroupIdx) function(unitTable) {
        return unitTable.unitName == unitName && unitTable.armyGroupIdx == armyGroupIdx
      })(unitName, armyGroupIdx))
  }

  function updateUnitValue(unitIndex, value)
  {
    local curValue = ::clamp(value, 0, unitsList[unitIndex].maxValue)
    if (curValue == unitsList[unitIndex].value)
      return

    unitsList[unitIndex].value = value

    local selectedUnitsInfo = getSelectedUnitsInfo()
    if (prevSelectedUnitsMask != selectedUnitsInfo.selectedUnitsMask)
    {
      prevSelectedUnitsMask = selectedUnitsInfo.selectedUnitsMask
      foreach (unitTable in unitsList)
        if (unitTable.armyGroupIdx == selectedGroupIdx)
          setupQuantityManageButtons(selectedUnitsInfo, unitTable)
    }

    local unitClass = unitsList[unitIndex].unitClass
    local unitsClassValue = getReqDataFromSelectedUnitsInfo(selectedUnitsInfo, unitClass, "amount", 0)
    local unitsClassMaxValue = unitsList[unitIndex].maxUnitClassValue
    local excess = max(unitsClassValue - unitsClassMaxValue, 0)
    if (excess)
      unitsList[unitIndex].value = value - excess

    setupQuantityManageButtons(selectedUnitsInfo, unitsList[unitIndex])
    updateSlider(unitsList[unitIndex], selectedUnitsInfo)
    setupSendButton()
    fillFlyOutDescription()
  }

  function updateSlider(unitTable, selUnitsInfo)
  {
    local blockObj = scene.findObject(unitTable.unitName + "_" + unitTable.armyGroupIdx)
    if (!::checkObj(blockObj))
      return

    local sliderObj = blockObj.findObject("progress_slider")
    local newProgressOb = sliderObj.findObject("new_progress")
    newProgressOb.setValue(unitTable.value)
    if (sliderObj.getValue() != unitTable.value)
      sliderObj.setValue(unitTable.value)

    setUnitSliderEnable(blockObj, selUnitsInfo, unitTable)
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
        isForceHidePlayerInfo = true
        useGenericTooltip = true
        hasMenu = hasPresetToChoose(unit)
      })
    modItemObj.pos = "0, 2"

    local centralBlockObj = modItemObj.findObject("centralBlock")
    if (::checkObj(centralBlockObj))
      centralBlockObj.unitName = unitTable.unitName
  }

  function hasPresetToChoose(unit)
  {
    return unit.weapons.len() > 1
  }

  function onModItemClick(obj)
  {
    local unit = ::getAircraftByName(obj.unitName)
    if (!hasPresetToChoose(unit))
      return

    local cb = ::Callback(function (unitName, weaponName)
    {
      changeUnitWeapon(unitName, weaponName)
    }, this)
    ::ww_gui_start_choose_unit_weapon(unit, cb, {
        canShowStatusImage = false
        canShowResearch = false
        canShowPrice = false
        isForceHidePlayerInfo = true
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
    foreach (unitTable in unitsList)
      if (unitTable.armyGroupIdx == selectedGroupIdx && unitTable.value > 0)
        minTime = minTime <= 0 ? unitTable.maxFlyTime : min(minTime, unitTable.maxFlyTime)

    return ::loc("worldwar/airfield/army_fly_time") + ::loc("ui/colon") + getFlyTimeText(minTime)
  }

  function getUnitClassMaxValue(unitClass)
  {
    return ::max(currentOperation.getQuantityToFlyOut(unitClass, unitClass).y,
                 currentOperation.getQuantityToFlyOut(unitClass, WW_UNIT_CLASS.COMBINED).y)
  }

  function sendAircrafts()
  {
    local listObj = scene.findObject("armies_tabs")
    if (!::checkObj(listObj))
      return

    local isAircraftsChoosen = false
    local armyGroupIdx = ::getTblValue(listObj.getValue(), availableArmiesArray, -1).getArmyGroupIdx()
    local units = {}
    foreach (unitTable in unitsList)
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
