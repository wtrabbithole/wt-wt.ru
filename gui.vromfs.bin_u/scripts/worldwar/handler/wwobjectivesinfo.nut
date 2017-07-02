class ::gui_handlers.WwObjectivesInfo extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/modalSceneWithGamercard.blk"
  sceneTplName = "gui/worldWar/objectivesInfoWindow"

  staticBlk = null
  dynamicBlk = null

  teamObjectiveHandlersArray = null

  static function open()
  {
    ::handlersManager.loadHandler(::gui_handlers.WwObjectivesInfo)
  }

  function getSceneTplView()
  {
    return {
      teamBlock = getTeamsData()
    }
  }

  function getSceneTplContainerObj()
  {
    return scene.findObject("root-box")
  }

  function initScreen()
  {
    teamObjectiveHandlersArray = []
    foreach (side in ::g_world_war.getSidesOrder())
      initSideBlock(side, ::ww_side_val_to_name(side))
    ::play_gui_sound("ww_globe_battle_select")
  }

  function initSideBlock(side, objId)
  {
    local operationBlockObj = scene.findObject(objId)
    if (!::checkObj(operationBlockObj))
      return

    local objectiveHandler = ::handlersManager.loadHandler(::gui_handlers.wwObjective, {
      scene = operationBlockObj,
      side = side,
      needShowOperationDesc = false,
      reqFullMissionObjectsButton = false
    })

    if (!objectiveHandler)
      return

    teamObjectiveHandlersArray.append(objectiveHandler)
    registerSubHandler(objectiveHandler)
  }

  function getTeamsData()
  {
    local mySide = ::ww_get_player_side()
    local teams = []
    foreach (side in ::g_world_war.getSidesOrder())
    {
      teams.append({
        teamName = ::ww_side_val_to_name(side)
        teamColor = side == mySide? "blue" : "red"
      })
    }

    return teams
  }
}
