class ::gui_handlers.wwObjective extends ::BaseGuiHandler
{
  wndType = handlerType.CUSTOM
  sceneTplName = "gui/worldWar/worldWarObjectivesInfo"
  sceneBlkName = null
  objectiveItemTpl = "gui/worldWar/worldWarObjectiveItem"
  singleOperationTplName = "gui/worldWar/operationString"

  staticBlk = null
  dynamicBlk = null

  timersArray = null

  side = ::SIDE_NONE
  needShowOperationDesc = true
  reqFullMissionObjectsButton = true
  restrictShownObjectives = false
  hasObjectiveDesc = false

  function getSceneTplView()
  {
    return {
      reqFullMissionObjectsButton = reqFullMissionObjectsButton
    }
  }

  function getSceneTplContainerObj()
  {
    return scene
  }

  function isValid()
  {
    return ::checkObj(scene) && ::checkObj(scene.findObject("ww_mission_objectives"))
  }

  function initScreen()
  {
    update()
    checkTimers()
  }

  function update()
  {
    local placeObj = scene.findObject("ww_mission_objectives")
    if (!::check_obj(placeObj))
      return

    updateObjectivesData()

    local objectivesList = getObjectivesList(staticBlk.blockCount())
    local view = {
      objectiveBlock = getObjectiveBlocksArray()
      reqFullMissionObjectsButton = reqFullMissionObjectsButton
      hiddenObjectives = ::max(objectivesList.primary.len() - getShowMaxObjectivesCount(), 0)
      hasObjectiveDesc = hasObjectiveDesc
    }
    local data = ::handyman.renderCached(objectiveItemTpl, view)
    guiScene.replaceContentFromText(placeObj, data, data.len(), this)
  }

  function checkTimers()
  {
    timersArray = []
    foreach (id, dataBlk in staticBlk)
    {
      local statusBlk = dynamicBlk.getBlockByName(id)
      local type = ::g_ww_objective_type.getTypeByTypeName(dataBlk.type)

      local handler = this
      foreach (param, func in type.timersArrayByParamName)
        timersArray.extend(func(handler, scene, param, dataBlk, statusBlk, type, side))
    }
  }

  function updateObjectivesData()
  {
    local objectivesBlk = ::g_world_war.getOperationObjectives()
    if (!objectivesBlk)
      return

    staticBlk = ::u.copy(objectivesBlk.data) || ::DataBlock()
    dynamicBlk = ::u.copy(objectivesBlk.status) || ::DataBlock()
  }

  function canShowObjective(objBlock, checkType = true)
  {
    if (::g_world_war.isDebugModeEnabled())
      return true

    if (needShowOperationDesc && !objBlock.showInOperationDesc)
      return false

    if (checkType)
    {
      local type = ::g_ww_objective_type.getTypeByTypeName(objBlock.type)
      local isDefender = type.isDefender(objBlock, ::ww_side_val_to_name(side))

      if (objBlock.showOnlyForDefenders)
        return isDefender

      if (objBlock.showOnlyForAttackers)
        return !isDefender
    }

    return true
  }

  function getShowMaxObjectivesCount()
  {
    if (!restrictShownObjectives || ::g_world_war.isDebugModeEnabled())
      return staticBlk.blockCount()

    if (::get_current_fonts_css() == SCALE_FONTS_CSS)
    {
      if (::g_option_menu_safearea.isEnabled())
        return 1

      local winner = ::ww_get_operation_winner()
      if (winner != ::SIDE_NONE)
        return 1
    }

    local objAmount = 0
    foreach (block in staticBlk)
      if (canShowObjective(block))
        objAmount++

    local guiScene = scene.getScene()

    local panelObj = guiScene["content_block_1"]
    local holderObj = panelObj.getParent()

    local busyHeight = holderObj.findObject("operation_info").getSize()[1]

    local content1BlockHeight = guiScene["ww-right-panel"].getSize()[1]
      - guiScene.calcString("1@content2BlockHeight + 1@content3BlockHeight + 2@framePadding", null)
    local blockHeight = content1BlockHeight - busyHeight

    local reservedHeight = guiScene.calcString("1@frameSmallHeaderHeight + 1@objectiveBlockHeaderHeight", null)
    local availObjectivesHeight = blockHeight - reservedHeight

    local singleObjectiveHeight = guiScene.calcString("1@objectiveHeight", null)
    local allowObjectives = availObjectivesHeight / singleObjectiveHeight

    return ::max(1, ::min(objAmount, allowObjectives))
  }

  function setTopPosition(objectivesAmount = 1)
  {
    if (!restrictShownObjectives)
      return

    local guiScene = scene.getScene()
    local content1BlockHeight = guiScene["ww-right-panel"].getSize()[1]
      - guiScene.calcString("1@content2BlockHeight + 1@content3BlockHeight + 2@framePadding", null)

    local busyHeight = guiScene["operation_info"].getSize()[1]

    local reservedHeight = guiScene.calcString("1@frameSmallHeaderHeight + 1@objectiveBlockHeaderHeight", null)
    local objectivesHeight = guiScene.calcString(objectivesAmount + "@objectiveHeight", null)

    local panelObj = guiScene["content_block_1"]
    panelObj.top = content1BlockHeight - busyHeight - reservedHeight - objectivesHeight
  }

  function getObjectiveBlocksArray()
  {
    local availableObjectiveSlots = getShowMaxObjectivesCount()

    setTopPosition(availableObjectiveSlots)

    local objectivesList = getObjectivesList(availableObjectiveSlots)

    local countryIcon = ""
    local groups = ::g_world_war.getArmyGroupsBySide(side)
    if (groups.len() > 0)
      countryIcon = groups[0].getCountryIcon(false)

    local objectiveBlocks = []
    foreach (name in ["primary", "secondary"])
    {
      local array = objectivesList[name]
      objectiveBlocks.append({
          id = name,
          countryIcon = countryIcon
          hide = array.len() == 0
          objectives = getObjectiveViewsArray(array)
        })
    }

    return objectiveBlocks
  }

  function getObjectivesList(availableObjectiveSlots, checkType = true)
  {
    local list = {
      primary = []
      secondary = []
    }

    local usedObjectiveSlots = 0

    for (local i = 0; i < staticBlk.blockCount(); i++)
    {
      if (usedObjectiveSlots >= availableObjectiveSlots)
        continue

      local objBlock = staticBlk.getBlock(i)
      if (!canShowObjective(objBlock, checkType))
        continue

      usedObjectiveSlots++

      objBlock.id <- objBlock.getBlockName()

      if (objBlock.mainObjective)
        list.primary.append(objBlock)
      else
        list.secondary.append(objBlock)
    }

    if (::u.isEmpty(list.primary) && checkType)
      list = getObjectivesList(1, false)

    return list
  }

  function getObjectiveViewsArray(objectives)
  {
    return ::u.mapAdvanced(objectives, (@(dynamicBlk, side) function(statObjBlk, idx, array) {
      local blockId = statObjBlk.getBlockName()
      local dynObjBlk = dynamicBlk.getBlockByName(blockId)
      return ::WwObjectiveView(
        statObjBlk,
        dynObjBlk,
        side,
        array.len() == 1 || idx == (array.len() - 1)
      )
    })(dynamicBlk, side))
  }

  function onEventWWLoadOperation(params)
  {
    local objectivesBlk = ::g_world_war.getOperationObjectives()
    if (!objectivesBlk)
      return

    updateDynamicData(objectivesBlk)
    checkTimers()
  }

  function onEventWWOperationFinished(params)
  {
    update()
    checkTimers()
  }

  function updateDynamicData(objectivesBlk)
  {
    dynamicBlk = ::u.copy(objectivesBlk.status) || ::DataBlock()
    for (local i = 0; i < dynamicBlk.blockCount(); i++)
    {
      local dynBlock = dynamicBlk.getBlock(i)
      updateDynamicDataBlock(dynBlock)
    }
  }

  function updateDynamicDataBlock(dynBlock)
  {
    local id = dynBlock.getBlockName()
    local statBlk = staticBlk.getBlockByName(id)
    if (!statBlk)
      return

    local type = ::g_ww_objective_type.getTypeByTypeName(statBlk.type)
    local sideEnumVal = ::ww_side_val_to_name(side)
    local result = type.getUpdatableParamsArray(statBlk, dynBlock, sideEnumVal)
    local zones = type.getUpdatableZonesParams(statBlk, dynBlock, sideEnumVal)

    local objectiveObj = scene.findObject(id)
    if (!::checkObj(objectiveObj))
      return

    local statusType = type.getObjectiveStatus(dynBlock.winner, sideEnumVal)
    objectiveObj.status = statusType.name

    local imageObj = objectiveObj.findObject("statusImg")
    if (::checkObj(imageObj))
      imageObj["background-image"] = statusType.wwMissionObjImg

    local titleObj = objectiveObj.findObject(type.getNameId(statBlk, side))
    if (::checkObj(titleObj))
      titleObj.setValue(type.getName(statBlk, dynBlock, sideEnumVal))

    foreach (block in result)
    {
      if (!("id" in block))
        continue

      local updatableParamObj = objectiveObj.findObject(block.id)
      if (!::checkObj(updatableParamObj))
        continue

      foreach (textId in ["pName", "pValue"])
      if (textId in block)
      {
        local nameObj = updatableParamObj.findObject(textId)
        if (::checkObj(nameObj))
          nameObj.setValue(block[textId])
      }

      if ("team" in block)
        updatableParamObj.team = block.team
    }

    if (zones.len())
      foreach(zone in zones)
      {
        local zoneObj = objectiveObj.findObject(zone.id)
        if (::checkObj(zoneObj))
          zoneObj.team = zone.team
      }
  }

  function getStatusBlock()
  {
    local objectivesBlk = ::g_world_war.getOperationObjectives()
    if (!objectivesBlk.status || !(id in objectivesBlk.status))
      return null

    local block = ::u.copy(objectivesBlk.status[id])
    return block
  }

  function onOpenFullMissionObjects()
  {
    ::gui_handlers.WwObjectivesInfo.open()
  }

  function onHoverName(obj)
  {
    local zonesList = []
    for (local i = 0; i < obj.childrenCount(); i++)
    {
      local zoneObj = obj.getChild(i)
      if (!::checkObj(zoneObj))
        continue

      zonesList.append(zoneObj.id)
    }
    if (zonesList.len())
      ::ww_mark_zones_as_outlined_by_name(zonesList)
  }

  function onHoverLostName(obj)
  {
    ::ww_clear_outlined_zones()
  }
}
