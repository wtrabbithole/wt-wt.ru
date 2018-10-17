class ::gui_handlers.CrewUnitSpecHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "gui/empty.blk"
  isPrimaryFocus = false
  crew = null
  crewLevel = null
  units = null
  curCrewUnitType = null
  isHandlerVisible = true

  function initScreen()
  {
    initFocusArray()
  }

  function getMainFocusObj()
  {
    return scene
  }

  function setHandlerVisible(value)
  {
    isHandlerVisible = value
    scene.show(value)
    scene.enable(value)
  }

  function setHandlerData(newCrew, newCrewLevel, newUnits, newCrewUnitType)
  {
    crew = newCrew
    crewLevel = newCrewLevel
    units = newUnits
    curCrewUnitType = newCrewUnitType

    loadSceneTpl()

    foreach(i, unit in units)
      updateAirRow(i)

    local totalRows = scene.childrenCount()
    if (totalRows > 0 && totalRows <= scene.getValue())
      scene.setValue(0)
    else
      ::selectTableNavigatorObj(scene)
  }

  function loadSceneTpl()
  {
    local rows = []
    foreach(i, unit in units)
    {
      local specType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unit)
      rows.append({
        id = getRowName(i)
        even = i % 2 == 0
        holderId = i
        unitName = ::getUnitName(unit.name)
        hasProgressBar = true
        rowTooltipId   = ::g_tooltip.getIdCrewSpecialization(crew.id, unit.name, -1)
        buySpecTooltipId1 = ::g_crew_spec_type.EXPERT.getBtnBuyTooltipId(crew, unit)
        buySpecTooltipId2 = ::g_crew_spec_type.ACE.getBtnBuyTooltipId(crew, unit)
        buySpecTooltipId = ::g_tooltip.getIdBuyCrewSpec(crew.id, unit.name, -1)
      })
    }

    local view = { rows = rows }
    local data = ::handyman.renderCached("gui/crew/crewAirRow", view)
    guiScene.replaceContentFromText(scene, data, data.len(), this)
  }

  function updateAirRow(rowIndex)
  {
    local rowObj = scene.findObject(getRowName(rowIndex))
    local rowUnit = ::getTblValue(rowIndex, units)
    if (!::checkObj(rowObj) || rowUnit == null)
      return

    local balance = ::get_balance()
    local crewSpecType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, rowUnit)

    rowObj.findObject("curValue").setValue(crewSpecType.getName())

    local costText = ""
    if (crewSpecType.hasNextType())
      costText = crewSpecType.getUpgradeCostByCrewAndByUnit(crew, rowUnit).tostring()
    rowObj.findObject("cost").setValue(costText)

    local hasNextType = crewSpecType.hasNextType()
    local nextType = crewSpecType.getNextType()
    local reqLevel = hasNextType ? nextType.getReqCrewLevel(rowUnit) : 0

    local enable = reqLevel <= crewLevel
    local btnObj = rowObj.findObject("buttonRowApply")
    local discObj = rowObj.findObject("buy-discount")
    btnObj.show(hasNextType)
    btnObj.enable(enable)
    rowObj.findObject("cost").show(enable)
    if (hasNextType)
    {
      local buttonLabel = enable
        ? crewSpecType.getButtonLabel()
        : ::loc("crew/qualifyRequirement", { reqLevel = reqLevel })
      btnObj.setValue(buttonLabel)
      ::showAirDiscount(discObj, rowUnit.name,
        "specialization", nextType.specName)
    }
    else
      ::hideBonus(discObj)

    local crewLevel = ::g_crew.getCrewLevel(crew, rowUnit.getCrewUnitType())
    local curSpecType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, rowUnit)
    updateRowSpecButton(rowObj, ::g_crew_spec_type.EXPERT, crewLevel, rowUnit, curSpecType)
    updateRowSpecButton(rowObj, ::g_crew_spec_type.ACE, crewLevel, rowUnit, curSpecType)

    local progressBarObj = rowObj.findObject("crew_spec_progress_bar")
    if (::checkObj(progressBarObj))
    {
      local isProgressBarVisible = needShowExpUpgrade(crew, rowUnit)
      progressBarObj.show(isProgressBarVisible)
      if (isProgressBarVisible)
      {
        local progressBarValue = 1000 * curSpecType.getExpLeftByCrewAndUnit(crew, rowUnit)
          / curSpecType.getTotalExpByUnit(rowUnit)
        progressBarObj.setValue(progressBarValue.tointeger())
      }
    }
  }

  function needShowExpUpgrade(crew, unit)
  {
    local specType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unit)
    return specType.needShowExpUpgrade(crew, unit)
  }

  function updateRowSpecButton(rowObj, specType, crewLevel, unit, curSpecType)
  {
    local obj = rowObj.findObject("btn_spec" + specType.code)
    if (!::checkObj(obj))
      return

    local icon = specType.getIcon(curSpecType.code, crewLevel, unit)
    obj["foreground-image"] = icon
    obj.enable(icon != "" && curSpecType.code < specType.code)
  }

  function getRowName(rowIndex)
  {
    return ::format("skill_row%d", rowIndex)
  }

  function applyRowButton(obj)
  {
    // Here 'scene' is table object with id "specs_table".
    if (!checkObj(obj) || obj.id != "buttonRowApply")
    {
      if (!::checkObj(scene))
        return
      local idx = scene.getValue()
      local rowObj = scene.getChild(idx)
      if (!::checkObj(rowObj))
        return
      obj = rowObj.findObject("buttonRowApply")
    }

    if (!checkObj(obj) || !obj.isEnabled())
      return

    local rowIndex = ::g_crew.getButtonRow(obj, scene, scene)
    local rowUnit = ::getTblValue(rowIndex, units)
    if (rowUnit == null)
      return

    ::g_crew.upgradeUnitSpec(crew, rowUnit)
  }

  function onButtonRowApply(obj)
  {
    applyRowButton(obj)
  }

  function increaseSpec(nextSpecType, obj = null)
  {
    local rowIndex = ::g_crew.getButtonRow(obj, scene, scene)
    local rowUnit = ::getTblValue(rowIndex, units)
    if (rowUnit)
      ::g_crew.upgradeUnitSpec(crew, rowUnit, null, nextSpecType)
  }

  function onSpecIncrease1(obj)
  {
    increaseSpec(::g_crew_spec_type.EXPERT, obj)
  }

  function onSpecIncrease2(obj)
  {
    increaseSpec(::g_crew_spec_type.ACE, obj)
  }
}
