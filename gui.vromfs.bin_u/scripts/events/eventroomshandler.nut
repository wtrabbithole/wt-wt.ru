enum eRoomFlags { //bit enum. sorted by priority
  HAS_PLACES            = 0x0001
  HAS_PLACES_IN_MY_TEAM = 0x0002

  HAS_COUNTRY           = 0x0010
  HAS_UNIT_MATCH_RULES  = 0x0020
  HAS_AVAILABLE_UNITS   = 0x0040 //has available unis by game mode without checking room rules
  HAS_REQUIRED_UNIT     = 0x0080
  IS_ALLOWED_BY_BALANCE = 0x0100

  //masks
  NONE                  = 0x0000
  ALL                   = 0xFFFF
}

const EROOM_FLAGS_KEY_NAME = "_flags" //added to room root params for faster sort.

class ::gui_handlers.EventRoomsHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName   = "gui/events/eventsModal.blk"
  wndOptionsMode = ::OPTIONS_MODE_MP_DOMINATION

  event = null
  hasBackToEventsButton = false

  curRoomId = ""
  curChapterId = ""
  roomIdToSelect = null
  roomsListData = null
  isSelectedRoomDataChanged = false
  roomsListObj  = null

  chaptersTree = null
  collapsedChapterNamesArray = null

  slotbarActions = ["aircraft", "crew", "weapons", "showroom", "rankinfo", "repair"]

  eventDescription = null

  static TEAM_DIVIDE = "/"
  static COUNTRY_DIVIDE = ", "

  static ROOM_ID_SPLIT = ":"
  static CHAPTER_REGEXP = regexp2(":.*$")
  static ROOM_REGEXP = regexp2(".*(:)")

  function open(event, hasBackToEventsButton = false, roomIdToSelect = null)
  {
    if (event)
      ::handlersManager.loadHandler(::gui_handlers.EventRoomsHandler,
      {
        event = event
        hasBackToEventsButton = hasBackToEventsButton
        roomIdToSelect = roomIdToSelect
      })
  }

  function initScreen()
  {
    collapsedChapterNamesArray = []
    chaptersTree = []

    if (hasBackToEventsButton)
      initFrameOverEventsWnd()

    roomsListObj = scene.findObject("items_list")
    roomsListData = ::MRoomsList.getMRoomsListByRequestParams({ eventEconomicName = ::events.getEventEconomicName(event) })
    eventDescription = ::create_event_description(scene)
    refreshList()
    fillRoomsList()
    updateWindow()
    ::show_selected_clusters(scene.findObject("cluster_select_button_text"))

    scene.findObject("wnd_title").setValue(::events.getEventNameText(event))
    scene.findObject("event_update").setUserData(this)
    initFocusArray()
  }

  function initFrameOverEventsWnd()
  {
    local frameObj = scene.findObject("wnd_frame")
    frameObj.width = "1@slotbarWidthFull - 6@framePadding"
    frameObj.height = "1@maxWindowHeightWithSlotbar - 1@frameFooterHeight - 1@frameHeaderHeight"
    frameObj.top = "1@battleBtnBottomOffset - 1@frameFooterHeight - h"

    local roomsListBtn = showSceneBtn("btn_rooms_list", true)
    roomsListBtn.btnName = "B"
    roomsListBtn.isOpened = "yes"
    guiScene.applyPendingChanges(false)
    local pos = roomsListBtn.getPosRC()
    pos[0] -= guiScene.calcString("3@framePadding", null)
    pos[1] += guiScene.calcString("1@frameFooterHeight", null)
    roomsListBtn.style = format("position:root; pos:%d,%d;", pos[0], pos[1])
  }

  function getMainFocusObj()
  {
    return roomsListObj
  }

  function getCurRoom()
  {
    return roomsListData.getRoom(curRoomId)
  }

  function onItemSelect()
  {
    if (!isValid())
      return
    onItemSelectAction()
  }

  function onItemSelectAction()
  {
    local selItemIdx = roomsListObj.getValue()
    if (selItemIdx < 0 || selItemIdx >= roomsListObj.childrenCount())
      return
    local selItemObj = roomsListObj.getChild(selItemIdx)
    if (!::checkObj(selItemObj))
      return

    local selChapterId = getChapterNameByObjId(selItemObj.id)
    local selRoomId = getRoomIdByObjId(selItemObj.id)

    if (!isSelectedRoomDataChanged && selChapterId == curChapterId && selRoomId == curRoomId)
      return

    isSelectedRoomDataChanged = false
    curChapterId = selChapterId
    curRoomId = selRoomId

    updateWindow()
  }

  function updateWindow()
  {
    ::init_slotbar(this, scene.findObject("nav-help"), true, null, { eventId = event.name, room = getCurRoom() })
    updateDescription()
    updateButtons()
  }

  function onJoinEvent()
  {
    if (curRoomId != "")
      ::EventJoinProcess(event, getCurRoom())
  }

  function refreshList()
  {
    roomsListData.requestList()
  }

  function onUpdate(obj, dt)
  {
    doWhenActiveOnce("refreshList")
  }

  function onEventSearchedRoomsChanged(p)
  {
    isSelectedRoomDataChanged = true
    fillRoomsList()
  }

  function onOpenClusterSelect(obj)
  {
    ::gui_handlers.ClusterSelect.open(obj, "bottom")
  }

  function onEventClusterChange(params)
  {
    ::show_selected_clusters(scene.findObject("cluster_select_button_text"))
    fillRoomsList()
  }

  function onEventSquadStatusChanged(params)
  {
    updateButtons()
  }

  function onEventSquadSetReady(params)
  {
    updateButtons()
  }

  function onEventSquadDataUpdated(params)
  {
    updateButtons()
  }

  function updateDescription()
  {
    eventDescription.selectEvent(event, getCurRoom())
  }

  function updateButtons()
  {
    local hasRoom = curRoomId.len() != 0
    local reasonData = ::events.getCantJoinReasonData(event, getCurRoom())
    if (!hasRoom && !reasonData.reasonText.len())
      reasonData.reasonText = ::loc("multiplayer/no_room_selected")

    local roomMGM = ::SessionLobby.getMGameMode(getCurRoom())
    local isReady = ::g_squad_manager.isMeReady()
    local isSquadMember = ::g_squad_manager.isSquadMember()

    local joinButtonObj = showSceneBtn("btn_join_event", hasRoom)
    joinButtonObj.inactiveColor = reasonData.activeJoinButton || isSquadMember ? "no" : "yes"
    joinButtonObj.tooltip = isSquadMember ? reasonData.reasonText : ""
    local availTeams = ::events.getAvailableTeams(roomMGM)
    local startText = ""
    local startTextParams = {}
    if (isSquadMember)
      startText = ::loc(isReady ? "multiplayer/btnNotReady" : "mainmenu/btnReady")
    else if (roomMGM && !::events.isEventSymmetricTeams(roomMGM) && availTeams.len() == 1)
      startText = ::loc("events/join_event_by_team",
        { team = ::g_team.getTeamByCode(availTeams[0]).getShortName() })
    else
      startText = ::loc("events/join_event")

    local battlePriceText = ::events.getEventBattleCostText(event, "activeTextColor", true, true)
    if (battlePriceText.len() > 0 && reasonData.activeJoinButton)
      startText += ::format(" (%s)", battlePriceText)

    ::set_double_text_to_button(scene, "btn_join_event", startText)
    local reasonTextObj = showSceneBtn("cant_join_reason", reasonData.reasonText.len() > 0)
    reasonTextObj.setValue(reasonData.reasonText)

    showSceneBtn("btn_create_room", ::events.canCreateCustomRoom(event))
  }

  function getCurFilter()
  {
    return { clusters = ::get_current_clusters(), hasFullRooms = true }
  }

  function checkRoomsOrder()
  {
    fillRoomsList(true)
  }

  function fillRoomsList(isUpdateOnlyWhenFlagsChanged = false)
  {
    local roomsList = roomsListData.getList(getCurFilter())
    local isFlagsUpdated = updateRoomsFlags(roomsList)
    if (isUpdateOnlyWhenFlagsChanged && !isFlagsUpdated)
      return

    generateChapters(roomsList)
    updateListInfo(roomsList.len())
    restoreFocus()
  }

  function getMGameModeFlags(mGameMode, room, isMultiSlot)
  {
    local res = eRoomFlags.NONE
    if (!::events.getAvailableTeams(mGameMode).len())
      return res
    res = res | eRoomFlags.HAS_COUNTRY

    if (!isMultiSlot && ::events.isCurUnitMatchesRoomRules(event, room)
        || isMultiSlot && ::events.checkPlayersCraftsRoomRules(event, room))
    {
      res = res | eRoomFlags.HAS_UNIT_MATCH_RULES
      if (::events.checkRequiredUnits(mGameMode, room))
        res = res | eRoomFlags.HAS_REQUIRED_UNIT
    }

    if (!isMultiSlot && ::events.checkCurrentCraft(mGameMode)
        || isMultiSlot && ::events.checkPlayersCrafts(mGameMode))
      res = res | eRoomFlags.HAS_AVAILABLE_UNITS

    if (::events.isAllowedByRoomBalance(mGameMode, room))
      res = res | eRoomFlags.IS_ALLOWED_BY_BALANCE

    return res
  }

  function updateRoomsFlags(roomsList)
  {
    local hasChanges = false
    local isMultiSlot = ::events.isEventMultiSlotEnabled(event)
    local needCheckAvailable = ::events.checkPlayersCrafts(event)
    local teamSize = ::events.getMaxTeamSize(event)
    foreach(room in roomsList)
    {
      local wasFlags = ::getTblValue(EROOM_FLAGS_KEY_NAME, room, eRoomFlags.NONE)
      local flags = eRoomFlags.NONE
      local mGameMode = ::events.getMGameMode(event, room)

      local countTbl = ::SessionLobby.getMembersCountByTeams(room)
      if (countTbl.total < 2 * teamSize)
      {
        flags = flags | eRoomFlags.HAS_PLACES
        local availTeams = ::events.getAvailableTeams(mGameMode)
        if (availTeams.len() > 1 || (availTeams.len() && countTbl[availTeams[0]] < teamSize))
          flags = flags | eRoomFlags.HAS_PLACES_IN_MY_TEAM
      }

      if (needCheckAvailable)
        flags = flags | getMGameModeFlags(mGameMode, room, isMultiSlot)

      room[EROOM_FLAGS_KEY_NAME] <- flags
      hasChanges = hasChanges || wasFlags != flags
    }
    return hasChanges
  }

  function getRoomNameText(room)
  {
    local fullColor = null
    local flags = room[EROOM_FLAGS_KEY_NAME]
    local mustHaveMask = eRoomFlags.HAS_COUNTRY
                       | eRoomFlags.HAS_AVAILABLE_UNITS | eRoomFlags.HAS_REQUIRED_UNIT
                       | eRoomFlags.HAS_PLACES | eRoomFlags.HAS_PLACES_IN_MY_TEAM
                       | eRoomFlags.IS_ALLOWED_BY_BALANCE
    if ((flags & mustHaveMask) != mustHaveMask)
      fullColor = "@minorTextColor"

    local text = ::SessionLobby.getMissionNameLoc(room)
    local reqUnits = ::SessionLobby.getRequiredCratfs(Team.A, room)
    if (reqUnits)
    {
      local color = ""
      if (!fullColor && !(room[EROOM_FLAGS_KEY_NAME] & eRoomFlags.HAS_UNIT_MATCH_RULES))
        color = "@warningTextColor"

      local rankText = ::events.getTierTextByRules(reqUnits)
      local ruleTexts = ::u.map(reqUnits, getRuleText)
      local rulesText = ::colorize(color, ::implode(ruleTexts, ::loc("ui/comma")))

      text = ::colorize(color, rankText) + " " + text
      if (rulesText.len())
        text += ::loc("ui/comma") + rulesText
    }

    if (fullColor)
      text = ::colorize(fullColor, text)
    return text
  }

  function getRuleText(rule, needTierRule = false)
  {
    if (!needTierRule && ::events.getTierNumByRule(rule) != -1)
      return ""
    return ::events.generateEventRule(rule, true)
  }

  function updateListInfo(visibleRoomsAmount)
  {
    local needWaitIcon = !visibleRoomsAmount && roomsListData.isInUpdate
    scene.findObject("items_list_wait_icon").show(needWaitIcon)

    local infoText = ""
    if (!visibleRoomsAmount && !needWaitIcon)
      infoText = ::loc(roomsListData.getList().len() ? "multiplayer/no_rooms_by_clusters" : "multiplayer/no_rooms")

    scene.findObject("items_list_msg").setValue(infoText)
  }

  function getCurrentEdiff()
  {
    local ediff = ::events.getEDiffByEvent(event)
    return ediff != -1 ? ediff : ::get_current_ediff()
  }

  function onEventCountryChanged(p)
  {
    updateButtons()
    checkRoomsOrder()
  }

  function updateChaptersTree(roomsList)
  {
    chaptersTree.clear()
    foreach (idx, room in roomsList)
    {
      local roomMGM = ::SessionLobby.getMGameMode(room, false)
      local foundChapter = ::u.search(chaptersTree, function(chapter) {return chapter.chapterGameMode == roomMGM})
      if (foundChapter == null)
      {
        chaptersTree.append({
          name = roomMGM? roomMGM.gameModeId.tostring() : "",
          chapterGameMode = roomMGM,
          [EROOM_FLAGS_KEY_NAME] = room[EROOM_FLAGS_KEY_NAME],
          rooms = [room]
        })
      }
      else
      {
        foundChapter.rooms.append(room)
        foundChapter[EROOM_FLAGS_KEY_NAME] = foundChapter[EROOM_FLAGS_KEY_NAME] | room[EROOM_FLAGS_KEY_NAME]
      }
    }

    chaptersTree.sort(function(a, b)
    {
      return b[EROOM_FLAGS_KEY_NAME] - a[EROOM_FLAGS_KEY_NAME]
    })

    foreach (idx, chapter in chaptersTree)
      chapter.rooms.sort(function(a, b)
      {
        return b[EROOM_FLAGS_KEY_NAME] - a[EROOM_FLAGS_KEY_NAME]
      })

    return chaptersTree
  }

  function generateChapters(roomsList)
  {
    updateChaptersTree(roomsList)

    local selectedIndex = 1///select first room by default
    local view = { items = [] }

    foreach (idx, chapter in chaptersTree)
    {
      local haveRooms = chapter.rooms.len() > 0
      if (!haveRooms)
        continue

      if (chapter.name == curChapterId)
        selectedIndex = view.items.len()

      local listRow = {
        id = chapter.name
        isCollapsable = true
      }
      local mGameMode = chapter.chapterGameMode
      if (::events.isCustomGameMode(mGameMode))
        listRow.itemText <- ::colorize("activeTextColor", ::loc("events/playersRooms"))
      else
        foreach(side in ::events.getSidesList(mGameMode))
          listRow[::g_team.getTeamByCode(side).name + "Countries"] <-
          {
            country = getFlagsArrayByCountriesArray(
                        ::events.getCountries(::events.getTeamData(mGameMode, side)))
          }
      view.items.append(listRow)

      foreach (roomIdx, room in chapter.rooms)
      {
        local roomId = room.roomId
        if (roomId == curRoomId || roomId == roomIdToSelect)
        {
          selectedIndex = view.items.len()
          if (roomId == roomIdToSelect)
            curRoomId = roomIdToSelect
        }

        view.items.append({
          id = chapter.name + ROOM_ID_SPLIT + roomId
          isBattle = ::SessionLobby.isSessionStartedInRoom(room)
          itemText = getRoomNameText(room)
        })
      }
    }

    local data = ::handyman.renderCached("gui/events/eventRoomsList", view)
    guiScene.replaceContentFromText(roomsListObj, data, data.len(), this)

    if (roomsList.len())
    {
      roomsListObj.setValue(selectedIndex)
      if (roomIdToSelect == curRoomId)
        roomIdToSelect = null
    }
    else
    {
      curRoomId = ""
      curChapterId = ""
      updateWindow()
    }

    updateCollapseChaptersStatuses()
  }

  function getFlagsArrayByCountriesArray(countriesArray)
  {
    return ::u.map(
              countriesArray,
              function(country)
              {
                return {image = ::get_country_icon(country)}
              }
            )
  }

  function onCollapse(obj)
  {
    if (!obj)
      return

    local id = obj.id
    if (id.len() <= 4 || id.slice(0, 4) != "btn_")
      return

    local listItemCount = roomsListObj.childrenCount()
    for (local i = 0; i < listItemCount; i++)
    {
      local listItemId = roomsListObj.getChild(i).id
      if (listItemId == id.slice(4))
      {
        collapse(listItemId)
        break
      }
    }
  }

  function updateCollapseChaptersStatuses()
  {
    if (!::check_obj(roomsListObj))
      return

    for (local i = 0; i < roomsListObj.childrenCount(); i++)
    {
      local obj = roomsListObj.getChild(i)
      local chapterName = getChapterNameByObjId(obj.id)

      local isCollapsedChapter = ::isInArray(chapterName, collapsedChapterNamesArray)
      if (!isCollapsedChapter)
        continue

      if (obj.id == chapterName)
        obj.collapsed = "yes"
      else
      {
        obj.show(false)
        obj.enable(false)
      }
    }
  }

  function updateCollapseChapterStatus(chapterObj)
  {
    local index = ::find_in_array(collapsedChapterNamesArray, chapterObj.id)
    local collapse = index < 0
    if (collapse)
      collapsedChapterNamesArray.append(chapterObj.id)
    else
      collapsedChapterNamesArray.remove(index)

    chapterObj.collapsed = collapse? "yes" : "no"
  }

  function collapse(itemName = null)
  {
    if (!::check_obj(roomsListObj))
      return

    local chapterId = itemName && getChapterNameByObjId(itemName)
    local newValue = -1

    guiScene.setUpdatesEnabled(false, false)
    for (local i = 0; i < roomsListObj.childrenCount(); i++)
    {
      local obj = roomsListObj.getChild(i)
      if (obj.id == itemName) //is chapter block, can collapse
      {
        updateCollapseChapterStatus(obj)
        newValue = i
        continue
      }

      local iChapter = getChapterNameByObjId(obj.id)
      if (iChapter != chapterId)
        continue

      local show = !::isInArray(iChapter, collapsedChapterNamesArray)
      obj.enable(show)
      obj.show(show)
    }
    guiScene.setUpdatesEnabled(true, true)

    if (newValue >= 0)
      roomsListObj.setValue(newValue)
  }

  function getChapterNameByObjId(id)
  {
    return CHAPTER_REGEXP.replace("", id)
  }

  function getRoomIdByObjId(id)
  {
    local result = ROOM_REGEXP.replace("", id)
    if (result == id)
      return ""
    return result
  }

  function getObjIdByChapterNameRoomId(chapterName, roomId)
  {
    return chapterName + "/" + roomId
  }

  _isDelayedCrewchangedStarted = false
  function onEventCrewChanged(p)
  {
    if (_isDelayedCrewchangedStarted) //!!FIX ME: need to solve multiple CrewChanged events after change preset
      return
    _isDelayedCrewchangedStarted = true
    guiScene.performDelayed(this, function()
    {
      if (!isValid())
        return
      _isDelayedCrewchangedStarted = false
      updateButtons()
      checkRoomsOrder()
    })
  }

  function onEventAfterJoinEventRoom(event)
  {
    ::handlersManager.requestHandlerRestore(this, ::gui_handlers.EventsHandler)
  }

  function onEventEventsDataUpdated(p)
  {
    //is event still exist
    if (::events.getEventByEconomicName(::events.getEventEconomicName(event)))
      return

    guiScene.performDelayed(this, function()
    {
      if (isValid())
        goBack()
    })
  }

  function getHandlerRestoreData()
  {
    return {
      openData = {
        event = event
        hasBackToEventsButton = hasBackToEventsButton
      }
    }
  }

  function onCreateRoom()
  {
    ::events.openCreateRoomWnd(event)
  }

  function goBackShortcut() { goBack() }
  function onRoomsList()    { goBack() }

  function onLeaveEvent() {}
  function onStart() {}
  function onDownloadPack() {}
  function onQueueOptions() {}
}
