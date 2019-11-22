local function getUnitsGroups() {
  return ::g_ww_global_status.getOperationById(
    ::ww_get_operation_id())?.getMap().getUnitsGroupsByCountry()
}

local function overrideUnitViewParamsByGroups(wwUnitViewParams, unitsGroups) {
  local group = unitsGroups?[wwUnitViewParams.country].groups[wwUnitViewParams.id]
  if (group == null)
    return wwUnitViewParams

  local defaultUnit = group?.defaultUnit
  wwUnitViewParams.name         = ::loc(group.name)
  wwUnitViewParams.icon         = ::getUnitClassIco(defaultUnit)
  wwUnitViewParams.shopItemType = ::get_unit_role(defaultUnit)
  wwUnitViewParams.tooltipId    = null
  wwUnitViewParams.weapon       = null
  return wwUnitViewParams
}

local function overrideUnitsViewParamsByGroups(wwUnitsViewParams) {
  local unitsGroups = getUnitsGroups()
  if (unitsGroups == null)
    return wwUnitsViewParams

  return wwUnitsViewParams.map(@(wwUnit) overrideUnitViewParamsByGroups(wwUnit, unitsGroups))
}

return {
  getUnitsGroups = getUnitsGroups
  overrideUnitViewParamsByGroups = overrideUnitViewParamsByGroups
  overrideUnitsViewParamsByGroups = overrideUnitsViewParamsByGroups
}