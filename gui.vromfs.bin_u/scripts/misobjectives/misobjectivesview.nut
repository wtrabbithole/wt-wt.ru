function gui_load_mission_objectives(nestObj, leftAligned, typesMask = 0)
{
  return ::handlersManager.loadHandler(::gui_handlers.misObjectivesView,
                                       { scene = nestObj,
                                         sceneBlkName = leftAligned ? "gui/missions/misObjective.blk" : "gui/missions/misObjectiveRight.blk"
                                         objTypeMask = typesMask || ::gui_handlers.misObjectivesView.typesMask
                                       })
}

class ::gui_handlers.misObjectivesView extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "gui/missions/misObjective.blk"

  objTypeMask = (1 << ::OBJECTIVE_TYPE_PRIMARY) + (1 << ::OBJECTIVE_TYPE_SECONDARY)

  curList = null

  function initScreen()
  {
    curList = []
    scene.findObject("objectives_list_timer").setUserData(this)
    refreshList()
  }

  function onUpdate(obj, dt)
  {
    refreshList()
  }

  function onSceneActivate(show)
  {
    if (show)
      refreshList()
  }

  function getNewList()
  {
    local fullList = ::get_objectives_list()
    local res = []
    foreach(misObj in fullList)
      if (misObj.status > 0 && (objTypeMask & (1 << misObj.type)))
        res.append(misObj)

    res.sort(function(a, b) {
      if (a.type != b.type)
        return a.type > b.type ? 1 : -1
      if (a.id != b.id)
        return (a.id > b.id) ? 1 : -1
      return 0
    })
    return res
  }

  function refreshList()
  {
    local newList = getNewList()
    local total = ::max(newList.len(), curList.len())
    local lastObj = null
    for(local i = 0; i < total; i++)
    {
      local newObjective = ::getTblValue(i, newList)
      if (::u.isEqual(::getTblValue(i, curList), newObjective))
        continue

      local obj = updateObjective(i, newObjective)
      if (obj) lastObj = obj
    }

    if (lastObj)
      lastObj.scrollToView()

    curList = newList
  }

  function updateObjective(idx, objective)
  {
    local obj = getMisObjObject(idx)
    local show = objective != null
    obj.show(show)
    if (!show)
      return null

    local status = ::g_objective_status.getObjectiveStatusByCode(objective.status)
    obj.findObject("obj_img")["background-image"] = status.missionObjImg

    local text = ::loc(objective.text)
    if (!::u.isEmpty(objective.mapSquare))
      text += "  " + objective.mapSquare
    obj.findObject("obj_text").setValue(text)
    return obj
  }

  function getMisObjObject(idx)
  {
    local id = "objective_" + idx
    local obj = scene.findObject(id)
    if (::checkObj(obj))
      return obj

    obj = scene.findObject("objective_teamplate").getClone(scene, this)
    obj.id = id
    return obj
  }
}