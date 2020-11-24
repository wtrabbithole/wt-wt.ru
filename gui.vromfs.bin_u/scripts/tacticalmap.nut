local { getWeaponShortTypeFromWpName } = require("scripts/weaponry/weaponryVisual.nut")
::gui_start_tactical_map <- function gui_start_tactical_map(use_tactical_control = false)
{
  ::tactical_map_handler = ::handlersManager.loadHandler(::gui_handlers.TacticalMap,
                           { forceTacticalControl = use_tactical_control })
}

::gui_start_tactical_map_tc <- function gui_start_tactical_map_tc()
{
  gui_start_tactical_map(true);
}

class ::gui_handlers.TacticalMap extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "gui/tacticalMap.blk"
  shouldBlurSceneBg = true
  keepLoaded = true
  wndControlsAllowMask = CtrlsInGui.CTRL_ALLOW_TACTICAL_MAP |
                         CtrlsInGui.CTRL_ALLOW_MP_STATISTICS |
                         CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD |
                         CtrlsInGui.CTRL_ALLOW_VEHICLE_JOY

  forceTacticalControl = false

  units = []
  unitsActive = []
  numUnits = 0
  wasPlayer = 0
  focus = -1
  restoreType = ::ERT_TACTICAL_CONTROL
  isFocusChanged = false
  wasMenuShift = false
  isActiveTactical = false

  function initScreen()
  {
    scene.findObject("update_timer").setUserData(this)

    subHandlers.append(
      ::gui_load_mission_objectives(scene.findObject("primary_tasks_list"),   false, 1 << ::OBJECTIVE_TYPE_PRIMARY),
      ::gui_load_mission_objectives(scene.findObject("secondary_tasks_list"), false, 1 << ::OBJECTIVE_TYPE_SECONDARY)
    )

    initWnd()
  }

  function initWnd()
  {
    restoreType = ::get_mission_restore_type();

    if ((restoreType != ::ERT_TACTICAL_CONTROL))
      isActiveTactical = false

    local playerArr = [1]
    numUnits = ::get_player_group(units, playerArr)
    dagor.debug("numUnits = "+numUnits)

    initData()

//    scene.findObject("dmg_hud").tag = "" + units[focus]

    local isRespawn = false

    if (restoreType == ::ERT_TACTICAL_CONTROL)
    {
      for (local i = 0; i < numUnits; i++)
      {
        if (::is_aircraft_delayed(units[i]))
          continue

        if (::is_aircraft_player(units[i]))
        {
          if (! ::is_aircraft_active(units[i]))
            isRespawn = true
          break
        }
      }
      if (isRespawn || forceTacticalControl)
      {
        dagor.debug("[TMAP] isRespawn = "+isRespawn)
        dagor.debug("[TMAP] 2 forceTacticalControl = " + forceTacticalControl)
        isActiveTactical = true
      }
      else
        isActiveTactical = false
    }

    scene.findObject("objectives_panel").show(!isActiveTactical)
    scene.findObject("pilots_panel").show(isActiveTactical)

    updatePlayer()
    update(null, 0.03)
    updateTitle()

    showSceneBtn("btn_select", isActiveTactical)
    showSceneBtn("btn_back", ::use_touchscreen)
    showSceneBtn("screen_button_back", ::use_touchscreen)
  }

  function reinitScreen(params = {})
  {
    setParams(params)
    initWnd()
    /*
    initData()
    updatePlayer()
    update(null, 0.03)
    updateTitle()
    */
  }

  function updateTitle()
  {
    local gt = ::get_game_type()
    local titleText = ::loc_current_mission_name()
    if (gt & ::GT_VERSUS)
      titleText = ::loc("multiplayer/" + ::get_cur_game_mode_name() + "Mode")

    setSceneTitle(titleText, scene, "menu-title")
  }

  function update(obj, dt)
  {
    updateTacticalControl(obj, dt)

    if (::is_respawn_screen())
    {
      ::gui_start_respawn();
      ::update_gamercards()
    }
  }

  function updateTacticalControl(obj, dt)
  {
    if (restoreType != ::ERT_TACTICAL_CONTROL)
      return;
    if (!isActiveTactical)
      return

    if (focus >= 0 && focus < numUnits)
    {
      local isActive = ::is_aircraft_active(units[focus])
      if (!isActive)
      {
        scene.findObject("objectives_panel").show(false)
        scene.findObject("pilots_panel").show(true)

        onFocusDown(null)
      }
      if (!::is_aircraft_active(units[focus]))
      {
        dagor.debug("still no active aircraft");
        guiScene.performDelayed(this, function()
        {
          doClose()
        })
        return;
      }
      if (!isActive)
      {
        ::set_tactical_screen_player(units[focus], false)
        guiScene.performDelayed(this, function()
        {
          doClose()
        })
      }
    }


    for (local i = 0; i < numUnits; i++)
    {
      if (::is_aircraft_delayed(units[i]))
      {
        dagor.debug("unit "+i+" is delayed");
        continue;
      }

      local isActive = ::is_aircraft_active(units[i]);
      if (isActive != unitsActive[i])
      {
        local trObj = scene.findObject("pilot_name" + i)
        trObj.enable = isActive ? "yes" : "no";
        trObj.inactive = isActive ? null : "yes"
        unitsActive[i] = isActive;
      }
    }
  }

  function initData()
  {
    if (restoreType != ::ERT_TACTICAL_CONTROL)
      return;
    fillPilotsTable()

    for (local i = 0; i < numUnits; i++)
    {
      if (::is_aircraft_delayed(units[i]))
        continue

      if (::is_aircraft_player(units[i]))
      {
        wasPlayer = i
        focus = wasPlayer
        break
      }
    }

    for (local i = 0; i < numUnits; i++)
      unitsActive.append(true)

    for (local i = 0; i < numUnits; i++)
    {
      if (::is_aircraft_delayed(units[i]))
        continue;

      local pilotFullName = ""
      local pilotId = ::get_pilot_name(units[i], i)
      if (pilotId != "")
      {
        if (::get_game_type() & ::GT_COOPERATIVE)
        {
          pilotFullName = pilotId; //player nick
        }
        else
        {
          pilotFullName = ::loc(pilotId)
        }
      }
      else
        pilotFullName = "Pilot "+(i+1).tostring()

      dagor.debug("pilot "+i+" name = "+pilotFullName+" (id = " + pilotId.tostring()+")")

      scene.findObject("pilot_text" + i).setValue(pilotFullName)
      local objTr = scene.findObject("pilot_name" + i)
      local isActive = ::is_aircraft_active(units[i])

      objTr.mainPlayer = (wasPlayer == i)? "yes" : "no"

      if (restoreType == ::ERT_TACTICAL_CONTROL)
      {
        objTr.enable = isActive ? "yes" : "no"
        objTr.inactive = isActive ? null : "yes"
        objTr.selected = (focus == i)? "yes" : "no"
      }
    }

    if (numUnits)
      scene.findObject("pilot_name" + wasPlayer).mainPlayer = "yes"
  }

  function fillPilotsTable()
  {
    local data = ""
    for(local k = 0; k < numUnits; k++)
      data += format("tr { id:t = 'pilot_name%d'; css-hier-invalidate:t='all'; td { text { id:t = 'pilot_text%d'; }}}",
                     k, k)

    local pilotsObj = scene.findObject("pilots_list")
    guiScene.replaceContentFromText(pilotsObj, data, data.len(), this)
    ::move_mouse_on_child(pilotsObj, 0)
    pilotsObj.baseRow = (numUnits < 13)? "yes" : "rows16"
  }

  function updatePlayer()
  {
    if (!::checkObj(scene))
      return

    if (numUnits && (restoreType == ::ERT_TACTICAL_CONTROL) && isActiveTactical)
    {
      if (!(focus in units))
        focus = 0

      ::set_tactical_screen_player(units[focus], true)

      for (local i = 0; i < numUnits; i++)
      {
        if (::is_aircraft_delayed(units[i]))
          continue

//        if ((focus < 0) && ::is_aircraft_player(units[i]))
//          focus = i

        scene.findObject("pilot_name" + i).selected = (focus == i) ? "yes" : "no"
      }

  //    scene.findObject("dmg_hud").tag = "" + units[focus]
      local obj = scene.findObject("pilot_name" + focus)
      if (obj)
        obj.scrollToView()
    }

    local obj = scene.findObject("pilot_aircraft")
    if (obj)
    {
      local fm = ::get_player_unit_name()
      local unit = ::getAircraftByName(fm)
      local text = ::getUnitName(fm)
      if (unit?.isAir() || unit?.isHelicopter?())
        text += ::loc("ui/colon") + getWeaponShortTypeFromWpName(::get_cur_unit_weapon_preset(), fm)
      obj.setValue(text)
    }
  }

  function onFocusDown(obj)
  {
    if (restoreType != ::ERT_TACTICAL_CONTROL)
      return
    if (!isActiveTactical)
      return

    local wasFocus = focus
    focus++
    if (focus >= numUnits)
      focus = 0;

    local cur = focus
    for (local i = 0; i < numUnits; i++)
    {
      local isActive = ::is_aircraft_active(units[cur])
      local isDelayed = ::is_aircraft_delayed(units[cur])
      if (isActive && !isDelayed)
        break

      cur++
      if (cur >= numUnits)
        cur = 0
    }

    focus = cur
    if (wasFocus != focus)
    {
      updatePlayer()
    }
    else
      dagor.debug("onFocusDown - can't find aircraft that is active and not delayed")
  }

  function onFocusUp(obj)
  {
    if (restoreType != ::ERT_TACTICAL_CONTROL)
      return
    if (!isActiveTactical)
      return

    local wasFocus = focus
    focus--
    if (focus < 0)
      focus = numUnits - 1;

    local cur = focus
    for (local i = 0; i < numUnits; i++)
    {
      local isActive = ::is_aircraft_active(units[cur])
      local isDelayed = ::is_aircraft_delayed(units[cur])

      if (isActive && !isDelayed)
        break

      cur--
      if (cur < 0)
        cur = numUnits - 1
    }

    focus = cur

    if (wasFocus != focus)
      updatePlayer()
  }

  function onPilotsSelect(obj)
  {
    if (restoreType != ::ERT_TACTICAL_CONTROL)
      return
    if (!isActiveTactical)
      return

    focus = scene.findObject("pilots_list").getValue()
    updatePlayer()
  }

  function doClose()
  {
    guiScene.performDelayed(this, function()
    {
      if (::is_in_flight())
        ::close_ingame_gui()
    })
  }

  function onClose(obj)
  {
    doClose()
  }

  function onCancel(obj)
  {
    if ((restoreType != ::ERT_TACTICAL_CONTROL) || !isActiveTactical)
      return doClose()

    local playerUnit = ::getTblValue(wasPlayer, units)
    if (playerUnit && ::is_aircraft_active(playerUnit))
      ::set_tactical_screen_player(playerUnit, false)
    doClose()
  }

  function goBack (obj) { onCancel(obj) }

  function onStart(obj)
  {
    if ((restoreType != ::ERT_TACTICAL_CONTROL) || !isActiveTactical)
      return onCancel(obj)

    updateTacticalControl(obj, 0.0)
    if (focus in units)
      ::set_tactical_screen_player(units[focus], false)
    doClose()
  }

  function onSelect (obj) { onStart(obj) }
}

::addHideToObjStringById <- function addHideToObjStringById(data, objId)
{
  local pos = data.indexof("id:t = '" + objId + "';")
  if (pos)
    return data.slice(0, pos) + "display:t='hide'; " + data.slice(pos)
  return data
}

::is_tactical_map_active <- function is_tactical_map_active()
{
  if (!("TacticalMap" in ::gui_handlers))
    return false
  local curHandler = ::handlersManager.getActiveBaseHandler()
  return curHandler != null &&  (curHandler instanceof ::gui_handlers.TacticalMap ||
    curHandler instanceof ::gui_handlers.ArtilleryMap || curHandler instanceof ::gui_handlers.RespawnHandler)
}
