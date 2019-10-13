/*
  ::dmViewer API:

  toggle(state = null)  - switch view_mode to state. if state == null view_mode will be increased by 1
  update()              - update dm viewer active status
                          depend on canShowDmViewer function in cur_base_gui_handler and top_menu_handler
                          and modal windows.
*/

::on_check_protection <- function(params) { // called from client
  ::broadcastEvent("ProtectionAnalysisResult", params)
}

::dmViewer <- {
  [PERSISTENT_DATA_PARAMS] = [ "active", "view_mode", "_currentViewMode", "isDebugMode",
    "isVisibleExternalPartsArmor", "isVisibleExternalPartsXray" ]

  active = false
  // This is saved view mode. It is used to restore
  // view mode after player returns from somewhere.
  view_mode = ::DM_VIEWER_NONE
  unit = null
  crew = null
  unitBlk = null
  unitWeaponBlkList = null
  xrayRemap = {}
  difficulty = null

  modes = {
    [::DM_VIEWER_NONE]  = "none",
    [::DM_VIEWER_ARMOR] = "armor",
    [::DM_VIEWER_XRAY]  = "xray",
  }

  isVisibleExternalPartsArmor = true
  isVisibleExternalPartsXray  = true

  prevHintParams = {}

  screen = [ 0, 0 ]
  unsafe = [ 0, 0 ]
  offset = [ 0, 0 ]

  absoluteArmorThreshold = 500
  relativeArmorThreshold = 5.0

  prepareNameId = [
    { pattern = ::regexp2(@"_l_|_r_"),   replace = "_" },
    { pattern = ::regexp2(@"[0-9]|dm$"), replace = "" },
    { pattern = ::regexp2(@"__+"),       replace = "_" },
    { pattern = ::regexp2(@"_+$"),       replace = "" },
  ]

  xrayDescriptionCache = {}
  isDebugMode = false
  isSecondaryModsValid = false

  _currentViewMode = ::DM_VIEWER_NONE
  function getCurrentViewMode() { return _currentViewMode }
  function setCurrentViewMode(value)
  {
    _currentViewMode = value
    ::hangar_set_dm_viewer_mode(value)
    updateNoPartsNotification()
  }

  function init(handler)
  {
    screen = [ ::screen_width(), ::screen_height() ]
    unsafe = [ handler.guiScene.calcString("@bw", null), handler.guiScene.calcString("@bh", null) ]
    offset = [ screen[1] * 0.1, 0 ]

    local guiBlk = ::configs.GUI.get()
    absoluteArmorThreshold = guiBlk?.armor_thickness_absolute_threshold ?? absoluteArmorThreshold
    relativeArmorThreshold = guiBlk?.armor_thickness_relative_threshold ?? relativeArmorThreshold

    updateUnitInfo()
    local timerObj = handler.getObj("dmviewer_hint")
    if (timerObj)
      timerObj.setUserData(handler) //!!FIX ME: it a bad idea link timer to handler.
                                    //better to link all timers here, and switch them off when not active.

    update()
  }

  function updateSecondaryMods()
  {
    if( ! unit)
      return
    isSecondaryModsValid = ::check_unit_mods_update(unit)
            && ::check_secondary_weapon_mods_recount(unit)
  }

  function onEventSecondWeaponModsUpdated(params)
  {
    if( ! unit || unit.name != getTblValueByPath("unit.name", params))
      return
    isSecondaryModsValid = true
    resetXrayCache()
    prevHintParams = {}
    reinit()
  }

  function resetXrayCache()
  {
    xrayDescriptionCache.clear()
  }

  function canUse()
  {
    local hangarUnitName = ::hangar_get_current_unit_name()
    local hangarUnit = ::getAircraftByName(hangarUnitName)
    return ::has_feature("DamageModelViewer") && hangarUnit && (::isTank(hangarUnit) || ::has_feature("DamageModelViewerAircraft"))
  }

  function reinit()
  {
    if (!::g_login.isLoggedIn())
      return

    updateUnitInfo()
    update()
  }

  function updateUnitInfo(fircedUnitId = null)
  {
    local unitId = fircedUnitId || ::hangar_get_current_unit_name()
    if (unit && unitId == unit.name)
      return
    unit = ::getAircraftByName(unitId)
    if( ! unit)
      return
    crew = ::getCrewByAir(unit)
    loadUnitBlk()
    local map = ::getTblValue("xray", unitBlk)
    xrayRemap = map ? ::u.map(map, function(val) { return val }) : {}
    resetXrayCache()
    clearHint()
    difficulty = ::get_difficulty_by_ediff(::get_current_ediff())
    updateSecondaryMods()
  }

  function updateNoPartsNotification()
  {
    local isShow = ::hangar_model_load_manager.getLoadState() == HangarModelLoadState.LOADED &&
      getCurrentViewMode() == ::DM_VIEWER_ARMOR && ::hangar_get_dm_viewer_parts_count() == 0
    local handler = ::handlersManager.getActiveBaseHandler()
    if (!handler || !::check_obj(handler.scene))
      return
    local obj = handler.scene.findObject("unit_has_no_armoring")
    if (!::check_obj(obj))
      return
    obj.show(isShow)
    clearHint()
  }

  function loadUnitBlk()
  {
    clearUnitWeaponBlkList() //unit weapons are part of unit blk, should be unloaded togeter with unitBlk
    unitBlk = ::get_full_unit_blk(unit.name)
  }

  function getUnitWeaponList()
  {
    if(unitWeaponBlkList == null)
      recacheWeapons()
    return unitWeaponBlkList
  }

  function recacheWeapons()
  {
    unitWeaponBlkList = []
    if( ! unitBlk)
      return

    local primaryList = [ ::get_last_primary_weapon(unit) ]
    foreach (modName in ::getPrimaryWeaponsList(unit))
      ::u.appendOnce(modName, primaryList)

    foreach(modName in primaryList)
    {
      local commonWeapons = ::getCommonWeaponsBlk(unitBlk, modName)
      local compareWeaponFunc = function(w1, w2)
      {
        return ::u.isEqual(w1?.trigger ?? "", w2?.trigger ?? "")
            && ::u.isEqual(w1?.blk ?? "", w2?.blk ?? "")
            && ::u.isEqual(w1?.bullets ?? "", w2?.bullets ?? "")
            && ::u.isEqual(w1?.gunDm ?? "", w2?.gunDm ?? "")
            && ::u.isEqual(w1?.barrelDP ?? "", w2?.barrelDP ?? "")
            && ::u.isEqual(w1?.breechDP ?? "", w2?.breechDP ?? "")
            && ::u.isEqual(w1?.ammoDP ?? "", w2?.ammoDP ?? "")
            && ::u.isEqual(w1?.dm ?? "", w2?.dm ?? "")
      }

      if(commonWeapons != null)
        foreach (weapon in (commonWeapons % "Weapon"))
          if (weapon?.blk && !weapon?.dummy)
            ::u.appendOnce(weapon, unitWeaponBlkList, false, compareWeaponFunc)
    }

    local curPresetName =  ::get_last_weapon(unit.name)
    local rawPresetsList = unitBlk.weapon_presets % "preset"
    local presetsList = ::u.filter(rawPresetsList, @(p) p?.name == curPresetName).extend(
      ::u.filter(rawPresetsList, @(p) p?.name != curPresetName))

    foreach (preset in presetsList)
    {
      if( ! ("blk" in preset))
        continue
      local presetBlk = ::DataBlock(preset["blk"])
      foreach (weapon in (presetBlk % "Weapon"))  // preset can have many weapons in it or no one
        if (weapon?.blk && !weapon?.dummy)
          ::u.appendOnce(::u.copy(weapon), unitWeaponBlkList, false, ::u.isEqual)
    }
  }

  function toggle(state = null)
  {
    if (state == view_mode)
      return

    view_mode =
      (state == null) ? (( view_mode + 1 ) % modes.len()) :
      (state in modes) ? state :
      ::DM_VIEWER_NONE

    //need to update active status before repaint
    if (!update() && active)
      show()
    if (!active || view_mode == ::DM_VIEWER_NONE)
      clearHint()
  }

  function show(vis = true)
  {
    active = vis
    local viewMode = (active && canUse()) ? view_mode : ::DM_VIEWER_NONE
    setCurrentViewMode(viewMode)
    if (!active)
      clearHint()
    repaint()
  }

  function update()
  {
    updateNoPartsNotification()

    local newActive = canUse() && !::handlersManager.isAnyModalHandlerActive()
    if (!newActive && !active) //no need to check other conditions when not canUse and not active.
      return false

    local handler = ::handlersManager.getActiveBaseHandler()
    newActive = newActive && handler && (("canShowDmViewer" in handler) ? handler.canShowDmViewer() : false)
    if (::top_menu_handler && ::top_menu_handler.isSceneActive())
      newActive = newActive && ::top_menu_handler.canShowDmViewer()

    if (newActive == active)
    {
      repaint()
      return false
    }

    show(newActive)
    return true
  }

  function repaint()
  {
    local handler = ::handlersManager.getActiveBaseHandler()
    if (!handler)
      return

    local obj = ::showBtn("air_info_dmviewer_listbox", canUse(), handler.scene)
    if(!::checkObj(obj))
      return

    obj.setValue(view_mode)
    obj.enable(active)

    // Protection analysis button
    if (::has_feature("DmViewerProtectionAnalysis"))
    {
      obj = handler.scene.findObject("dmviewer_protection_analysis_btn")
      if (::check_obj(obj))
        obj.show(view_mode == ::DM_VIEWER_ARMOR && ::isTank(unit))
    }

    // Outer parts visibility toggle in Armor and Xray modes
    if (::has_feature("DmViewerExternalArmorHiding"))
    {
      obj = handler.scene.findObject("dmviewer_show_external_dm")
      if (::check_obj(obj))
      {
        local isShowOption = view_mode == ::DM_VIEWER_ARMOR && unit.isTank()
        obj.show(isShowOption)
        if (isShowOption)
          obj.setValue(isVisibleExternalPartsArmor)
      }
      obj = handler.scene.findObject("dmviewer_show_extra_xray")
      if (::check_obj(obj))
      {
        local isShowOption = view_mode == ::DM_VIEWER_XRAY && unit.isTank()
        obj.show(isShowOption)
        if (isShowOption)
          obj.setValue(isVisibleExternalPartsXray)
      }
    }

    // Customization navbar button
    obj = handler.scene.findObject("btn_dm_viewer")
    if(!::checkObj(obj))
      return

    local modeNameCur  = modes[ view_mode  ]
    local modeNameNext = modes[ ( view_mode + 1 ) % modes.len() ]

    obj.tooltip = ::loc("mainmenu/viewDamageModel/tooltip_" + modeNameNext)
    obj.setValue(::loc("mainmenu/btn_dm_viewer_" + modeNameNext))

    local objIcon = obj.findObject("btn_dm_viewer_icon")
    if (::checkObj(objIcon))
      objIcon["background-image"] = "#ui/gameuiskin#btn_dm_viewer_" + modeNameCur + ".svg"
  }

  function clearHint()
  {
    updateHint({ thickness = 0, name = null, posX = 0, posY = 0})
  }

  function clearUnitWeaponBlkList()
  {
    unitWeaponBlkList = null
  }

  function getHintObj()
  {
    local handler = ::handlersManager.getActiveBaseHandler()
    if (!handler)
      return null
    local res = handler.scene.findObject("dmviewer_hint")
    return ::check_obj(res) ? res : null
  }

  function resetPrevHint()
  {
    prevHintParams = {}
  }

  function hasPrevHint()
  {
    return prevHintParams.len() != 0
  }

  function updateHint(params)
  {
    if (!active)
    {
      if (hasPrevHint())
      {
        resetPrevHint()
        local hintObj = getHintObj()
        if (hintObj)
          hintObj.show(false)
      }
      return
    }

    local needUpdatePos = false
    local needUpdateContent = false

    if(view_mode == ::DM_VIEWER_XRAY)
      // change tooltip info only for new unit part
      needUpdateContent = (::getTblValue("name", params, true) != ::getTblValue("name", prevHintParams, false))
    else
      foreach (key, val in params)
        if (val != ::getTblValue(key, prevHintParams))
        {
          if (key == "posX" || key == "posY")
            needUpdatePos = true
          else
            needUpdateContent = true
        }

    if (!needUpdatePos && !needUpdateContent)
      return
    prevHintParams = params

    local obj = getHintObj()
    if(!obj)
      return
    if (needUpdatePos && !needUpdateContent)
      return placeHint(obj)

    local nameId = getPartNameId(params)
    local isVisible = nameId != ""
    obj.show(isVisible)
    if (!isVisible)
      return

    local info = { title="", desc="" }
    local isUseCache = view_mode == ::DM_VIEWER_XRAY && !isDebugMode
    local cacheId = ::getTblValue("name", params, "")

    if (isUseCache && (cacheId in xrayDescriptionCache))
      info = xrayDescriptionCache[cacheId]
    else
    {
      info = getPartTooltipInfo(nameId, params)
      info.title = ::stringReplace(info.title, " ", ::nbsp)
      info.desc  = ::stringReplace(info.desc,  " ", ::nbsp)

      if (isUseCache)
        xrayDescriptionCache[cacheId] <- info
    }

    obj.findObject("dmviewer_title").setValue(info.title)
    obj.findObject("dmviewer_desc").setValue(info.desc)
    placeHint(obj)
  }

  function placeHint(obj)
  {
    if(!::checkObj(obj))
      return
    local guiScene = obj.getScene()

    guiScene.setUpdatesEnabled(true, true)
    local cursorPos = ::get_dagui_mouse_cursor_pos_RC()
    local size = obj.getSize()
    local posX = ::clamp(cursorPos[0] + offset[0], unsafe[0], ::max(unsafe[0], screen[0] - unsafe[0] - size[0]))
    local posY = ::clamp(cursorPos[1] + offset[1], unsafe[1], ::max(unsafe[1], screen[1] - unsafe[1] - size[1]))
    obj.pos = ::format("%d, %d", posX, posY)
  }

  function getPartNameId(params)
  {
    local nameId = ::getTblValue("name", params) || ""
    if (view_mode != ::DM_VIEWER_XRAY || nameId == "")
      return nameId

    nameId = ::getTblValue(nameId, xrayRemap, nameId)
    foreach(re in prepareNameId)
      nameId = re.pattern.replace(re.replace, nameId)
    if (nameId == "gunner")
      nameId += "_" + ::getUnitTypeTextByUnit(unit).tolower()
    return nameId
  }

  function getPartNameLocText(nameId)
  {
    local localizedName = ""
    local localizationSources = ["armor_class/", "dmg_msg_short/", "weapons_types/"]
    local nameVariations = [nameId]
    local idxSeparator = nameId.find("_")
    if(idxSeparator)
      nameVariations.push(nameId.slice(0, idxSeparator))
    if(unit != null)
      nameVariations.push(::getUnitTypeText(unit.esUnitType).tolower() + "_" + nameId)

    foreach(localizationSource in localizationSources)
      foreach(nameVariant in nameVariations)
      {
        localizedName = ::loc(localizationSource + nameVariant, "")
        if(localizedName != "")
          return ::g_string.utf8ToUpper(localizedName, 1);
      }
    return nameId
  }

  function getPartTooltipInfo(nameId, params)
  {
    local res = {
      title = ""
      desc  = ""
    }

    local isHuman = nameId == "steel_tankman"
    if (isHuman || nameId == "")
      return res

    params.nameId <- nameId

    switch (view_mode)
    {
      case ::DM_VIEWER_ARMOR:
        res.desc = getDescriptionInArmorMode(params)
        break
      case ::DM_VIEWER_XRAY:
        res.desc = getDescriptionInXrayMode(params)
        break
      default:
    }

    res.title = getPartNameLocText(params?.partLocId ?? params.nameId)

    return res
  }

  function getDescriptionInArmorMode(params)
  {
    local desc = []

    local solid = ::getTblValue("solid", params)
    local variableThickness = ::getTblValue("variable_thickness", params)
    local thickness = ::getTblValue("thickness", params)
    local effectiveThickness = ::getTblValue("effective_thickness", params)

    if (solid && variableThickness)
    {
      desc.append(::loc("armor_class/variable_thickness_armor"))
    }
    else if (thickness)
    {
      local thicknessStr = thickness.tostring()
      desc.append(::loc("armor_class/thickness") + ::nbsp +
        ::colorize("activeTextColor", thicknessStr) + ::nbsp + ::loc("measureUnits/mm"))
    }

    if (effectiveThickness)
    {
      if (solid)
      {
        desc.append(::loc("armor_class/armor_dimensions_at_point") + ::nbsp +
          ::colorize("activeTextColor", ::round(effectiveThickness)) +
          ::nbsp + ::loc("measureUnits/mm"))
      }
      else
      {
        local effectiveThicknessClamped = ::min(effectiveThickness,
          ::min((relativeArmorThreshold * thickness).tointeger(), absoluteArmorThreshold))

        desc.append(::loc("armor_class/effective_thickness") + ::nbsp +
          (effectiveThicknessClamped < effectiveThickness ? ">" : "") +
          ::round(effectiveThicknessClamped) + ::nbsp + ::loc("measureUnits/mm"))
      }
    }

    local normalAngleValue = ::getTblValue("normal_angle", params, null)
    if (normalAngleValue != null)
      desc.append(::loc("armor_class/normal_angle") + ::nbsp +
        (normalAngleValue+0.5).tointeger() + ::nbsp + ::loc("measureUnits/deg"))

    if(isDebugMode)
      desc.push("\n" + ::colorize("badTextColor", params.nameId))

    return ::g_string.implode(desc, "\n")
  }

  function getFirstFound(dataArray, getter, defValue = null)
  {
    local result = null
    foreach (data in dataArray)
    {
      result = getter(data)
      if (result != null)
        break
    }
    return result ?? defValue
  }

  function getDescriptionInXrayMode(params)
  {
    if (!unit || !unitBlk)
      return ""

    if (!::has_feature("XRayDescription") || !params?.name)
      return ""

    local partId = params?.nameId ?? ""
    local partName = params.name
    local weaponPartName = null

    local desc = []

    switch (partId)
    {
      case "engine":              // Engines
        switch (unit.esUnitType)
        {
          case ::ES_UNIT_TYPE_TANK:
            local infoBlk = unitBlk?.VehiclePhys?.engine
            if(infoBlk)
            {
              local engineInfo = []
              if (infoBlk?.manufacturer)
                engineInfo.push(::loc("engine_manufacturer/" + infoBlk.manufacturer))
              if (infoBlk?.model)
                engineInfo.push(::loc("engine_model/" + infoBlk.model))

              local engineConfig = []
              if (infoBlk?.configuration)
                engineConfig.push(::loc("engine_configuration/" + infoBlk.configuration))
              if (infoBlk?.type)
                engineConfig.push(g_string.utf8ToLower(::loc("engine_type/" + infoBlk.type)))

              local engineString = ::g_string.implode(engineInfo, " ")
              if (engineConfig.len())
                engineString += " (" + ::g_string.implode(engineConfig, " ") + ")"
              if (engineString.len())
                desc.push(engineString)

              if (infoBlk?.displacement)
                desc.push(::loc("engine_displacement")
                          + ::loc("ui/colon")
                          + ::loc("measureUnits/displacement", { num = infoBlk.displacement.tointeger() }))
            }

            if ( ! isSecondaryModsValid)
              updateSecondaryMods()

            local currentParams = getTblValueByPath("modificators." + difficulty.crewSkillName, unit)
            if (isSecondaryModsValid && currentParams && currentParams.horsePowers && currentParams.maxHorsePowersRPM)
            {
              desc.push(::format("%s %s (%s %d %s)", ::loc("engine_power") + ::loc("ui/colon"),
                ::g_measure_type.HORSEPOWERS.getMeasureUnitsText(currentParams.horsePowers),
                ::loc("shop/unitValidCondition"), currentParams.maxHorsePowersRPM.tointeger(), ::loc("measureUnits/rpm")))
            }
            if (infoBlk)
              desc.push(getMassInfo(infoBlk))
          break;

          case ::ES_UNIT_TYPE_AIRCRAFT:
          case ::ES_UNIT_TYPE_HELICOPTER:
            local partIndex = ::to_integer_safe(trimBetween(partName, "engine", "_"), -1, false)
            if (partIndex <= 0)
              break

            local fmBlk = ::get_fm_file(unit.name, unitBlk)
            if (!fmBlk)
              break

            partIndex-- //engine1_dm -> Engine0

            local infoBlk = getInfoBlk(partName)
            local engineInfo = []
            if (infoBlk?.manufacturer)
              engineInfo.push(::loc("engine_manufacturer/" + infoBlk.manufacturer))
            if (infoBlk?.model)
              engineInfo.push(::loc("engine_model/" + infoBlk.model))

            local enginePartId = infoBlk?.part_id ?? ("Engine" + partIndex.tostring())
            local engineTypeId = "EngineType" + (fmBlk?[enginePartId].Type ?? -1).tostring()
            local engineMainBlk = fmBlk?[engineTypeId].Main ?? fmBlk?[enginePartId].Main
            if (!engineMainBlk)
            { // try to find booster
              local numEngines = 0
              while(("Engine" + numEngines) in fmBlk)
                numEngines ++
              local boosterPartIndex = partIndex - numEngines //engine3_dm -> Booster0
              engineMainBlk = getTblValueByPath("Booster" + boosterPartIndex + ".Main", fmBlk)
            }

            if (!engineMainBlk)
              break
            local engineType = getFirstFound([infoBlk, engineMainBlk], @(b) b?.Type ?? b?.type, "").tolower()
            if (engineType == "inline" || engineType == "radial")
            {
              local cylinders = getFirstFound([infoBlk, engineMainBlk], @(b) b?.Cylinders ?? b?.cylinders, 0)
              if (cylinders > 0)
                engineInfo.push(cylinders + ::loc("engine_cylinders_postfix"))
            }
            if (engineType && engineType.len())
              engineInfo.push(g_string.utf8ToLower(::loc("plane_engine_type/" + engineType)))
            desc.push(::g_string.implode(engineInfo, " "))

            // display cooling type only for Inline and Radial engines
            if ((engineType == "inline" || engineType == "radial")
                && "IsWaterCooled" in engineMainBlk)           // Plane : Engine : Cooling
            {
              local coolingKey = engineMainBlk?.IsWaterCooled ? "water" : "air"
              desc.push(::loc("plane_engine_cooling_type") + ::loc("ui/colon")
              + ::loc("plane_engine_cooling_type_" + coolingKey))
            }

            if (!isSecondaryModsValid)
            {
              updateSecondaryMods()
              break;
            }
            // calculating power values
            local powerMax = 0
            local powerTakeoff = 0
            local thrustMax = 0
            local thrustTakeoff = 0
            local horsePowerValue = getFirstFound([infoBlk, engineMainBlk],
              @(b) b?.ThrustMax?.PowerMax0 ?? b?.HorsePowers ?? b?.Power, 0)
            local thrustValue = getFirstFound([infoBlk, engineMainBlk], @(b) b?.ThrustMax?.ThrustMax0, 0)
            local throttleBoost = getFirstFound([infoBlk, engineMainBlk], @(b) b?.ThrottleBoost, 0)
            local afterburnerBoost = getFirstFound([infoBlk, engineMainBlk], @(b) b?.AfterburnerBoost, 0)
            // for planes modifications have delta values
            local thrustModDelta = getTblValueByPath("modificators." +
              difficulty.crewSkillName + ".thrust", unit, 0) / KGF_TO_NEWTON  // mod thrust comes in Newtons
            local horsepowerModDelta = getTblValueByPath("modificators." +
              difficulty.crewSkillName + ".horsePowers", unit, 0)
            switch(engineType)
            {
              case "inline":
              case "radial":
                if (throttleBoost > 1)
                {
                  powerMax = horsePowerValue
                  powerTakeoff = horsePowerValue * throttleBoost * afterburnerBoost
                }
                else
                  powerTakeoff = horsePowerValue
              break

              case "rocket":
                local sources = [infoBlk, engineMainBlk]
                local boosterMainBlk = getTblValueByPath("Booster" + partIndex + ".Main", fmBlk)
                if (boosterMainBlk)
                  sources.insert(1, boosterMainBlk)
                thrustTakeoff = getFirstFound(sources, @(b) b?.Thrust ?? b?.thrust, 0)
              break

              case "turboprop":
                  powerMax = horsePowerValue
                  thrustMax = thrustValue
              break

              case "jet":
              case "pvrd":
              default:
                if (throttleBoost > 1 && afterburnerBoost > 1)
                {
                  thrustTakeoff = thrustValue * afterburnerBoost
                  thrustMax = thrustValue
                }
                else
                  thrustTakeoff = thrustValue
              break
            }

            // final values can be overriden in info block
            powerMax = ::getTblValue("power_max", infoBlk, powerMax)
            powerTakeoff = ::getTblValue("power_takeoff", infoBlk, powerTakeoff)
            thrustMax = ::getTblValue("thrust_max", infoBlk, thrustMax)
            thrustTakeoff = ::getTblValue("thrust_takeoff", infoBlk, thrustTakeoff)

            // display power values
            if (powerMax > 0)
            {
              powerMax += horsepowerModDelta
              desc.push(::loc("engine_power_max") + ::loc("ui/colon")
                + ::g_measure_type.HORSEPOWERS.getMeasureUnitsText(powerMax))
            }
            if (powerTakeoff > 0)
            {
              powerTakeoff += horsepowerModDelta
              desc.push(::loc("engine_power_takeoff") + ::loc("ui/colon")
                + ::g_measure_type.HORSEPOWERS.getMeasureUnitsText(powerTakeoff))
            }
            if (thrustMax > 0)
            {
              thrustMax += thrustModDelta
              desc.push(::loc("engine_thrust_max") + ::loc("ui/colon")
                + ::g_measure_type.THRUST_KGF.getMeasureUnitsText(thrustMax))
            }
            if (thrustTakeoff > 0)
            {
              thrustTakeoff += thrustModDelta
              desc.push(::loc("engine_thrust_takeoff") + ::loc("ui/colon")
                + ::g_measure_type.THRUST_KGF.getMeasureUnitsText(thrustTakeoff))
            }

            // mass
            desc.push(getMassInfo(infoBlk))
          break;
        }
        break

      case "transmission":
        local info = unitBlk?.VehiclePhys?.mechanics
        if (info)
        {
          local manufacturer = info?.manufacturer ? ::loc("transmission_manufacturer/" + info.manufacturer,
            ::loc("engine_manufacturer/" + info.manufacturer, ""))
                               : ""
          local model = info?.model ? ::loc("transmission_model/" + info.model, "") : ""
          local props = info?.type ? ::g_string.utf8ToLower(::loc("transmission_type/" + info.type, "")) : ""
          desc.push(::g_string.implode([ manufacturer, model ], " ") +
            (props == "" ? "" : ::loc("ui/parentheses/space", { text = props })))

          local maxSpeed = unit?.modificators?[difficulty.crewSkillName]?.maxSpeed ?? 0
          if (maxSpeed && info?.gearRatios)
          {
            local gearsF = 0
            local gearsB = 0
            local ratioF = 0
            local ratioB = 0
            foreach (gear in (info.gearRatios % "ratio")) {
              if (gear > 0) {
                gearsF++
                ratioF = ratioF ? ::min(ratioF, gear) : gear
              }
              else if (gear < 0) {
                gearsB++
                ratioB = ratioB ? ::min(ratioB, -gear) : -gear
              }
            }
            local maxSpeedF = maxSpeed
            local maxSpeedB = ratioB ? (maxSpeed * ratioF / ratioB) : 0
            if (maxSpeedF && gearsF)
              desc.append(::loc("xray/transmission/maxSpeed/forward") + ::loc("ui/colon") +
                ::countMeasure(0, maxSpeedF) + ::loc("ui/comma") +
                  ::loc("xray/transmission/gears") + ::loc("ui/colon") + gearsF)
            if (maxSpeedB && gearsB)
              desc.append(::loc("xray/transmission/maxSpeed/backward") + ::loc("ui/colon") +
                ::countMeasure(0, maxSpeedB) + ::loc("ui/comma") +
                  ::loc("xray/transmission/gears") + ::loc("ui/colon") + gearsB)
          }
        }
        break

      case "ammo_turret":
      case "ammo_body":
      case "ammunition_storage":
        local isShip = unit.isShip()
        if (isShip)
        {
          local ammoQuantity = getAmmoQuantityByPartName(partName)
          if (ammoQuantity > 1)
            desc.push(::loc("shop/ammo") + ::loc("ui/colon") + ammoQuantity)
        }
        local stowageInfo = getAmmoStowageInfo(null, partName, isShip)
        if (stowageInfo.isCharges)
          params.partLocId <- isShip ? "ship_charges_storage" : "ammo_charges"
        if (stowageInfo.firstStageCount)
        {
          local txt = ::loc("xray/ammo/first_stage")
          if (unit.isTank())
            txt += ::loc("ui/comma") + stowageInfo.firstStageCount + " " + ::loc("measureUnits/pcs")
          desc.append(txt)
        }
        if (stowageInfo.isAutoLoad)
            desc.append(::loc("xray/ammo/auto_load"))
        break

      case "drive_turret_h":
      case "drive_turret_v":

        weaponPartName = ::stringReplace(partName, partId, "gun_barrel")
        local weaponInfoBlk = getWeaponByXrayPartName(weaponPartName)
        if( ! weaponInfoBlk)
          break
        local isHorizontal = partId == "drive_turret_h"
        desc.extend(getWeaponDriveTurretDesc(weaponPartName, weaponInfoBlk, isHorizontal, !isHorizontal))
        break

      case "main_caliber_turret":
      case "auxiliary_caliber_turret":
      case "aa_turret":
        weaponPartName = ::stringReplace(partName, "turret", "gun")
        foreach(weapon in getUnitWeaponList())
          if (weapon?.turret?.gunnerDm == partName && weapon?.breechDP)
          {
            weaponPartName = weapon.breechDP
            break
          }
        // No break!

      case "mg":
      case "gun":
      case "mgun":
      case "cannon":
      case "mask":
      case "gun_mask":
      case "gun_barrel":
      case "cannon_breech":
      case "tt":
      case "torpedo":
      case "main_caliber_gun":
      case "auxiliary_caliber_gun":
      case "depth_charge":
      case "aa_gun":

        weaponPartName = weaponPartName || partName
        local weaponInfoBlk = getWeaponByXrayPartName(weaponPartName)
        if( ! weaponInfoBlk)
          break

        local isSpecialBullet = ::isInArray(partId, [ "torpedo", "depth_charge" ])
        local isSpecialBulletEmitter = ::isInArray(partId, [ "tt" ])

        local weaponBlkLink = weaponInfoBlk?.blk ?? ""
        local weaponName = ::get_weapon_name_by_blk_path(weaponBlkLink)

        local ammo = isSpecialBullet ? 1 : getWeaponTotalBulletCount(partId, weaponInfoBlk)
        local shouldShowAmmoInTitle = isSpecialBulletEmitter
        local ammoTxt = ammo > 1 && shouldShowAmmoInTitle ? ::format(::loc("weapons/counter"), ammo) : ""

        if(weaponName != "")
          desc.push(::loc("weapons" + weaponName) + ammoTxt)
        if(weaponInfoBlk && ammo > 1 && !shouldShowAmmoInTitle)
          desc.push(::loc("shop/ammo") + ::loc("ui/colon") + ammo)

        if (isSpecialBullet || isSpecialBulletEmitter)
          desc[desc.len() - 1] += ::getWeaponXrayDescText(weaponInfoBlk, unit, ::get_current_ediff())
        else {
          local status = getWeaponStatus(weaponPartName, weaponInfoBlk)
          desc.extend(getWeaponShotFreqAndReloadTimeDesc(weaponName, weaponInfoBlk, status))
          desc.push(getMassInfo(::DataBlock(weaponBlkLink)))
          if (status?.isPrimary || status?.isSecondary)
          {
            if (weaponInfoBlk?.autoLoader)
              desc.push(::loc("xray/ammo/auto_load"))
            local firstStageCount = getAmmoStowageInfo(weaponInfoBlk?.trigger).firstStageCount
            if (firstStageCount)
              desc.push(::loc("xray/ammo/first_stage") + ::loc("ui/colon") + firstStageCount)
          }
          desc.extend(getWeaponDriveTurretDesc(weaponPartName, weaponInfoBlk, true, true))
        }

        checkPartLocId(partId, partName, weaponInfoBlk, params)
      break;

      case "tank":                     // aircraft fuel tank (tank's fuel tank is 'fuel_tank')
        local tankInfoTable = unit?.info?[params.name]
        if (!tankInfoTable)
          tankInfoTable = unit?.info?.tanks_params
        if (!tankInfoTable)
          break

        local tankInfo = []

        if ("protected" in tankInfoTable)
        {
          tankInfo.push(tankInfoTable.protected ?
          ::loc("fuelTank/selfsealing") :
          ::loc("fuelTank/not_selfsealing"))
        }
        if ("protected_boost" in tankInfoTable)
          tankInfo.push(::loc("fuelTank/neutralGasSystem"))
        if (tankInfo.len())
          desc.push(::g_string.implode(tankInfo, ", "))

      break

      case "composite_armor_hull":            // tank Composite armor
      case "composite_armor_turret":          // tank Composite armor
      case "ex_era_hull":                     // tank Explosive reactive armor
      case "ex_era_turret":                   // tank Explosive reactive armor
        local info = getModernArmorParamsByDmPartName(partName)

        local strUnits = ::nbsp + ::loc("measureUnits/mm")
        local strBullet = ::loc("ui/bullet")
        local strColon  = ::loc("ui/colon")

        if (info.titleLoc != "")
          params.nameId <- info.titleLoc

        foreach (data in info.referenceProtectionArray)
        {
          if (::u.isPoint2(data.angles))
            desc.push(::loc("shop/armorThicknessEquivalent/angles",
              { angle1 = ::abs(data.angles.y), angle2 = ::abs(data.angles.x) }))
          else
            desc.push(::loc("shop/armorThicknessEquivalent"))

          if (data.kineticProtectionEquivalent)
            desc.push(strBullet + ::loc("shop/armorThicknessEquivalent/kinetic") + strColon +
              ::round(data.kineticProtectionEquivalent) + strUnits)
          if (data.cumulativeProtectionEquivalent)
            desc.push(strBullet + ::loc("shop/armorThicknessEquivalent/cumulative") + strColon +
              ::round(data.cumulativeProtectionEquivalent) + strUnits)
        }

        local blockSep = desc.len() ? "\n" : ""

        if (info.isComposite && !::u.isEmpty(info.layersArray)) // composite armor
        {
          local texts = []
          foreach (layer in info.layersArray)
          {
            local thicknessText = ""
            if (::u.isFloat(layer?.armorThickness) && layer.armorThickness > 0)
              thicknessText = ::round(layer.armorThickness).tostring()
            else if (::u.isPoint2(layer?.armorThickness) && layer.armorThickness.x > 0 && layer.armorThickness.y > 0)
              thicknessText = ::round(layer.armorThickness.x).tostring() + ::loc("ui/mdash") + ::round(layer.armorThickness.y).tostring()
            if (thicknessText != "")
              thicknessText = ::loc("ui/parentheses/space", { text = thicknessText + strUnits })
            texts.append(strBullet + getPartNameLocText(layer?.armorClass) + thicknessText)
          }
          desc.push(blockSep + ::loc("xray/armor_composition") + ::loc("ui/colon") + "\n" + ::g_string.implode(texts, "\n"))
        }
        else if (!info.isComposite && !::u.isEmpty(info.armorClass)) // reactive armor
          desc.push(blockSep + ::loc("plane_engine_type") + ::loc("ui/colon") + getPartNameLocText(info.armorClass))

        break

      case "optic_gun":
        local info = unitBlk?.cockpit
        if (info?.sightName)
        {
          local fovToZoom = @(fov) (2*::asin(::sin((80/2)/(180/PI))/fov))*(180/PI)
          local zoom = ::u.map([info.zoomOutFov, info.zoomInFov], @(fov) fovToZoom(fov))
          if (::abs(zoom[0] - zoom[1]) < 0.1)
            zoom.remove(0)
          local zoomTexts = ::u.map(zoom, @(zoom) zoom ? ::format("%.1fx", zoom) : "")
          zoomTexts = ::g_string.implode(zoomTexts, ::loc("ui/mdash"))
          desc.push(::loc("sight_model/" + info.sightName, ""))
          desc.push(::loc("optic/zoom") + ::loc("ui/colon") + zoomTexts)
        }
        break
    }

    if (isDebugMode)
      desc.push("\n" + ::colorize("badTextColor", partName))

    local description = ::g_string.implode(desc, "\n")
    return description
  }

  function getWeaponTotalBulletCount(partId, weaponInfoBlk)
  {
    if (partId == "cannon_breech")
    {
      local result = 0
      local currentBreechDp = weaponInfoBlk?.breechDP
      if (!currentBreechDp)
        return result
      foreach(weapon in getUnitWeaponList())
      {
        if (weapon?.breechDP == currentBreechDp)
          result += ::getTblValue("bullets", weapon, 0)
      }
      return result
    } else
      return ::getTblValue("bullets", weaponInfoBlk, 0)
  }

  function getInfoBlk(partName = null)
  {
    local sources = [unitBlk]
    local unitTags = ::getTblValue(unit.name, ::get_unittags_blk(), null)
    if (unitTags != null)
      sources.insert(0, unitTags)
    local infoBlk = getFirstFound(sources, @(b) partName ? b?.info?[partName] : b?.info)
    if (infoBlk && partName != null && "alias" in infoBlk)
      infoBlk = getInfoBlk(infoBlk.alias)
    return infoBlk
  }

  function getXrayViewerDataByDmPartName(partName)
  {
    local dataBlk = unitBlk && unitBlk?.xray_viewer_data
    if (dataBlk)
      for (local b = 0; b < dataBlk.blockCount(); b++)
      {
        local blk = dataBlk.getBlock(b)
        if (blk?.xrayDmPart == partName)
          return blk
      }
    return null
  }

  function getAmmoQuantityByPartName(partName)
  {
    local ammoStowages = unitBlk?.ammoStowages
    if (ammoStowages)
      for (local i = 0; i < ammoStowages.blockCount(); i++)
      {
        local blk = ammoStowages.getBlock(i)
        foreach (blockName in [ "shells", "charges" ])
          foreach (shells in blk % blockName)
            if (shells?[partName])
              return shells[partName].count
      }
    return 0
  }

  function getWeaponByXrayPartName(partName)
  {
    local partLinkSources = [ "dm", "barrelDP", "breechDP", "maskDP", "gunDm", "ammoDP", "emitter" ]
    local partLinkSourcesGenFmt = [ "emitterGenFmt", "ammoDpGenFmt" ]
    local weaponList = getUnitWeaponList()
    foreach(weapon in weaponList)
    {
      foreach(linkKey in partLinkSources)
        if(linkKey in weapon && weapon[linkKey] == partName)
          return weapon
      if (::u.isPoint2(weapon?.emitterGenRange))
      {
        local rangeMin = ::min(weapon.emitterGenRange.x, weapon.emitterGenRange.y)
        local rangeMax = ::max(weapon.emitterGenRange.x, weapon.emitterGenRange.y)
        foreach(linkKeyFmt in partLinkSourcesGenFmt)
          if (weapon?[linkKeyFmt])
          {
            if (weapon[linkKeyFmt].find("%02d") == null)
            {
              dagor.assertf(false, "Bad weapon param " + linkKeyFmt + "='" + weapon[linkKeyFmt] +
                "' on " + unit.name)
              continue
            }
            for(local i = rangeMin; i <= rangeMax; i++)
              if (::format(weapon[linkKeyFmt], i) == partName)
                return weapon
          }
      }
      if("partsDP" in weapon && weapon["partsDP"].find(partName) != null)
        return weapon
    }
    return null
  }

  function getWeaponStatus(weaponPartName, weaponInfoBlk)
  {
    local blkPath = weaponInfoBlk?.blk ?? ""
    local blk = ::DataBlock(blkPath)
    switch (unit.esUnitType)
    {
      case ::ES_UNIT_TYPE_TANK:
        local isRocketGun = blk?.rocketGun
        local isMachinegun = !!blk?.bullet?.caliber && !::isCaliberCannon(1000 * blk.bullet.caliber)
        local isPrimary = !isRocketGun && !isMachinegun
        if (!isPrimary)
        {
          local commonBlk = ::getCommonWeaponsBlk(dmViewer.unitBlk, "")
          foreach (weapon in (commonBlk % "Weapon"))
          {
            if (!weapon?.blk || weapon?.dummy)
              continue
            isPrimary = weapon.blk == blkPath
            break
          }
        }
        local isSecondary = !isPrimary && !isMachinegun
        return { isPrimary = isPrimary, isSecondary = isSecondary, isMachinegun = isMachinegun }
      case ::ES_UNIT_TYPE_SHIP:
        local isPrimaryName       = ::g_string.startsWith(weaponPartName, "main")
        local isSecondaryName     = ::g_string.startsWith(weaponPartName, "auxiliary")
        local isPrimaryTrigger    = weaponInfoBlk?.triggerGroup == "primary"
        local isSecondaryTrigger  = weaponInfoBlk?.triggerGroup == "secondary"
        return {
          isPrimary     = isPrimaryTrigger   || (isPrimaryName   && !isSecondaryTrigger)
          isSecondary   = isSecondaryTrigger || (isSecondaryName && !isPrimaryTrigger)
          isMachinegun  = weaponInfoBlk?.triggerGroup == "machinegun"
        }
      case ::ES_UNIT_TYPE_AIRCRAFT:
      case ::ES_UNIT_TYPE_HELICOPTER:
      default:
        return { isPrimary = true, isSecondary = false, isMachinegun = false }
    }
  }

  function getWeaponDriveTurretDesc(weaponPartName, weaponInfoBlk, needAxisX, needAxisY)
  {
    local desc = []
    local needSingleAxis = !needAxisX || !needAxisY
    local status = getWeaponStatus(weaponPartName, weaponInfoBlk)
    if (!needSingleAxis && ::isTank(unit) && !status.isPrimary && !status.isSecondary)
      return desc

    local deg = ::loc("measureUnits/deg")
    foreach (g in [
      { need = needAxisX, angles = weaponInfoBlk?.limits?.yaw,   label = "shop/angleHorizontalGuidance" }
      { need = needAxisY, angles = weaponInfoBlk?.limits?.pitch, label = "shop/angleVerticalGuidance"   }
    ]) {
      if (!g.need || (!g.angles?.x && !g.angles?.y))
        continue
      local anglesText = (g.angles.x + g.angles.y == 0) ? ::format("±%d%s", g.angles.y, deg)
        : ::format("%d%s/+%d%s", g.angles.x, deg, g.angles.y, deg)
      desc.append(::loc(g.label) + " " + anglesText)
    }

    if (needSingleAxis || status.isPrimary || (::isShip(unit) && status.isSecondary))
    {
      local unitModificators = unit?.modificators?[difficulty.crewSkillName]
      foreach (a in [
        { need = needAxisX, modifName = "turnTurretSpeed",      blkName = "speedYaw",
          shipFxName = [ "mainSpeedYawK",   "auxSpeedYawK",   "aaSpeedYawK"   ] },
        { need = needAxisY, modifName = "turnTurretSpeedPitch", blkName = "speedPitch",
          shipFxName = [ "mainSpeedPitchK", "auxSpeedPitchK", "aaSpeedPitchK" ] },
      ]) {
        if (!a.need)
          continue

        local speed = 0
        switch (unit.esUnitType)
        {
          case ::ES_UNIT_TYPE_TANK:
            local mainTurretSpeed = unitModificators?[a.modifName] ?? 0
            local value = weaponInfoBlk?[a.blkName] ?? 0
            local weapons = getUnitWeaponList()
            local mainTurretValue = weapons?[0]?[a.blkName] ?? 0
            speed = mainTurretValue ? (mainTurretSpeed * value / mainTurretValue) : mainTurretSpeed
            break
          case ::ES_UNIT_TYPE_SHIP:
            local modId   = status.isPrimary    ? "new_main_caliber_turrets"
                          : status.isSecondary  ? "new_aux_caliber_turrets"
                          : status.isMachinegun ? "new_aa_caliber_turrets"
                          : ""
            local effectId = status.isPrimary    ? a.shipFxName[0]
                           : status.isSecondary  ? a.shipFxName[1]
                           : status.isMachinegun ? a.shipFxName[2]
                           : ""
            local baseSpeed = weaponInfoBlk?[a.blkName] ?? 0
            local noModMul = ::get_modifications_blk()?.modifications?[modId]?.effects?[effectId] ?? 1.0
            local modMul =  ::shop_is_modification_enabled(unit.name, modId) ? 1.0 : noModMul
            speed = baseSpeed * modMul
            break
        }

        if (speed)
        {
          local speedTxt = speed < 10 ? ::format("%.1f", speed) : ::format("%d", ::round(speed))
          desc.append(::loc("crewSkillParameter/" + a.modifName) + ::loc("ui/colon") +
            speedTxt + ::loc("measureUnits/deg_per_sec"))
        }
      }
    }

    if (::isTank(unit))
    {
      local gunStabilizer = weaponInfoBlk?.gunStabilizer
      local isStabilizerX = needAxisX && gunStabilizer?.hasHorizontal
      local isStabilizerY = needAxisY && gunStabilizer?.hasVertical
      if (isStabilizerX || isStabilizerY)
      {
        local valueLoc = needSingleAxis ? "options/yes"
          : (isStabilizerX ? "shop/gunStabilizer/twoPlane" : "shop/gunStabilizer/vertical")
        desc.append(::loc("shop/gunStabilizer") + " " + ::loc(valueLoc))
      }
    }

    return desc
  }

  function getWeaponShotFreqAndReloadTimeDesc(weaponName, weaponInfoBlk, status)
  {
    local shotFreqRPM = 0.0 // rounds/min
    local reloadTimeS = 0 // sec

    local weaponBlk = ::DataBlock(weaponInfoBlk?.blk ?? "")
    local isCartridge = weaponBlk?.reloadTime != null
    local cyclicShotFreqS  = weaponBlk?.shotFreq ?? 0.0 // rounds/sec

    switch (unit.esUnitType)
    {
      case ::ES_UNIT_TYPE_AIRCRAFT:
      case ::ES_UNIT_TYPE_HELICOPTER:
        shotFreqRPM = cyclicShotFreqS * 60
        break

      case ::ES_UNIT_TYPE_TANK:
        if (!status.isPrimary)
          break

        local mainGunReloadTime = 0.0
        if (crew)
        {
          local crewSkillParams = ::g_crew_skill_parameters.getParametersByCrewId(crew.id)
          local crewSkill = crewSkillParams?[difficulty.crewSkillName]?.loader
          mainGunReloadTime = crewSkill?.loading_time_mult?.tankLoderReloadingTime ?? 0
        }
        else
          mainGunReloadTime = unit?.modificators?[difficulty.crewSkillName]?.reloadTime ?? 0.0

        local mainGunShotFreq = ::DataBlock(getUnitWeaponList()?[0]?.blk ?? "")?.shotFreq ?? 0.0
        local mainGunReloadCfgVal = mainGunShotFreq ? (1.0 / mainGunShotFreq) : 0.0
        local thisGunReloadCfgVal = cyclicShotFreqS ? (1.0 / cyclicShotFreqS) : 0.0
        local valueMult = mainGunReloadCfgVal ? (mainGunReloadTime / mainGunReloadCfgVal) : 1.0
        reloadTimeS = cyclicShotFreqS ? (thisGunReloadCfgVal * valueMult) : 0.0
        break

      case ::ES_UNIT_TYPE_SHIP:
        if (crew)
        {
          local crewSkillParams = ::g_crew_skill_parameters.getParametersByCrewId(crew.id)
          local crewSkill = crewSkillParams?[difficulty.crewSkillName]?.ship_artillery
          foreach (c in [ "main_caliber_loading_time", "aux_caliber_loading_time", "antiair_caliber_loading_time" ])
          {
            reloadTimeS = (crewSkill?[c]?["weapons" + weaponName]) ?? 0.0
            if (reloadTimeS)
              break
          }
        }
        else
          reloadTimeS = weaponBlk?.reloadTime ?? 0.0

        if (isCartridge)
          shotFreqRPM = cyclicShotFreqS * 60
        else
        {
          shotFreqRPM = reloadTimeS != 0 ? (60 / reloadTimeS) : (cyclicShotFreqS * 60)
          reloadTimeS = 0.0
        }
        break
    }

    local desc = []
    if (shotFreqRPM)
      desc.append(::loc("shop/shotFreq") + " " + ::round(shotFreqRPM) + " " +
        ::loc("measureUnits/rounds_per_min"))
    if (reloadTimeS)
    {
      reloadTimeS = (reloadTimeS % 1) ? ::format("%.1f", reloadTimeS) : ::format("%d", reloadTimeS)
      desc.append(::loc("shop/reloadTime") + " " + reloadTimeS + " " + ::loc("measureUnits/seconds"))
    }
    return desc
  }

  // Gets info either by weaponTrigger (for guns and turrets)
  // or by ammoStowageId (for tank stowage or ship ammo storage)
  function getAmmoStowageInfo(weaponTrigger, ammoStowageId = null, collectOnlyThisStowage = false)
  {
    local res = { firstStageCount = 0, isAutoLoad = false, isCharges = false }
    for (local ammoNum = 1; ammoNum <= 20; ammoNum++) // tanks use 1, ships use 1 - ~10.
    {
      local stowage = unitBlk?.ammoStowages?["ammo" + ammoNum]
      if (!stowage)
        break
      if (weaponTrigger && stowage.weaponTrigger != weaponTrigger)
        continue
      foreach (blockName in [ "shells", "charges" ])
      {
        foreach (block in (stowage % blockName))
        {
          if (ammoStowageId && !block?[ammoStowageId])
            continue
          res.isCharges = blockName == "charges"
          if (block?.autoLoad)
            res.isAutoLoad = true
          if (block?.firstStage || block?.autoLoad)
          {
            if (ammoStowageId && collectOnlyThisStowage)
              res.firstStageCount += block?[ammoStowageId]?.count ?? 0
            else
              for (local i = 0; i < block.blockCount(); i++)
                res.firstStageCount += block.getBlock(i)?.count ?? 0
          }
          return res
        }
      }
    }
    return res
  }

  function getModernArmorParamsByDmPartName(partName)
  {
    local res = {
      isComposite = ::g_string.startsWith(partName, "composite_armor")
      titleLoc = ""
      armorClass = ""
      referenceProtectionArray = []
      layersArray = []
    }

    local blk = getXrayViewerDataByDmPartName(partName)
    if (blk)
    {
      res.titleLoc = blk?.titleLoc ?? ""

      local referenceProtectionBlocks = blk?.referenceProtectionTable ? (blk.referenceProtectionTable % "i")
        : (blk?.kineticProtectionEquivalent || blk?.cumulativeProtectionEquivalent) ? [ blk ]
        : []
      res.referenceProtectionArray = ::u.map(referenceProtectionBlocks, @(b) {
        angles = b?.angles
        kineticProtectionEquivalent    = b?.kineticProtectionEquivalent    ?? 0
        cumulativeProtectionEquivalent = b?.cumulativeProtectionEquivalent ?? 0
      })

      local armorParams = { armorClass = "", armorThickness = 0.0 }
      local armorLayersArray = (blk?.armorArrayText ?? ::DataBlock()) % "layer"

      foreach (layer in armorLayersArray)
      {
        local info = getDamagePartParamsByDmPartName(layer?.dmPart, armorParams)
        if (layer?.xrayTextThickness != null)
          info.armorThickness = layer.xrayTextThickness
        res.layersArray.append(info)
      }
    }
    else
    {
      local armorParams = { armorClass = "", kineticProtectionEquivalent = 0, cumulativeProtectionEquivalent = 0 }
      local info = getDamagePartParamsByDmPartName(partName, armorParams)
      res.referenceProtectionArray = [{
        angles = null
        kineticProtectionEquivalent    = info.kineticProtectionEquivalent
        cumulativeProtectionEquivalent = info.cumulativeProtectionEquivalent
      }]
      res = ::u.tablesCombine(res, info, @(a, b) b == null ? a : b, null, false)
    }

    return res
  }

  function getDamagePartParamsByDmPartName(partName, paramsTbl)
  {
    local res = clone paramsTbl
    if (!unitBlk?.DamageParts)
      return res
    local dmPartsBlk = unitBlk.DamageParts
    res = ::u.tablesCombine(res, dmPartsBlk, @(a, b) b == null ? a : b, null, false)
    for (local b = 0; b < dmPartsBlk.blockCount(); b++)
    {
      local groupBlk = dmPartsBlk.getBlock(b)
      if (!groupBlk || !groupBlk?[partName])
        continue
      res = ::u.tablesCombine(res, groupBlk, @(a, b) b == null ? a : b, null, false)
      res = ::u.tablesCombine(res, groupBlk[partName], @(a, b) b == null ? a : b, null, false)
      break
    }
    return res
  }

  function checkPartLocId(partId, partName, weaponInfoBlk, params)
  {
    switch (unit.esUnitType)
    {
      case ::ES_UNIT_TYPE_TANK:
        if (partId == "gun_barrel" &&  weaponInfoBlk?.blk)
        {
          local status = getWeaponStatus(partName, weaponInfoBlk)
          params.partLocId <- status.isPrimary ? "weapon/primary"
            : status.isMachinegun ? "weapon/machinegun"
            : "weapon/secondary"
        }
        break
      case ::ES_UNIT_TYPE_SHIP:
        if (::g_string.startsWith(partId, "main") && weaponInfoBlk?.triggerGroup == "secondary")
          params.partLocId <- ::stringReplace(partId, "main", "auxiliary")
        if (::g_string.startsWith(partId, "auxiliary") && weaponInfoBlk?.triggerGroup == "primary")
          params.partLocId <- ::stringReplace(partId, "auxiliary", "main")
        break
      case ::ES_UNIT_TYPE_HELICOPTER:
        if (::isInArray(partId, [ "gun", "cannon" ]))
          params.partLocId <- ::g_string.startsWith(weaponInfoBlk?.trigger, "gunner") ? "turret" : "cannon"
    }
  }

  function trimBetween(source, from, to, strict = true)
  {
    local beginIndex = source.find(from) ?? -1
    local endIndex = source.find(to) ?? -1
    if(strict && (beginIndex == -1 || endIndex == -1 || beginIndex >= endIndex))
      return null
    if(beginIndex == -1)
      beginIndex = 0
    beginIndex += from.len()
    if(endIndex == -1)
      beginIndex = source.len()
    return source.slice(beginIndex, endIndex)
  }

  function getMassInfo(data)
  {
    local massPatterns = [
      { variants = ["mass", "Mass"], langKey = "mass/kg" },
      { variants = ["mass_lbs", "Mass_lbs"], langKey = "mass/lbs" }
    ]
    foreach(pattern in massPatterns)
      foreach(nameVariant in pattern.variants)
        if(nameVariant in data)
          return format(::loc("shop/tank_mass") + " " + ::loc(pattern.langKey), data[nameVariant])
    return "";
  }

  function showExternalPartsArmor(isShow)
  {
    isVisibleExternalPartsArmor = isShow
    ::hangar_show_external_dm_parts_change(isShow)
  }

  function showExternalPartsXray(isShow)
  {
    isVisibleExternalPartsXray = isShow
    ::hangar_show_hidden_xray_parts_change(isShow)
  }

  function onEventActiveHandlersChanged(p)
  {
    update()
  }

  function onEventHangarModelLoading(p)
  {
    reinit()
  }

  function onEventHangarModelLoaded(p)
  {
    reinit()
  }

  function onEventUnitModsRecount(p)
  {
    if (p?.unit != unit)
      return
    recacheWeapons()
    resetXrayCache()
  }

  function onEventUnitWeaponChanged(p)
  {
    if (!unit || p?.unitName != unit.name)
      return
    recacheWeapons()
    resetXrayCache()
  }

  function onEventCurrentGameModeIdChanged(p)
  {
    difficulty = ::get_difficulty_by_ediff(::get_current_ediff())
    resetXrayCache()
  }

  function onEventGameLocalizationChanged(p)
  {
    resetXrayCache()
  }
}

::g_script_reloader.registerPersistentDataFromRoot("dmViewer")
::subscribe_handler(::dmViewer, ::g_listener_priority.DEFAULT_HANDLER)

::on_hangar_damage_part_pick <- function on_hangar_damage_part_pick(params) // Called from API
{
  ::dmViewer.updateHint(params)
}
