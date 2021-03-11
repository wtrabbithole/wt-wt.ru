local { getOperationById, getOperationGroupByMapId
} = require("scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")

class ::gui_handlers.WwOperationsListModal extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName   = "gui/worldWar/wwOperationsListModal.blk"

  map = null
  isDescrOnly = false

  selOperation = null
  isOperationJoining = false
  opListObj = null

  descHandlerWeak = null

  function initScreen()
  {
    if (!map)
      return goBack()

    opListObj = scene.findObject("items_list")
    fillOperationList()
  }

  function getOpGroup()
  {
    return getOperationGroupByMapId(map.getId())
  }

  function getSortedOperationsData()
  {
    local opDataList = ::u.map(getOpGroup().getOperationsList(),
                               function(o) { return { operation = o, priority = o.getPriority() } })

    opDataList.sort(
      @(a, b) b.operation.isAvailableToJoin() <=> a.operation.isAvailableToJoin()
           || b.priority <=> a.priority
           || a.operation.id <=> b.operation.id
    )
    return opDataList
  }

  function getOperationsListView()
  {
    if (isDescrOnly)
      return null

    local sortedOperationsDataList = getSortedOperationsData()
    if (!sortedOperationsDataList.len())
      return null

    local view = { items = [] }
    local isActiveChapterAdded = false
    local isFinishedChapterAdded = false
    foreach (idx, opData in sortedOperationsDataList)
    {
      local operation = opData.operation
      local isAvailableToJoin = operation.isAvailableToJoin()
      local itemColor = isAvailableToJoin ? "activeTextColor" : "commonTextColor"
      if (isAvailableToJoin)
      {
        if (!isActiveChapterAdded)
        {
          view.items.append({
            id = "active_group"
            itemText = ::colorize(itemColor, ::loc("worldwar/operation/active"))
            isCollapsable = true
          })
          isActiveChapterAdded = true
        }
      }
      else if (!isFinishedChapterAdded)
      {
        view.items.append({
          id = "finished_group"
          itemText = ::colorize(itemColor, ::loc("worldwar/operation/finished"))
          isCollapsable = true
        })
        isFinishedChapterAdded = true
      }

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
        itemText = ::colorize(itemColor, operation.getNameText(false))
        isLastPlayedIcon = isLastPlayed
      })
    }

    return view
  }

  function fillOperationList()
  {
    local view = getOperationsListView()
    local isOperationListVisible = view != null
    showSceneBtn("chapter_place", isOperationListVisible)
    showSceneBtn("separator_line", isOperationListVisible)
    local data = ::handyman.renderCached("gui/worldWar/wwOperationsMapsItemsList", view)
    guiScene.replaceContentFromText(opListObj, data, data.len(), this)

    selectFirstItem(opListObj)
  }

  function selectFirstItem(containerObj)
  {
    for (local i = 0; i < containerObj.childrenCount(); i++)
    {
      local itemObj = containerObj.getChild(i)
      if (!itemObj?.collapse_header && itemObj.isEnabled())
      {
        selOperation = null //force refresh description
        containerObj.setValue(i)
        break
      }
    }
    onItemSelect()
  }

  function refreshSelOperation()
  {
    local idx = opListObj.getValue()
    if (idx < 0 || idx >= opListObj.childrenCount())
      return false
    local opObj = opListObj.getChild(idx)
    if(!::checkObj(opObj))
      return false

    local newOperation = opObj?.collapse_header ? null
      : getOperationById(::to_integer_safe(opObj?.id))
    if (newOperation == selOperation)
      return false
    local isChanged = !newOperation || !selOperation || !selOperation.isEqual(newOperation)
    selOperation = newOperation
    return isChanged
  }

  function onCollapse(obj)
  {
    if (!::check_obj(obj))
      return

    local headerObj = obj.getParent()
    if (::check_obj(headerObj))
      doCollapse(headerObj)
  }

  function onCollapsedChapter()
  {
    local rowObj = opListObj.getChild(opListObj.getValue())
    if (::check_obj(rowObj))
      doCollapse(rowObj)
  }

  function doCollapse(obj)
  {
    local containerObj = obj.getParent()
    if (!::check_obj(containerObj))
      return

    obj.collapsing = "yes"

    local containerLen = containerObj.childrenCount()
    local isHeaderFound = false
    local isShow = obj?.collapsed == "yes"
    local selectIdx = containerObj.getValue()
    local needReselect = false

    for (local i = 0; i < containerLen; i++)
    {
      local itemObj = containerObj.getChild(i)
      if (!isHeaderFound)
      {
        if (itemObj?.collapsing == "yes")
        {
          itemObj.collapsing = "no"
          itemObj.collapsed = isShow ? "no" : "yes"
          isHeaderFound = true
        }
      }
      else
      {
        if (itemObj?.collapse_header)
          break
        itemObj.show(isShow)
        itemObj.enable(isShow)
        if (!isShow && i == selectIdx)
          needReselect = true
      }
    }

    local selectedObj = containerObj.getChild(containerObj.getValue())
    if (needReselect || (::check_obj(selectedObj) && !selectedObj.isVisible()))
      selectFirstItem(containerObj)

    updateButtons()
  }

  //operation select
  _wasSelectedOnce = false
  function onItemSelect()
  {
    if (!refreshSelOperation() && _wasSelectedOnce)
      return updateButtons()

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

    if (!selOperation)
    {
      local isListEmpty = opListObj.getValue() < 0
      local collapsedChapterBtnObj = ::showBtn("btn_collapsed_chapter", !isListEmpty, scene)
      if (!isListEmpty && collapsedChapterBtnObj != null)
      {
        local rowObj = opListObj.getChild(opListObj.getValue())
        if (rowObj?.isValid())
          collapsedChapterBtnObj.setValue(rowObj?.collapsed == "yes"
            ? ::loc("mainmenu/btnExpand")
            : ::loc("mainmenu/btnCollapse"))
      }

      local operationDescText = scene.findObject("operation_short_info_text")
      operationDescText.setValue(getOpGroup().getOperationsList().len() == 0
        ? ::loc("worldwar/msg/noActiveOperations")
        : "" )
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

  function onEventQueueChangeState(params)
  {
    updateButtons()
  }

  function onModalWndDestroy()
  {
    base.onModalWndDestroy()
    ::ww_stop_preview()
  }
}
