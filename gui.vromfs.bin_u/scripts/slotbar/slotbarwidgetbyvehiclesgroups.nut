local slotbarPresets = require("scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")

local handlerClass = class extends ::gui_handlers.SlotbarWidget
{
  unitsGroupsByCountry = null
  countryPresets = null

  function validateParams()
  {
    base.validateParams()
    validatePresetsParams()
  }

  function validatePresetsParams()
  {
    local curPreset = slotbarPresets.getCurPreset()
    unitsGroupsByCountry = curPreset.groupsList
    countryPresets = curPreset.countryPresets
  }

  function gatherVisibleCrewsConfig(onlyForCountryIdx = null)
  {
    local res = []
    local country = getForcedCountry()
    foreach(idx, coutryCrews in ::g_crews_list.get())
    {
      if (onlyForCountryIdx != null && onlyForCountryIdx != idx)
        continue

      local listCountry = coutryCrews.country
      if ((singleCountry != null && singleCountry != listCountry)
          || !::is_country_visible(listCountry))
        continue

      local countryData = {
        country = listCountry
        id = idx
        isEnabled = (!country || country == listCountry)
        crews = []
      }
      res.append(countryData)

      if (!countryData.isEnabled)
        continue

      local crewsList = coutryCrews.crews
      local unitsList = countryPresets?[listCountry]
      local realCrewsCount = crewsList.len()
      local groupsList = unitsGroupsByCountry?[listCountry].groups
      local isVisualDisabled = groupsList == null
      local crewsCount = ::max(realCrewsCount, showNewSlot ? (groupsList?.len() ?? 0) : 0)
      for(local i = 0; i < crewsCount; i++)
      {
        local crew = crewsList?[i] ?? getDefaultCrew(listCountry, idx, i)
        local unit = unitsList?.units[i]
        local status = isVisualDisabled || (unit != null && !(unit.name in availableUnits))
          ? bit_unit_status.disabled
          : bit_unit_status.owned

        addCrewData(countryData.crews, {
          crew = crew,
          unit = unit,
          status = status,
          isSelectable = true
          isVisualDisabled = isVisualDisabled
          isLocalState = false
        })
      }
    }
    return res
  }

  function applySlotSelection(obj, selSlot)
  {
    curSlotCountryId = selSlot.countryId
    curSlotIdInCountry = selSlot.crewIdInCountry

    if (::slotbar_oninit)
    {
      if (afterSlotbarSelect)
        afterSlotbarSelect()
      return
    }

    local crewList = ::g_crews_list.get()?[curSlotCountryId]
    local country = crewList?.country ?? ""
    local crew = crewList?.crews[curSlotIdInCountry]
      ?? getDefaultCrew(country, curSlotCountryId, curSlotIdInCountry)
    local groupsList = unitsGroupsByCountry?[country].groups
    local unit = getCrewUnit(crew)
    if (unit || groupsList == null)
    {
      ::set_show_aircraft(unit)
      //need to send event when crew in country not changed, because main unit changed.
      ::select_crew(curSlotCountryId, curSlotIdInCountry, true)
    }
    else if (needActionsWithEmptyCrews)
      onSlotChangeAircraft()

    if (hasActions)
    {
      local slotItem = ::get_slot_obj(obj, curSlotCountryId, ::to_integer_safe(obj?.cur_col))
      openUnitActionsList(slotItem, true)
    }

    if (afterSlotbarSelect)
      afterSlotbarSelect()
  }

  getDefaultCrew = @(country, idCountry, idInCountry) {
    country = country
    idCountry = idCountry
    idInCountry = idInCountry
  }

  function getCurSlotUnit()
  {
    return countryPresets?[getCurCountry()].units[curSlotIdInCountry]
  }

  function getCrewUnit(crew)
  {
    return countryPresets?[crew.country].units[crew.idInCountry]
  }

  function onEventPresetsByGroupsChanged(p)
  {
    local newCrew = p?.crew
    local newUnit = p?.unit
    if (newCrew != null && newUnit != null)
    {
      ::select_crew(newCrew.idCountry, newCrew.idInCountry)
      ::set_show_aircraft(newUnit)
    }
    validatePresetsParams()
    fullUpdate()
  }

  getParamsForActionsList = @() { hasSlotbarByUnitsGroups = true }
}

::gui_handlers.slotbarWidgetByVehiclesGroups <- handlerClass

local function create(params)
{
  local nest = params?.scene
  if (!::check_obj(nest))
    return null

  if (params?.shouldAppendToObject ?? true) //we append to nav-bar by default
  {
    local data = "slotbarDiv { id:t='nav-slotbar' }"
    nest.getScene().appendWithBlk(nest, data)
    params.scene = nest.findObject("nav-slotbar")
  }

  return ::handlersManager.loadHandler(handlerClass, params)
}

return {
  create = create
}