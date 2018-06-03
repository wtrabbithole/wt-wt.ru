local callback = ::require("sqStdLibs/helpers/callback.nut")
local Callback = callback.Callback

::slotbar_oninit <- false //!!FIX ME: Why this variable is global?

class ::gui_handlers.SlotbarWidget extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "gui/slotbar/slotbar.blk"
  ownerWeak = null

  //slotbar config
  singleCountry = null //country name to show it alone in slotbar
  crewId = null //crewId to force select. reset after init
  shouldSelectCrewRecruit = false //should select crew recruit slot on create slotbar.
  isCountryChoiceAllowed = true //When false, not allow to change country, but show all countries.
                               //(look like it almost duplicate of singleCountry)
  customCountry = null //country name when not isCountryChoiceAllowed mode.
  showTopPanel = true  //need to show panel with repair checkboxes. ignored in singleCountry or when not isCountryChoiceAllowed modes
  hasActions = true
  missionRules = null
  showNewSlot = null //bool
  showEmptySlot = null //bool
  emptyText = "#shop/chooseAircraft" //text to show on empty slot
  alwaysShowBorder = false //should show focus border when no show_console_buttons
  checkRespawnBases = false //disable slot when no available respawn bases for unit
  hasExtraInfoBlock = null //bool
  unitForSpecType = null //unit to show crew specializations
  shouldSelectAvailableUnit = null //bool
  needPresetsPanel = null //bool

  //!!FIX ME: Better to remove parameters group below, and replace them by isUnitEnabled function
  mainMenuSlotbar = false //is slotbar in mainmenu
  roomCreationContext = false //check enbled by roomCreation context
  availableUnits = null //available units table
  customUnitsList = null //custom units table to filter unsuitable units in unit selecting
  customUnitsListName = null //string. Custom list name for unit select option filter
  eventId = null //string. Used to check unit availability
  gameModeName = null //string. Custom mission name for unit select option filter

  toBattle = false //has toBattle button
  haveRespawnCost = false //!!FIX ME: should to take this from mission rules
  haveSpawnDelay = false  //!!FIX ME: should to take this from mission rules
  totalSpawnScore = -1 //to disable slots by spawn score //!!FIX ME: should to take this from mission rules
  sessionWpBalance = 0 //!!FIX ME: should to take this from mission rules

  shouldCheckQueue = null //bool.  should check queue before select unit. !::is_in_flight by default.
  needActionsWithEmptyCrews = true //allow create crew and choose unit to crew while select empty crews.
  beforeSlotbarSelect = null //function(onContinueCb, onCancelCb) to do before apply slotbar select.
                             //must call one of listed callbacks on finidh.
                             //when onContinueCb will be called, slotbar will aplly unit selection
                             //when onCancelCb will be called, slotbar will return selection to previous state
  afterSlotbarSelect = null //function() will be called after unit selection applied.
  onSlotDblClick = null //function(crew) when not set will open unit modifications window
  onCountryChanged = null //function()
  beforeFullUpdate = null //function()
  afterFullUpdate = null //function()
  onSlotBattleBtn = null //function()


  //******************************* self slotbar params ***********************************//
  isPrimaryFocus = false
  isSceneLoaded = false
  loadedCountries = null //loaded countries versions
  focusArray = [@() getFocusObj()]
  currentFocusItem = 0

  curSlotCountryId = -1
  curSlotIdInCountry = -1
  slotbarActions = null
  isShaded = false

  ignoreCheckSlotbar = false
  skipCheckCountrySelect = false
  skipCheckAirSelect = false

  static function create(params)
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

    return ::handlersManager.loadHandler(::gui_handlers.SlotbarWidget, params)
  }

  function destroy()
  {
    if (::check_obj(scene))
      guiScene.replaceContentFromText(scene, "", 0, null)
    scene = null
  }

  function initScreen()
  {
    loadedCountries = {}
    isSceneLoaded = true
    refreshAll()
  }

  function setParams(params)
  {
    base.setParams(params)
    if (ownerWeak)
      ownerWeak = ownerWeak.weakref()
    validateParams()
    if (isSceneLoaded)
    {
      loadedCountries.clear() //params can change visual style and visibility of crews
      refreshAll()
    }
  }

  function validateParams()
  {
    showNewSlot = showNewSlot ?? !singleCountry
    showEmptySlot = showEmptySlot ?? !singleCountry
    hasExtraInfoBlock = hasExtraInfoBlock ?? !singleCountry
    shouldSelectAvailableUnit = shouldSelectAvailableUnit ?? ::is_in_flight()
    needPresetsPanel = needPresetsPanel ?? !singleCountry && isCountryChoiceAllowed
    shouldCheckQueue = shouldCheckQueue ?? !::is_in_flight()

    onSlotDblClick = onSlotDblClick
      ?? function(crew) {
           local unit = ::g_crew.getCrewUnit(crew)
           if (unit)
             ::open_weapons_for_unit(unit, getCurrentEdiff())
         }

    //update callbacks
    foreach(funcName in ["beforeSlotbarSelect", "afterSlotbarSelect", "onSlotDblClick", "onCountryChanged",
        "beforeFullUpdate", "afterFullUpdate", "onSlotBattleBtn"])
      if (this[funcName])
        this[funcName] = callback.make(this[funcName], ownerWeak)
  }

  function refreshAll()
  {
    fillCountries()

    if (!singleCountry)
      ::set_show_aircraft(getCurSlotUnit())

    if (crewId != null)
      crewId = null
    if (ownerWeak) //!!FIX ME: Better to presets list self catch canChangeCrewUnits
      ownerWeak.setSlotbarPresetsListAvailable(needPresetsPanel && ::SessionLobby.canChangeCrewUnits())
  }

  function getForcedCountry() //return null if you have countries choice
  {
    if (singleCountry)
      return singleCountry
    if (!::SessionLobby.canChangeCountry())
      return ::get_profile_country_sq()
    if (!isCountryChoiceAllowed)
      return customCountry || ::get_profile_country_sq()
    return null
  }

  function addCrewData(list, params)
  {
    local crew = params?.crew
    local data = {
      crew = crew,
      unit = null,
      isUnlocked = true,
      status = bit_unit_status.owned
      idInCountry = crew?.idInCountry ?? -1 //for recruit slots, but correct for all
      idCountry = crew?.idCountry ?? -1         //for recruit slots, but correct for all
    }.__update(params)

    data.crewIdVisible <- list.len()

    local canSelectEmptyCrew = shouldSelectCrewRecruit || !needActionsWithEmptyCrews
    data.isSelectable <- (data.isUnlocked || !shouldSelectAvailableUnit) && (canSelectEmptyCrew || data.unit != null)
    local isControlledUnit = !::is_respawn_screen()
      && ::is_player_unit_alive()
      && ::get_player_unit_name() == data.unit?.name
    if (haveRespawnCost
        && data.isSelectable
        && data.unit
        && totalSpawnScore >= 0
        && (totalSpawnScore < data.unit.getSpawnScore() || totalSpawnScore < data.unit.getMinimumSpawnScore())
        && !isControlledUnit)
      data.isSelectable = false

    list.append(data)
    return data
  }

  function gatherVisibleCrewsConfig(onlyForCountryIdx = null)
  {
    local res = []
    local country = getForcedCountry()
    local needNewSlot = !::g_crews_list.isSlotbarOverrided && showNewSlot
    local needShowLockedSlots = missionRules == null || missionRules.needShowLockedSlots
    local needEmptySlot = !::g_crews_list.isSlotbarOverrided && needShowLockedSlots && showEmptySlot

    local crewsListFull = ::g_crews_list.get()
    for(local c = 0; c < crewsListFull.len(); c++)
    {
      if (onlyForCountryIdx != null && onlyForCountryIdx != c)
        continue

      local listCountry = crewsListFull[c].country
      if (singleCountry != null && singleCountry != listCountry
          || !::is_country_visible(listCountry))
        continue

      local countryData = {
        country = listCountry
        id = c
        isEnabled = !country || country == listCountry
        crews = []
      }
      res.append(countryData)

      if (!countryData.isEnabled)
        continue

      local crewsList = crewsListFull[c].crews
      foreach(crewIdInCountry, crew in crewsList)
      {
        local unit = ::g_crew.getCrewUnit(crew)

        if (!unit && !needEmptySlot)
          continue

        local unitName = unit?.name || ""
        local isUnitEnabledByRandomGroups = !missionRules || missionRules.isUnitEnabledByRandomGroups(unitName)
        local isUnlocked = ::isUnitUnlocked(this, unit, c, crewIdInCountry, country, true)
        local status = bit_unit_status.owned
        local isUnitForcedVisible = missionRules && missionRules.isUnitForcedVisible(unitName)
        if (unit)
        {
          if (!isUnlocked)
            status = bit_unit_status.locked
          else if (!::is_crew_slot_was_ready_at_host(crew.idInCountry, unit.name, true))
            status = bit_unit_status.broken
          else
          {
            local disabled = !::is_unit_enabled_for_slotbar(unit, this)
            if (checkRespawnBases)
              disabled = disabled || !::get_available_respawn_bases(unit.tags).len()
            if (disabled)
              status = bit_unit_status.disabled
          }
        }

        local isAllowedByLockedSlots = isUnitForcedVisible || needShowLockedSlots || status == bit_unit_status.owned
        if (unit && (!isAllowedByLockedSlots || !isUnitEnabledByRandomGroups))
          continue

        addCrewData(countryData.crews,
          { crew = crew, unit = unit, isUnlocked = isUnlocked, status = status })
      }

      if (!needNewSlot)
        continue

      local slotCostTbl = ::get_crew_slot_cost(listCountry)
      if (!slotCostTbl || slotCostTbl.costGold > 0 && !::has_feature("SpendGold"))
        continue

      addCrewData(countryData.crews,
        { idInCountry = crewsList.len()
          idCountry = c
          cost = ::Cost(slotCostTbl.cost, slotCostTbl.costGold)
        })
    }
    return res
  }

  //calculate selected crew and country by slotbar params
  function calcSelectedCrewData(crewsConfig)
  {
    local forcedCountry = getForcedCountry()
    local curPlayerCountry = forcedCountry || ::get_profile_country_sq()
    local curUnit = ::get_show_aircraft()
    local curCrewId = crewId
    local unitShopCountry = curPlayerCountry

    if (!forcedCountry && !curCrewId)
    {
      if (!::isCountryAvailable(unitShopCountry) && ::unlocked_countries.len() > 0)
        unitShopCountry = ::unlocked_countries[0]
      if (curUnit && curUnit.shopCountry != unitShopCountry)
        curUnit = null
    }
    else if (forcedCountry && curSlotIdInCountry >= 0)
    {
      local curCrew = ::getSlotItem(curSlotCountryId, curSlotIdInCountry)
      if (curCrew)
        curCrewId = curCrew.id
    }

    if (curCrewId || shouldSelectCrewRecruit)
      curUnit = null

    local isFoundCurUnit = false
    local selCrewData = null
    foreach(countryData in crewsConfig)
    {
      if (!countryData.isEnabled)
        continue

      //when current crew not available in this mission, first available crew will be selected.
      local firstAvailableCrewData = null
      local selCrewidInCountry = ::selected_crews?[countryData.id]
      foreach(crewData in countryData.crews)
      {
        local crew = crewData.crew
        local unit = crewData.unit
        local isSelectable = crewData.isSelectable
        if (crew && curCrewId == crew.id
          || unit && unit == curUnit
          || !crew && shouldSelectCrewRecruit)
        {
          selCrewData = crewData
          isFoundCurUnit = true
          if (isSelectable)
            break
        }

        if (isSelectable
          && (!firstAvailableCrewData || selCrewidInCountry == crew?.idInCountry))
          firstAvailableCrewData = crewData
      }

      if (isFoundCurUnit && selCrewData.isSelectable)
        break

      if (firstAvailableCrewData
          && (!selCrewData || !selCrewData.isSelectable || unitShopCountry == countryData.country))
        selCrewData = firstAvailableCrewData

      if (!selCrewData && countryData.crews.len())
        selCrewData = countryData.crews[0] //select not selectable when nothing found
    }

    return selCrewData
  }

  //get crew data selected in country (selected_crews[curSlotCountryId])
  function getSelectedCrewDataInCountry(countryData)
  {
    local selCrewData = null
    local selCrewIdInCountry = ::selected_crews?[countryData.id]
    foreach(crewData in countryData.crews)
    {
      if (crewData.idInCountry == selCrewIdInCountry)
      {
        selCrewData = crewData
        break
      }

      if (!selCrewData || crewData.isSelectable && !selCrewData.isSelectable)
        selCrewData = crewData
    }
    return selCrewData
  }

  function fillCountries()
  {
    if (!::g_login.isLoggedIn())
      return
    if (::slotbar_oninit)
    {
      ::script_net_assert_once("slotbar recursion", "init_slotbar: recursive call found")
      return
    }

    if (!::g_crews_list.get().len())
    {
      if (::g_login.isLoggedIn() && (::isProductionCircuit() || ::get_cur_circuit_name() == "nightly"))
        ::scene_msg_box("no_connection", null, ::loc("char/no_connection"), [["ok", function () {::gui_start_logout()}]], "ok")
      return
    }

    ::slotbar_oninit = true

    ::init_selected_crews()
    ::update_crew_skills_available()
    local crewsConfig = gatherVisibleCrewsConfig()
    local selCrewData = calcSelectedCrewData(crewsConfig)

    guiScene.setUpdatesEnabled(false, false);
    scene["singleCountry"] = singleCountry ? "yes" : "no"

    local isFullSlotbar = crewsConfig.len() > 1
    if (isFullSlotbar && showTopPanel)
      ::initSlotbarTopBar(scene, true) //show autorefill checkboxes

    local countriesObj = scene.findObject("slotbar-countries")
    countriesObj.hasBackground = isFullSlotbar ? "no" : "yes"
    local hObj = scene.findObject("slotbar_background")
    hObj.show(isFullSlotbar)
    if (::show_console_buttons)
      ::showBtn("slotbar_nav_block", isFullSlotbar, scene)

    local selCountryIdx = 0
    foreach(idx, countryData in crewsConfig)
    {
      local country = countryData.country
      if (countryData.id == selCrewData?.idCountry)
        selCountryIdx = idx

      local itemName = "slotbar-country" + countryData.id
      local itemObj = null
      local prevObjStrIdx = null
      if (countriesObj.childrenCount() > idx)
      {
        itemObj = countriesObj.getChild(idx)
        prevObjStrIdx = ::getObjIdByPrefix(itemObj, "slotbar-country")
        itemObj.id = itemName
      }
      else
      {
        local itemText = format("slotsOption { id:t='%s' _on_deactivate:t='restoreFocus'} ", itemName)
        guiScene.appendWithBlk(countriesObj, itemText, this)
        itemObj = countriesObj.findObject(itemName)
        guiScene.replaceContent(itemObj, "gui/slotbar/slotbarItem.blk", this)
      }

      //update item main part (what visible even when not selected)
      itemObj.enable(countryData.isEnabled)

      local cTooltipObj = itemObj.findObject("tooltip_country_")
      if (cTooltipObj)
        cTooltipObj.id = "tooltip_" + country

      local cUnlocked = ::isCountryAvailable(country)
      itemObj.inactive = "no"
      if (!cUnlocked)
      {
        itemObj.inactive = "yes"
        itemObj.tooltip = ::loc("mainmenu/countryLocked/tooltip")
      }

      local cImg = ::get_country_icon(country, false, !cUnlocked)
      itemObj.findObject("hdr_image")["background-image"] = cImg
      itemObj.findObject("hdr_block").tooltip = ::loc(country)
      if (!::is_first_win_reward_earned(country, INVALID_USER_ID))
      {
        local mObj = itemObj.findObject("hdr_bonus")
        showCountryBonus(mObj, country)
      }
      fillCountryInfo(itemObj, country)
      if (::has_feature("SlotbarShowCountryName"))
        itemObj.findObject("hdr_caption").setValue(::getVerticalText(::loc(country + "/short", "")))


      //update item secondary part
      local tblObj = itemObj.findObject(prevObjStrIdx ? "airs_table_" + prevObjStrIdx : "airs_table")
      tblObj.id = "airs_table_" + countryData.id
      tblObj.alwaysShowBorder = alwaysShowBorder ? "yes" : "no"

      if ((!selCrewData && !idx) || countryData.id == selCrewData?.idCountry)
        fillCountryContent(countryData, tblObj, selCrewData)
    }

    if (crewsConfig.len())
      countriesObj.setValue(selCountryIdx)

    if (selCrewData)
    {
      local selItem = ::get_slot_obj(countriesObj, selCrewData.idCountry, selCrewData.idInCountry)
      if (selItem)
        guiScene.performDelayed(this, function() {
          if (::check_obj(selItem) && selItem.isVisible())
            selItem.scrollToView()
        })
    }

    guiScene.setUpdatesEnabled(true, true);
    ::slotbar_oninit = false

    if (crewsConfig.len() > 1)
      initSlotbarAnim(countriesObj, guiScene)

    local needEvent = selCrewData
      && (curSlotCountryId >= 0 && curSlotCountryId != selCrewData.idCountry
        || curSlotIdInCountry >= 0 && curSlotIdInCountry != selCrewData.idInCountry)
    if (needEvent)
    {
      local cObj = scene.findObject("airs_table_" + selCrewData.idCountry)
      if (::check_obj(cObj))
      {
        skipCheckAirSelect = true
        onSlotbarSelect(cObj)
      }
    } else
    {
      curSlotCountryId   = selCrewData?.idCountry ?? -1
      curSlotIdInCountry = selCrewData?.idInCountry ?? -1
    }
  }

  function fillCountryContent(countryData, tblObj, selCrewData = null)
  {
    if (loadedCountries?[countryData.id] == ::g_crews_list.version
      || !::check_obj(tblObj))
      return

    loadedCountries[countryData.id] <- ::g_crews_list.version

    if (!selCrewData || selCrewData.idCountry != countryData.id)
      selCrewData = getSelectedCrewDataInCountry(countryData)

    local rowData = ""
    foreach(crewData in countryData.crews)
    {
      local id = ::get_slot_obj_id(countryData.id, crewData.idInCountry)
      local crew = crewData.crew
      if (!crew)
      {
        rowData += ::build_aircraft_item(
          id,
          null,
          {
            emptyText = "#shop/recruitCrew",
            crewImage = "#ui/gameuiskin#slotbar_crew_recruit_" + ::g_string.slice(countryData.country, 8)
            isCrewRecruit = true
            emptyCost = crewData.cost
            inactive = true
          })
        continue
      }

      local airParams = {
        emptyText      = emptyText,
        crewImage      = "#ui/gameuiskin#slotbar_crew_free_" + ::g_string.slice(countryData.country, 8)
        status         = ::getUnitItemStatusText(crewData.status),
        inactive       = ::show_console_buttons && crewData.status == bit_unit_status.locked && ::is_in_flight(),
        hasActions     = hasActions
        toBattle       = toBattle
        mainActionFunc = ::SessionLobby.canChangeCrewUnits() ? "onSlotChangeAircraft" : ""
        mainActionText = "" // "#multiplayer/changeAircraft"
        mainActionIcon = "#ui/gameuiskin#slot_change_aircraft.svg"
        crewId         = crew.id
        isSlotbarItem  = true
        showBR         = ::has_feature("SlotbarShowBattleRating")
        getEdiffFunc   = getCurrentEdiff.bindenv(this)
        hasExtraInfoBlock = hasExtraInfoBlock
        haveRespawnCost = haveRespawnCost
        haveSpawnDelay = haveSpawnDelay
        totalSpawnScore = totalSpawnScore
        sessionWpBalance = sessionWpBalance
        curSlotIdInCountry = crew.idInCountry
        curSlotCountryId = crew.idCountry
        unlocked = crewData.isUnlocked
        tooltipParams = { needCrewInfo = !::g_crews_list.isSlotbarOverrided }
        missionRules = missionRules
        forceCrewInfoUnit = unitForSpecType
      }

      rowData += ::build_aircraft_item(id, crewData.unit, airParams)
    }

    rowData = "tr { " + rowData + " } "

    guiScene.replaceContentFromText(tblObj, rowData, rowData.len(), this)

    if (selCrewData)
      ::gui_bhv.columnNavigator.selectCell(tblObj, 0, selCrewData.crewIdVisible, false)

    foreach(crewData in countryData.crews)
      if (crewData.unit)
      {
        local id = ::get_slot_obj_id(countryData.id, crewData.idInCountry)
        ::fill_unit_item_timers(tblObj.findObject(id), crewData.unit)
        local bonusId = ::get_slot_obj_id(countryData.id, crewData.idInCountry, true)
        ::showAirExpWpBonus(tblObj.findObject(bonusId), crewData.unit.name)
      }
  }

  function checkUpdateCountryInScene(countryIdx)
  {
    if (loadedCountries?[countryIdx] == ::g_crews_list.version)
      return

    local countryData = gatherVisibleCrewsConfig(countryIdx)?[0]
    if (countryData)
      fillCountryContent(countryData, scene.findObject("airs_table_" + countryData.id))
  }

  function getCurSlotUnit()
  {
    return ::getSlotAircraft(curSlotCountryId, curSlotIdInCountry)
  }

  function getCurCrew() //will return null when selected recruitCrew
  {
    return getSlotItem(curSlotCountryId, curSlotIdInCountry)
  }

  function getCurCountry()
  {
    return ::g_crews_list.get()?[curSlotCountryId]?.country ?? ""
  }

  function getCurrentEdiff()
  {
    if (::u.isFunction(ownerWeak?.getCurrentEdiff))
      return ownerWeak.getCurrentEdiff()
    return ::get_current_ediff()
  }

  function getSlotbarActions()
  {
    return slotbarActions || ownerWeak && ownerWeak.getSlotbarActions()
  }

  function getFocusObj()
  {
    return getCurrentAirsTable()
  }

  function getCurrentAirsTable()
  {
    return scene.findObject("airs_table_" + curSlotCountryId)
  }

  function getCurrentCrewSlot()
  {
    local airsTable = getCurrentAirsTable()
    if (!::check_obj(airsTable))
      return null

    if (airsTable.getChild(0).childrenCount() > curSlotIdInCountry)
      return airsTable.getChild(0).getChild(curSlotIdInCountry).getChild(1)
    return null
  }

  function getSlotIdByObjId(slotObjId, countryId)
  {
    local prefix = "td_slot_"+countryId+"_"
    if (!::g_string.startsWith(slotObjId, prefix))
      return -1
    return ::to_integer_safe(slotObjId.slice(prefix.len()), -1)
  }

  function getSelSlotDataByObj(obj)
  {
    local res = {
      isValid = false
      countryId = -1
      crewIdInCountry = -1
    }

    local countryIdStr = ::getObjIdByPrefix(obj, "airs_table_")
    if (!countryIdStr)
      return res
    res.countryId = countryIdStr.tointeger()

    local curCol = obj.cur_col.tointeger()
    if (curCol < 0)
      return res
    local trObj = obj.getChild(0)
    if (curCol >= trObj.childrenCount())
      return res

    local curTdId = trObj.getChild(curCol).id
    res.crewIdInCountry = getSlotIdByObjId(curTdId, res.countryId)
    res.isValid = res.crewIdInCountry >= 0
    return res
  }

  function onSlotbarSelect(obj)
  {
    if (!::checkObj(obj))
      return

    if (::slotbar_oninit || skipCheckAirSelect || !shouldCheckQueue)
    {
      onSlotbarSelectImpl(obj)
      skipCheckAirSelect = false
    }
    else
      checkedAirChange(
        (@(obj) function() {
          if (::checkObj(obj))
            onSlotbarSelectImpl(obj)
        })(obj),
        (@(obj) function() {
          if (::checkObj(obj))
          {
            skipCheckAirSelect = true
            selectTblAircraft(obj, ::selected_crews[curSlotCountryId])
          }
        })(obj)
      )
  }

  function onSlotbarSelectImpl(obj)
  {
    if (!::check_obj(obj))
      return

    local selSlot = getSelSlotDataByObj(obj)
    if (!selSlot.isValid)
      return
    if (curSlotCountryId == selSlot.countryId
        && curSlotIdInCountry == selSlot.crewIdInCountry)
      return

    if (beforeSlotbarSelect)
    {
      ignoreCheckSlotbar = true
      beforeSlotbarSelect(
        Callback(function()
        {
          ignoreCheckSlotbar = false
          if (::check_obj(obj))
            applySlotSelection(obj, selSlot)
        }, this),
        Callback(function()
        {
          ignoreCheckSlotbar = false
          if (curSlotCountryId != selSlot.countryId)
            setCountry(::g_crews_list.get()?[curSlotCountryId]?.country)
          else if (::check_obj(obj))
            selectTblAircraft(obj, curSlotIdInCountry)
        }, this),
        selSlot
      )
    }
    else
      applySlotSelection(obj, selSlot)
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

    local crew = getSlotItem(curSlotCountryId, curSlotIdInCountry)
    if (needActionsWithEmptyCrews && !crew && (curSlotCountryId in ::g_crews_list.get()))
    {
      local country = ::g_crews_list.get()[curSlotCountryId].country

      local rawCost = ::get_crew_slot_cost(country)
      local cost = rawCost && ::Cost(rawCost.cost, rawCost.costGold)
      if (cost && ::old_check_balance_msgBox(cost.wp, cost.gold))
      {
        if (cost > ::zero_money)
        {
          local msgText = format(::loc("shop/needMoneyQuestion_purchaseCrew"), cost.tostring())
          ignoreCheckSlotbar = true
          msgBox("need_money", msgText,
            [["ok", (@(country) function() {
                      ignoreCheckSlotbar = false
                      purchaseNewSlot(country)
                    })(country) ],
             ["cancel", (@(obj, curSlotCountryId) function() {
                          ignoreCheckSlotbar = false
                          selectTblAircraft(obj, ::selected_crews[curSlotCountryId])
                        })(obj, curSlotCountryId) ]
            ], "ok")
        }
        else
          purchaseNewSlot(country)
      }
      else
        selectTblAircraft(obj, ::selected_crews[curSlotCountryId])
    }
    else if (crew)
    {
      local unit = ::g_crew.getCrewUnit(crew)
      if (unit)
      {
        ::set_show_aircraft(unit)
        //need to send event when crew in country not changed, because main unit changed.
        ::select_crew(curSlotCountryId, curSlotIdInCountry, true)
      }
      else if (needActionsWithEmptyCrews)
        onSlotChangeAircraft()
    }

    if (hasActions)
    {
      local slotItem = ::get_slot_obj(obj, curSlotCountryId, ::to_integer_safe(obj.cur_col))
      openUnitActionsList(slotItem, true)
    }

    if (afterSlotbarSelect)
      afterSlotbarSelect()
  }

  /**
   * Selects crew in slotbar with specified id
   * as if player clicked slot himself.
   */
  function selectCrew(crewIdInCountry)
  {
    local objId = "airs_table_" + curSlotCountryId
    local obj = scene.findObject(objId)
    if (::checkObj(obj))
      selectTblAircraft(obj, crewIdInCountry)
  }

  function selectTblAircraft(tblObj, slotIdInCountry=0)
  {
    if (tblObj && tblObj.isValid() && slotIdInCountry >= 0)
    {
      local slotIdx = getSlotIdxBySlotIdInCountry(tblObj, slotIdInCountry)
      if (slotIdx < 0)
        return
      ::gui_bhv.columnNavigator.selectCell.call(::gui_bhv.columnNavigator, tblObj, 0, slotIdx)
    }
  }

  function getSlotIdxBySlotIdInCountry(tblObj, slotIdInCountry)
  {
    if (!tblObj.childrenCount())
      return -1
    if (tblObj.id != "airs_table_" + curSlotCountryId)
    {
      local tblObjId = tblObj.id
      local countryId = curSlotCountryId
      ::script_net_assert_once("bad slot country id", "Error: Try to select crew from wrong country")
      return -1
    }
    local slotListObj = tblObj.getChild(0)
    if (!::checkObj(slotListObj))
      return -1
    local prefix = "td_slot_" + curSlotCountryId +"_"
    for(local i = 0; i < slotListObj.childrenCount(); i++)
    {
      local id = ::getObjIdByPrefix(slotListObj.getChild(i), prefix)
      if (!id)
      {
        local objId = slotListObj.getChild(i).id
        ::script_net_assert_once("bad slot id", "Error: Bad slotbar slot id")
        continue
      }

      if (::to_integer_safe(id) == slotIdInCountry)
        return i
    }

    return -1
  }

  function onSlotbarDblClick()
  {
    onSlotDblClick(getCurCrew())
  }

  function checkSelectCountryByIdx(obj)
  {
    local idx = obj.getValue()
    local countryIdx = ::to_integer_safe(
      ::getObjIdByPrefix(obj.getChild(idx), "slotbar-country"), curSlotCountryId)
    if (curSlotCountryId >= 0 && curSlotCountryId != countryIdx && countryIdx in ::g_crews_list.get()
        && !::isCountryAvailable(::g_crews_list.get()[countryIdx].country) && ::isAnyBaseCountryUnlocked())
    {
      msgBox("notAvailableCountry", ::loc("mainmenu/countryLocked/tooltip"),
             [["ok", (@(obj) function() {
               if (::checkObj(obj))
                 obj.setValue(curSlotCountryId)
             })(obj) ]], "ok")
      return false
    }
    return true
  }

  function onSlotbarCountry(obj)
  {
    local countryData = getCountryDataByObject(obj)
    if (countryData)
      checkUpdateCountryInScene(countryData.idx)

    if (::slotbar_oninit || skipCheckCountrySelect)
    {
      onSlotbarCountryImpl(obj, countryData)
      skipCheckCountrySelect = false
      return
    }

    local lockedCountryData = ::g_world_war.getLockedCountryData()
      || ::g_squad_manager.getLockedCountryData()

    if (lockedCountryData && lockedCountryData.country != countryData.country)
    {
      setCountry(::get_profile_country_sq())
      ::showInfoMsgBox(lockedCountryData.reasonText)
    }
    else
      switchSlotbarCountry(obj, countryData)
  }

  function switchSlotbarCountry(obj, countryData)
  {
    if (!shouldCheckQueue)
    {
      if (checkSelectCountryByIdx(obj))
        onSlotbarCountryImpl(obj, countryData)
    }
    else
    {
      if (!checkSelectCountryByIdx(obj))
        return

      checkedCrewModify((@(obj) function() {
          if (::checkObj(obj))
            onSlotbarCountryImpl(obj, countryData)
        })(obj),
        (@(obj) function() {
          if (::checkObj(obj))
            setCountry(::get_profile_country_sq())
        })(obj))
    }
  }

  function setCountry(country)
  {
    foreach(idx, c in ::g_crews_list.get())
      if (c.country == country)
      {
        local cObj = scene.findObject("slotbar-countries")
        if (cObj && cObj.getValue()!=idx)
        {
          skipCheckCountrySelect = true
          skipCheckAirSelect = true
          cObj.setValue(idx)
        }
        break
      }
  }

  function getCountryDataByObject(obj)
  {
    if (!::check_obj(obj))
      return null

    local curValue = obj.getValue()
    if (obj.childrenCount() <= curValue)
      return null

    local countryIdx = ::to_integer_safe(
      ::getObjIdByPrefix(obj.getChild(curValue), "slotbar-country"), curSlotCountryId)
    local country = ::g_crews_list.get()[countryIdx].country

    return {
      idx = countryIdx
      country = country
    }
  }

  function onSlotbarCountryImpl(obj, countryData)
  {
    if (!::check_obj(obj) || !countryData)
      return

    if (!singleCountry)
    {
      if (!checkSelectCountryByIdx(obj))
        return

      ::switch_profile_country(countryData.country)
      onSlotbarSelect(obj.findObject("airs_table_" + countryData.idx))
    }
    else
      onSlotbarSelect(obj.findObject("airs_table_" + countryData.idx))

    onSlotbarCountryChanged()
  }

 function onSlotbarCountryChanged()
  {
    if (ownerWeak?.presetsListWeak)
      ownerWeak.presetsListWeak.update()
    if (onCountryChanged)
      onCountryChanged()
  }

  function prevCountry(obj) { switchCountry(-1) }

  function nextCountry(obj) { switchCountry(1) }

  function switchCountry(way)
  {
    if (singleCountry)
      return

    local hObj = scene.findObject("slotbar-countries")
    if (hObj.childrenCount() <= 1)
      return

    local curValue = hObj.getValue()
    local value = ::getNearestSelectableChildIndex(hObj, curValue, way)
    if(value != curValue)
      hObj.setValue(value)
  }

  function onSlotChangeAircraft()
  {
    local crew = getCurCrew()
    if (!crew)
      return

    local slotbar = this
    ignoreCheckSlotbar = true
    checkedCrewAirChange(function() {
        ignoreCheckSlotbar = false
        ::gui_start_select_unit(crew, slotbar)
      },
      function() {
        ignoreCheckSlotbar = false
        checkSlotbar()
      }
    )
  }

  function nextSlot(way)
  {
    local tblObj = scene.findObject("airs_table_" + curSlotCountryId)
    if (::check_obj(tblObj))
      ::gui_bhv.columnNavigator.selectColumn.call(::gui_bhv.columnNavigator, tblObj, way)
  }

  function onSlotbarNextAir() { nextSlot(1) }
  function onSlotbarPrevAir() { nextSlot(-1) }

  function shade(shouldShade)
  {
    if (isShaded == shouldShade)
      return

    isShaded = shouldShade
    local shadeObj = scene.findObject("slotbar_shade")
    if(::check_obj(shadeObj))
      shadeObj.animation = isShaded ? "show" : "hide"
    if (::show_console_buttons)
      showSceneBtn("slotbar_nav_block", !isShaded)
  }

  function forceUpdate()
  {
    updateSlotbarImpl()
  }

  function fullUpdate()
  {
    doWhenActiveOnce("updateSlotbarImpl")
  }

  function updateSlotbarImpl()
  {
    if (ignoreCheckSlotbar)
      return

    loadedCountries.clear()
    if (beforeFullUpdate)
      beforeFullUpdate()

    refreshAll()
    if (isSceneActiveNoModals() && ownerWeak)
      ownerWeak.restoreFocus()

    if (afterFullUpdate)
      afterFullUpdate()
  }

  function checkSlotbar()
  {
    if (ignoreCheckSlotbar || !::isInMenu())
      return

    if (!(curSlotCountryId in ::g_crews_list.get())
        || ::g_crews_list.get()[curSlotCountryId].country != ::get_profile_country_sq()
        || curSlotIdInCountry != ::selected_crews[curSlotCountryId])
      updateSlotbarImpl()
  }

  function onSceneActivate(show)
  {
    base.onSceneActivate(show)
    if (checkActiveForDelayedAction())
      checkSlotbar()
  }

  function onEventModalWndDestroy(p)
  {
    base.onEventModalWndDestroy(p)
    if (checkActiveForDelayedAction())
      checkSlotbar()
  }

  function purchaseNewSlot(country)
  {
    ignoreCheckSlotbar = true

    local onTaskSuccess = Callback(function()
    {
      ignoreCheckSlotbar = false
      onSlotChangeAircraft()
    }, this)

    local onTaskFail = Callback(function(result) { ignoreCheckSlotbar = false }, this)

    if (!::g_crew.purchaseNewSlot(country, onTaskSuccess, onTaskFail))
      ignoreCheckSlotbar = false
  }

  //return GuiBox of visible slotbar units
  function getBoxOfUnits()
  {
    local obj = scene.findObject("airs_table_" + curSlotCountryId)
    if (!::check_obj(obj))
      return null

    local box = ::GuiBox().setFromDaguiObj(obj)
    local pBox = ::GuiBox().setFromDaguiObj(obj.getParent())
    if (box.c2[0] > pBox.c2[0])
      box.c2[0] = pBox.c2[0] + pBox.c1[0] - box.c1[0]
    return box
  }

  //return GuiBox of visible slotbar countries
  function getBoxOfCountries()
  {
    local res = null
    for(local i = 0; i <= curSlotCountryId; i++)
    {
      local obj = scene.findObject("slotbar-country" + i)
      if (!::check_obj(obj))
        continue

      local box = ::GuiBox().setFromDaguiObj(obj.findObject("hdr_block"))
      if (res)
        res.addBox(box)
      else
        res = box
    }
    return res
  }

  function getSlotsData(unitId = null, crewId = -1, withEmptySlots = false)
  {
    local unitSlots = []
    foreach(countryId, countryData in ::g_crews_list.get())
      if (!singleCountry || countryData.country == singleCountry)
        foreach (idInCountry, crew in countryData.crews)
        {
          if (crewId != -1 && crewId != crew.id)
            continue
          local unit = ::g_crew.getCrewUnit(crew)
          if (unitId && unit && unitId != unit.name)
            continue
          local obj = ::get_slot_obj(scene, countryId, idInCountry)
          if (obj && (unit || withEmptySlots))
            unitSlots.append({
              unit      = unit
              crew      = crew
              countryId = countryId
              obj       = obj
            })
        }

    return unitSlots
  }

  function updateDifficulty(unitSlots = null)
  {
    unitSlots = unitSlots || getSlotsData()

    local showBR = ::has_feature("SlotbarShowBattleRating")
    local curEdiff = getCurrentEdiff()

    foreach (slot in unitSlots)
    {
      local obj = slot.obj.findObject("rank_text")
      if (::checkObj(obj))
      {
        local unitRankText = ::get_unit_rank_text(slot.unit, slot.crew, showBR, curEdiff)
        obj.setValue(unitRankText)
      }
    }
  }

  function updateCrews(unitSlots = null)
  {
    if (::g_crews_list.isSlotbarOverrided)
      return

    unitSlots = unitSlots || getSlotsData()

    foreach (slot in unitSlots)
    {
      slot.obj["crewStatus"] = ::get_crew_status(slot.crew)

      local obj = slot.obj.findObject("crew_level")
      if (::checkObj(obj))
      {
        local crewLevelText = slot.unit ? ::g_crew.getCrewLevel(slot.crew, ::get_es_unit_type(slot.unit)).tointeger().tostring() : ""
        obj.setValue(crewLevelText)
      }

      local obj = slot.obj.findObject("crew_spec")
      if (::check_obj(obj))
      {
        local crewSpecIcon = ::g_crew_spec_type.getTypeByCrewAndUnit(slot.crew, slot.unit).trainedIcon
        obj["background-image"] = crewSpecIcon
      }
    }
  }

  function onSlotBattle(obj)
  {
    if (onSlotBattleBtn)
      onSlotBattleBtn()
  }

  function onEventCrewsListChanged(p)
  {
    fullUpdate()
  }

  function onEventCrewSkillsChanged(params)
  {
    local crew = ::getTblValue("crew", params)
    if (crew)
      updateCrews(getSlotsData(null, crew.id))
  }

  function onEventQualificationIncreased(params)
  {
    local unit = ::getTblValue("unit", params)
    if (unit)
      updateCrews(getSlotsData(unit.name))
  }

  function onEventAutorefillChanged(params)
  {
    if (!("id" in params) || !("value" in params))
      return

    local obj = scene.findObject(params.id)
    if (obj && obj.getValue() != params.value)
      obj.setValue(params.value)
  }
}