const COLLAPSED_CHAPTERS_SAVE_ID = "events_collapsed_chapters"
const ROOMS_LIST_OPEN_COUNT_SAVE_ID = "tutor/roomsListOpenCount"
const SHOW_RLIST_ASK_DELAY_DEFAULT = 10
const SHOW_RLIST_BEFORE_OPEN_DEFAULT = 10

/**
 * Available obtions options:
 *  - event: open specified event in events window
 *  - chapter: open first event in specified chapter
 * Chapter has greater priority but it's bad prctice to use both options
 * simultaneously.
 */
function gui_start_modal_events(options = {})
{
  local eventId = null
  local chapterId = ::getTblValue ("chapter", options, null)

  if (chapterId)
  {
    local chapter = ::events.chapters.getChapter(chapterId)
    if (chapter && !chapter.isEmpty())
    {
      local chapterEvents = chapter.getEvents()
      eventId = chapterEvents[0]
    }
  }

  eventId = eventId || ::getTblValue("event", options, null)

  if (eventId == null)
  {
    local lastPlayedEvent = ::events.getLastPlayedEvent()
    eventId = ::getTblValue("name", lastPlayedEvent, ::events.getFeaturedEvent())
  }

  ::gui_start_modal_wnd(::gui_handlers.EventsHandler, {curEventId = eventId})
}

class ::gui_handlers.EventsHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName   = "gui/events/eventsModal.blk"
  eventsListObj  = null
  curEventId     = ""
  slotbarActions = ["aircraft", "crew", "weapons", "showroom", "repair"]

  queueToShow    = null
  skipCheckQueue = false
  queueInfoHandlerWeak = null
  newIconWidgetByEventId = null

  eventDescription = null
  collapsedChapters = null

  canAskAboutRoomsList = true
  isQueueWasStartedWithRoomsList = false

  function initScreen()
  {
    mainOptionsMode = ::get_gui_options_mode()
    ::set_gui_options_mode(::OPTIONS_MODE_MP_DOMINATION)
    eventsListObj = scene.findObject("items_list")
    if (!::checkObj(eventsListObj))
      return goBack()

    eventDescription = ::create_event_description(scene)
    skipCheckQueue = true
    fillEventsList()
    skipCheckQueue = false

    updateQueueInterface()
    updateButtons()
    ::show_selected_clusters(scene.findObject("cluster_select_button_text"))

    initFocusArray()
    scene.findObject("event_update").setUserData(this)
  }

  function getMainFocusObj()
  {
    return queueToShow ? null : getObj("items_list")
  }

  //----CONTROLLER----//
  function onItemSelect()
  {
    onItemSelectAction()
  }

  function hideNewIconWidgetByEventId(eventId)
  {
    local widget = ::getTblValue(eventId, newIconWidgetByEventId, null)
    if (widget != null)
      widget.setWidgetVisible(false)
  }

  function onItemSelectAction(onlyChanged = true)
  {
    local curEventIdx = eventsListObj.getValue()
    local curEventItemObj = null
    if (curEventIdx < 0 || curEventIdx >= eventsListObj.childrenCount())
      return
    curEventItemObj = eventsListObj.getChild(curEventIdx)
    if(!::checkObj(curEventItemObj))
      return
    if(onlyChanged && curEventId == curEventItemObj.id)
      return

    local newEventId = ::events.getEvent(curEventItemObj.id) ? curEventItemObj.id : ""
    hideNewIconWidgetByEventId(newEventId)
    if (curEventId==newEventId)
      return updateWindow()

    checkQueue((@(newEventId) function () {
        curEventId = newEventId
        updateWindow()
      })(newEventId),
      function() { selectEvent(curEventId) })
  }

  function updateWindow()
  {
    createSlotbar({
      eventId = curEventId
      afterSlotbarSelect = @() updateButtons()
    })
    showEventDescription(curEventId)
    updateButtons()
  }

  function reinitSlotbarAction()
  {
    base.reinitSlotbarAction()
    updateButtons()
  }

  function selectEvent(eventId)
  {
    if (eventId == "" || !::checkObj(eventsListObj))
      return false
    for(local i = 0; i < eventsListObj.childrenCount(); i++)
      if (eventsListObj.getChild(i).id == eventId)
      {
        eventsListObj.setValue(i)
        onItemSelectAction()
        return true
      }
    return false
  }

  function onJoinEvent()
  {
    local event = ::events.getEvent(curEventId)
    if (!event)
      return
    isQueueWasStartedWithRoomsList = ::events.isEventWithLobby(event)
    ::EventJoinProcess(event)
  }

  function onUpdate(obj, dt)
  {
    checkAskOpenRoomsList()
  }

  function checkAskOpenRoomsList()
  {
    if (!canAskAboutRoomsList
        || !isQueueWasStartedWithRoomsList
        || !queueToShow)
      return

    local delay = ::getTblValue("timeToAskShowRoomsListSec", ::configs.GUI.get().eventRoomsList,
                    SHOW_RLIST_ASK_DELAY_DEFAULT)
    if (queueToShow.getActiveTime() < delay)
      return

    local maxCount = ::getTblValue("askBeforeOpenCount", ::configs.GUI.get().eventRoomsList,
                       SHOW_RLIST_BEFORE_OPEN_DEFAULT)
    if (maxCount < ::load_local_account_settings(ROOMS_LIST_OPEN_COUNT_SAVE_ID, 0))
    {
      canAskAboutRoomsList = false
      return
    }

    local economicName = ::events.getEventEconomicName(::events.getEvent(curEventId))
    local roomsListData = ::MRoomsList.getMRoomsListByRequestParams({ eventEconomicName = economicName })
    if (!roomsListData.getList().len())
      return

    canAskAboutRoomsList = false
    ::gui_handlers.InfoWnd.openChecked({
      checkId = "askOpenRoomsList"
      header = ::loc("multiplayer/hint")
      message = ::loc("multiplayer/rooms_list/askToOpen")
      buttons = [
        {
          text = "#multiplayer/rooms_list"
          shortcut = "A"
          onClick = onRoomsList
        }
      ]
      buttonsContext = this
      canCloseByEsc = false
    })
  }

  function onLeaveEvent()
  {
    if (!::g_squad_utils.canJoinFlightMsgBox({ isLeaderCanJoin = true, msgId = "squad/only_leader_can_cancel" },
                                             ::Callback(onLeaveEventActions, this)))
      return
    else
      onLeaveEventActions()
  }

  function getCurEventQueue()
  {
    local q = ::queues.findQueue({}, QUEUE_TYPE_BIT.EVENT)
    return (q && ::queues.isQueueActive(q)) ? q : null
  }

  function isInEventQueue()
  {
    return queueToShow != null  //to all interface work consistent with view
  }

  function onLeaveEventActions()
  {
    local q = getCurEventQueue()
    if (q)
      ::queues.leaveQueue(q)
  }

  function onEventQueueChangeState(_queue)
  {
    if (!::queues.isEventQueue(_queue))
      return

    updateQueueInterface()
    updateButtons()
  }

  function onEventAfterJoinEventRoom(event)
  {
    ::handlersManager.requestHandlerRestore(this, ::gui_handlers.MainMenu)
  }

  function onOpenClusterSelect(obj)
  {
    checkQueue((@(obj) function () {
      ::gui_handlers.ClusterSelect.open(obj, "bottom")
    })(obj))
  }

  function onEventEventsDataUpdated(params)
  {
    fillEventsList()
  }

  function onEventClusterChange(params)
  {
    ::show_selected_clusters(scene.findObject("cluster_select_button_text"))
  }

  function afterModalDestroy()
  {
    ::reinitAllSlotbars()
  }

  function goBack()
  {
    checkedForward(base.goBack)
  }

  function goBackShortcut()
  {
    if (isInEventQueue())
      onLeaveEvent()
    else
      goBack()
  }

  function checkQueue(func, cancelFunc = null)
  {
    if (skipCheckQueue)
      return func()

    checkedModifyQueue(QUEUE_TYPE_BIT.EVENT, func, cancelFunc)
  }

  function restoreQueueParams()
  {
    if (!queueToShow || !::checkObj(scene))
      return

    skipCheckQueue = true
    selectEvent(::queues.getQueueMode(queueToShow))
    skipCheckQueue = false
  }

  function onStart() {}

  function onEventSquadStatusChanged(params)
  {
    updateButtons()
  }

  function onEventSquadSetReady(params)
  {
    updateButtons()
  }

  function onEventSquadDataUpdated(p)
  {
    updateButtons()
  }

  function onDestroy()
  {
    ::events.markAllEventsSeen()
  }

  function getHandlerRestoreData()
  {
    return {
      openData = { curEventId = curEventId }
    }
  }

  function onRoomsList()
  {
    ::gui_handlers.EventRoomsHandler.open(::events.getEvent(curEventId), true)
    canAskAboutRoomsList = false
    ::save_local_account_settings(ROOMS_LIST_OPEN_COUNT_SAVE_ID,
      ::load_local_account_settings(ROOMS_LIST_OPEN_COUNT_SAVE_ID, 0) + 1)
  }

  function onDownloadPack()
  {
    ::events.checkEventFeaturePacks(::events.getEvent(curEventId))
  }

  function onQueueOptions(obj)
  {
    local optionsData = ::queue_classes.Event.getOptions(curEventId)
    if (!optionsData)
      return

    local params = {
      options = optionsData.options
      optionsConfig = optionsData.context
      wndOptionsMode = ::OPTIONS_MODE_MP_DOMINATION
      wndGameMode = ::GM_DOMINATION
      align = ALIGN.TOP
      alignObj = obj
      columnsRatio = 0.6
    }
    ::handlersManager.loadHandler(::gui_handlers.FramedOptionsWnd, params)
  }

  function onCreateRoom() {}

  //----END_CONTROLLER----//

  //----VIEW----//
  function showEventDescription(eventId)
  {
    local event = ::events.getEvent(eventId)
    eventDescription.selectEvent(event)
    if (event != null)
      markEventSeenAndUpdate(event)
  }

  function onEventItemBought(params)
  {
    local item = ::getTblValue("item", params)
    if (item && item.isForEvent(curEventId))
      updateButtons()
  }

  function markEventSeenAndUpdate(event)
  {
    ::events.markEventSeen(event)
    local txtObj = scene.findObject("txt_" + event.name)
    if (::checkObj(txtObj))
      txtObj.setValue(getEventNameForListBox(event))
  }

  function checkQueueInfoBox()
  {
    if (!queueToShow || ::handlersManager.isHandlerValid(queueInfoHandlerWeak))
      return

    local queueObj = showSceneBtn("div_before_chapters_list", true)
    queueObj.height = "ph"
    local queueHandlerClass = queueToShow && ::queues.getQueuePreferredViewClass(queueToShow)
    local queueHandler = ::handlersManager.loadHandler(queueHandlerClass,
                           { scene = queueObj  })
    registerSubHandler(queueHandler)
    queueInfoHandlerWeak = queueHandler
  }

  function updateQueueInterface()
  {
    if (!queueToShow || !::queues.isQueueActive(queueToShow))
      queueToShow = getCurEventQueue()
    checkQueueInfoBox()
    restoreQueueParams()
    scene.findObject("chapters_list_place").show(!isInEventQueue())
    shadeSlotbar(isInEventQueue())
    restoreFocus()
  }

  function updateButtons()
  {
    local event = ::events.getEvent(curEventId)
    local isValid = event != null
    local reasonData = ::events.getCantJoinReasonData(event)
    local isInQueue = isInEventQueue()
    local isReady = ::g_squad_manager.isMeReady()
    local isSquadMember = ::g_squad_manager.isSquadMember()

    local showJoinBtn = isValid && (!isInQueue || (isSquadMember && !isReady))
    local joinButtonObj = scene.findObject("btn_join_event")
    joinButtonObj.show(showJoinBtn)
    joinButtonObj.enable(showJoinBtn)
    joinButtonObj.inactiveColor = (reasonData.activeJoinButton && !isInQueue) || isSquadMember
                                  ? "no"
                                  : "yes"
    joinButtonObj.tooltip = isSquadMember ? reasonData.reasonText : ""
    local startText = "events/join_event"
    if (isSquadMember)
      startText = isReady ? "multiplayer/btnNotReady" : "mainmenu/btnReady"
    startText = ::loc(startText)

    // Used for proper button width calculation.
    local uncoloredStartText = startText

    local battlePriceText = ::events.getEventBattleCostText(event, "activeTextColor", true, true)
    if (battlePriceText.len() > 0 && reasonData.activeJoinButton)
    {
      startText += ::format(" (%s)", battlePriceText)
      uncoloredStartText += ::format(" (%s)", ::events.getEventBattleCostText(
        event, "activeTextColor", true, false))
    }

    ::setDoubleTextToButton(scene, "btn_join_event", uncoloredStartText, startText)
    local leaveButtonObj = scene.findObject("btn_leave_event")
    leaveButtonObj.show(isInQueue)
    leaveButtonObj.enable(isInQueue)

    local reasonTextObj = scene.findObject("cant_join_reason")
    reasonTextObj.setValue(reasonData.reasonText)
    reasonTextObj.show(reasonData.reasonText.len() > 0 && !isInQueue)

    showSceneBtn("btn_rooms_list", isValid && ::events.isEventWithLobby(event))

    local pack = ::events.getEventReqPack(event, true)
    local needDownloadPack = pack != null && !::have_package(pack)
    local packBtn = showSceneBtn("btn_download_pack", needDownloadPack)
    if (needDownloadPack && packBtn)
    {
      packBtn.tooltip = ::get_pkg_loc_name(pack)
      packBtn.setValue(::loc("msgbox/btn_download") + " " + ::get_pkg_loc_name(pack, true))
    }

    showSceneBtn("btn_queue_options", !!event && ::queue_classes.Event.hasOptions(event.name))
  }

  function fillEventsList()
  {
    local totalRows = 0
    local selIdx = -1

    local chapters = ::events.getChapters()

    local view = { items = [] }
    foreach(chapter in chapters)
    {
      if (chapter.getEvents().len() > 0)
      {
        totalRows++
        view.items.append({
          itemTag = "campaign_item"
          id = chapter.name
          itemText = chapter.getLocName()
          isCollapsable = true
        })
      }
      foreach (eventName in chapter.getEvents())
      {
        totalRows++
        if (eventName == curEventId || selIdx < 0)
          selIdx = totalRows
        local event = ::events.getEvent(eventName)
        view.items.append({
          itemIcon = ::events.getDifficultyImg(eventName)
          id = eventName
          itemText = getEventNameForListBox(event)
          newIconWidgetLayout = ::NewIconWidget.createLayout()
        })
      }
    }

    local data = ::handyman.renderCached("gui/missions/missionBoxItemsList", view)
    guiScene.replaceContentFromText(eventsListObj, data, data.len(), this)

    newIconWidgetByEventId = {}
    foreach(chapter in chapters)
    {
      foreach (eventName in chapter.getEvents())
      {
        local newIconWidgetContainer = eventsListObj.findObject("new_icon_widget_" + eventName)
        if (!::checkObj(newIconWidgetContainer))
          continue
        local widget = NewIconWidget(guiScene, newIconWidgetContainer)
        newIconWidgetByEventId[eventName] <- widget
        local event = ::events.getEvent(eventName)
        widget.setWidgetVisible(::events.isEventNew(event) && ::events.isEventActive(event))
      }
    }

    if (selIdx >= 0)
      eventsListObj.setValue(selIdx - 1)
    else
      curEventId = "" //curEvent not found
    onItemSelectAction(false)

    foreach (chapterId, value in getCollapsedChapters())
      collapseChapter(chapterId)
  }

  function getEventNameForListBox(event)
  {
    local text = ::events.getEventNameText(event)
    if (::events.isEventEnded(event))
      text = ::colorize("oldTextColor", text)
    return text
  }

  function getCurrentEdiff()
  {
    local event = ::events.getEvent(curEventId)
    local ediff = event ? ::events.getEDiffByEvent(event) : -1
    return ediff != -1 ? ediff : ::get_current_ediff()
  }

  function onSlotbarCountryAction(obj)
  {
    base.onSlotbarCountryAction(obj)
    updateButtons()
  }

  function onCollapse(obj)
  {
    if ( ! obj || ! obj.id)
      return
    collapseChapter(::g_string.cutPrefix(obj.id, "btn_", obj.id))
  }

  function collapseChapter(chapterId)
  {
    local chapterObj = eventsListObj.findObject(chapterId)
    if ( ! chapterObj)
      return
    local collapsed = chapterObj.collapsed == "yes" ? true : false
    local chapter = ::events.chapters.getChapter(chapterId)
    if( ! chapter)
      return
    foreach (eventName in chapter.getEvents())
    {
      local eventObj = eventsListObj.findObject(eventName)
      if( ! ::checkObj(eventObj))
        continue
      eventObj.show(collapsed)
      eventObj.enable(collapsed)
    }

    chapterObj.collapsed = collapsed ? "no" : "yes"
    getCollapsedChapters()[chapterId] = collapsed ? null : true
    ::saveLocalByAccount(COLLAPSED_CHAPTERS_SAVE_ID, getCollapsedChapters())
  }

  function getCollapsedChapters()
  {
    if(collapsedChapters == null)
      collapsedChapters = ::loadLocalByAccount(COLLAPSED_CHAPTERS_SAVE_ID, ::DataBlock())
    return collapsedChapters
  }
  //----END_VIEW----//
}

function get_events_handler()
{
  local handler = ::handlersManager.findHandlerClassInScene(::gui_handlers.EventsHandler)
  if (!handler)
  {
    ::gui_start_modal_events(null)
    handler = ::handlersManager.findHandlerClassInScene(::gui_handlers.EventsHandler)
  }
  return handler
}
