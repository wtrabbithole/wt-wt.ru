function gui_choose_slotbar_preset(owner = null)
{
  return ::handlersManager.loadHandler(::gui_handlers.ChooseSlotbarPreset, { owner = owner })
}

class ::gui_handlers.ChooseSlotbarPreset extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/slotbar/slotbarChoosePreset.blk"

  owner = null
  presets = []
  activePreset = null
  chosenValue = -1

  function initScreen()
  {
    reinit(null, true)
    initFocusArray()
  }

  function reinit(showPreset = null, verbose = false)
  {
    if (!::slotbarPresets.canLoad(verbose))
      return goBack()

    presets = ::slotbarPresets.list()
    activePreset = ::slotbarPresets.getCurrent()
    chosenValue = showPreset != null ? showPreset : activePreset != null ? activePreset : -1

    local objPresets = scene.findObject("items_list")
    if (!::checkObj(objPresets))
      return

    local view = { items = [] }
    foreach (idx, preset in presets)
    {
      local title = preset.title
      if (idx == activePreset)
        title += ::nbsp + ::loc("shop/current")

      view.items.append({
        itemTag = preset.enabled ? "mission_item_unlocked" : "mission_item_locked"
        id = "preset" + idx
        isSelected = idx == chosenValue
        itemText = title
      })
    }

    local data = ::handyman.renderCached("gui/missions/missionBoxItemsList", view)
    guiScene.replaceContentFromText(objPresets, data, data.len(), this)
    onItemSelect(objPresets)
  }

  function getMainFocusObj()
  {
    return scene.findObject("items_list")
  }

  function updateDescription()
  {
    local objDesc = scene.findObject("item_desc")
    if (!::checkObj(objDesc))
      return

    if (chosenValue in presets)
    {
      local preset = presets[chosenValue]
      local hasFeatureTanks = ::has_feature("Tanks")
      local perRow = 3
      local cells = ceil(preset.units.len() / perRow.tofloat()) * perRow
      local unitItems = []

      local presetBattleRatingText = ""
      if (::has_feature("SlotbarShowBattleRating"))
      {
        local ediff = getCurrentEdiff()
        local battleRatingMin = 0
        local battleRatingMax = 0
        foreach (unitId in preset.units)
        {
          local br = ::get_unit_battle_rating_by_mode(::getAircraftByName(unitId), ediff)
          battleRatingMin = !battleRatingMin ? br : ::min(battleRatingMin, br)
          battleRatingMax = !battleRatingMax ? br : ::max(battleRatingMax, br)
        }
        local battleRatingRange = ::format("%.1f %s %.1f", battleRatingMin, ::loc("ui/mdash"), battleRatingMax)
        presetBattleRatingText = ::loc("shop/battle_rating") + ::loc("ui/colon") + battleRatingRange + "~n"
      }

      local data = ::format("textarea{ text:t='%s' padding:t='-1@textPaddingBugWorkaround, 8*@sf/@pf' } ",
        ::stripTags(presetBattleRatingText) +
        ::loc("shop/slotbarPresets/contents") + ::loc("ui/colon"))
      data += "table{ class:t='slotbarPresetsTable' "
      for (local r = 0; r < cells / perRow; r++)
      {
        data += "tr{ "
        for (local c = 0; c < perRow; c++)
        {
          local idx = r * perRow + c
          local unitId = idx < preset.units.len() ? preset.units[idx] : ""
          local unit = unitId == "" ? null : ::getAircraftByName(unitId)
          local params = {
            active = false
            status = (hasFeatureTanks || !::isTank(::getAircraftByName(unitId))) ? "owned" : "locked"
            showBR = ::has_feature("SlotbarShowBattleRating")
            getEdiffFunc = getCurrentEdiff.bindenv(this)
          }
          data += unit ? ::build_aircraft_item(unitId, unit, params) : ""
          if (unit)
            unitItems.append({ id = unitId, unit = unit, params = params })
        }
        data += "}"
      }
      data += "}"

      if (!preset.enabled)
        data += ::format("textarea{ text:t='%s' padding:t='-1@textPaddingBugWorkaround, 8*@sf/@pf' } ",
          ::colorize("badTextColor", ::stripTags(::loc("shop/slotbarPresets/forbidden/unitTypes"))))

      guiScene.replaceContentFromText(objDesc, data, data.len(), this)
      foreach (unitItem in unitItems)
        ::fill_unit_item_timers(objDesc.findObject(unitItem.id), unitItem.unit, unitItem.params)
    }
    else
    {
      local data = ::format("textarea{ text:t='%s' width:t='pw' } ", ::stripTags(::loc("shop/slotbarPresets/presetUnknown")))
      guiScene.replaceContentFromText(objDesc, data, data.len(), this)
    }

    updateButtons()
  }

  function updateButtons()
  {
    local isAnyPresetSelected = chosenValue != -1
    local isCurrentPresetSelected = chosenValue == activePreset
    local isNonCurrentPresetSelected = isAnyPresetSelected && !isCurrentPresetSelected
    local selectedPresetEnabled = isCurrentPresetSelected || ((chosenValue in presets) ? presets[chosenValue].enabled : false)

    ::enableBtnTable(scene, {
        btn_preset_delete = ::slotbarPresets.canErase()  && isNonCurrentPresetSelected
        btn_preset_load   = ::slotbarPresets.canLoad()   && isAnyPresetSelected && selectedPresetEnabled
        btn_preset_move_up= isAnyPresetSelected && chosenValue > 0
        btn_preset_move_dn= isAnyPresetSelected && chosenValue < presets.len() - 1
    })

    local objBtn = scene.findObject("btn_preset_load")
    if (::checkObj(objBtn))
      objBtn.text = ::loc(isNonCurrentPresetSelected ? "mainmenu/btnApply" : "mainmenu/btnClose")
  }

  function onItemSelect(obj)
  {
    local objPresets = scene.findObject("items_list")
    if (!::checkObj(objPresets))
      return
    chosenValue = objPresets.getValue()
    updateDescription()
  }

  function onBtnPresetAdd(obj)
  {
    if (::slotbarPresets.canCreate())
      ::slotbarPresets.create()
    else
    {
      local reason = ::slotbarPresets.havePresetsReserve() ?
                              ::loc("shop/slotbarPresetsReserve",
                                { tier = ::roman_numerals[::slotbarPresets.eraIdForBonus],
                                  unitTypes = ::slotbarPresets.getPresetsReseveTypesText()})
                             :
                              ::loc("shop/slotbarPresetsMax")

      showInfoMsgBox(::format(::loc("weaponry/action_not_allowed"), reason))
    }
  }

  function onBtnPresetDelete(obj)
  {
    if (!::slotbarPresets.canErase() || !(chosenValue in presets))
      return

    local preset = presets[chosenValue]
    local msgText = ::loc("msgbox/genericRequestDelete", { item = preset.title })

    local unitNames = []
    foreach (unitId in preset.units)
      unitNames.append(::loc(unitId + "_shop"))
    local comment = "(" + ::loc("shop/slotbarPresets/contents") + ::loc("ui/colon") + ::implode(unitNames, ::loc("ui/comma")) + ")"
    comment = ::format("textarea{overlayTextColor:t='bad'; text:t='%s'}", ::stripTags(comment))

    msgBox("question_delete_preset", msgText,
    [
      ["delete", (@(chosenValue) function() { ::slotbarPresets.erase(chosenValue) })(chosenValue) ],
      ["cancel", function() {} ]
    ], "cancel", { data_below_text = comment })
  }

  function onBtnPresetLoad(obj)
  {
    local handler = this
    checkedCrewModify((@(handler, chosenValue) function () {
      if (::slotbarPresets.canLoad())
        if (chosenValue in presets)
        {
          ::slotbarPresets.load(chosenValue)
          handler.goBack()
        }
    })(handler, chosenValue))
  }

  function onBtnPresetMoveUp(obj)
  {
    ::slotbarPresets.move(chosenValue, -1)
  }

  function onBtnPresetMoveDown(obj)
  {
    ::slotbarPresets.move(chosenValue, 1)
  }

  function onBtnPresetRename(obj)
  {
    ::slotbarPresets.rename(chosenValue)
  }

  function onStart(obj)
  {
    onBtnPresetLoad(obj)
  }

  function onEventSlotbarPresetLoaded(params)
  {
    reinit()
  }

  function onEventSlotbarPresetsChanged(params)
  {
    reinit(::getTblValue("showPreset", params, -1))
  }
}

//------------------------------------------------------------------------------

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
    return ::implode(typeNames, ", ")
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

    ::batch_train_crew(tasksData, { showProgressBox = true },
      (@(idx, countryIdx, countryId, selCrewIdx, selUnitId, skipGameModeSelect, preset) function () {
        onTrainCrewTasksSuccess(idx, countryIdx, countryId, selCrewIdx, selUnitId, skipGameModeSelect, preset)
      })(idx, countryIdx, countryId, selCrewIdx, selUnitId, skipGameModeSelect, preset),
      function (taskResult = -1) {
        onTrainCrewTasksFail()
      },
      ::slotbarPresets)

    return true
  }

  function onTrainCrewTasksSuccess(idx, countryIdx, countryId, selCrewIdx, selUnitId, skipGameModeSelect, preset)
  {
    isLoading = false
    selected[countryId] = idx

    local handler = ::handlersManager.getActiveBaseHandler()
    if (handler && ("showAircraft" in handler))
      handler.showAircraft(selUnitId) //!!FIX ME: unit must to update self by event
    ::select_crew(countryIdx, selCrewIdx, true)

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
