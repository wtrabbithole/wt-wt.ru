local function getUnitsGroups() {
  local unitsGroupByCountry = ::g_ww_global_status.getOperationById(
    ::ww_get_operation_id())?.getMap().getUnitsGroupsByCountry()
  if (unitsGroupByCountry == null)
    return null

  local fullGroupsList = {}
  foreach (country in unitsGroupByCountry)
    fullGroupsList.__update(country.groups)
  return fullGroupsList
}

local function overrideUnitViewParamsByGroups(wwUnitViewParams, unitsGroups) {
  local group = unitsGroups?[wwUnitViewParams.id]
  if (group == null)
    return wwUnitViewParams

  local defaultUnit = group?.defaultUnit
  wwUnitViewParams.name         = ::loc(group.name)
  wwUnitViewParams.icon         = ::getUnitClassIco(defaultUnit)
  wwUnitViewParams.shopItemType = ::get_unit_role(defaultUnit)
  wwUnitViewParams.tooltipId    = ::g_tooltip_type.UNIT_GROUP.getTooltipId(group)
  wwUnitViewParams.hasPresetWeapon = false
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