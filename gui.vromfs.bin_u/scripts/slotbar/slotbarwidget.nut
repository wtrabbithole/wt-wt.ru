local callback = ::require("sqStdLibs/helpers/callback.nut")
local Callback = callback.Callback

class ::gui_handlers.SlotbarWidget extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "gui/slotbar/slotbar.blk"
  ownerWeak = null

  //slotbar config
  singleCountry = null //country name to show it alone in slotbar
  crewId = null //crewId to force select. reset after init
  shouldSelectCrewRecruit = false //should select crew recruit slot on create slotbar.
  limitCountryChoice = false //When true, not allow to change country, but show all countries.
                               //(look like it almost duplicate of singleCountry)
  customCountry = null //country name for limitCountryChoice mode.
  showTopPanel = true  //need to show panel with repair checkboxes. ignored in singleCountry or limitCountryChoice modes
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
  eventId = null //string. Used to check unit availability

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
      refreshAll()
  }

  function validateParams()
  {
    showNewSlot = showNewSlot ?? !singleCountry
    showEmptySlot = showEmptySlot ?? !singleCountry
    hasExtraInfoBlock = hasExtraInfoBlock ?? !singleCountry
    shouldSelectAvailableUnit = shouldSelectAvailableUnit ?? ::is_in_flight()
    needPresetsPanel = needPresetsPanel ?? !singleCountry && !limitCountryChoice
    shouldCheckQueue = shouldCheckQueue ?? !::is_in_flight()

    onSlotDblClick = onSlotDblClick
      ?? function(crew) {
           local unit = ::g_crew.getCrewUnit(crew)
           if (unit)
             ::open_weapons_for_unit(unit)
         }

    //update callbacks
    foreach(funcName in ["beforeSlotbarSelect", "afterSlotbarSelect", "onSlotDblClick", "onCountryChanged",
        "beforeFullUpdate", "afterFullUpdate", "onSlotBattleBtn"])
      if (this[funcName])
        this[funcName] = callback.make(this[funcName], ownerWeak)
  }

  function refreshAll()
  {
    ::init_slotbar(this, scene, this)
    if (crewId != null)
      crewId = null
    if (ownerWeak) //!!FIX ME: Better to presets list self catch canChangeCrewUnits
      ownerWeak.setSlotbarPresetsListAvailable(needPresetsPanel && ::SessionLobby.canChangeCrewUnits())
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
      beforeSlotbarSelect(
        Callback(@() ::check_obj(obj) && applySlotSelection(obj, selSlot), this),
        Callback(@() curSlotCountryId == selSlot.countryId && ::check_obj(obj)
            && selectTblAircraft(obj, curSlotIdInCountry),
          this),
        selSlot
      )
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

    local needActionsWithEmptyCrews = needActionsWithEmptyCrews
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
    else if (crew && ("aircraft" in crew))
    {
      showAircraft(crew.aircraft)
      select_crew(curSlotCountryId, curSlotIdInCountry)
    }
    else if (needActionsWithEmptyCrews && crew && !("aircraft" in crew))
      onSlotChangeAircraft()

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
    if (::slotbar_oninit || skipCheckCountrySelect)
    {
      onSlotbarCountryImpl(obj)
      skipCheckCountrySelect = false
    }
    else if (!shouldCheckQueue)
    {
      if (checkSelectCountryByIdx(obj))
        onSlotbarCountryImpl(obj)
    }
    else
    {
      if (!checkSelectCountryByIdx(obj))
        return

      checkedCrewModify((@(obj) function() {
          if (::checkObj(obj))
            onSlotbarCountryImpl(obj)
        })(obj),
        (@(obj) function() {
          if (::checkObj(obj))
            setCountry(::get_profile_info().country)
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

  function onSlotbarCountryImpl(obj)
  {
    if (!::checkObj(obj))
      return

    local curValue = obj.getValue()
    if (obj.childrenCount() <= curValue)
      return

    local countryIdx = ::to_integer_safe(
      ::getObjIdByPrefix(obj.getChild(curValue), "slotbar-country"), curSlotCountryId)

    if (!singleCountry)
    {
      if (!checkSelectCountryByIdx(obj))
        return

      onSlotbarSelect(obj.findObject("airs_table_"+countryIdx))
      local c = ::g_crews_list.get()[countryIdx].country
      ::switch_profile_country(c)
    }
    else
      onSlotbarSelect(obj.findObject("airs_table_"+countryIdx))

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
        || ::g_crews_list.get()[curSlotCountryId].country != ::get_profile_info().country
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

      local box = ::GuiBox().setFromDaguiObj(obj.findObject("slots_header_"))
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