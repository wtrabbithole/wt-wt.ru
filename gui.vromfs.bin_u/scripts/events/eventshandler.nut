local seenEvents = require("scripts/seen/seenList.nut").get(SEEN.EVENTS)
local bhvUnseen = require("scripts/seen/bhvUnseen.nut")
local { getTextWithCrossplayIcon,
        isCrossPlayEnabled,
        needShowCrossPlayInfo } = require("scripts/social/crossplay.nut")
local clustersModule = require("scripts/clusterSelect.nut")
local QUEUE_TYPE_BIT = require("scripts/queue/queueTypeBit.nut")
local { setDoubleTextToButton } = require("scripts/viewUtils/objectTextUpdate.nut")
local { isPlatformSony } = require("scripts/clientState/platform.nut")
local { suggestAndAllowPsnPremiumFeatures } = require("scripts/user/psnFeatures.nut")
local { checkAndShowMultiplayerPrivilegeWarning } = require("scripts/user/xboxFeatures.nut")
local { resetSlotbarOverrided, updateOverrideSlotbar } = require("scripts/slotbar/slotbarOverride.nut")
local { needShowOverrideSlotbar, getCustomViewCountryData } = require("scripts/events/eventInfo.nut")


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
::gui_start_modal_events <- function gui_start_modal_events(options = {})
{
  if (!suggestAndAllowPsnPremiumFeatures())
    return

  if (!checkAndShowMultiplayerPrivilegeWarning())
    return

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
    chapterId = ::events.getEventsChapter(::events.getEvent(eventId))
  }

  ::gui_start_modal_wnd(::gui_handlers.EventsHandler, {
    curEventId = eventId
    curChapterId = chapterId
  })
}

class ::gui_handlers.EventsHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName   = "gui/events/eventsModal.blk"
  eventsListObj  = null
  curEventId     = ""
  curChapterId = ""
  slotbarActions = ["aircraft", "crew", "sec_weapons", "weapons", "showroom", "repair"]

  queueToShow    = null
  skipCheckQueue = false
  queueInfoHandlerWeak = null

  eventDescription = null
  collapsedChapters = null

  canAskAboutRoomsList = true
  isQueueWasStartedWithRoomsList = false

  listMap = null
  listIdxPID = ::dagui_propid.add_name_id("listIdx")
  hoveredIdx  = -1
  selectedIdx = -1
  isMouseMode = true

  function initScreen()
  {
    mainOptionsMode = ::get_gui_options_mode()
    ::set_gui_options_mode(::OPTIONS_MODE_MP_DOMINATION)
    eventsListObj = scene.findObject("items_list")
    if (!::checkObj(eventsListObj))
      return goBack()

    updateMouseMode()
    eventDescription = ::create_event_description(scene)
    skipCheckQueue = true
    fillEventsList()
    skipCheckQueue = false

    updateQueueInterface()
    updateButtons()
    updateClusters()

    scene.findObject("event_update").setUserData(this)
    guiScene.applyPendingChanges(false)
    ::move_mouse_on_child_by_value(eventsListObj)
  }

  //----CONTROLLER----//
  function onItemSelect()
  {
    onItemSelectAction()
  }

  function onItemSelectAction(onlyChanged = true)
  {
    local curEventIdx = eventsListObj.getValue()
    local rowId = listMap?[curEventIdx]
    if (rowId == null)
      return
    local newEvent = ::events.getEvent(rowId)
    local newEventId = newEvent?.name ?? ""
    local newChapterId = newEvent != null ? ::events.getEventsChapter(newEvent) : rowId

    if(onlyChanged && newChapterId == curChapterId && curEventId == newEventId)
      return

    if (newChapterId == curChapterId && curEventId==newEventId)
      return updateWindow()

    checkQueue((@(newEventId) function () {
        curChapterId = newChapterId
        curEventId = newEventId
        selectedIdx = curEventIdx
        updateWindow()
      })(newEventId),
      function() { selectEvent(curEventId) })
  }

  function updateWindow()
  {
    local event = ::events.getEvent(curEventId)
    local showOverrideSlotbar = needShowOverrideSlotbar(::events.getEvent(curEventId))
    if (showOverrideSlotbar)
      updateOverrideSlotbar(::events.getEventMission(curEventId))
    else
      resetSlotbarOverrided()
    createSlotbar({
      eventId = curEventId
      afterSlotbarSelect = updateButtons
      afterFullUpdate = updateButtons
      needPresetsPanel = !showOverrideSlotbar
      showAlwaysFullSlotbar = true
      customViewCountryData = getCustomViewCountryData(event)
      needCheckUnitUnlock = showOverrideSlotbar
    })
    showEventDescription(curEventId)
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
    joinEvent()
  }

  function goToBattleFromDebriefing()
  {
    joinEvent(true)
  }

  function joinEvent(isFromDebriefing = false)
  {
    local event = ::events.getEvent(curEventId)
    if (!event)
      return

    if (!suggestAndAllowPsnPremiumFeatures())
      return
    if (!checkAndShowMultiplayerPrivilegeWarning())
      return

    isQueueWasStartedWithRoomsList = ::events.isEventWithLobby(event)
    local configForStatistic = {
      actionPlace = isFromDebriefing ? "debriefing" : "event_window"
      economicName = ::events.getEventEconomicName(event)
      difficulty = event?.difficulty ?? ""
      canIntoToBattle = true
      missionsComplete = ::my_stats.getMissionsComplete()
    }

    ::EventJoinProcess(event, null,
      @(event) ::add_big_query_record("to_battle_button", ::save_to_json(configForStatistic)),
      function() {
        configForStatistic.canIntoToBattle <- false
        ::add_big_query_record("to_battle_button", ::save_to_json(configForStatistic))
      })
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

    local eventRoomsListCfgBlk = ::configs.GUI.get()?.eventRoomsList

    local delay = eventRoomsListCfgBlk?.timeToAskShowRoomsListSec ?? SHOW_RLIST_ASK_DELAY_DEFAULT
    if (queueToShow.getActiveTime() < delay)
      return

    local maxCount = eventRoomsListCfgBlk?.askBeforeOpenCount ?? SHOW_RLIST_BEFORE_OPEN_DEFAULT
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
    if (!q)
      return

    ::queues.leaveQueue(q, { isCanceledByPlayer = true })
  }

  function onEventQueueChangeState(p)
  {
    if (!::queues.isEventQueue(p?.queue))
      return

    updateQueueInterface()

    if (isInEventQueue())
      hoveredIdx = -1
    else
      ::move_mouse_on_child_by_value(eventsListObj)

    updateButtons()
  }

  function onEventAfterJoinEventRoom(event)
  {
    ::handlersManager.requestHandlerRestore(this, ::gui_handlers.MainMenu)
  }

  function onOpenClusterSelect(obj)
  {
    ::queues.checkAndStart(
      ::Callback(@() clustersModule.createClusterSelectMenu(obj, "bottom"), this),
      null,
      "isCanChangeCluster")
  }

  function onEventEventsDataUpdated(params)
  {
    fillEventsList()
  }

  function onEventClusterChange(params)
  {
    updateClusters()
  }

  function updateClusters()
  {
    clustersModule.updateClusters(scene.findObject("cluster_select_button_text"))
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

  function onItemDblClick() {
    if (::show_console_buttons)
      return

    if (curEventId == "") {
      collapseChapter(curChapterId)
      updateButtons()
    } else
      joinEvent()
  }

  function onItemHover(obj)
  {
    if (!::show_console_buttons)
      return
    local isHover = obj.isHovered()
    local idx = obj.getIntProp(listIdxPID, -1)
    if (isHover == (hoveredIdx == idx))
      return
    hoveredIdx = isHover ? idx : -1
    updateMouseMode()
    updateButtons()
  }

  function onHoveredItemSelect(obj)
  {
    if (hoveredIdx != -1 && ::check_obj(eventsListObj))
      eventsListObj.setValue(hoveredIdx)
  }

  function updateMouseMode()
  {
    isMouseMode = !::show_console_buttons || ::is_mouse_last_time_used()
  }

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
    seenEvents.markSeen(::events.getEventsForEventsWindow())
    resetSlotbarOverrided()
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
      seenEvents.markSeen(event.name)
  }

  function onEventItemBought(params)
  {
    local item = ::getTblValue("item", params)
    if (item && item.isForEvent(curEventId))
      updateButtons()
  }

  function checkQueueInfoBox()
  {
    if (!queueToShow || ::handlersManager.isHandlerValid(queueInfoHandlerWeak))
      return

    local queueObj = showSceneBtn("div_before_chapters_list", true)
    queueObj.height = "ph"
    local queueHandlerClass = queueToShow && ::queues.getQueuePreferredViewClass(queueToShow)
    local queueHandler = ::handlersManager.loadHandler(queueHandlerClass, {
      scene = queueObj,
      leaveQueueCb = ::Callback(onLeaveEvent, this)
    })
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
    local slotbar = getSlotbar()
    if (slotbar)
      slotbar.shade(isInEventQueue())
  }

  function updateButtons()
  {
    local event = ::events.getEvent(curEventId)
    local isEvent = event != null
    local isHeader = curChapterId != "" && curEventId == ""
    local isInQueue = isInEventQueue()

    local isCurItemInFocus = (isEvent || isHeader) && (isMouseMode || hoveredIdx == selectedIdx || isInQueue)

    local reasonData = ::events.getCantJoinReasonData(isCurItemInFocus ? event : null)
    local isReady = ::g_squad_manager.isMeReady()
    local isSquadMember = ::g_squad_manager.isSquadMember()

    showSceneBtn("btn_select_console", !isCurItemInFocus && (isEvent || isHeader))

    local showJoinBtn = isCurItemInFocus && (isEvent && (!isInQueue || (isSquadMember && !isReady)))
    local joinButtonObj = scene.findObject("btn_join_event")
    joinButtonObj.show(showJoinBtn)
    joinButtonObj.enable(showJoinBtn)
    joinButtonObj.inactiveColor = (reasonData.activeJoinButton && !isInQueue)
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
    if (battlePriceText.len() > 0)
    {
      startText += ::format(" (%s)", battlePriceText)
      uncoloredStartText += ::format(" (%s)", ::events.getEventBattleCostText(
        event, "activeTextColor", true, false))
    }

    setDoubleTextToButton(scene, "btn_join_event", uncoloredStartText, startText)
    local leaveButtonObj = scene.findObject("btn_leave_event")
    leaveButtonObj.show(isInQueue)
    leaveButtonObj.enable(isInQueue)

    local isShowCollapseBtn = isCurItemInFocus && isHeader
    local collapsedButtonObj = showSceneBtn("btn_collapsed_chapter", isShowCollapseBtn)
    if (isShowCollapseBtn)
    {
      local isCollapsedChapter = getCollapsedChapters()?[curChapterId]
      startText = ::loc(isCollapsedChapter ? "mainmenu/btnExpand" : "mainmenu/btnCollapse")
      collapsedButtonObj.setValue(startText)
    }

    local reasonTextObj = scene.findObject("cant_join_reason")
    reasonTextObj.setValue(reasonData.reasonText)
    reasonTextObj.show(reasonData.reasonText.len() > 0 && !isInQueue)

    showSceneBtn("btn_rooms_list", isCurItemInFocus && isEvent
      && ::events.isEventWithLobby(event))

    local pack = isCurItemInFocus && isEvent ? ::events.getEventReqPack(event, true) : null
    local needDownloadPack = pack != null && !::have_package(pack)
    local packBtn = showSceneBtn("btn_download_pack", needDownloadPack)
    if (needDownloadPack && packBtn)
    {
      packBtn.tooltip = ::get_pkg_loc_name(pack)
      packBtn.setValue(::loc("msgbox/btn_download") + " " + ::get_pkg_loc_name(pack, true))
    }

    showSceneBtn("btn_queue_options", isCurItemInFocus && isEvent
      && ::queue_classes.Event.hasOptions(event.name))
  }

  function fillEventsList()
  {
    local chapters = ::events.getChapters()
    local needSkipCrossplayEvent = isPlatformSony && !isCrossPlayEnabled()

    local view = { items = [] }
    foreach (chapter in chapters)
    {
      local eventItems = []
      foreach (eventName in chapter.getEvents())
      {
        local event = ::events.getEvent(eventName)
        if (needSkipCrossplayEvent && !::events.isEventPlatformOnlyAllowed(event))
          continue

        eventItems.append({
          itemIcon = ::events.getDifficultyImg(eventName)
          id = eventName
          itemText = getEventNameForListBox(event)
          unseenIcon = bhvUnseen.makeConfigStr(SEEN.EVENTS, eventName)
          isNeedOnHover = ::show_console_buttons
        })
      }

      if (eventItems.len() > 0)
        eventItems.insert(0, {
          itemTag = "campaign_item"
          id = chapter.name
          itemText = chapter.getLocName()
          isCollapsable = true
          isNeedOnHover = ::show_console_buttons
        })

      view.items.extend(eventItems)
    }

    local data = ::handyman.renderCached("gui/missions/missionBoxItemsList", view)
    guiScene.replaceContentFromText(eventsListObj, data, data.len(), this)
    for (local i = 0; i < eventsListObj.childrenCount(); i++)
      eventsListObj.getChild(i).setIntProp(listIdxPID, i)

    local cId = curEventId
    listMap = view.items.map(@(v) v.id)
    selectedIdx = listMap.findindex(@(rowId) rowId == cId ) ?? 0

    if (selectedIdx <= 0)
    {
      selectedIdx = 1 //0 index is header
      curEventId = "" //curEvent not found
      curChapterId = ""
    }

    eventsListObj.setValue(selectedIdx)
    onItemSelectAction(false)

    foreach (chapterId, value in getCollapsedChapters())
      collapseChapter(chapterId)
  }

  function getEventNameForListBox(event)
  {
    local text = ::events.getEventNameText(event)
    if (needShowCrossPlayInfo())
    {
      local isPlatformOnlyAllowed = ::events.isEventPlatformOnlyAllowed(event)
      text = getTextWithCrossplayIcon(!isPlatformOnlyAllowed, text)
      if (!isPlatformOnlyAllowed && !isCrossPlayEnabled())
        text = ::colorize("warningTextColor", text)
    }

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

  function onEventCountryChanged(p)
  {
    updateButtons()
  }

  function onCollapse(obj)
  {
    if (!obj?.id)
      return
    collapseChapter(::g_string.cutPrefix(obj.id, "btn_", obj.id))
    updateButtons()
  }

  function onCollapsedChapter()
  {
    collapseChapter(curChapterId)
    updateButtons()
  }

  function collapseChapter(chapterId)
  {
    local chapterObj = eventsListObj.findObject(chapterId)
    if ( ! chapterObj)
      return
    local collapsed = chapterObj.collapsed == "yes" ? true : false
    local curChapter = ::events.chapters.getChapter(chapterId)
    if( ! curChapter)
      return
    foreach (eventName in curChapter.getEvents())
    {
      local eventObj = eventsListObj.findObject(eventName)
      if( ! ::checkObj(eventObj))
        continue
      eventObj.show(collapsed)
      eventObj.enable(collapsed)
    }

    if (chapterId == curChapterId)
    {
      local chapters = ::events.getChapters()
      local totalRows = -1
      foreach(chapter in chapters)
        if (chapter.getEvents().len() > 0)
        {
          totalRows++
          if (chapter.name == curChapterId)
          {
            eventsListObj.setValue(totalRows)
            break
          }

          totalRows += chapter.getEvents().len();
        }
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

::get_events_handler <- function get_events_handler()
{
  local handler = ::handlersManager.findHandlerClassInScene(::gui_handlers.EventsHandler)
  if (!handler)
  {
    ::gui_start_modal_events(null)
    handler = ::handlersManager.findHandlerClassInScene(::gui_handlers.EventsHandler)
  }
  return handler
}
