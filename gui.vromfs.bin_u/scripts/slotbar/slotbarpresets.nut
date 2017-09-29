::slotbarPresets <- {
  [PERSISTENT_DATA_PARAMS] = ["presets", "selected"]

  activeTypeBonusByCountry = null

  baseCountryPresetsAmount = 8
  eraBonusPresetsAmount = 2  // amount of five era bonus, given for each unit type
  eraIdForBonus = 5
  minCountryPresets = 1

  isLoading = false
  validatePresetNameRegexp = regexp2(@"^#|[;|\\<>]")

  /** Array of presets by country id. */
  presets = {}

  /** Selected preset index by country id. */
  selected = {}

  function init()
  {
    foreach(country in ::shopCountriesList)
      initCountry(country)

    saveAllCountries() // maintenance
  }

  function newbieInit(newbiePresetsData)
  {
    presets = {}
    foreach (presetDataItem in newbiePresetsData.presetDataItems)
    {
      // This adds empty array to presets table if not already.
      presets[presetDataItem.country] <- ::getTblValue(presetDataItem.country, presets, [])
      if (!presetDataItem.hasUnits)
        continue
      local gameMode = ::game_mode_manager.getGameModeByUnitType(presetDataItem.unitType, -1, true)
      // Creating preset from preset data item.
      local preset = _createPresetTemplate(0)
      preset.title = ::get_unit_type_army_text(presetDataItem.unitType)
      preset.gameModeId = ::getTblValue("id", gameMode, "")
      foreach (taskData in presetDataItem.tasksData)
      {
        if (taskData.airName == "")
          continue
        preset.units.push(taskData.airName)
        preset.crews.push(taskData.crewId)
        if (preset.selected == -1)
          preset.selected = taskData.crewId
      }
      _updateInfo(preset)
      presets[presetDataItem.country].push(preset)

      local presetIndex = presets[presetDataItem.country].len() - 1
      presetDataItem.presetIndex <- presetIndex

      if (newbiePresetsData.selectedCountry == presetDataItem.country &&
          newbiePresetsData.selectedUnitType == presetDataItem.unitType &&
          preset.gameModeId != "")
        ::game_mode_manager.setCurrentGameModeById(preset.gameModeId)
    }

    selected = {}
    // Attempting to select preset with selected unit type for each country.
    foreach(country in ::shopCountriesList)
    {
      local presetDataItem = getPresetDataByCountryAndUnitType(newbiePresetsData, country, newbiePresetsData.selectedUnitType)
      selected[country] <- ::getTblValue("presetIndex", presetDataItem, 0)
    }

    saveAllCountries()
  }

  function getPresetDataByCountryAndUnitType(presetsData, country, unitType)
  {
    foreach (presetDataItem in presetsData.presetDataItems)
    {
      if (presetDataItem.country == country && presetDataItem.unitType == unitType)
        return presetDataItem
    }
    return null
  }

  function initCountry(countryId)
  {
    presets[countryId] <- getPresetsList(countryId)
    local selPresetId = ::loadLocalByAccount("slotbar_presets/" + countryId + "/selected", null)

    if (selPresetId != null && (selPresetId in presets[countryId]))
      updatePresetFromSlotbar(presets[countryId][selPresetId], countryId)
    else
    {
      selPresetId = null
      local slotbarPreset = createPresetFromSlotbar(countryId)
      foreach (idx, preset in presets[countryId])
        if (::u.isEqual(preset.crews, slotbarPreset.crews) && ::u.isEqual(preset.units, slotbarPreset.units))
        {
          selPresetId = idx
          break
        }
    }

    selected[countryId] <- selPresetId
  }

  function list(countryId = null)
  {
    if (!countryId)
      countryId = ::get_profile_info().country
    local res = []
    if (!(countryId in presets))
    {
      res.append(createPresetFromSlotbar(countryId))
      return res
    }

    local currentIdx = getCurrent(countryId, -1)
    foreach(idx, preset in presets[countryId])
    {
      if (idx == currentIdx)
        updatePresetFromSlotbar(preset, countryId)
      res.append(preset)
    }

    return res
  }

  function getCurrent(country = null, defValue = null)
  {
    if (!country)
      country = ::get_profile_info().country
    return (country in selected) ? selected[country] : defValue
  }

  /**
   * Returns selected preset for specified country.
   * @param  {string} country If not specified then current
   *                          profile-selected country is used.
   */
  function getCurrentPreset(country = null)
  {
    if (!country)
      country = ::get_profile_info().country
    local index = getCurrent(country, -1)
    local currentPresets = ::getTblValue(country, presets)
    return ::getTblValue(index, currentPresets)
  }

  function canCreate()
  {
    local countryId = ::get_profile_info().country
    return (countryId in presets) && presets[countryId].len() < getMaxPresetsCount(countryId)
  }

  function getPresetsReseveTypesText(country = null)
  {
    if ( ! country)
      country = ::get_profile_info().country
    local unitTypes = getUnitTypesWithNotActivePresetBonus(country)
    local typeNames = ::u.map(unitTypes, function(u) { return u.getArmyLocName()})
    return ::g_string.implode(typeNames, ", ")
  }

  function havePresetsReserve(country = null)
  {
    if ( ! country)
      country = ::get_profile_info().country
    return getUnitTypesWithNotActivePresetBonus(country).len() > 0
  }

  function getMaxPresetsCount(country = null)
  {
    if ( ! country)
      country = ::get_profile_info().country
    validateSlotsCountCache()
    local result = baseCountryPresetsAmount
    foreach (unitType, typeStatus in ::getTblValue(country, activeTypeBonusByCountry, {}))
      if(typeStatus)
        result += eraBonusPresetsAmount
    return result
  }

  function getTotalPresetsCount()
  {
    return baseCountryPresetsAmount + ::g_unit_type.types.len() * eraBonusPresetsAmount
  }

  function getUnitTypesWithNotActivePresetBonus(country = null)
  {
    if ( ! country)
      country = ::get_profile_info().country
    validateSlotsCountCache()
    local result = []
    foreach (unitType, typeStatus in ::getTblValue(country, activeTypeBonusByCountry, {}))
      if( ! typeStatus)
        result.push(unitType)
    return result
  }

  function clearSlotsCache()
  {
    activeTypeBonusByCountry = null
  }

  function validateSlotsCountCache()
  {
    if(activeTypeBonusByCountry)
      return

    activeTypeBonusByCountry = {}

    foreach(unit in ::all_units)
    {
      if (unit.rank != eraIdForBonus ||
          ! unit.unitType.isAvailable() ||
          ! ::is_unit_visible_in_shop(unit))
        continue

      local countryName = ::getUnitCountry(unit)
      if ( ! (countryName in activeTypeBonusByCountry))
        activeTypeBonusByCountry[countryName] <- {}

      if( ! (unit.unitType in activeTypeBonusByCountry[countryName]))
        activeTypeBonusByCountry[countryName][unit.unitType] <- false

      if (::isUnitBought(unit))
        activeTypeBonusByCountry[countryName][unit.unitType] = true
    }
  }

  function onEventUnitBought(params)
  {
    clearSlotsCache()
  }

  function  onEventSignOut(params)
  {
    clearSlotsCache()
  }

  function create()
  {
    if (!canCreate())
      return false
    local countryId = ::get_profile_info().country
    presets[countryId].append(createEmptyPreset(countryId, presets[countryId].len()))
    save(countryId)
    ::broadcastEvent("SlotbarPresetsChanged", { showPreset = presets[countryId].len()-1 })
    return true
  }

  function canErase()
  {
    local countryId = ::get_profile_info().country
    return (countryId in presets) && presets[countryId].len() > minCountryPresets
  }

  function erase(idx)
  {
    if (!canErase())
      return false
    local countryId = ::get_profile_info().country
    if (idx == selected[countryId])
      return
    presets[countryId].remove(idx)
    if (selected[countryId] != null && selected[countryId] > idx)
      selected[countryId]--
    save(countryId)
    ::broadcastEvent("SlotbarPresetsChanged", { showPreset = min(idx, presets[countryId].len()-1) })
    return true
  }

  function move(idx, offset)
  {
    local countryId = ::get_profile_info().country
    local newIdx = ::clamp(idx + offset, 0, presets[countryId].len() - 1)
    if (newIdx == idx)
      return false
    presets[countryId].insert(newIdx, presets[countryId].remove(idx))
    if (selected[countryId] != null)
    {
      if (selected[countryId] == idx)
        selected[countryId] = newIdx
      else if (selected[countryId] == newIdx)
        selected[countryId] = idx
      else if (selected[countryId] > min(idx, newIdx) && selected[countryId] < max(idx, newIdx))
        selected[countryId] += (offset > 0 ? -1 : 1)
    }
    save(countryId)
    ::broadcastEvent("SlotbarPresetsChanged", { showPreset = newIdx })
    return true
  }

  function validatePresetName(name)
  {
    return validatePresetNameRegexp.replace("", name)
  }

  function rename(idx)
  {
    local countryId = ::get_profile_info().country
    if (!(countryId in presets) || !(idx in presets[countryId]))
      return

    local oldName = presets[countryId][idx].title
    ::gui_modal_editbox_wnd({
                      title = ::loc("mainmenu/newPresetName"),
                      maxLen = 16,
                      value = oldName,
                      owner = this,
                      checkButtonFunc = function (value) {
                        return value != null && ::clearBorderSymbols(value).len() > 0
                      },
                      validateFunc = function (value) {
                        return ::slotbarPresets.validatePresetName(value)
                      },
                      okFunc = (@(idx, countryId) function(newName) {
                        onChangePresetName(idx, ::clearBorderSymbols(newName), countryId)
                      })(idx, countryId)
                    })
  }

  function onChangePresetName(idx, newName, countryId)
  {
    local oldName = presets[countryId][idx].title
    if (oldName == newName)
      return

    presets[countryId][idx].title <- newName
    save(countryId)
    ::broadcastEvent("SlotbarPresetsChanged", { showPreset = idx})
  }

  function saveAllCountries()
  {
    local hasChanges = false
    foreach(countryId in ::shopCountriesList)
      hasChanges = save(countryId, false) || hasChanges
    if (hasChanges)
      ::save_profile_offline_limited(true)
  }

  function save(countryId = null, shouldSaveProfile = true)
  {
    if (!countryId)
      countryId = ::get_profile_info().country
    if (!(countryId in presets))
      return false
    local blk = null
    if (presets[countryId].len() > 0)
    {
      local curPreset = ::getTblValue(selected[countryId], presets[countryId])
      if (curPreset && countryId == ::get_profile_info().country)
        updatePresetFromSlotbar(curPreset, countryId)

      local list = []
      foreach (idx, p in presets[countryId])
      {
        list.append(::g_string.join([p.selected,
                               ::g_string.join(p.crews, ","),
                               ::g_string.join(p.units, ","),
                               p.title,
                               ::getTblValue("gameModeId", p, "")],
                              "|"))
      }
      blk = ::array_to_blk(list, "preset")
      if (selected[countryId] != null)
        blk.selected <- selected[countryId]
    }
    local cfgBlk = ::loadLocalByAccount("slotbar_presets/" + countryId)
    if (::u.isEqual(blk, cfgBlk) || blk == null && cfgBlk == null)
      return false
    ::saveLocalByAccount("slotbar_presets/" + countryId, blk, true, shouldSaveProfile)
    return true
  }

  function canLoad(verbose = false, country = null)
  {
    if (isLoading)
      return false
    country = (country == null) ? ::get_profile_info().country : country
    if (!(country in presets) || !::isInMenu() || !::queues.isCanModifyCrew())
      return false
    if (!::isCountryAllCrewsUnlockedInHangar(country))
    {
      if (verbose)
        ::showInfoMsgBox(::loc("charServer/updateError/52"), "slotbar_presets_forbidden")
      return false
    }
    return true
  }

  function canLoadPreset(preset, isSilent = false)
  {
    if (!preset)
      return false
    if (::SessionLobby.isInvalidCrewsAllowed())
      return true

    foreach (unitName in preset.units)
    {
      local unit = ::getAircraftByName(unitName)
      if (unit && ::SessionLobby.isUnitAllowed(unit))
        return true
    }

    if (!isSilent)
      ::showInfoMsgBox(::loc("msg/cantUseUnitInCurrentBattle",
                       { unitName = ::colorize("userlogColoredText", preset.title) }))
    return false
  }

  function load(idx, countryId = null, skipGameModeSelect = false)
  {
    if (!canLoad())
      return false

    if (countryId == null)
      countryId = ::get_profile_info().country

    save(countryId) //save current preset slotbar changes

    local preset = ::getTblValue(idx, presets[countryId])
    if (!canLoadPreset(preset))
      return false

    if (!preset.enabled)
      return false

    local countryIdx = -1
    local countryCrews = []
    foreach (cIdx, tbl in ::get_crew_info())
      if (tbl.country == countryId)
      {
        countryIdx = cIdx
        countryCrews = tbl.crews
        break
      }
    if (countryIdx == -1 || !countryCrews.len())
      return false

    local unitsList = {}
    local selUnitId = ""
    local selCrewIdx = 0
    foreach (crewIdx, crew in countryCrews)
    {
      local crewTrainedUnits = ::getTblValue("trained", crew, [])
      foreach (i, unitId in preset.units)
      {
        local crewId = preset.crews[i]
        if (crewId == crew.id)
        {
          local unit = ::getAircraftByName(unitId)
          if (unit && unit.isInShop && ::isUnitUsable(unit)
              && (!unit.trainCost || ::isInArray(unitId, crewTrainedUnits))
              && !(unitId in unitsList))
          {
            unitsList[unitId] <- crewId
            if (preset.selected == crewId)
            {
              selUnitId = unitId
              selCrewIdx = crewIdx
            }
          }
        }
      }
    }

    // Sometimes preset can consist of only invalid units (like expired rented units), so here
    // we automatically overwrite this permanently unloadable preset with valid one.
    if (!unitsList.len())
    {
      local p = createEmptyPreset(countryId)
      foreach (i, unitId in p.units)
      {
        unitsList[unitId] <- p.crews[i]
        selUnitId = unitId
        selCrewIdx = i
      }
    }

    local tasksData = []
    foreach (crew in countryCrews)
    {
      local curUnitId = ::getTblValue("aircraft", crew, "")
      local unitId = ""
      foreach (uId, crewId in unitsList)
        if (crewId == crew.id)
          unitId = uId
      if (unitId != curUnitId)
        tasksData.append({crewId = crew.id, airName = unitId})
    }

    isLoading = true // Blocking slotbar content and game mode id from overwritting during 'batch_train_crew' call.

    ::g_crews_list.suspendSlotbarUpdates()
    ::batch_train_crew(tasksData, { showProgressBox = true },
      (@(idx, countryIdx, countryId, selCrewIdx, selUnitId, skipGameModeSelect, preset) function () {
        onTrainCrewTasksSuccess(idx, countryIdx, countryId, selCrewIdx, selUnitId, skipGameModeSelect, preset)
      })(idx, countryIdx, countryId, selCrewIdx, selUnitId, skipGameModeSelect, preset),
      function (taskResult = -1) {
        ::g_crews_list.flushSlotbarUpdate()
        onTrainCrewTasksFail()
      },
      ::slotbarPresets)

    return true
  }

  function onTrainCrewTasksSuccess(idx, countryIdx, countryId, selCrewIdx, selUnitId, skipGameModeSelect, preset)
  {
    selected[countryId] = idx

    ::crews_list = ::get_crew_info() //slotbar updates suspended, so no one to refresh this list.
    ::select_crew(countryIdx, selCrewIdx, true)
    ::g_crews_list.flushSlotbarUpdate()

    // Game mode select is performed only
    // after successful slotbar vehicles change.
    if (!skipGameModeSelect)
    {
      local gameModeId = ::getTblValue("gameModeId", preset, "")
      local gameMode = ::game_mode_manager.getGameModeById(gameModeId)
      // This means that some game mode id is
      // linked to preset but can not be found.
      if (gameMode == null && gameModeId != "")
      {
        gameModeId = ::game_mode_manager.findCurrentGameModeId(true)
        gameMode = ::game_mode_manager.getGameModeById(gameModeId)
      }

      // If game mode is not valid for preset
      // we will try to find better one.
      if (gameMode != null && !::game_mode_manager.isPresetValidForGameMode(preset, gameMode))
      {
        local betterGameModeId = ::game_mode_manager.findCurrentGameModeId(true, gameMode.diffCode)
        if (betterGameModeId != null)
          gameMode = ::game_mode_manager.getGameModeById(betterGameModeId)
      }

      if (gameMode != null)
        ::game_mode_manager.setCurrentGameModeById(gameMode.id)
    }

    isLoading = false
    save(countryId)

    ::broadcastEvent("SlotbarPresetLoaded", { crewsChanged = true })
  }

  function onTrainCrewTasksFail()
  {
    isLoading = false
  }

  function getPresetsList(countryId)
  {
    local list = []
    local blk = ::loadLocalByAccount("slotbar_presets/" + countryId)
    if (blk)
    {
      local presetsBlk = blk % "preset"
      foreach (idx, strPreset in presetsBlk)
      {
        local data = ::g_string.split(strPreset, "|")
        if (data.len() < 3)
          continue
        local preset = _createPresetTemplate(idx)
        preset.selected = ::to_integer_safe(data[0], -1)
        local title = validatePresetName(::getTblValue(3, data, ""))
        if (title.len())
          preset.title = title
        preset.gameModeId = ::getTblValue(4, data, "")

        local unitNames = ::g_string.split(data[2], ",")
        local crewIds = ::g_string.split(data[1], ",")
        if (!unitNames.len() || unitNames.len() != crewIds.len())
          continue

        //validate crews and units
        for(local i = 0; i < unitNames.len(); i++)
        {
          local unitName = unitNames[i]
          local crewId = ::to_integer_safe(crewIds[i], -1)
          if (!::getAircraftByName(unitName) || crewId < 0)
            continue

          preset.units.append(unitName)
          preset.crews.append(crewId)
        }

        if (!preset.units.len())
          continue

        _updateInfo(preset)
        list.append(preset)
        if (list.len() == getMaxPresetsCount(countryId))
          break
      }
    }
    if (!list.len())
      list.append(createPresetFromSlotbar(countryId))
    return list
  }

  function _createPresetTemplate(presetIdx)
  {
    return {
      units = []
      crews = []
      selected = -1
      title = ::loc("shop/slotbarPresets/item", { number = presetIdx + 1 })
      gameModeId = ""

      unitTypesMask = 0
      enabled = true
    }
  }

  function _updateInfo(preset)
  {
    local unitTypesMask = 0
    foreach (unitId in preset.units)
    {
      local unit = ::getAircraftByName(unitId)
      local unitType = unit ? ::get_es_unit_type(unit) : ::ES_UNIT_TYPE_INVALID
      if (unitType != ::ES_UNIT_TYPE_INVALID)
        unitTypesMask = unitTypesMask | (1 << unitType)
    }

    local enabled = ::has_feature("Tanks") || (unitTypesMask != (1 << ::ES_UNIT_TYPE_TANK))

    preset.unitTypesMask = unitTypesMask
    preset.enabled = enabled

    return preset
  }

  function updatePresetFromSlotbar(preset, countryId)
  {
    if (isLoading)
      return

    ::init_selected_crews()
    preset.units = []
    preset.crews = []
    foreach (tbl in ::crews_list)
      if (tbl.country == countryId)
      {
        foreach (crew in tbl.crews)
          if (("aircraft" in crew))
          {
            preset.units.append(crew.aircraft)
            preset.crews.append(crew.id)
            if (preset.selected == -1 || crew.idInCountry == ::selected_crews[crew.idCountry])
              preset.selected = crew.id
          }
      }

    if (countryId == ::get_profile_info().country)
    {
      local curGameModeId = ::game_mode_manager.getCurrentGameModeId()
      if (curGameModeId)
        preset.gameModeId = curGameModeId
    }

    _updateInfo(preset)
    return preset
  }

  function createPresetFromSlotbar(countryId, presetIdx = 0)
  {
    return updatePresetFromSlotbar(_createPresetTemplate(presetIdx), countryId)
  }

  function createEmptyPreset(countryId, presetIdx = 0)
  {
    local crews_list = ::get_crew_info()
    foreach (tbl in crews_list)
      if (tbl.country == countryId)
      {
        local unitId = tbl.crews[0].trained[0]

        if (!::has_feature("Tanks") && ::isTank(::getAircraftByName(unitId)))
          foreach (id in tbl.crews[0].trained)
            if (!::isTank(::getAircraftByName(id)))
            {
              unitId = id
              break
            }

        local preset = _createPresetTemplate(presetIdx)
        local crewId = tbl.crews[0].id
        preset.units = [ unitId ]
        preset.crews = [ crewId ]
        preset.selected = crewId
        _updateInfo(preset)
        return preset
      }
    return _createPresetTemplate(presetIdx)
  }
}

::g_script_reloader.registerPersistentDataFromRoot("slotbarPresets")
::subscribe_handler(::slotbarPresets)
