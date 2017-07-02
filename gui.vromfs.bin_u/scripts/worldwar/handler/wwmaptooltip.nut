enum WW_MAP_TOOLTIP_TYPE
{
  NONE,
  ARMY,
  BATTLE
}

const SHOW_TOOLTIP_DELAY_TIME = 0.35

class ::gui_handlers.wwMapTooltip extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  controllerScene = null

  params = null

  specifyTypeOrder = [
    {battleName = WW_MAP_TOOLTIP_TYPE.BATTLE},
    {armyName = WW_MAP_TOOLTIP_TYPE.ARMY}
  ]

  currentType = null
  currentId = ""
  showTooltipTimer = null
  descriptionTimer = null

  function initScreen()
  {
    scene.setUserData(this) //to not unload handler even when scene not loaded
    updateScreen()
  }

  function updateScreen()
  {
    updateSpecs()

    if (currentType == WW_MAP_TOOLTIP_TYPE.NONE)
      return hideTooltip()

    startShowTooltipTimer()
  }

  function onEventWWMapUpdateCursorByTimer(p)
  {
    if (::u.isEqual(params, p))
      return

    params = ::u.copy(p)
    updateScreen()
  }

  function onEventWWLoadOperation(params = {})
  {
    scene.lastCurrentId = ""
    if (currentType != WW_MAP_TOOLTIP_TYPE.NONE)
      show()
  }

  function updateSpecs()
  {
    foreach(idx, table in specifyTypeOrder)
      foreach (key, enumType in table)
      {
        if (key in params)
        {
          currentType = enumType
          currentId = params[key]
          return
        }
      }

    currentType = WW_MAP_TOOLTIP_TYPE.NONE
    currentId = ""
  }

  function hideTooltip()
  {
    params = null
    onTooltipObjClose(scene)
  }

  function isValid()
  {
    return true
  }

  function startShowTooltipTimer()
  {
    onTooltipObjClose(scene)
    if (!::checkObj(controllerScene))
      return

    if (showTooltipTimer)
      showTooltipTimer.destroy()

    showTooltipTimer = ::Timer(controllerScene, SHOW_TOOLTIP_DELAY_TIME,
      function()
      {
        show()
      }, this, false)
  }

  function show()
  {
    if (!::checkObj(scene))
      return

    local isShow = currentType != WW_MAP_TOOLTIP_TYPE.NONE && isSceneActiveNoModals()

    scene.show(isShow)
    if (!isShow)
      return

    if (scene.lastCurrentId == currentId)
      return

    scene.lastCurrentId = currentId
    scene.tooltipId = getWWMapIdHoveredObjectId()
    onGenericTooltipOpen(scene)
    updatePos()

    if (currentType == WW_MAP_TOOLTIP_TYPE.ARMY)
    {
      local hoveredArmy = ::g_world_war.getArmyByName(currentId)
      destroyDescriptionTimer()

      descriptionTimer = ::Timer(
        scene, 1, @() updateSelectedArmy(hoveredArmy), this, true
      )
    }

    if (currentType == WW_MAP_TOOLTIP_TYPE.BATTLE)
    {
      local battleDescObj = scene.findObject("battle_desc")
      if (::checkObj(battleDescObj))
      {
        local maxTeamContentWidth = 0
        foreach(teamName in ["teamA", "teamB"])
        {
          local teamInfoObj = scene.findObject(teamName)
          if (::checkObj(teamInfoObj))
            maxTeamContentWidth = ::max(teamInfoObj.getSize()[0], maxTeamContentWidth)
        }

        battleDescObj.width = (2*maxTeamContentWidth) + "+4@framePadding"

        local hoveredBattle = ::g_world_war.getBattleById(currentId)
        destroyDescriptionTimer()

        descriptionTimer = ::Timer(
          scene, 1, @() updateSelectedBattle(hoveredBattle), this, true
        )
      }
    }
  }

  function destroyDescriptionTimer()
  {
    if (descriptionTimer)
    {
      descriptionTimer.destroy()
      descriptionTimer = null
    }
  }

  function updateSelectedArmy(hoveredArmy)
  {
    if (!::checkObj(scene) || !hoveredArmy)
      return

    hoveredArmy.update(hoveredArmy.name)
    local armyView = hoveredArmy.getView()
    foreach (fieldId, func in armyView.getRedrawArmyStatusData())
    {
      local redrawFieldObj = scene.findObject(fieldId)
      if (::check_obj(redrawFieldObj))
        redrawFieldObj.setValue(func.call(armyView))
    }
  }

  function updateSelectedBattle(hoveredBattle)
  {
    if (!::checkObj(scene) || !hoveredBattle)
      return

    local durationContainerObj = scene.findObject("battle_duration")
    if (!::check_obj(durationContainerObj))
      return
    local durationTimerObj = durationContainerObj.findObject("battle_duration_text")
    if (!::check_obj(durationTimerObj))
      return

    local battleView = hoveredBattle.getView()
    durationTimerObj.setValue(battleView.getBattleDurationTime())
    durationContainerObj.show(battleView.hasBattleDurationTime())
  }

  function getWWMapIdHoveredObjectId()
  {
    if (currentType == WW_MAP_TOOLTIP_TYPE.BATTLE)
      return ::g_tooltip_type.WW_MAP_TOOLTIP_TYPE_BATTLE.getTooltipId(currentId, params)

    if (currentType == WW_MAP_TOOLTIP_TYPE.ARMY)
      return ::g_tooltip_type.WW_MAP_TOOLTIP_TYPE_ARMY.getTooltipId(currentId, params)

    return ""
  }

  function onUpdateTooltip(obj, dt)
  {
    if (!isSceneActiveNoModals())
      return

    updatePos()
  }

  function updatePos()
  {
    local cursorPos = ::get_dagui_mouse_cursor_pos_RC()
    cursorPos[0] = cursorPos[0]  + "+1@wwMapTooltipOffset"
    ::g_dagui_utils.setObjPosition(scene, cursorPos, ["@bw", "@bh"])
  }
}
