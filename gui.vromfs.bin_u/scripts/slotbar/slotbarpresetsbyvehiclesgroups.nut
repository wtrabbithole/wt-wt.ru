local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")

local curPreset = {
  groupsList = {} //groups config by country
  countryPresets = {} //units list in slotbar by country
  presetId = "" //eventId or mapId for WW
}

local cachedPresetsListByEventId = {}
local getPresetTemplate = @() {
  units = []
}

local getPresetSaveIdByEventId = @(presetId) "slotbar_presets_by_game_modes/{0}".subst(presetId)

local function invalidateCashe() {
  cachedPresetsListByEventId = {}
  curPreset = {
    groupsList = {}
    countryPresets = {}
    presetId = ""
  }
}

local function getDefaultPresets(countryGroupsList) {
  local preset = getPresetTemplate()
  preset.units = countryGroupsList.defaultUnitsListByGroups.values()
  return preset
}

local function generateDefaultPresets(groupsList) {
  return groupsList.map(@(country) getDefaultPresets(country))
}

local function savePresets(presetId, countryPresets) {
  local blk = ::DataBlock()
  foreach(countryId, preset in countryPresets)
    blk[countryId] <- ",".join(preset.units.map(@(unit) unit?.name ?? ""))

  local cfgBlk = ::load_local_account_settings(getPresetSaveIdByEventId(presetId))
  if (::u.isEqual(blk, cfgBlk))
    return

  ::save_local_account_settings(getPresetSaveIdByEventId(presetId), blk)
}

local function isDefaultUnitForGroup(unit, groupsList, country) {
  local unitsGroups = groupsList[country]
  if (!unitsGroups)
    return false

  return unitsGroups.defaultUnitsListByGroups[unitsGroups.groupIdByUnitName[unit.name]].name == unit.name
}

local function canAssignInSlot(unit, groupsList, country) {
  return isDefaultUnitForGroup(unit, groupsList, country) || unit.canAssignToCrew(country)
}

local function validatePresets(presetId, groupsList, countryPresets) {
  if ((countryPresets?.len() ?? 0) == 0)
    return generateDefaultPresets(groupsList)

  foreach (countryId in ::shopCountriesList)
  {
    local countryGroupsList = groupsList?[countryId]
    local countryPreset = countryPresets?[countryId]
    if (countryGroupsList == null)
    {
      if (countryPreset != null)
        countryPresets.rawdelete(countryId)
      continue
    }

    if (countryGroupsList != null && countryPreset == null)
    {
      countryPresets[countryId] <- getDefaultPresets(countryGroupsList)
      continue
    }

    local defaultUnitsListByGroups = clone countryGroupsList.defaultUnitsListByGroups
    local presetUnits = countryPreset.units
    local emptySLots = []
    for(local i = 0; i < ::max(presetUnits.len(), defaultUnitsListByGroups.len()); i++)
    {
      local unit = presetUnits?[i]
      if (unit == null || !canAssignInSlot(unit, groupsList, countryId))
      {
        emptySLots.append(i)
        continue
      }

      local unitGroup = countryGroupsList.groupIdByUnitName?[unit.name]
      if (unitGroup in defaultUnitsListByGroups)
      {
         defaultUnitsListByGroups.rawdelete(unitGroup)
         continue
      }

      presetUnits[i] = null   //not found unit group, need clear slot.
      emptySLots.append(i)
    }

    local i = 0
    foreach(defaultUnit in defaultUnitsListByGroups)
    {
      local slotIdx = emptySLots[i]
      if (slotIdx in presetUnits)
        presetUnits[slotIdx] = defaultUnit
      else
        presetUnits.append(defaultUnit)
      i++
    }
  }

  return countryPresets
}

local function getPresetsList(presetId, groupsList) {
  local countryPresets = cachedPresetsListByEventId?[presetId]
  if ((countryPresets?.len() ?? 0) != 0)
    return countryPresets

  local savedPresetsBlk = ::load_local_account_settings(getPresetSaveIdByEventId(presetId))
  if (savedPresetsBlk)
  {
    countryPresets = {}
    local countryCount = savedPresetsBlk.paramCount()
    for(local c = 0; c < countryCount; c++)
    {
      local strPreset = savedPresetsBlk.getParamValue(c)
      local preset = getPresetTemplate()
      local unitNames = ::g_string.split(strPreset, ",")
      if (unitNames.len() == 0)
        continue

      local hasUnits = false
      for(local i = 0; i < unitNames.len(); i++)
      {
        local unitName = unitNames[i]
        local unit = ::getAircraftByName(unitName)
        if (unit != null)
          hasUnits = true

        preset.units.append(unit)
      }

      if (!hasUnits)
        continue

      countryPresets[savedPresetsBlk.getParamName(c)] <- preset
    }
  }

  countryPresets = validatePresets(presetId, groupsList, countryPresets)
  cachedPresetsListByEventId[presetId] <- countryPresets
  return countryPresets
}

local function updatePresets(presetId, countryPresets) {
  cachedPresetsListByEventId[presetId] <- countryPresets
  savePresets(presetId, countryPresets)
}

local groupInSlotMsgBoxlocId = "msgbox/groupAlreadyInOtherSlot"

local function setUnit(crew, unit, onFinishCb) {
  local country = crew.country
  local curCountryPreset = curPreset.countryPresets?[country]
  if (curCountryPreset == null)
    return onFinishCb(true)
  local idx = crew.idInCountry
  local curUnit =  curCountryPreset.units?[idx]
  if (curUnit == unit)
    return onFinishCb(true)

  local countryGroups = curPreset.groupsList[country]
  local groupIdByUnitName = countryGroups.groupIdByUnitName
  local unitGroup = groupIdByUnitName[unit.name]
  local curUnitGroup = groupIdByUnitName?[curUnit?.name ?? ""] ?? ""
  local onApplyCb = function() {
    if (idx >= curCountryPreset.units.len())
      curPreset.countryPresets[country].units.resize(idx + 1, null)

    curPreset.countryPresets[country].units[idx] = unit
    updatePresets(curPreset.presetId, curPreset.countryPresets)
    ::broadcastEvent("PresetsByGroupsChanged", { crew = crew, unit = unit})
    onFinishCb(true)
  }

  local oldGroupIdx = curCountryPreset.units.searchindex(@(u)
    groupIdByUnitName?[u?.name ?? ""] == unitGroup)
  if (unitGroup != curUnitGroup && oldGroupIdx != null)
  {
    local groupName = ::colorize("activeTextColor", ::loc(countryGroups.groups[unitGroup].name))
    local descLocId = "{0}/{1}".subst(groupInSlotMsgBoxlocId, curUnit == null ? "inEmptySlot" : "slotWithUnit")
    ::scene_msg_box("group_already_in_other_slot", null,
      ::loc(groupInSlotMsgBoxlocId, {
        groupName = groupName
        slotIdx = oldGroupIdx + 1
        descMsg = ::loc(descLocId, {
          unitName = ::colorize("activeTextColor", ::getUnitName(unit))
          curGroupUnitName = ::colorize("activeTextColor",
            ::getUnitName(curCountryPreset.units[oldGroupIdx]))
          curUnitName = ::colorize("activeTextColor", ::getUnitName(curUnit))
          slotIdx = oldGroupIdx + 1
        })
      }),
      [[ "ok", function() {
            curPreset.countryPresets[country].units[oldGroupIdx] = curUnit
            onApplyCb()
          }
        ], [ "cancel", @() null ]],
      "ok")
  }
  else
    onApplyCb()
}

local function setCurPreset(presetId, groupsList) {
  local curPresetId = curPreset.presetId
  if (curPresetId == presetId)
    return
  local countryPresets = getPresetsList(presetId, groupsList)
  curPreset = {
    groupsList = groupsList
    countryPresets = countryPresets
    presetId = presetId
  }
  ::broadcastEvent("PresetsByGroupsChanged")
}

local function getCurPreset() {
  return curPreset
}

local function getCurCraftsInfo() {
  return (curPreset.countryPresets?[::get_profile_country_sq()].units ?? []).map(@(unit) unit?.name ?? "")
}

local function getCrewByUnit(unit) {
  local country = unit.shopCountry
  local idCountry = shopCountriesList.findindex(@(cName) cName == country)
  local units = curPreset.countryPresets?[country].units ?? []
  local idInCountry = units.findindex(@(u) u == unit)
  if (idInCountry == null)
    return null

  return {
    country = country
    idCountry = idCountry
    idInCountry = idInCountry
  }
}

subscriptions.addListenersWithoutEnv({
  SignOut = @(p) invalidateCashe()
})

return {
  setCurPreset = setCurPreset
  getCurPreset = getCurPreset
  setUnit = ::kwarg(setUnit)
  isDefaultUnitForGroup = isDefaultUnitForGroup
  getCurCraftsInfo = getCurCraftsInfo
  getCrewByUnit = getCrewByUnit
}