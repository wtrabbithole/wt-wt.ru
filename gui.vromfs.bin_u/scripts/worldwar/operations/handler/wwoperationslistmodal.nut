class ::gui_handlers.WwOperationsListModal extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName   = "gui/worldWar/wwOperationsListModal.blk"

  map = null

  selOperation = null
  isOperationJoining = false
  opListObj = null

  descHandlerWeak = null

  function initScreen()
  {
    if (!map)
      return goBack()

    opListObj = scene.findObject("items_list")
    initFocusArray()

    fillOperationList()
  }

  function getMainFocusObj()
  {
    return opListObj.isVisible() ? opListObj : null
  }

  function getOpGroup()
  {
    return ::g_ww_global_status.getOperationGroupByMapId(map.getId())
  }

  function getSortedOperationsData()
  {
    local opDataList = ::u.map(getOpGroup().getOperationsList(),
                               function(o) { return { operation = o, priority = o.getPriority() } })

    opDataList.sort(function(a,b)
    {
      if (a.priority != b.priority)
        return a.priority > b.priority ? -1 : 1
      if (a.operation.id != b.operation.id)
        return a.operation.id > b.operation.id ? 1 : -1
      return 0
    })
    return opDataList
  }

  function fillOperationList()
  {
    local view = { items = [] }
    local selIdx = -1
    local selPriority = -1

    local sortedOperationsDataList = getSortedOperationsData()
    local isOperationListVisible = sortedOperationsDataList.len() > 1
    showSceneBtn("chapter_place", isOperationListVisible)
    showSceneBtn("separator_line", isOperationListVisible)

    foreach (idx, opData in sortedOperationsDataList)
    {
      local operation = opData.operation
      local icon = null

      local isLastPlayed = false
      if (operation.isMyClanParticipate())
        icon = ::g_world_war.myClanParticipateIcon
      else if (operation.isLastPlayed())
      {
        icon = ::g_world_war.lastPlayedIcon
        isLastPlayed = true
      }

      view.items.append({
        itemIcon = icon
        id = operation.id.tostring()
        itemText = operation.getNameText(false)
        isLastPlayedIcon = isLastPlayed
      })

      local priority = operation.isEqual(selOperation) ? WW_MAP_PRIORITY.MAX : opData.priority
      if (priority > selPriority)
      {
        selPriority = priority
        selIdx = idx
      }
    }

    local data = ::handyman.renderCached("gui/missions/missionBoxItemsList", view)
    guiScene.replaceContentFromText(opListObj, data, data.len(), this)

    selOperation = null //force refresh description
    if (selIdx >= 0)
      opListObj.setValue(selIdx)
    onItemSelect()

    restoreFocus()
  }

  function refreshSelOperation()
  {
    local idx = opListObj.getValue()
    if (idx < 0 || idx >= opListObj.childrenCount())
      return false
    local opObj = opListObj.getChild(idx)
    if(!::checkObj(opObj))
      return false

    local newOperation = ::g_ww_global_status.getOperationById(::to_integer_safe(opObj.id))
    if (newOperation == selOperation)
      return false
    local isChanged = !newOperation || !selOperation || !selOperation.isEqual(newOperation)
    selOperation = newOperation
    return isChanged
  }

  //operation select
  _wasSelectedOnce = false
  function onItemSelect()
  {
    if (!refreshSelOperation() && _wasSelectedOnce)
      return
    _wasSelectedOnce = true

    updateWindow()
  }

  function updateWindow()
  {
    updateTitle()
    updateDescription()
    updateButtons()
  }

  function updateTitle()
  {
    local titleObj = scene.findObject("wnd_title")
    if (!::check_obj(titleObj))
      return

    titleObj.setValue(selOperation ?
      selOperation.getNameText() : map.getNameText())
  }

  function updateDescription()
  {
    if (descHandlerWeak)
      return descHandlerWeak.setDescItem(selOperation)

    local handler = ::gui_handlers.WwMapDescription.link(scene.findObject("item_desc"), selOperation, map)
    descHandlerWeak = handler.weakref()
    registerSubHandler(handler)
  }

  function updateButtons()
  {
    ::showBtn("operation_join_block", selOperation, scene)
    ::showBtn("operation_create_block", !selOperation, scene)
    if (!selOperation)
    {
      ::showBtn("btn_create_operation", isClanQueueAvaliable(), scene)
      local operationDescText = scene.findObject("operation_short_info_text")
      operationDescText.setValue(::loc("worldwar/msg/noActiveOperations"))
      return
    }

    foreach(side in ::g_world_war.getCommonSidesOrder())
    {
      local cantJoinReasonData = selOperation.getCantJoinReasonDataBySide(side)

      local sideName = ::ww_side_val_to_name(side)
      local joinBtn = scene.findObject("btn_join_" + sideName)
      joinBtn.inactiveColor = cantJoinReasonData.canJoin ? "no" : "yes"
      joinBtn.findObject("is_clan_participate_img").show(selOperation.isMyClanSide(side))

      local joinBtnFlagsObj = joinBtn.findObject("side_countries")
      if (::checkObj(joinBtnFlagsObj))
      {
        local wwMap = selOperation.getMap()
        local markUpData = wwMap.getCountriesViewBySide(side, false)
        guiScene.replaceContentFromText(joinBtnFlagsObj, markUpData, markUpData.len(), this)
      }
    }
  }

  function isClanQueueAvaliable()
  {
    return ::has_feature("WorldWarClansQueue") &&
           ::has_feature("Clans") &&
           ::is_in_clan() && map.isActive()
  }

  function onCreateOperation()
  {
    goBack()
    ::ww_event("CreateOperation")
  }

  function onJoinOperationSide1()
  {
    if (selOperation)
      joinOperationBySide(::SIDE_1)
  }

  function onJoinOperationSide2()
  {
    if (selOperation)
      joinOperationBySide(::SIDE_2)
  }

  function joinOperationBySide(side)
  {
    if (isOperationJoining)
      return

    local reasonData = selOperation.getCantJoinReasonDataBySide(side)
    if (reasonData.canJoin)
    {
      isOperationJoining = true
      return selOperation.join(reasonData.country)
    }

    ::scene_msg_box(
      "cant_join_operation",
      null,
      reasonData.reasonText,
      [["ok", function() {}]],
      "ok"
    )
  }

  function onEventWWStopWorldWar(params)
  {
    isOperationJoining = false
  }

  function onEventWWGlobalStatusChanged(p)
  {
    if (p.changedListsMask & WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS)
      fillOperationList()
  }

  function onModalWndDestroy()
  {
    base.onModalWndDestroy()
    ::ww_stop_preview()
  }
}
