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

    local objectivesList = getObjectivesList(getObjectivesCount(false))
    local view = {
      objectiveBlock = getObjectiveBlocksArray()
      reqFullMissionObjectsButton = reqFullMissionObjectsButton
      hiddenObjectives = ::max(objectivesList.primary.len() - getShowMaxObjectivesCount().x, 0)
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
      local statusBlk = getStatusBlock(dataBlk)
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
    local winner = ::ww_get_operation_winner()
    if (restrictShownObjectives && winner != ::SIDE_NONE)
      return ::Point2(1, 0)

    local objectivesCount = getObjectivesCount()

    if (!restrictShownObjectives || ::g_world_war.isDebugModeEnabled())
      return objectivesCount

    local guiScene = scene.getScene()

    local panelObj = guiScene["content_block_1"]
    local holderObj = panelObj.getParent()

    local busyHeight = holderObj.findObject("operation_info").getSize()[1]

    local content1BlockHeight = guiScene["ww-right-panel"].getSize()[1]
      - guiScene.calcString("1@content2BlockHeight + 1@content3BlockHeight + 2@framePadding", null)
    local blockHeight = content1BlockHeight - busyHeight

    local headers = 0
    if (objectivesCount.x > 0) headers++
    if (objectivesCount.y > 0) headers++
    local reservedHeight = guiScene.calcString("1@frameHeaderHeight + " + headers + "@objectiveBlockHeaderHeight", null)

    local availObjectivesHeight = blockHeight - reservedHeight

    local singleObjectiveHeight = guiScene.calcString("1@objectiveHeight", null)
    local allowObjectives = availObjectivesHeight / singleObjectiveHeight
    local res = ::Point2(0, 0)
    res.x = ::max(1, ::min(objectivesCount.x, allowObjectives))
    if (allowObjectives > res.x)
      res.y = ::max(1, ::min(objectivesCount.y, allowObjectives))
    return res
  }

  function getObjectivesCount(checkType = true)
  {
    local objectivesCount = ::Point2(0,0)
    foreach (block in staticBlk)
      if (canShowObjective(block, checkType))
      {
        if (block.mainObjective)
          objectivesCount.x++
        else
          objectivesCount.y++
      }

    return objectivesCount
  }

  function setTopPosition(objectivesCount)
  {
    if (!restrictShownObjectives)
      return

    local guiScene = scene.getScene()
    local content1BlockHeight = guiScene["ww-right-panel"].getSize()[1]
      - guiScene.calcString("1@content2BlockHeight + 1@content3BlockHeight + 2@framePadding", null)

    local busyHeight = guiScene["operation_info"].getSize()[1]

    local headers = 0
    if (objectivesCount.x > 0) headers++
    if (objectivesCount.y > 0) headers++

    local reservedHeight = guiScene.calcString("1@frameHeaderHeight + " + headers + "@objectiveBlockHeaderHeight", null)
    local objectivesHeight = guiScene.calcString((objectivesCount.x + objectivesCount.y) + "@objectiveHeight", null)

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
          isPrimary = name == "primary"
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

    local usedObjectiveSlots = ::Point2(0,0)

    for (local i = 0; i < staticBlk.blockCount(); i++)
    {
      if (usedObjectiveSlots.x >= availableObjectiveSlots.x
        && usedObjectiveSlots.y >= availableObjectiveSlots.y)
        continue

      local objBlock = staticBlk.getBlock(i)
      if (!canShowObjective(objBlock, checkType))
        continue

      objBlock.id <- objBlock.getBlockName()

      if (objBlock.mainObjective && usedObjectiveSlots.x < availableObjectiveSlots.x)
      {
        usedObjectiveSlots.x++
        list.primary.append(objBlock)
      }
      else if (usedObjectiveSlots.y < availableObjectiveSlots.y)
      {
        usedObjectiveSlots.y++
        list.secondary.append(objBlock)
      }
    }

    if (::u.isEmpty(list.primary) && checkType)
      list = getObjectivesList(::Point2(1,0), false)

    return list
  }

  function getObjectiveViewsArray(objectives)
  {
    return ::u.mapAdvanced(objectives, ::Callback(
      @(dataBlk, idx, array)
        ::WwObjectiveView(
          dataBlk,
          getStatusBlock(dataBlk),
          side,
          array.len() == 1 || idx == (array.len() - 1)
        ),
      this))
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
    for (local i = 0; i < staticBlk.blockCount(); i++)
    {
      updateDynamicDataBlock(staticBlk.getBlock(i))
    }
  }

  function updateDynamicDataBlock(objectiveBlk)
  {
    local objectiveBlockId = objectiveBlk.getBlockName()
    local statusBlock = getStatusBlock(objectiveBlk)

    local type = ::g_ww_objective_type.getTypeByTypeName(objectiveBlk.type)
    local sideEnumVal = ::ww_side_val_to_name(side)
    local result = type.getUpdatableParamsArray(objectiveBlk, statusBlock, sideEnumVal)
    local zones = type.getUpdatableZonesParams(objectiveBlk, statusBlock, sideEnumVal)

    local objectiveObj = scene.findObject(objectiveBlockId)
    if (!::checkObj(objectiveObj))
      return

    local statusType = type.getObjectiveStatus(statusBlock.winner, sideEnumVal)
    objectiveObj.status = statusType.name

    local imageObj = objectiveObj.findObject("statusImg")
    if (::checkObj(imageObj))
      imageObj["background-image"] = statusType.wwMissionObjImg

    local titleObj = objectiveObj.findObject(type.getNameId(objectiveBlk, side))
    if (::checkObj(titleObj))
      titleObj.setValue(type.getName(objectiveBlk, statusBlock, sideEnumVal))

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

    local descObj = objectiveObj.findObject("updatable_data_text")
    if (::check_obj(descObj))
    {
      local text = type.getUpdatableParamsDescriptionText(objectiveBlk, statusBlock, sideEnumVal)
      descObj.setValue(text)
    }
  }

  function getStatusBlock(blk)
  {
    return dynamicBlk.getBlockByName(blk?.guiStatusBlk || blk.getBlockName())
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
