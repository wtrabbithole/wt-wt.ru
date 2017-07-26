/*
  ::dmViewer API:

  toggle(state = null)  - switch view_mode to state. if state == null view_mode will be increased by 1
  update()              - update dm viewer active status
                          depend on canShowDmViewer function in cur_base_gui_handler and top_menu_handler
                          and modal windows.
*/

::dmViewer <- {
  [PERSISTENT_DATA_PARAMS] = ["active", "view_mode", "_currentViewMode"]

  active = false
  // This is saved view mode. It is used to restore
  // view mode after player returns from somewhere.
  view_mode = ::DM_VIEWER_NONE
  unit = null
  unitBlk = null
  unitWeaponBlkList = null
  xrayRemap = {}

  modes = {
    [::DM_VIEWER_NONE]  = "none",
    [::DM_VIEWER_ARMOR] = "armor",
    [::DM_VIEWER_XRAY]  = "xray",
  }

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
  }

  function init(handler)
  {
    screen = [ ::screen_width(), ::screen_height() ]
    unsafe = [ handler.guiScene.calcString("@bw", null), handler.guiScene.calcString("@bh", null) ]
    offset = [ screen[1] * 0.1, 0 ]

    local guiBlk = ::configs.GUI.get()
    absoluteArmorThreshold = guiBlk.armor_thickness_absolute_threshold || absoluteArmorThreshold
    relativeArmorThreshold = guiBlk.armor_thickness_relative_threshold || relativeArmorThreshold

    updateUnitInfo()
    local timerObj = handler.getObj("dmviewer_hint")
    if (timerObj)
      timerObj.setUserData(handler) //!!FIX ME: it a bad idea link timer to handler.
                                    //better to link all timers here, and switch them off when not active.

    update(handler)
    repaint(handler)
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
    updateUnitInfo()
    update()
  }

  function updateUnitInfo()
  {
    local hangarUnitName = ::hangar_get_current_unit_name()
    if (unit && hangarUnitName == unit.name)
      return
    unit = ::getAircraftByName(hangarUnitName)
    if( ! unit)
      return
    unitBlk = ::DataBlock(::get_unit_file_name(unit.name))
    local map = ::getTblValue("xray", unitBlk)
    xrayRemap = map ? ::u.map(map, function(val) { return val }) : {}
    resetXrayCache()
    clearHint()
    updateSecondaryMods()
    clearUnitWeaponBlkList()
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
    local commonWeapons = ::getCommonWeaponsBlk(unitBlk, "")
    if(commonWeapons != null)
      foreach (weapon in (commonWeapons % "Weapon"))
        unitWeaponBlkList.push(weapon)

    foreach (preset in (unitBlk.weapon_presets % "preset"))
    {
      if( ! ("blk" in preset))
        continue
      local presetBlk = ::DataBlock(preset["blk"])
      foreach (weapon in (presetBlk % "Weapon"))  // preset can have many weapons in it or no one
        unitWeaponBlkList.push(::DataBlock(weapon))
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

  function update(handler = null)
  {
    local newActive = canUse()
    if (!newActive && !active) //no need to check other conditions when not canUse and not active.
      return false

    if (!handler)
      handler = ::handlersManager.getActiveBaseHandler()
    newActive = newActive && (("canShowDmViewer" in handler) ? handler.canShowDmViewer() : false)
    if (::top_menu_handler && ::top_menu_handler.isSceneActive())
      newActive = newActive && ::top_menu_handler.canShowDmViewer()

    if (newActive == active)
      return false

    show(newActive)
    return true
  }

  function repaint(handler = null)
  {
    if (!handler)
      handler = ::handlersManager.getActiveBaseHandler()
    if (!handler)
      return

    local obj = ::showBtn("air_info_dmviewer_listbox", canUse(), handler.scene)
    if(!::checkObj(obj))
      return

    obj.setValue(view_mode)
    obj.enable(active)

    obj = handler.scene.findObject("btn_dm_viewer")
    if(!::checkObj(obj))
      return

    local modeNameCur  = modes[ view_mode  ]
    local modeNameNext = modes[ ( view_mode + 1 ) % modes.len() ]

    obj.tooltip = ::loc("mainmenu/viewDamageModel/tooltip_" + modeNameNext)
    obj.setValue(::loc("mainmenu/btn_dm_viewer_" + modeNameNext))

    local objIcon = obj.findObject("btn_dm_viewer_icon")
    if (::checkObj(objIcon))
      objIcon["background-image"] = "#ui/gameuiskin#btn_dm_viewer_" + modeNameCur
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

    local title = getPartNameLocText(nameId)
    local description = getPartDescription(nameId, params)

    title = ::stringReplace(title, " ", ::nbsp)
    description = ::stringReplace(description, " ", ::nbsp)

    obj.findObject("dmviewer_title").setValue(title)
    obj.findObject("dmviewer_desc").setValue(description)
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
    local posX = ::clamp(cursorPos[0] + offset[0], unsafe[0], screen[0] - unsafe[0] - size[0])
    local posY = ::clamp(cursorPos[1] + offset[1], unsafe[1], screen[1] - unsafe[1] - size[1])
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

  function getPartDescription(nameId, params)
  {
    local isHuman = nameId == "steel_tankman"
    if (isHuman || nameId == "")
      return ""

    switch (view_mode)
    {
      case ::DM_VIEWER_ARMOR:   return getDescriptionInArmorMode(params)
      case ::DM_VIEWER_XRAY:    return getDescriptionInXrayMode(nameId, params)
      default:                  return ""
    }
  }

  function getDescriptionInArmorMode(params)
  {
    local desc = []

    local thickness = ::getTblValue("thickness", params)
    if (thickness)
      desc.append(::loc("armor_class/thickness") + ::nbsp +
        ::colorize("activeTextColor", thickness) + ::nbsp + ::loc("measureUnits/mm"))

    local effectiveThickness = ::getTblValue("effective_thickness", params)
    if (effectiveThickness)
    {
      local effectiveThicknessClamped = ::min(effectiveThickness,
        ::min((relativeArmorThreshold * thickness).tointeger(), absoluteArmorThreshold))

      desc.append(::loc("armor_class/effective_thickness") + ::nbsp +
        (effectiveThicknessClamped < effectiveThickness ? ">" : "") +
        ::roundToDigits(effectiveThicknessClamped, 3) +
        ::nbsp + ::loc("measureUnits/mm"))
    }

    local normalAngleValue = ::getTblValue("normal_angle", params, null)
    if (normalAngleValue != null)
      desc.append(::loc("armor_class/normal_angle") + ::nbsp +
        (normalAngleValue+0.5).tointeger() + ::nbsp + ::loc("measureUnits/deg"))

    return ::implode(desc, "\n")
  }

  function getDescriptionInXrayMode(partId, params)
  {
    if ( ! ::has_feature("XRayDescription") || ! ("name" in params))
      return ""
    local partName = params["name"]
    local cacheKey = partId + partName
    if ( ! isDebugMode && ::getTblValue(cacheKey, xrayDescriptionCache))
      return ::getTblValue(cacheKey, xrayDescriptionCache)

    local desc = []
    local difficulty = ::get_difficulty_by_ediff(::get_current_ediff())

    if ( ! unit || ! unitBlk)
      return "";

    switch (partId)
    {
      case "engine":              // Engines
        local infoBlk = getInfoBlk(partName)
        switch (unit.esUnitType)
        {
          case ::ES_UNIT_TYPE_TANK:
            if(infoBlk)
            {
              local engineString = ""
              local engineInfo = []
              local engineConfig = []
              if (infoBlk.manufacturer)
                engineInfo.push(::loc("engine_manufacturer/" + infoBlk.manufacturer))
              if (infoBlk.model)
                engineInfo.push(::loc("engine_model/" + infoBlk.model))
              if (infoBlk.configuration)
                engineConfig.push(::loc("engine_configuration/" + infoBlk.configuration))
              if (infoBlk.type)
                engineConfig.push(g_string.utf8ToLower(::loc("engine_type/" + infoBlk.type)))
              engineString = ::implode(engineInfo, " ")
              if (engineConfig.len())
                engineString += " (" + ::implode(engineConfig, " ") + ")"
              if (engineString.len())
                desc.push(engineString)
              if (infoBlk.displacement)
              desc.push(::loc("engine_displacement") + ::loc("ui/colon") +
              ::loc("measureUnits/displacement", { num = infoBlk.displacement.tointeger() }))
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
            local fmBlk = ::get_fm_file(unit.name, unitBlk)
            if ( ! fmBlk)
              break
            local partIndex = ::to_integer_safe(trimBetween(partName, "engine", "_"), -1, false)
            if (partIndex < 0)
              break
            local partIndex = partIndex.tointeger() - 1 //engine1_dm -> Engine0

            local engineInfo = []
            if (infoBlk && infoBlk.manufacturer)
              engineInfo.push(::loc("engine_manufacturer/" + infoBlk.manufacturer))
            if (infoBlk && infoBlk.model)
              engineInfo.push(::loc("engine_model/" + infoBlk.model))

            local engineMainBlk = getTblValueByPath(
              ::getTblValue("part_id", infoBlk, "Engine" + partIndex)
              + ".Main", fmBlk)
            if ( ! engineMainBlk)
            { // try to find booster
              local numEngines = 0
              while("Engine" + numEngines in fmBlk)
                numEngines ++
              local boosterPartIndex = partIndex - numEngines //engine3_dm -> Booster0
              engineMainBlk = getTblValueByPath("Booster" + boosterPartIndex + ".Main", fmBlk)
            }

            if ( ! engineMainBlk)
              break

            local engineType = ::u.getFirstFound(["Type", "type"], [infoBlk, engineMainBlk]).tolower()
            if (engineType == "inline" || engineType == "radial")
            {
              local cylinders = ::u.getFirstFound(["Cylinders", "cylinders"], [infoBlk, engineMainBlk], 0)
              if(cylinders > 0)
                engineInfo.push(cylinders + ::loc("engine_cylinders_postfix"))
            }
            if (engineType && engineType.len())
              engineInfo.push(g_string.utf8ToLower(::loc("plane_engine_type/" + engineType)))
            desc.push(::implode(engineInfo, " "))

            // display cooling type only for Inline and Radial engines
            if ((engineType == "inline" || engineType == "radial")
                && "IsWaterCooled" in engineMainBlk)           // Plane : Engine : Cooling
            {
              local coolingKey = engineMainBlk.IsWaterCooled ? "water" : "air"
              desc.push(::loc("plane_engine_cooling_type") + ::loc("ui/colon")
              + ::loc("plane_engine_cooling_type_" + coolingKey))
            }

            if( ! isSecondaryModsValid)
            {
              updateSecondaryMods()
              break;
            }
            // calculating power values
            local powerMax = 0
            local powerTakeoff = 0
            local thrustMax = 0
            local thrustTakeoff = 0
            local horsePowerValue = ::u.getFirstFound(["ThrustMax.PowerMax0", "HorsePowers", "Power"], [infoBlk, engineMainBlk], 0)
            local thrustValue = ::u.getFirstFound(["ThrustMax.ThrustMax0"], [infoBlk, engineMainBlk], 0)
            local throttleBoost = ::u.getFirstFound(["ThrottleBoost"], [infoBlk, engineMainBlk], 0)
            local afterburnerBoost = ::u.getFirstFound(["AfterburnerBoost"], [infoBlk, engineMainBlk], 0)
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
                thrustTakeoff = ::u.getFirstFound(["Thrust", "thrust"], sources, 0)
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
      break;

      case "mg":           // TODO all weapons list
      case "gun":
      case "mgun":
      case "cannon":
      case "mask":
      case "gun_mask":
      case "gun_barrel":
      case "cannon_breech":
      case "tt":
      case "torpedo":

        local weaponInfoBlk = getWeaponByXrayPartName(partName)
        if( ! weaponInfoBlk)
          break

        local bulletsList = ["torpedo"]
        local weaponBlkLink = getTblValueByPath("blk", weaponInfoBlk)
        local weaponName = ::get_weapon_name_by_blk_path(weaponBlkLink)
        local weaponBlk = ::DataBlock(weaponBlkLink)
        local massInfoAdded = false

        if(weaponName && weaponName.len())
          desc.push(::loc("weapons" + weaponName))
        if(weaponInfoBlk && weaponInfoBlk.bullets && ! ::isInArray(partId, bulletsList))
          desc.push(::loc("shop/ammo") + ::loc("ui/colon") + weaponInfoBlk.bullets)
        if( ! weaponBlk)
          break
        if(partId == "torpedo" && weaponBlk && weaponBlk.torpedo)
        {
          local maxSpeedInWater = getTblValueByPath("maxSpeedInWater", weaponBlk.torpedo)
          if(maxSpeedInWater)
            desc.push(::loc("bullet_properties/maxSpeedInWater") + ::loc("ui/colon") +
              ::g_measure_type.SPEED.getMeasureUnitsText(maxSpeedInWater))

          local diveDepth = getTblValueByPath("diveDepth", weaponBlk.torpedo)
          if(diveDepth)
            desc.push(::loc("bullet_properties/diveDepth") + ::loc("ui/colon") +
              ::g_measure_type.DEPTH.getMeasureUnitsText(diveDepth))

          local explosiveType = ::getTblValue("explosiveType", weaponBlk.torpedo)
          if (explosiveType)
            desc.push(::loc("bullet_properties/explosiveType") + ::loc("ui/colon") +
              ::loc("explosiveType/" + explosiveType))

          local explosiveMass = ::getTblValue("explosiveMass", weaponBlk.torpedo)
          if (explosiveMass)
            desc.push(::loc("bullet_properties/explosiveMass") + ::loc("ui/colon") +
              ::g_dmg_model.getMeasuredExplosionText(explosiveMass))

          if (explosiveMass && explosiveType)
          {
            local tntEqText = ::g_dmg_model.getTntEquivalentText(explosiveType, explosiveMass)
            if (tntEqText.len())
              desc.push(::loc("bullet_properties/explosiveMassInTNTEquivalent") +
                ::loc("ui/colon") + tntEqText)
          }

          local massInfo = getMassInfo(weaponBlk.torpedo)
          if(massInfo != "")
          {
            desc.push(getMassInfo(weaponBlk.torpedo))
            massInfoAdded = true
          }
        }
        if( ! massInfoAdded)
          desc.push(getMassInfo(weaponBlk))

      break;

      case "tank":                     // aircraft fuel tank (tank's fuel tank is 'fuel_tank')
        local fmBlk = ::get_fm_file(unit.name, unitBlk)
        if( ! fmBlk)
          break;

        foreach (part in (unitBlk % "DamageGen"))
        {
          local tankMaterial = getTblValueByPath(partName + ".mat", part)
          if(tankMaterial == null)
            continue
          local tankInfo = []
          if(tankMaterial.find("protected") != null)
            tankInfo.push(::loc("fuelTank/selfsealing"))
          else if (tankMaterial.find("unprotected") != null)
            tankInfo.push(::loc("fuelTank/not_selfsealing"))
          if(tankMaterial.find("boost") != null)
            tankInfo.push(::loc("fuelTank/neutralGasSystem"))
          if(tankInfo.len())
            desc.push(::implode(tankInfo, ", "))
          break
        }
      break;
    }

    if(isDebugMode)
    {
      desc.push("\n")
      desc.push("DEBUG! partId=" + partId + ", partName=" + partName)
    }

    local description = ::implode(desc, "\n")
    xrayDescriptionCache[cacheKey] <- description
    return description
  }

  function getInfoBlk(partName = null)
  {
    local sources = [unitBlk]
    local unitTags = ::getTblValue(unit.name, ::get_unittags_blk(), null)
    if(unitTags != null)
      sources.insert(0, unitTags)
    local path = "info"
    if(partName != null)
      path += "." + partName
    local infoBlk = ::u.getFirstFound([path], sources)
    if(infoBlk && partName != null && "alias" in infoBlk)
      infoBlk = getInfoBlk(getTblValue("alias", infoBlk))
    return infoBlk
  }

  function getWeaponByXrayPartName(partName)
  {
    local partLinkSources = ["dm", "barrelDP", "breechDP", "maskDP"]
    foreach(weapon in getUnitWeaponList())
    {
      foreach(linkKey in partLinkSources)
        if(linkKey in weapon && weapon[linkKey] == partName)
          return weapon
      if("partsDP" in weapon && weapon["partsDP"].find(partName) != null)
        return weapon
    }
    return null
  }

  function trimBetween(source, from, to, strict = true)
  {
    local beginIndex = source.find(from)
    local endIndex = source.find(to)
    if(strict && (beginIndex == null || endIndex == null ||
      endIndex == beginIndex || endIndex <= beginIndex))
      return null
    if(beginIndex == null)
      beginIndex = 0
    beginIndex += from.len()
    if(endIndex == null)
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

  function onEventSwitchedBaseHandler(p)
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

  function onEventGameLocalizationChanged(p)
  {
    resetXrayCache()
  }
}

::g_script_reloader.registerPersistentDataFromRoot("dmViewer")
::subscribe_handler(::dmViewer, ::g_listener_priority.DEFAULT_HANDLER)

function on_hangar_damage_part_pick(params) // Called from API
{
  ::dmViewer.updateHint(params)
}
