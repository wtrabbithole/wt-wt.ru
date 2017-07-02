::missionBuilderVehicleConfigForBlk <- {}

class ::gui_handlers.MissionBuilder extends ::gui_handlers.GenericOptionsModal
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/options/genericOptionsModal.blk"
  sceneNavBlkName = "gui/navTestflight.blk"
  multipleInstances = false
  wndGameMode = ::GM_TEST_FLIGHT
  wndOptionsMode = ::OPTIONS_MODE_TRAINING
  applyAtClose = false
  afterCloseFunc = null

  notBoughtAircraft = null
  air = null
  isTestFlight = false
  isTacticalMapLoaded = false

  weaponsSelectorWeak = null

  slobarActions = ["autorefill", "aircraft", "crew", "weapons", "repair"]

  function initScreen()
  {
    air = ::show_aircraft
    if (!air)
      return goBack()

    ::gui_handlers.GenericOptions.initScreen.bindenv(this)()

    scene.findObject("btn_builder").setValue(::loc(isTestFlight? "mainmenu/btnBuilder" : "mainmenu/btnApply"))
    showSceneBtn("btn_select", isTestFlight)

    local needSlotbar = ::isUnitInSlotbar(air)
    if (needSlotbar)
    {
      scene.findObject("wnd_frame").size = "1@slotbarWidthFull, 1@maxWindowHeightWithSlotbar"
      scene.findObject("wnd_frame").pos = "50%pw-50%w, 1@battleBtnBottomOffset-h"
    }

    showSceneBtn("unit_weapons_selector", true)
    guiScene.applyPendingChanges(false)

    guiScene.setUpdatesEnabled(false, false)

    updateAircraft()

    guiScene.setUpdatesEnabled(true, true)

    local navObj = scene.findObject("nav-help")
    if (needSlotbar)
      ::init_slotbar(this, navObj)
    else
    {
      if(!notBoughtAircraft)
        notBoughtAircraft = ::show_aircraft

      local unitNestObj = scene.findObject("unit_nest")
      if (::checkObj(unitNestObj))
      {
        local airData = ::build_aircraft_item(air.name, air)
        guiScene.appendWithBlk(unitNestObj, airData, this)
        ::fill_unit_item_timers(unitNestObj.findObject(air.name), air)
      }
    }

    initFocusArray()

    local focusObj = getMainFocusObj2()
    focusObj.select()
    checkCurrentFocusItem(focusObj)
  }

  function getMainFocusObj()
  {
    return weaponsSelectorWeak && weaponsSelectorWeak.getMainFocusObj()
  }

  function getMainFocusObj2()
  {
    return scene.findObject("testflight_options")
  }

  function updateWeaponsSelector()
  {
    if (weaponsSelectorWeak)
    {
      weaponsSelectorWeak.setUnit(air)
      delayedRestoreFocus()
      return
    }

    local weaponryObj = scene.findObject("unit_weapons_selector")
    local handler = ::handlersManager.loadHandler(::gui_handlers.unitWeaponsHandler,
                                       { scene = weaponryObj
                                         unit = air
                                         parentHandlerWeak = this
                                         canChangeBulletsAmount = false
                                       })

    weaponsSelectorWeak = handler.weakref()
    registerSubHandler(handler)
    delayedRestoreFocus()
  }

  function getCantFlyText(unit)
  {
    return !unit.unitType.isAvailable() ? ::loc("mainmenu/unitTypeLocked") : unit.unitType.getTestFlightUnavailableText()
  }

  function updateOptionsArray()
  {
    options = [
      [::USEROPT_DIFFICULTY, "spinner"],
    ]
    if (::isAircraft(air))
    {
      options.append([::USEROPT_LIMITED_FUEL, "spinner"])
      options.append([::USEROPT_LIMITED_AMMO, "spinner"])
    }

    local skin_options = [
      [::USEROPT_SKIN, "spinner"]
    ]
    if (::has_feature("UserSkins"))
      skin_options.append([::USEROPT_USER_SKIN, "spinner"])

    local aircraft_options = [
      [::USEROPT_GUN_TARGET_DISTANCE, "spinner"],
      [::USEROPT_GUN_VERTICAL_TARGETING, "spinner"],
      [::USEROPT_BOMB_ACTIVATION_TIME, "spinner"],
      [::USEROPT_ROCKET_FUSE_DIST, "spinner"],
      [::USEROPT_LOAD_FUEL_AMOUNT, "spinner"],
    ]

    local common_options = [
      [::USEROPT_MODIFICATIONS, "spinner"],
      [::USEROPT_TIME, "spinner"],
      [::USEROPT_WEATHER, "spinner"],
    ]

    options.extend(skin_options)
    if (::isAircraft(air))
      options.extend(aircraft_options)

    options.extend(common_options)
    return options
  }

  function updateAircraft()
  {
    updateButtons()

    air = notBoughtAircraft? notBoughtAircraft : ::show_aircraft
    if (!air)
      return goBack()

    updateWeaponsSelector()

    local showOptions = isTestFlightAvailable()

    local optListObj = scene.findObject("optionslist")
    local textObj = scene.findObject("no_options_textarea")
    optListObj.show(showOptions)
    textObj.setValue(showOptions? "" : getCantFlyText(air))

    local hObj = scene.findObject("header_name")
    if (!::checkObj(hObj))
      return

    local headerText = (isTestFlight ? air.unitType.getTestFlightText() : ::loc("mainmenu/btnBuilder"))
      + " " + ::loc("ui/mdash") + " " + ::getUnitName(air.name)
    hObj.setValue(headerText)

    if (!showOptions)
      return

    updateOptionsArray()

    ::test_flight_aircraft <- air
    ::cur_aircraft_name = air.name
    ::aircraft_for_weapons = air.name
    ::set_gui_option(::USEROPT_AIRCRAFT, air.name)

    local container = create_options_container("testflight_options", options, true, true, true)
    guiScene.replaceContentFromText(optListObj, container.tbl, container.tbl.len(), this)

    optionsContainers = [container.descr]
    updateLinkedOptions()
  }

  function isBuilderAvailable()
  {
    return ::show_aircraft!=null && ::isUnitAvailableForGM(::show_aircraft, ::GM_BUILDER)
  }
  function isTestFlightAvailable()
  {
    return ::show_aircraft!=null && ::isTestFlightAvailable(::show_aircraft)
  }

  function updateButtons()
  {
    if (!::checkObj(scene))
      return

    scene.findObject("btn_builder").inactiveColor = (isBuilderAvailable() && ::isUnitInSlotbar(::show_aircraft))? "no" : "yes"
    scene.findObject("btn_select").inactiveColor = isTestFlightAvailable()? "no" : "yes"
    showSceneBtn("btn_inviteSquad", ::enable_coop_in_QMB && ::g_squad_manager.canInviteMember())
  }

  function onMissionBuilder()
  {
    if (!::g_squad_utils.canJoinFlightMsgBox({ isLeaderCanJoin = ::enable_coop_in_QMB }))
      return

    if (!::isUnitInSlotbar(::show_aircraft))
    {
      saveAircraftOptions()
      ::gui_start_modal_wnd(::gui_handlers.changeAircraftForBuilder, {owner = this, shopAir = ::show_aircraft})
      return
    }

    if (!isBuilderAvailable())
      return msgBox("not_available", ::loc("msg/builderOnlyForAircrafts"), [["ok", function() {} ]], "ok", { cancel_fn = function() {}})

    applyFunc = function()
    {
      saveAircraftOptions()

      ::gui_start_builder_screen2(this)
    }
    applyOptions()
  }

  function onApply(obj)
  {
    ::broadcastEvent("MissionBuilderApplied")

    if (::g_squad_manager.isNotAloneOnline())
      return onMissionBuilder()

    if (!isTestFlightAvailable())
      return msgBox("not_available", getCantFlyText(::show_aircraft), [["ok", function() {} ]], "ok", { cancel_fn = function() {}})

    if (::isInArray(getSceneOptValue(::USEROPT_DIFFICULTY), ["hardcore", "custom"]))
      if (!::check_diff_pkg(::g_difficulty.SIMULATOR.diffCode))
        return

    if (air)
      ::set_gui_option(::USEROPT_WEAPONS, ::get_last_weapon(air.name))

    applyFunc = function()
    {
      if (::get_gui_option(::USEROPT_DIFFICULTY) == "custom")
      {
        ::gui_start_cd_options(startTestFlight, this) // See "MissionDescriptor::loadFromBlk"
        doWhenActiveOnce("updateSceneDifficulty")
      }
      else
        startTestFlight()
    }
    applyOptions()
  }

  function onEventSquadStatusChanged(params)
  {
    updateButtons()
  }

  function startTestFlight()
  {
    local aircraft = ::show_aircraft
    ::test_flight <- true

    local misName = getTestFlightMisName(aircraft.testFlight)
    local misBlk = ::get_mission_meta_info(misName)
    if (!misBlk)
      return ::dagor.assertf(false, "Error: wrong testflight mission " + misName)

    ::current_campaign_mission <- misName

    saveAircraftOptions()

    ::mergeToBlk({
        _gameMode = ::GM_TEST_FLIGHT
        name      = misName
        chapter   = "training"
        takeOffOnStart = false
        weather     = getSceneOptValue(::USEROPT_WEATHER)
        environment = getSceneOptValue(::USEROPT_TIME)
      }, misBlk)

    ::mergeToBlk(::missionBuilderVehicleConfigForBlk, misBlk)

    ::select_training_mission(misBlk)
    guiScene.performDelayed(this, ::gui_start_flight)
  }

  function getTestFlightMisName(misName)
  {
    local lang = ::g_language.getLanguageName()
    return ::get_blk_value_by_path(get_game_settings_blk(), "testFlight_override/" + lang + "/" + misName, misName)
  }

  function saveAircraftOptions()
  {
    local aircraft = ::show_aircraft

    local dif = ::get_option(::USEROPT_DIFFICULTY)
    local difValue = dif.values[dif.value]

    local skin = ::get_option(::USEROPT_SKIN)
    local skinValue = skin.values[skin.value]
    local fuelValue = getSceneOptValue(::USEROPT_LOAD_FUEL_AMOUNT)
    local limitedFuel = ::get_option(::USEROPT_LIMITED_FUEL)
    local limitedAmmo = ::get_option(::USEROPT_LIMITED_AMMO)

    ::aircraft_for_weapons = aircraft.name
    enable_bullets_modifications(::aircraft_for_weapons)
    enable_current_modifications(::aircraft_for_weapons)

    ::missionBuilderVehicleConfigForBlk = {
        selectedSkin  = skinValue,
        difficulty    = difValue,
        isLimitedFuel = limitedFuel.value,
        isLimitedAmmo = limitedAmmo.value,
        fuelAmount    = (fuelValue.tofloat()/1000000.0),
    }

    if (aircraft.unitType.canUseSeveralBulletsForGun)
      updateBulletCountOptions(aircraft)
  }

  function updateBulletCountOptions(unit)
  {
    //prepare data to calc amounts
    local groupsCount = ::getBulletsGroupCount(unit, false)
    local bulletsInfo = ::getBulletsInfoForPrimaryGuns(unit)
    local gunsData = []
    for(local i = 0; i < groupsCount; i++)
    {
      local bInfo = ::getTblValue(i, bulletsInfo, null)
      gunsData.append({
        gunsAmount = ::getTblValue("guns", bInfo, 0)
        catridge = ::getTblValue("catridge", bInfo, 0)
        leftCatridges = ::getTblValue("total", bInfo, 0)
        leftGroups = 0
      })
    }

    local bulDataList = []
    for (local groupIdx = 0; groupIdx < ::BULLETS_SETS_QUANTITY; groupIdx++)
    {
      local isActive = ::isBulletGroupActive(unit, groupIdx)

      local gunIdx = ::get_linked_gun_index(groupIdx, groupsCount)
      local modName = ::get_last_bullets(unit.name, groupIdx)
      local maxToRespawn = 0

      if (isActive)
      {
        local bulletsSet = ::getBulletsSetData(unit, modName)
        maxToRespawn = ::getTblValue("maxToRespawn", bulletsSet, 0)
        if (maxToRespawn <= 0)
          maxToRespawn = ::getAmmoMaxAmount(unit.name, modName, AMMO.PRIMARY)

        gunsData[gunIdx].leftGroups++
      }

      bulDataList.append({
        groupIdx = groupIdx
        gunIdx = gunIdx
        modName = modName
        isActive = isActive
        maxAmount = maxToRespawn
        amountToSet = 0
      })
    }

    //calc bullets amount
    bulDataList.sort(function(a, b) {
      if (a.maxAmount != b.maxAmount)
        if (!a.maxAmount || !b.maxAmount)
          return a.maxAmount ? -1 : 1
        else
          return a.maxAmount - b.maxAmount
      return 0
    })
    foreach(bulData in bulDataList)
    {
      if (!bulData.isActive)
        continue

      local gun = gunsData[bulData.gunIdx]
      local catridgesToSet = (gun.leftCatridges / (gun.leftGroups || 1)).tointeger()
      if (bulData.maxAmount)
      {
        local catridgesMax = (bulData.maxAmount / gun.gunsAmount).tointeger() || 1
        catridgesToSet = ::min(catridgesToSet, catridgesMax)
      }
      gun.leftCatridges -= catridgesToSet
      gun.leftGroups--
      bulData.amountToSet = catridgesToSet * gun.gunsAmount
    }

    //save bullets and count
    bulDataList.sort(function(a, b) {
      if (a.isActive != b.isActive)
        return a.isActive ? -1 : 1
      return a.groupIdx - b.groupIdx
    })
    foreach(bulIdx, bulData in bulDataList)
    {
      local modName = bulData.isActive ? bulData.modName : ""
      ::set_unit_option(unit.name, ::USEROPT_BULLETS0 + bulIdx, modName)
      ::set_gui_option(::USEROPT_BULLETS0 + bulIdx, modName)
      ::set_gui_option(::USEROPT_BULLET_COUNT0 + bulIdx, bulData.amountToSet)
    }
  }

  function onSlotbarSelectAction(obj)
  {
    if (::slotbar_oninit)
      return

    local handler = this
    applyFunc = (@(obj, handler) function() {
      if(!::checkObj(obj) || !handler)
        return

      ::gui_handlers.BaseGuiHandlerWT.onSlotbarSelectAction.call(handler, obj)
      if (!::slotbar_oninit)
        updateAircraft()
    })(obj, handler)
    applyOptions()
  }

  function onDifficultyChange(obj)
  {
    base.onDifficultyChange(obj)
    updateSceneDifficulty()
  }

  function updateSceneDifficulty()
  {
    ::update_slotbar_difficulty(this)

    local unitNestObj = air ? scene.findObject("unit_nest") : null
    if (::checkObj(unitNestObj))
    {
      local obj = unitNestObj.findObject("rank_text")
      if (::checkObj(obj))
        obj.setValue(::get_unit_rank_text(air, null, true, getCurrentEdiff()))
    }
  }

  function getCurrentEdiff()
  {
    local diffValue = getSceneOptValue(::USEROPT_DIFFICULTY)
    local difficulty = (diffValue == "custom") ?
      ::g_difficulty.getDifficultyByDiffCode(::get_cd_base_difficulty()) :
      ::g_difficulty.getDifficultyByName(diffValue)
    if (difficulty.diffCode != -1)
    {
      local battleType = ::get_battle_type_by_unit(::show_aircraft)
      return difficulty.getEdiff(battleType)
    }
    return ::get_current_ediff()
  }

  function afterModalDestroy()
  {
    if (afterCloseFunc)
      afterCloseFunc()
  }

  function onEventCrewChanged(params)
  {
    local crew = getSlotItem(curSlotCountryId, curSlotIdInCountry)
    local unit = ::g_crew.getCrewUnit(crew)
    if (!unit || unit == air)
      return

    ::show_aircraft = unit
    updateAircraft()
  }
}

class ::gui_handlers.changeAircraftForBuilder extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/shop/shopTakeAircraft.blk"
  shopAir = null
  owner = null

  function initScreen()
  {
     ::init_slotbar(this, scene.findObject("take-aircraft-slotbar"), false, null, {showNewSlot = false, showEmptySlot = false})

     local textObj = scene.findObject("take-aircraft-text")
     textObj.top = "1@titleLogoPlateHeight + 1@frameHeaderHeight"
     textObj.setValue(::loc("mainmenu/missionBuilderNotAvailable"))

     local crew = getSlotItem(curSlotCountryId, curSlotIdInCountry)
     local airName = ("aircraft" in crew)? crew.aircraft : ""
     local air = getAircraftByName(airName)
     ::show_aircraft = air
     updateButtons()
     initFocusArray()
  }

  function onTakeCancel()
  {
    ::show_aircraft = shopAir
    goBack()
  }

  function onSlotbarDblClick()
  {
    if (::isTank(::show_aircraft))
      msgBox("not_available", ::loc("mainmenu/cantTestDrive"), [["ok", function() {} ]], "ok", { cancel_fn = function() {}})
    else
      ::gui_start_builder_screen2(owner)
  }

  function updateButtons()
  {
    scene.findObject("btn_set_air").inactiveColor = ::isTank(::show_aircraft)? "yes" : "no"
  }

  function onSlotbarSelect(obj)
  {
    base.onSlotbarSelect(obj)
    updateButtons()
  }
}

//=============================================================================

class ::gui_handlers.MissionBuilderOptions extends ::gui_handlers.GenericOptionsModal
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/options/genericOptionsMap.blk"
  sceneNavBlkName = "gui/navBuilderOptions.blk"
  wndGameMode = ::GM_BUILDER
  wndOptionsMode = ::OPTIONS_MODE_DYNAMIC
  owner = null

  applyAtClose = false
  can_generate_missions = true

  function initScreen()
  {
    ::gui_handlers.GenericOptions.initScreen.bindenv(this)()

    guiScene.setUpdatesEnabled(false, false)
    init_builder_map()
    generate_builder_list(true)

    local options =
    [
      [::USEROPT_DYN_MAP, "combobox"],
//      [::USEROPT_YEAR, "spinner"],
//      [::USEROPT_MP_TEAM, "spinner"],
      [::USEROPT_DYN_ZONE, "combobox"],
      [::USEROPT_DYN_SURROUND, "spinner"],
      [::USEROPT_DMP_MAP, "spinner"],
  //    [::USEROPT_DYN_ALLIES, "spinner"],
      [::USEROPT_FRIENDLY_SKILL, "spinner"],
  //    [::USEROPT_DYN_ENEMIES, "spinner"],
      [::USEROPT_ENEMY_SKILL, "spinner"],
      [::USEROPT_DIFFICULTY, "spinner"],
      [::USEROPT_TIME, "spinner"],
      [::USEROPT_WEATHER, "spinner"],
      [::USEROPT_TAKEOFF_MODE, "combobox"],
      [::USEROPT_LIMITED_FUEL, "spinner"],
      [::USEROPT_LIMITED_AMMO, "spinner"],
  //    [::USEROPT_SESSION_PASSWORD, "editbox"],
    ]

    local container = create_options_container("builder_options", options, true, true, true, true, true)
    local optListObj = scene.findObject("optionslist")
    guiScene.replaceContentFromText(optListObj, container.tbl, container.tbl.len(), this)
    optionsContainers.push(container.descr)
    ::set_menu_title(::loc("mainmenu/btnDynamicTraining"), scene, "menu-title")

    local desc = ::get_option(::USEROPT_DYN_ZONE)
    local dynZoneObj = guiScene["dyn_zone"]
    local value = desc.value
    if(::checkObj(dynZoneObj))
      value = guiScene["dyn_zone"].getValue()

    ::g_map_preview.setSummaryPreview(scene.findObject("tactical-map"), ::DataBlock(), desc.values[value])

    if (::mission_settings.dynlist.len() == 0)
      return msgBox("no_missions_error", ::loc("msgbox/appearError"),
                     [["ok", goBack ]], "ok", { cancel_fn = goBack})

    update_takeoff()

    reinitOptionsList()
    guiScene.setUpdatesEnabled(true, true)

    if (::fetch_first_builder())
      randomize_builder_options()

    ::init_slotbar(this, scene.findObject("nav-help"))
    initFocusArray()
  }

  function getMainFocusObj()
  {
    return scene.findObject("builder_options")
  }

  function reinitOptionsList()
  {
    updateButtons()

    local air = ::show_aircraft
    if (!air || !::checkObj(scene))
      return goBack()

    local showOptions = isBuilderAvailable()

    local optListObj = scene.findObject("options_data")
    local textObj = scene.findObject("no_options_textarea")
    optListObj.show(showOptions)
    textObj.setValue(showOptions? "" : ::loc("msg/builderOnlyForAircrafts"))

    if (!showOptions)
      return

    update_dynamic_map()
  }

  function isBuilderAvailable()
  {
    return ::show_aircraft!=null && ::isUnitAvailableForGM(::show_aircraft, ::GM_BUILDER)
  }

  function updateButtons()
  {
    if (!::checkObj(scene))
      return

    local available = isBuilderAvailable()
    scene.findObject("btn_select").inactiveColor = available? "no" : "yes"
    showSceneBtn("btn_random", available)
    showSceneBtn("btn_inviteSquad", ::enable_coop_in_QMB && ::g_squad_manager.canInviteMember())
  }

  function onSlotbarSelectAction(obj)
  {
    base.onSlotbarSelectAction(obj)
    if (!::slotbar_oninit)
      reinitOptionsList()
  }

  function onApply()
  {
    if (!::g_squad_utils.canJoinFlightMsgBox({ isLeaderCanJoin = ::enable_coop_in_QMB }))
      return

    if (!isBuilderAvailable())
      return msgBox("not_available", ::loc("msg/builderOnlyForAircrafts"), [["ok", function() {} ]], "ok", { cancel_fn = function() {}})

    if (::isInArray(getSceneOptValue(::USEROPT_DIFFICULTY), ["hardcore", "custom"]))
      if (!::check_diff_pkg(::g_difficulty.SIMULATOR.diffCode))
        return

    applyOptions()
  }

  function getSceneOptRes(optName)
  {
    local option = ::get_option(optName)
    local obj = scene.findObject(option.id)
    local value = obj? obj.getValue() : -1
    if (!(value in option.items))
      value = option.value
    return { name = option.items[value], value = option.values[value] }
  }

  function init_builder_map()
  {
    local mapData = getSceneOptRes(::USEROPT_DYN_MAP)
    ::mission_settings.layout <- mapData.value
    ::mission_settings.layoutName <- mapData.name

    local settings = ::DataBlock();
    local playerSide = 1
    if (::show_aircraft.tags)
      foreach (tag in ::show_aircraft.tags)
       if (tag == "axis")
       {
         playerSide = 2
         break
       }
    settings.setInt("playerSide", /*getSceneOptValue(::USEROPT_MP_TEAM)*/playerSide)


    ::dynamic_init(settings, mapData.value);
  }

  function generate_builder_list(wait)
  {
    if (!can_generate_missions)
      return;

    ::aircraft_for_weapons = ::show_aircraft.name

    local settings = ::DataBlock();
    settings.setStr("player_class", ::show_aircraft.name)
    settings.setStr("player_weapons", getSceneOptValue(::USEROPT_WEAPONS) || "")
    settings.setStr("player_skin", getSceneOptValue(::USEROPT_SKIN) || "")
    settings.setStr("wishSector", getSceneOptValue(::USEROPT_DYN_ZONE))
    settings.setInt("sectorSurround", getSceneOptValue(::USEROPT_DYN_SURROUND))
    settings.setStr("year", "year_any" /*getSceneOptValue(::USEROPT_YEAR)*/)
    settings.setBool("isQuickMissionBuilder", true)

    ::mission_settings.dynlist <- ::dynamic_get_list(settings, wait)

    local add = []
    for (local i = 0; i < ::mission_settings.dynlist.len(); i++)
    {
      local misblk = ::mission_settings.dynlist[i].mission_settings.mission

      ::mergeToBlk(::missionBuilderVehicleConfigForBlk, misblk)

      misblk.setStr("mis_file", ::mission_settings.layout)
      misblk.setStr("type", "builder")
      misblk.setStr("chapter", "builder")
      if (::mission_settings.coop)
        misblk.setBool("gt_cooperative", true);
      add.append(misblk)
    }
    ::add_mission_list_full(::GM_BUILDER, add, ::mission_settings.dynlist)
  }

  function update_dynamic_map()
  {
    local descr = ::get_option(::USEROPT_DYN_MAP)
    local txt = ::create_option_list(descr.id, descr.items, descr.value, descr.cb, false)
    local dObj = scene.findObject(descr.id)
    guiScene.replaceContentFromText(dObj, txt, txt.len(), this)

    init_builder_map()
    if (descr.cb in this)
      this[descr.cb](dObj)
    return descr
  }

  function update_dynamic_layout(guiScene, obj, descr)
  {
    init_builder_map()

    local descrWeap = ::get_option(::USEROPT_DYN_ZONE)
    local txt = ::create_option_list(descrWeap.id, descrWeap.items, descrWeap.value, "onSectorChange", false)
    local dObj = scene.findObject(descrWeap.id)
    guiScene.replaceContentFromText(dObj, txt, txt.len(), this)
    return descrWeap
  }

  function update_dynamic_sector(guiScene, obj, descr)
  {
    generate_builder_list(true)
    local descrWeap = ::get_option(::USEROPT_DMP_MAP)
    local txt = ::create_option_list(descrWeap.id, descrWeap.items, descrWeap.value, null, false)
    local dObj = scene.findObject(descrWeap.id)
    guiScene.replaceContentFromText(dObj, txt, txt.len(), this)

    update_takeoff()

    ::g_map_preview.setSummaryPreview(scene.findObject("tactical-map"), ::DataBlock(), getSceneOptValue(::USEROPT_DYN_ZONE))

    return descrWeap
  }

  function update_takeoff()
  {
    local haveTakeOff = false
    local mapObj = scene.findObject("dyn_mp_map")
    if (::checkObj(mapObj))
      ::mission_settings.currentMissionIdx = mapObj.getValue()

    local dynMission = ::getTblValue(::mission_settings.currentMissionIdx, ::mission_settings.dynlist)
    if (!dynMission)
      return

    if (dynMission.mission_settings.mission.paramExists("takeoff_mode"))
      haveTakeOff = true

    ::mission_name_for_takeoff <- dynMission.mission_settings.mission.name
    local descrWeap = ::get_option(::USEROPT_TAKEOFF_MODE)
    if (!haveTakeOff)
    {
      for(local i=0; i<descrWeap.items.len(); i++)
        descrWeap.items[i] = { text = descrWeap.items[i], enabled = (i==0) }
      descrWeap.value = 0
    }
    local txt = ::create_option_combobox(descrWeap.id, descrWeap.items, descrWeap.value, "onMissionChange", false)
    local dObj = scene.findObject(descrWeap.id)
    if (::checkObj(dObj))
      guiScene.replaceContentFromText(dObj, txt, txt.len(), this)
  }

  function setRandomOpt(optName)
  {
    local desc = ::get_option(optName)
    local obj = scene.findObject(desc.id)
    if (obj) obj.setValue(::math.rnd() % desc.values.len())
  }

  function randomize_builder_options()
  {
    if (!::checkObj(scene))
      return

    can_generate_missions = false;

    guiScene.setUpdatesEnabled(false, false)
    foreach(o in [/*::USEROPT_YEAR,*/ ::USEROPT_DYN_MAP /*, ::USEROPT_MP_TEAM*/ ] )
      setRandomOpt(o)

    onLayoutChange(scene.findObject("dyn_map"))
    setRandomOpt(::USEROPT_DYN_ZONE)
    guiScene.setUpdatesEnabled(true, true)

    guiScene.performDelayed(this, function()
      {
        foreach(o in [::USEROPT_TIME, ::USEROPT_WEATHER, ::USEROPT_DYN_SURROUND])
          setRandomOpt(o)

        onSectorChange(scene.findObject("dyn_zone"))

        guiScene.performDelayed(this, function()
          {
            can_generate_missions = true

            setRandomOpt(::USEROPT_DMP_MAP)
            update_takeoff()
          }
        )
      }
    )
  }

  function applyFunc()
  {
    if (!::g_squad_utils.canJoinFlightMsgBox({ isLeaderCanJoin = ::enable_coop_in_QMB }))
      return

    ::mission_settings.currentMissionIdx = scene.findObject("dyn_mp_map").getValue()
    local fullMissionBlk = ::getTblValue(::mission_settings.currentMissionIdx, ::mission_settings.dynlist)
    if (!fullMissionBlk)
      return

    if (fullMissionBlk.mission_settings.mission.paramExists("takeoff_mode"))
    {
      local takeoff_mode = scene.findObject("takeoff_mode").getValue()
      ::dynamic_set_takeoff_mode(fullMissionBlk, takeoff_mode, takeoff_mode)
    }

    local settings = DataBlock()
    settings.setInt("allyCount",  getSceneOptValue(::USEROPT_DYN_ALLIES))
    settings.setInt("enemyCount", getSceneOptValue(::USEROPT_DYN_ENEMIES))
    settings.setInt("allySkill",  getSceneOptValue(::USEROPT_FRIENDLY_SKILL))
    settings.setInt("enemySkill", getSceneOptValue(::USEROPT_ENEMY_SKILL))
    settings.setStr("dayTime",    getSceneOptValue(::USEROPT_TIME))
    settings.setStr("weather",    getSceneOptValue(::USEROPT_WEATHER))

    ::mission_settings.coop = (::enable_coop_in_QMB && ::g_squad_manager.isInSquad())
    ::mission_settings.friendOnly = false
    ::mission_settings.allowJIP = true

    ::dynamic_tune(settings, fullMissionBlk)

    local missionBlk = fullMissionBlk.mission_settings.mission

    missionBlk.setInt("_gameMode", ::GM_BUILDER)
    missionBlk.setBool("gt_cooperative", ::mission_settings.coop)
    if (::mission_settings.coop)
    {
      ::mission_settings.players = 4;
      missionBlk.setInt("_players", 4)
      missionBlk.setInt("maxPlayers", 4)
      missionBlk.setBool("gt_use_lb", false)
      missionBlk.setBool("gt_use_replay", true)
      missionBlk.setBool("gt_use_stats", true)
      missionBlk.setBool("gt_sp_restart", false)
      missionBlk.setBool("isBotsAllowed", true)
      missionBlk.setBool("autoBalance", false)
      missionBlk.setBool("isPrivate", ::mission_settings.friendOnly)
      missionBlk.setBool("allowJIP", ! ::mission_settings.friendOnly)
    }

    missionBlk.setStr("difficulty", getSceneOptValue(::USEROPT_DIFFICULTY))
    missionBlk.setStr("restoreType", "attempts")

    local fuelObj = scene.findObject("fuel_and_ammo")
    if (fuelObj)
    {
      local limits = fuelObj.getValue()
      ::mission_settings.isLimitedFuel = (limits == 2 || limits == 3)
      ::mission_settings.isLimitedAmmo = (limits == 1 || limits == 3)
      missionBlk.setBool("isLimitedFuel", ::mission_settings.isLimitedFuel)
      missionBlk.setBool("isLimitedAmmo", ::mission_settings.isLimitedAmmo)
    }

    ::current_campaign_mission = missionBlk.getStr("name","")
    ::mission_settings.mission = missionBlk
    ::mission_settings.missionFull = fullMissionBlk
    ::select_mission_full(missionBlk, fullMissionBlk);

    //dlog("missionBlk:"); debugTableData(missionBlk)

    ::gui_start_builder_screen3(this)
  }

  function onLayoutChange(obj)
  {
    guiScene.performDelayed(this, (@(obj) function() {
      updateOptionDescr(obj, update_dynamic_layout)
      updateOptionDescr(obj, update_dynamic_sector)
    })(obj))
  }

  function onMissionChange(obj)
  {
    update_takeoff()
  }

  function onSectorChange(obj)
  {
    guiScene.performDelayed(this, (@(obj) function() {
      updateOptionDescr(obj, update_dynamic_sector)
    })(obj))
  }

  function onYearChange(obj)
  {
    guiScene.performDelayed(this, (@(obj) function() {
      updateOptionDescr(obj, update_dynamic_sector)
    })(obj))
  }

  function onRandom(obj)
  {
    randomize_builder_options()
  }
}

//=============================================================================

class ::gui_handlers.MissionBuilderTuner extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/options/genericOptionsMap.blk"
  sceneNavBlkName = "gui/options/navOptionsBack.blk"
  owner = null

  noChoice = false
  unitsBlk = null
  listA = null
  listW = null
  listS = null
  listC = null

  wtags = null

  function initScreen()
  {
    ::set_menu_title(::loc("mainmenu/btnDynamicPreview"), scene, "menu-title")

    unitsBlk = DataBlock()
    ::dynamic_get_units(::mission_settings.missionFull, unitsBlk)

    local list = createOptions()
    local listObj = scene.findObject("optionslist")
    guiScene.replaceContentFromText(listObj, list, list.len(), this)

    for (local i = 1; i < listW.len(); i++)
      listObj.findObject(i.tostring() + "_w").setValue(0)

    //if (noChoice)
    //  applyOptions()

    //mission preview
    ::g_map_preview.setMapPreview(scene.findObject("tactical-map"), ::mission_settings.missionFull)

    local country = ::getCountryByAircraftName(::mission_settings.mission.getStr("player_class", ""))
    dagor.debug("1 player_class = "+::mission_settings.mission.getStr("player_class", "") + "; country = " + country)
    if (country != "")
      scene.findObject("briefing-flag")["background-image"] = ::get_country_flag_img("bgflag_" + country)

    local misObj = ""
    misObj = ::loc(format("mb/%s/objective", ::mission_settings.mission.getStr("name", "")), "")
    scene.findObject("mission-objectives").setValue(misObj)
    initFocusArray()
  }

  function getMainFocusObj()
  {
    return scene.findObject("tuner_options")
  }

  function buildAircraftOptions(aircrafts, curA, isPlayer)
  {
    local ret = ""
    for (local i = 0; i < aircrafts.len(); i++)
      ret += build_option_blk("#" + aircrafts[i] + "_shop", image_for_air(aircrafts[i]), curA == aircrafts[i])
    listA.append(aircrafts)
    return ret
  }

  function buildWeaponOptions(aircraft, curW, weapTags)
  {
    local weapons = get_weapons_list(aircraft, false, weapTags, false, false) //check_aircraft_purchased=false
    if (weapons.values.len() == 0)
    {
      dagor.debug("bomber without bombs: "+aircraft)
      weapons = get_weapons_list(aircraft, false, null, false, false) //check_aircraft_purchased=false
    }

    local ret = ""
    for (local i = 0; i < weapons.values.len(); i++)
    {
      ret += (
        "option { " +
        "optiontext { text:t = '" + ::locOrStrip(weapons.items[i].text) + "'} " +
        "tooltip:t = '" + ::locOrStrip(weapons.items[i].tooltip) + "' " +
        (curW == weapons.values[i] ? "selected:t = 'yes'; " : "") +
        " max-width:t='p.p.w'; pare-text:t='yes'} " //-10%sh
      )
    }
    listW.append(weapons.values)
    return ret
  }

  function buildSkinOptions(aircraft, curS)
  {
    local skins = ::g_decorator.getSkinsOption(aircraft)

    local ret = ""
    for (local i = 0; i < skins.values.len(); i++)
    {
      ret += (
        "option { " +
        "optiontext { text:t = '" + ::locOrStrip(skins.items[i]) + "'} " +
        (curS == skins.values[i] ? "selected:t = 'yes'; " : "") +
        " max-width:t='p.p.w'; pare-text:t='yes'} " //-10%sh
      )
    }
    listS.append(skins.values)
    return ret
  }

  function buildFuelOptions(desc)
  {
    local ret = ""
    for (local i = 0; i < desc.values.len(); i++)
    {
      ret += (
        "option { " +
        "optiontext { text:t = '" + ::locOrStrip(desc.items[i]) + "'} " +
        (desc.values[i] == 50 ? "selected:t = 'yes'; " : "") +
        " max-width:t='p.p.w'; pare-text:t='yes'} "  //-10%sh
      )
    }
    return ret
  }

  function buildCountOptions(minCount, maxCount, curC)
  {
    local ret = ""
    local list = []
    for (local i = minCount; i <= maxCount; i++)
    {
      ret += (
        "option { " +
        "optiontext { text:t = '" + i.tostring() + "'} " +
        (curC == i ? "selected:t = 'yes'; " : "") +
        " max-width:t='p.p.w'; pare-text:t='yes'} "  //-10%sh
      )
      list.append(i)
    }
    listC.append(list)
    return ret
  }

  function createOptions()
  {
    listA = []
    listW = []
    listS = []
    listC = []
    wtags = []
    noChoice = true

    local data = ""

    local wLeft  = "45%pw"
    local wRight = "55%pw"
    local selectedRow = 0
    local iRow = 0
    local separator = ""

    local isFreeFlight = ::mission_settings.missionFull.mission_settings.mission.isFreeFlight;

    for (local i = 0; i < unitsBlk.blockCount(); i++)
    {
      local armada = unitsBlk.getBlock(i)

      local name = armada.getStr("name","")
      local aircraft = armada.getStr("unit_class", "");
      local weapon = armada.getStr("weapons", "");
      local skin = armada.getStr("skin", "");
      local count = armada.getInt("count", 4);
      local army = armada.getInt("army", 1); //1-ally, 2-enemy
      local isBomber = armada.getBool("mustBeBomber", false);
      local isFighter = armada.getBool("mustBeFighter", false);
      local isAssault = armada.getBool("mustBeAssault", false);
      local isPlayer = armada.getBool("isPlayer", false);
      local minCount = armada.getInt("minCount", 1);
      local maxCount = armada.getInt("maxCount", 4);
      local excludeTag = isFreeFlight ? "not_in_free_flight" : "not_in_dynamic_campaign";

      if (isPlayer)
      {
        local airName = ::show_aircraft.name
        ::mission_settings.mission.player_class = airName
        armada.unit_class = airName
        armada.weapons = ::get_last_weapon(airName)
        armada.skin = ::hangar_get_last_skin(airName)
        listA.append([armada.unit_class])
        listW.append([armada.weapons])
        listS.append([armada.skin])
        listC.append([4])
        wtags.append([])
        continue
      }

      if ((name == "") || (aircraft == ""))
        break;

      local adesc = armada.description
      local fmTags = adesc % "needFmTag"
      local weapTags = adesc % "weaponOrTag"

      local aircrafts = []

      foreach(unit in ::all_units)
      {
        if (isInArray(excludeTag, unit.tags))
          continue
        if (isInArray("aux", unit.tags))
          continue
        local tagsOk = true
        for (local k = 0; k < fmTags.len(); k++)
          if (!isInArray(fmTags[k], unit.tags))
          {
            tagsOk = false
            break
          }
        if (!tagsOk)
          continue
        if (get_weapons_list(unit.name, false, weapTags, false, false).values.len() < 1) //check_aircraft_purchased=false
          continue
        if (isPlayer)
        {
//          if (!::is_unlocked_scripted(::UNLOCKABLE_AIRCRAFT, unit.name))
//            continue
          if (!unit.isUsable())
            continue
        }
        aircrafts.append(unit.name)
      }

      // make sure that aircraft exists in aircrafts array
      local found = false
      foreach (k in aircrafts)
        if (k == aircraft)
        {
          found = true;
          break
        }
      if (!found)
        aircrafts.append(aircraft)

      aircrafts.sort(function(a,b)
      {
        if(a > b) return 1
        else if(a<b) return -1
        return 0;
      })

      //aircraft type
      local trId = (army == unitsBlk.getInt("playerSide", 1)) ? "ally" : "enemy"
      if (isPlayer)
        trId = "player"
      if (isBomber)
        trId += "Bomber"
      else if (isFighter)
        trId += "Fighter"
      else if (isAssault)
        trId += "Assault"

      local trIdN = isPlayer ? trId : trId+i.tostring()

      dagor.debug("building "+trIdN)

      local rowData = ""
      local elemText = ""
      local optlist = ""

      wtags.append(weapTags)

      // Aircraft
      rowData = "td { cellType:t='left'; width:t='" + wLeft + "'; overflow:t='hidden'; optiontext { id:t = 'lbl_" + trIdN + "_a" + "'; text:t ='" +
        "#options/" + trId
        + "'; } }"
      optlist = buildAircraftOptions(aircrafts, aircraft, isPlayer)
      elemText = "ComboBox"+" { size:t='pw, ph'; " +
        "id:t = '" + i.tostring() + "_a'; " + "on_select:t = '" + "onChangeAircraft" + "'; " + optlist
        + " }"
      rowData += "td { cellType:t='right'; width:t='" + wRight + "'; padding-left:t='@optPad'; " + elemText + separator + " }"
      if (!isPlayer) data += "tr { width:t='pw'; iconType:t='aircraft'; id:t = '" + trIdN + "_a_tr" + "'; " + rowData + " } "

      // Weapon
      rowData = "td { cellType:t='left'; width:t='" + wLeft + "'; overflow:t='hidden'; optiontext { id:t = 'lbl_" + trIdN + "_w" + "'; text:t ='" +
        "#options/secondary_weapons"
        + "'; } }"
      optlist = buildWeaponOptions(aircraft, weapon, weapTags)
      elemText = "ComboBox"+" { size:t='pw, ph'; " +
        "id:t = '" + i.tostring() + "_w'; " + optlist
        + " }"
      rowData += "td { cellType:t='right'; width:t='" + wRight + "'; padding-left:t='@optPad'; " + elemText + " }"
      if (!isPlayer) data += "tr { width:t='pw'; id:t = '" + trIdN + "_w_tr" + "'; " + rowData + " } "

      // Skin
      rowData = "td { cellType:t='left'; width:t='" + wLeft + "'; overflow:t='hidden'; optiontext { id:t = 'lbl_" + trIdN + "_s" + "'; text:t ='" +
        "#options/skin"
        + "'; } }"
      optlist = buildSkinOptions(aircraft, skin)
      elemText = "ComboBox"+" { size:t='pw, ph'; " +
        "id:t = '" + i.tostring() + "_s'; " + optlist
        + " }"
      rowData += "td { cellType:t='right'; width:t='" + wRight + "'; padding-left:t='@optPad'; " + elemText + " }"
      if (!isPlayer) data += "tr { width:t='pw'; id:t = '" + trIdN + "_s_tr" + "'; " + rowData + " } "

      // Count
      rowData = "td { cellType:t='left'; width:t='" + wLeft + "'; overflow:t='hidden'; optiontext { id:t = 'lbl_" + trIdN + "_c" + "'; text:t ='" +
        "#options/count"
        + "'; } }"
      optlist = buildCountOptions(minCount, maxCount, count)
      elemText = control_for_count(maxCount-minCount+1, "spinnerListBox") + " { size:t='pw, ph'; " +
        "id:t = '" + i.tostring() + "_c'; " + optlist
        + " }"
      rowData += "td { cellType:t='right'; width:t='" + wRight + "'; padding-left:t='@optPad'; " + elemText + " }"
      if (!isPlayer)
      {
        data += "tr { width:t='pw'; id:t = '" + trIdN + "_c_tr" + "'; " + rowData + " } "
        noChoice = false
      }

      separator = "trSeparator{}"
    }

    local resTbl = @"
      table
      {
        id:t= 'tuner_options';
        pos:t = '(pw-w)/2,(ph-h)/2';
        width:t='pw';
        position:t = 'absolute';
        class:t = 'optionsTable';
        baseRow:t = 'yes';
        focus:t = 'yes';
        behavior:t = 'OptionsNavigator';
        cur_col:t='" + selectedRow + @"';
        cur_row:t='0';
        cur_min:t='1';
        num_rows:t='-1';
        "
        + data + @"
      }
      "
    ;

    return resTbl
  }

  function onChangeAircraft(obj)
  {
    for (local i = 0; i < listA.len(); i++)
    {
      local airId = i.tostring() + "_a"
      if (obj.id == airId)
      {
        local aircraft = listA[i][scene.findObject(airId).getValue()]

        local optlist = ""

        local weapons = get_weapons_list(aircraft, false, wtags[i], false, false) //check_aircraft_purchased=false
        if (weapons.values.len() == 0)
        {
          dagor.debug("bomber without bombs: "+aircraft)
          weapons = get_weapons_list(aircraft, false, null, false, false) //check_aircraft_purchased=false
        }

        for (local j = 0; j < weapons.values.len(); j++)
        {
          optlist += (
            "option { " +
            "optiontext { text:t = '" + ::locOrStrip(weapons.items[j].text) + "'} " +
            "tooltip:t = '" + ::locOrStrip(weapons.items[j].tooltip) + "' " +
            ((j==0) ? "selected:t = 'yes'; " : "") +
            " max-width:t='p.p.w-10%sh'; pare-text:t='yes'} "
          )
        }
        listW[i] = weapons.values

/*
        local newSpinner = "ComboBox"+" { size:t='pw, ph'; " +
          "id:t = '" + i.tostring() + "_w'; " + optlist
          + " }" */
        local newSpinner = optlist

        local weapObj = scene.findObject(i.tostring() + "_w")
        guiScene.replaceContentFromText(weapObj, newSpinner, newSpinner.len(), this)
        weapObj.setValue(0)

        local skins = ::g_decorator.getSkinsOption(aircraft)

        optlist = ""
        for (local j = 0; j < skins.values.len(); j++)
        {
          optlist += (
            "option { " +
            "optiontext { text:t = '" + ::locOrStrip(skins.items[j]) + "'} " +
            ((j==0) ? "selected:t = 'yes'; " : "") +
            " max-width:t='p.p.w-10%sh'; pare-text:t='yes'} "
          )
        }
        listS[i] = skins.values

/*        newSpinner = "spinnerListBox"+" { size:t='pw, ph'; " +
          "id:t = '" + i.tostring() + "_s'; " + optlist
          + " }"*/
        newSpinner = optlist

        local skinObj = scene.findObject(i.tostring() + "_s")
        guiScene.replaceContentFromText(skinObj, newSpinner, newSpinner.len(), this)
        skinObj.setValue(0)
        return
      }
    }
  }

  function onApply(obj)
  {
    if (!::g_squad_utils.canJoinFlightMsgBox({ isLeaderCanJoin = ::enable_coop_in_QMB }))
      return

    for (local i = 0; i < listA.len(); i++)
    {
      local airId = i.tostring() + "_a"
      local weapId = i.tostring() + "_w"
      local skinId = i.tostring() + "_s"
      local countId = i.tostring() + "_c"

      local aircraft = ""
      local weapon = ""
      local skin = ""
      local count = 4
      if (i == 0)
      {
        count = 4
        continue;
      }
      else
      {
        aircraft = listA[i][scene.findObject(airId).getValue()]
        weapon = listW[i][scene.findObject(weapId).getValue()]
        skin = listS[i][scene.findObject(skinId).getValue()]
        count = listC[i][scene.findObject(countId).getValue()]
      }

      local armada = unitsBlk.getBlock(i)
      armada.setStr("unit_class", aircraft);
      armada.setStr("weapons", weapon);
      armada.setStr("skin", skin);
      armada.setInt("count", count);
    }
    ::mission_settings.mission.setInt("_gameMode", ::GM_BUILDER)
    local fuelObj = scene.findObject("fuel_amount")
    if (fuelObj)
    {
      local am = ::get_option(::USEROPT_LOAD_FUEL_AMOUNT).values[fuelObj.getValue()]
      ::set_gui_option(::USEROPT_LOAD_FUEL_AMOUNT, am)
    }

    ::dynamic_set_units(::mission_settings.missionFull, unitsBlk)
    ::select_mission_full(::mission_settings.mission,
       ::mission_settings.missionFull)
    if (::SessionLobby.isInRoom())
      ::apply_host_settings(::mission_settings.mission)

    ::set_context_to_player("difficulty", ::get_mission_difficulty())

    local appFunc = function()
    {
      if (::SessionLobby.isInRoom())
        goForward(::gui_start_mp_lobby);
      else if (::mission_settings.coop)
      {
        // ???
      }
      else
        goForward(::gui_start_flight)
    }

    if (::get_gui_option(::USEROPT_DIFFICULTY) == "custom")
      ::gui_start_cd_options(appFunc, this)
    else
      appFunc()
  }

  function onBack(obj)
  {
    goBack()
  }
}

function mergeToBlk(sourceTable, blk)
{
  foreach (idx, val in sourceTable)
    blk[idx] = val
}

::last_called_gui_testflight <- null

function gui_start_testflight(afterCloseFunc = null)
{
  ::gui_start_builder(true, afterCloseFunc)
}

function gui_start_menu_builder()
{
  ::gui_start_mainmenu()
  ::gui_start_builder_screen2()
}

function gui_start_builder(isTestFlight = false, afterCloseFunc = null)
{
  ::gui_start_modal_wnd(::gui_handlers.MissionBuilder, { isTestFlight = isTestFlight, afterCloseFunc = afterCloseFunc })
  ::last_called_gui_testflight <- ::handlersManager.getLastBaseHandlerStartFunc()
}

function gui_start_builder_screen2(owner=null)
{
  ::gui_start_modal_wnd(::gui_handlers.MissionBuilderOptions, {owner = owner})
}

function gui_start_builder_screen3(owner=null)
{
  ::gui_start_modal_wnd(::gui_handlers.MissionBuilderTuner, {owner = owner})
}

function gui_start_dynamic_summary()
{
  ::handlersManager.loadHandler(::gui_handlers.CampaignPreview, { isFinal = false })
}

function gui_start_dynamic_summary_f()
{
  ::handlersManager.loadHandler(::gui_handlers.CampaignPreview, { isFinal = true })
}

function gui_start_dynamic_results()
{
  ::handlersManager.loadHandler(::gui_handlers.CampaignResults)
}
