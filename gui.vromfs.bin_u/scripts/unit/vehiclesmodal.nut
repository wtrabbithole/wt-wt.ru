local MAX_SLOT_COUNT_X = 4
local MAX_SLOT_COUNT_Y = 6

class ::gui_handlers.vehiclesModal extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType              = handlerType.MODAL
  slotbarActions       = [ "research", "buy", "take", "weapons", "testflight", "info", "repair" ]
  focusArray           = [ "countries_boxes", "units_boxes", "units_list" ]
  unitsFilter          = null
  units                = null
  countries            = null
  unitsTypes           = null
  sceneTplName         = "gui/unit/vehiclesModal"
  sceneCheckBoxListTpl = "gui/commonParts/checkbox"

  function getSceneTplView()
  {
    collectUnitData()
    return {
      slotCountX = MAX_SLOT_COUNT_X
      slotCountY = min( units.len() / MAX_SLOT_COUNT_X + 1, MAX_SLOT_COUNT_Y)
      filters = [
        {id = "countries_boxes", boxes = getCountriesCheckBoxesData()},
        {id = "units_boxes", isRightAlign = true, boxes = getUnitTypesCheckBoxesData()}
      ]
      unitsList = getUnitsListData()
    }
  }

  function initScreen()
  {
    initFocusArray()
    scene.findObject("countries_boxes").select()
  }

  function collectUnitData()
  {
    local curCountry = ::get_profile_country_sq()
    units = []
    countries = {}
    unitsTypes = {}

    foreach(unit in ::all_units)
      if (!unitsFilter || unitsFilter(unit))
      {
        local country = unit.shopCountry
        local id = unit.unitType.esUnitType
        units.append(unit)
        if (!(country in countries))
          countries[country] <- {
            id = country
            idx = ::u.searchIndex(::shopCountriesList, @(id) id == country, -1)
            value = country == curCountry
          }
        if (!(id.tostring() in unitsTypes))
          unitsTypes[id.tostring()] <- {unitType = unit.unitType, value = true}
      }
  }

  function getCountriesCheckBoxesData()
  {
    local view = { checkbox = [] }
    foreach(country in countries)
      view.checkbox.append({
        id = country.id
        idx = country.idx
        useImage = ::get_country_icon(country.id)
        tooltip = "#" + country.id
        value = country.value
        funcName = "onCountryChange"
      })

    view.checkbox.sort(function (a, b){
      if(a.idx != b.idx)
        return a.idx > b.idx ? 1:-1
      return 0
    })

    return ::handyman.renderCached(sceneCheckBoxListTpl, view)
  }

  function getUnitTypesCheckBoxesData()
  {
    local view = { checkbox = [] }
    foreach(inst in unitsTypes)
    {
      if (!inst.unitType.isAvailable())
        continue

      view.checkbox.append({
        id = inst.unitType.esUnitType
        useImage = inst.unitType.testFlightIcon
        tooltip = inst.unitType.getArmyLocName()
        value = inst.value
        funcName = "onUnitChange"
      })
    }

    view.checkbox.sort(function (a, b){
      if(a.id != b.id)
        return a.id > b.id ? 1:-1
      return 0
    })

    if (view.checkbox.len() > 0)
      view.checkbox[view.checkbox.len()-1].isLastCheckBox <- true

    return ::handyman.renderCached(sceneCheckBoxListTpl, view)
  }

  function getUnitsListData()
  {
    local data = ""
    foreach(idx, unit in units)
    {
      local country = unit.shopCountry
      if (!countries[country].value || !unitsTypes[unit.unitType.esUnitType.tostring()].value)
        continue

      data += ::format("unitItemContainer{id:t='cont_%s' %s}", unit.name,
        ::build_aircraft_item(unit.name, unit, getUnitItemParams(unit)))
    }
    return data
  }

  function fillUnitsList()
  {
    local listObj = scene.findObject("units_list")
    if (!::check_obj(listObj))
      return

    local data = getUnitsListData()
    guiScene.replaceContentFromText(listObj, data, data.len(), this)

    foreach(unit in units)
    {
      local placeObj = listObj.findObject("cont_" + unit.name)
      if (!placeObj)
        continue

      updateAdditionalProp(unit, placeObj)
      ::updateAirAfterSwitchMod(unit)
    }
  }

  function getUnitItemParams(unit)
  {
    return {
      hasActions         = true
      isInTable          = false
      fullBlock          = false
      showBR             = ::has_feature("GlobalShowBattleRating")
      tooltipParams      = { needShopInfo = true }
    }
  }

  getParamsForActionsList = @() {setResearchManually  = true}

  function checkUnitItemAndUpdate(unit)
  {
    if (!unit)
      return

    updateUnitItem(unit, scene.findObject("cont_" + unit.name))
    ::updateAirAfterSwitchMod(unit)
  }

  function updateUnitItem(unit, placeObj)
  {
    if (!::check_obj(placeObj))
      return

    local unitBlock = ::build_aircraft_item(unit.name, unit, getUnitItemParams(unit))
    guiScene.replaceContentFromText(placeObj, unitBlock, unitBlock.len(), this)
    updateAdditionalProp(unit, placeObj)
  }

  function updateAdditionalProp(unit, placeObj)
  {
    ::fill_unit_item_timers(placeObj.findObject(unit.name), unit, getUnitItemParams(unit))
    ::showUnitDiscount(placeObj.findObject(unit.name+"-discount"), unit)

    local bonusData = unit.name
    if (::isUnitGroup(unit))
      bonusData = ::u.map(unit.airsGroup, function(unit) { return unit.name })
    ::showAirExpWpBonus(placeObj.findObject(unit.name+"-bonus"), bonusData)
  }

  function onCountryChange(obj)
  {
    if (!::check_obj(obj))
      return

    countries[obj.id].value = obj.getValue()
    obj.select()
    fillUnitsList()
  }

  function onUnitChange(obj)
  {
    if (!::check_obj(obj))
      return

    unitsTypes[obj.id].value = obj.getValue()
    obj.select()
    fillUnitsList()
  }

  function onClick(obj)
  {
    if (!::check_obj(obj))
      return

    local idx = obj.getValue()
    if (idx == -1 || idx > obj.childrenCount()- 1)
      return

    local slot = obj.getChild(idx)?.getChild(0) ?? null
    if (!::check_obj(slot))
      return

    openUnitActionsList(slot, true, true)
    scene.findObject("units_list").select()
  }

  function onOpenActionsList(obj)
  {
    if (!::check_obj(obj))
      return

    openUnitActionsList(obj.getParent().getParent(), false, true)
  }

  function onEventUnitResearch(p)
  {
    local prevUnitName = p?.prevUnitName ?? null
    local unitName = p?.unitName ?? null

    if (prevUnitName && prevUnitName != unitName)
      checkUnitItemAndUpdate(::getAircraftByName(prevUnitName))

    checkUnitItemAndUpdate(::getAircraftByName(unitName))
  }

  function onEventUnitBought(p)
  {
    ::update_gamercards()
    checkUnitItemAndUpdate(::getAircraftByName(p?.unitName ?? null))
  }

  function onEventSquadronExpChanged(p)
  {
    checkUnitItemAndUpdate(::getAircraftByName(::clan_get_researching_unit()))
  }

  function onEventFlushSquadronExp(p)
  {
    checkUnitItemAndUpdate(p?.unit ?? null)
  }

  function onEventModificationPurchased(p)
  {
    checkUnitItemAndUpdate(p?.unit ?? null)
  }

  function onEventUnitRepaired(p)
  {
    checkUnitItemAndUpdate(p?.unit ?? null)
  }

  function onWrapDown(obj)
  {
    if(obj.isEqual(scene.findObject("units_boxes")))
      scene.findObject("units_list").select()
    base.onWrapDown(obj)
  }
}

return {
  open = function(unitsFilter=null)
  {
    ::gui_start_modal_wnd(::gui_handlers.vehiclesModal, {unitsFilter = unitsFilter})
  }
}