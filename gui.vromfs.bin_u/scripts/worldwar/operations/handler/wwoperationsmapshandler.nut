local time = require("scripts/time.nut")
local daguiFonts = require("scripts/viewUtils/daguiFonts.nut")
local seenWWMapsAvailable = ::require("scripts/seen/seenList.nut").get(SEEN.WW_MAPS_AVAILABLE)
local bhvUnseen = ::require("scripts/seen/bhvUnseen.nut")
::dagui_propid.add_name_id("countryId")
::dagui_propid.add_name_id("mapId")

enum WW_OM_WND_MODE
{
  PLAYER  // Personal operation selection
  CLAN    // Clan queues view
}

class ::gui_handlers.WwOperationsMapsHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName   = "gui/worldWar/wwOperationsMaps.blk"

  needToOpenBattles = false
  autoOpenMapOperation = null

  mode = WW_OM_WND_MODE.PLAYER

  mapsTbl = {}
  countryData = {}

  selMap = null
  mapsListObj = null
  collapsedChapters = []
  descHandlerWeak = null

  hasClanOperation = false
  hasRightsToQueueClan = false
  hasSelectAllCountriesBlock = false

  queuesJoinTime = 0

  isFillingList = false

  isCountryCheckBoxesUpdating = false

  objIdPrefixCountriesOfMap = "countries_selection_"
  objIdPrefixSelectAllCountry = "select_all_"
  formatCheckboxMapCountry = "map_%s_%s"

  function initScreen()
  {
    backSceneFunc = ::gui_start_mainmenu
    mapsListObj = scene.findObject("maps_list")
    setSceneTitle(::loc("mainmenu/btnWorldwar"))

    foreach (timerObjId in [
        "ww_status_check_timer",  // periodic ww status updates check
        "queues_wait_timer",      // frequent queues wait time text update
        "globe_hint",             // globe tooltip update
      ])
    {
      local timerObj = scene.findObject(timerObjId)
      if (timerObj)
        timerObj.setUserData(this)
    }

    initToBattleButton()
    reinitScreen()

    ::enableHangarControls(true)
    initFocusArray()

    if (needToOpenBattles)
      onStart()
    else if (autoOpenMapOperation)
      openOperationsListByMap(autoOpenMapOperation)
  }

  function initToBattleButton()
  {
    local toBattleNest = showSceneBtn("gamercard_tobattle", true)
    if (!toBattleNest)
      return

    scene.findObject("top_gamercard_bg").needRedShadow = "no"
    local toBattleBlk = ::handyman.renderCached("gui/mainmenu/toBattleButton", {
      enableEnterKey = !::is_platform_shield_tv()
    })
    guiScene.replaceContentFromText(toBattleNest, toBattleBlk, toBattleBlk.len(), this)
    updateToBattleButton()
  }

  function updateToBattleButton()
  {
    local toBattleButtonObj = scene.findObject("to_battle_button")
    if (!::checkObj(scene) || !::checkObj(toBattleButtonObj))
      return

    local text = ::loc("worldWar/btn_all_battles")
    toBattleButtonObj.fontOverride = daguiFonts.getMaxFontTextByWidth(text,
      to_pixels("1@maxToBattleButtonTextWidth"), "bold")
    toBattleButtonObj.findObject("to_battle_button_text").setValue(text)
  }

  function reinitScreen()
  {
    hasClanOperation = ::g_ww_global_status.getMyClanOperation() != null
    hasRightsToQueueClan = ::g_clans.hasRightsToQueueWWar()
    hasSelectAllCountriesBlock = ::g_world_war.getSetting("isAbleToSelectAllCountries", false)

    collectMaps()
    collectCountryData()

    findMapForSelection()
    fillMapsList()
    fillTrophyList()

    if (hasSelectAllCountriesBlock)
      fillSelectAllCountriesList()

    updateWindow()
  }

  function getMainFocusObj()
  {
    return mapsListObj
  }

  function collectMaps()
  {
    mapsTbl = {}
    local _mapsTbl = ::g_ww_global_status_type.MAPS.getList()
    foreach (mapId, map in _mapsTbl)
      if (map.isVisible())
        mapsTbl[mapId] <- map
  }

  function collectCountryData()
  {
    countryData = {}
    foreach (countryId in ::shopCountriesList)
      countryData[countryId] <- { selected = 0, total = 0 }
    foreach (map in mapsTbl)
      foreach (countryId in map.getCountries())
      {
        if (map.getQueue().isMyClanJoined(countryId))
          countryData[countryId].selected++
        if (map.isActive())
          countryData[countryId].total++
      }
  }

  function findMapForSelection()
  {
    if (selMap)
      return

    local selMapPriority = -1
    foreach (map in mapsTbl)
    {
      local priority = map.getPriority()
      if (priority <= selMapPriority)
        continue

      selMap = map
      selMapPriority = priority
    }
  }

  function fillMapsList()
  {
    local chaptersList = []
    local mapsByChapter = {}
    foreach (mapId, map in mapsTbl)
    {
      local chapterId = map.getChapterId()
      local chapterObjId = getChapterObjId(map)

      if (!(chapterId in mapsByChapter))
      {
        local title = map.getChapterText()
        local weight = chapterId == "" ? 0 : 1
        local view = {
          id = chapterObjId
          itemTag = "ww_map_item"
          itemText = title
          itemClass = "header"
          isCollapsable = true
        }

        if (map.isDebugChapter())
          collapsedChapters.append(chapterObjId)

        local mapsList = []
        chaptersList.append({ weight = weight, title = title, view = view, mapsList = mapsList })
        mapsByChapter[chapterId] <- mapsList
      }

      local countries = []
      foreach (countryId in map.getCountries())
        countries.append({
          id = ::format(formatCheckboxMapCountry, mapId, countryId)
          useImage = ::get_country_icon(countryId)
          value = map.getQueue().isMyClanJoined(countryId)
          funcName = "onMapCountrySelect"
          specialParams = "mapId:t= '"+mapId+"'; countryId:t= '"+countryId+"';"
          isDisable = !map.isActive()
        })

      local title = map.getNameText()
      local weight = 1
      local view = {
        id = mapId
        itemTag = "ww_map_item"
        itemIcon = map.getOpGroup().isMyClanParticipate() ? ::g_world_war.myClanParticipateIcon : null
        itemText = title
        hasWaitAnim = true
        checkbox = countries
        isActive = map.isActive()
        unseenIcon = map.isAnnounceAndNotDebug() && bhvUnseen.makeConfigStr(SEEN.WW_MAPS_AVAILABLE, mapId)
      }
      mapsByChapter[chapterId].append({ weight = weight, title = title, view = view, map = map })
    }

    local sortFunc = function(a, b)
    {
      if (a.weight != b.weight)
        return a.weight > b.weight ? -1 : 1
      if (a.title != b.title)
        return a.title < b.title ? -1 : 1
      return 0
    }

    local selIdx = -1
    local view = {
      items = []
      isCreateOperationMode = true
    }

    chaptersList.sort(sortFunc)
    foreach (c in chaptersList)
    {
      view.items.append(c.view)
      c.mapsList.sort(sortFunc)
      foreach (m in c.mapsList)
      {
        view.items.append(m.view)
        if (m.map.isEqual(selMap))
          selIdx = view.items.len() - 1
      }
    }

    if (selIdx == -1 && view.items.len())
      selIdx = 0

    isFillingList = true

    local markup = ::handyman.renderCached("gui/worldWar/wwOperationsMapsItemsList", view)
    guiScene.replaceContentFromText(mapsListObj, markup, markup.len(), this)

    selMap = null //force refresh description
    if (selIdx >= 0)
      mapsListObj.setValue(selIdx)
    onItemSelect()

    foreach (id in collapsedChapters)
      if (!selMap || getChapterObjId(selMap) != id)
        onCollapse(mapsListObj.findObject("btn_" + id))

    isFillingList = false
  }

  function fillTrophyList()
  {
    local trophiesBlk = ::g_world_war.getSetting("dailyTrophies", ::DataBlock())
    local trophiesAmount = trophiesBlk.blockCount()
    if (!trophiesAmount)
      return

    local view = {
      titleText = getTrophyDesc(trophiesBlk)
      trophy = []
    }
    local isLeftPanelVisible = false
    if (::has_feature("WorldWarDailyTrophies"))
      for (local i = 0; i < trophiesAmount; i++)
      {
        local trophy = trophiesBlk.getBlock(i)
        local trophyId = trophy.itemName || trophy.trophyName || trophy.mainTrophyId
        local trophyItem = ::ItemsManager.findItemById(trophyId)
        if (!trophyItem)
          continue

        local trophyAmount = trophy.amount || 1
        view.trophy.append({
          titleText = getTrophyDesc(trophy)
          wwTrophyMarkup = trophyItem.getNameMarkup(trophyAmount, false)
        })
        isLeftPanelVisible = true
      }

    local markup = ::handyman.renderCached("gui/worldWar/wwTrophiesList", view)
    local trophyBlockObj = scene.findObject("trophy_list")
    guiScene.replaceContentFromText(trophyBlockObj, markup, markup.len(), this)
    showSceneBtn("panel_left", isLeftPanelVisible)
  }

  getTrophyDesc = @(blk) ::loc(blk.locId || "worldwar/" + blk.getBlockName())

  function onEventItemsShopUpdate(params)
  {
    fillTrophyList()
  }

  function selectMapById(id)
  {
    for (local idx = 0; idx < mapsListObj.childrenCount(); idx++)
    {
      local mapObj = mapsListObj.getChild(idx)
      if(::checkObj(mapObj) && mapObj.collapse_header == null && mapObj.id == id)
      {
        mapsListObj.setValue(idx)
        return
      }
    }
  }

  function refreshSelMap()
  {
    local idx = mapsListObj.getValue()
    if (idx < 0 || idx >= mapsListObj.childrenCount())
      return false
    local mapObj = mapsListObj.getChild(idx)
    if(!::checkObj(mapObj))
      return false

    local isHeader = mapObj.collapse_header != null
    local newMap = isHeader ? null : ::g_ww_global_status.getMapByName(mapObj.id)
    if (newMap == selMap)
      return false
    local isChanged = !newMap || !selMap || !selMap.isEqual(newMap)
    selMap = newMap
    return isChanged
  }

  //operation select
  _wasSelectedOnce = false
  function onItemSelect()
  {
    local isSelChanged = refreshSelMap()

    if (!isSelChanged && _wasSelectedOnce)
      return updateButtons()

    if (selMap && isSelChanged && (!isFillingList || !_wasSelectedOnce))
      ::pick_globe_operation(selMap.getId(), false)

    _wasSelectedOnce = true

    updateUnseen()
    updateDescription()
    updateButtons()
  }

  function getSelectedMapObj()
  {
    if (!::check_obj(mapsListObj))
      return null

    local value = mapsListObj.getValue()
    return value >= 0 ? mapsListObj.getChild(value) : null
  }

  function isSelectedMapEditMode(mapObj)
  {
    if (!::check_obj(mapObj))
      return false

    return mapObj.selected == "yes" ? false : true
  }

  function getSelectedMapEditBtnText(mapObj)
  {
    if (!::check_obj(mapObj))
      return ""

    if (mapObj.collapse_header)
      return mapObj.collapsed == "yes"
        ? ::loc("mainmenu/btnExpand")
        : ::loc("mainmenu/btnCollapse")

    return ::loc("options/arcadeCountry")
  }

  function onMapAction(obj)
  {
    local mapObj = getSelectedMapObj()
    if (!::check_obj(mapObj))
      return

    if (isMapObjChapter(mapObj))
      onCollapse(mapObj)
    else
    {
      if (mapObj.selected == "yes")
        onSelectCountriesBlock()
      else
        onSelectCountry()
    }
  }

  function onSelectCountriesBlock()
  {
    local mapObj = getSelectedMapObj()
    if (!::check_obj(mapObj) || mapObj.collapse_header)
      return

    local countryContainerObj = getCountryBlockObj(mapObj)
    if (!canEditMapCountries(countryContainerObj))
      return

    countryContainerObj.select()
    updateButtons()
  }

  isMapObjChapter = @(obj) !!obj.collapse_header
  getCountryBlockObj = @(obj) obj.findObject("countries_selection_" + obj.id)
  canEditMapCountries = @(obj) ::check_obj(obj) && obj.isVisible() && obj.isEnabled()

  function onMapCountriesUp()
  {
    switchMapCountry(-1)
  }

  function onMapCountriesDown()
  {
    switchMapCountry(1)
  }

  function switchMapCountry(direction)
  {
    local value = getMapsListObjValue()
    if (value < 0)
      return

    value += direction
    while (value >= 0 && value < mapsListObj.childrenCount())
    {
      if (tryToSwitchMapCountry(value))
        break

      value += direction
    }
  }

  function getMapsListObjValue()
  {
    if (!::check_obj(mapsListObj))
      return -1

    return mapsListObj.getValue()
  }

  function tryToSwitchMapCountry(idx)
  {
    local mapObj = mapsListObj.getChild(idx)
    local countryContainerObj = getCountryBlockObj(mapObj)
    if (isMapObjChapter(mapObj) || !canEditMapCountries(countryContainerObj))
      return false

    mapsListObj.setValue(idx)
    onSelectCountriesBlock()
    return true
  }

  function onLeaveCountriesBlock()
  {
    mapsListObj.select()
    updateButtons()
  }

  function onSelectCountry()
  {
    local mapObj = getSelectedMapObj()
    if (!::check_obj(mapObj) || mapObj.collapse_header)
      return

    local countryContainerObj = mapObj.findObject("countries_selection_" + mapObj.id)
    if (!::check_obj(countryContainerObj))
      return

    local value = countryContainerObj.getValue()
    if (value < 0)
      return

    local countryCheckBoxObj = countryContainerObj.getChild(value)

    countryCheckBoxObj.setValue(!countryCheckBoxObj.getValue())
    onMapCountrySelect(countryCheckBoxObj)
  }

  function onCollapse(obj)
  {
    if (!::check_obj(obj))
      return
    local itemObj = obj.collapse_header ? obj : obj.getParent()
    local listObj = ::check_obj(itemObj) ? itemObj.getParent() : null
    if (!::check_obj(listObj) || !itemObj.collapse_header)
      return

    itemObj.collapsing = "yes"
    local isShow = itemObj.collapsed == "yes"
    local listLen = listObj.childrenCount()
    local selIdx = listObj.getValue()
    local headerIdx = -1
    local needReselect = false

    local found = false
    for (local i = 0; i < listLen; i++)
    {
      local child = listObj.getChild(i)
      if (!found)
      {
        if (child.collapsing == "yes")
        {
          child.collapsing = "no"
          child.collapsed  = isShow ? "no" : "yes"
          headerIdx = i
          found = true
        }
      }
      else
      {
        if (child.collapse_header)
          break
        child.show(isShow)
        child.enable(isShow)
        if (!isShow && i == selIdx)
          needReselect = true
      }
    }

    if (needReselect || !selMap)
    {
      local indexes = []
      for (local i = selIdx + 1; i < listLen; i++)
        indexes.append(i)
      for (local i = selIdx - 1; i >= 0; i--)
        indexes.append(i)

      local newIdx = -1
      foreach (idx in indexes)
      {
        local child = listObj.getChild(idx)
        if (!child.collapse_header && child.isEnabled())
        {
          newIdx = idx
          break
        }
      }
      selIdx = newIdx != -1 ? newIdx : headerIdx
      listObj.setValue(selIdx)
    }

    if (collapsedChapters && !::u.isEmpty(itemObj.id))
    {
      local idx = ::find_in_array(collapsedChapters, itemObj.id)
      if (isShow && idx != -1)
        collapsedChapters.remove(idx)
      else if (!isShow && idx == -1)
        collapsedChapters.append(itemObj.id)
    }
  }

  function fillSelectAllCountriesList()
  {
    local labelObj = scene.findObject("select_all_countries_text")
    if (::checkObj(labelObj))
      labelObj.setValue(::loc("ui/select_all") + ::loc("ui/colon"))

    local listObj = scene.findObject("select_all_countries_checkboxes")
    if (!::checkObj(listObj))
      return
    local countries = []
    foreach (countryId in ::shopCountriesList)
      if (countryData[countryId].total > 0)
        countries.append({
          id = objIdPrefixSelectAllCountry + countryId
          useImage = ::get_country_icon(countryId)
          value = countryData[countryId].selected >= countryData[countryId].total
          funcName = "onCountrySelectAll"
          specialParams = "countryId:t= '"+countryId+"';"
        })

    local view = { checkbox = countries }
    local markup = ::handyman.renderCached("gui/commonParts/checkbox", view)
    guiScene.replaceContentFromText(listObj, markup, markup.len(), this)
  }

  function onMapCountrySelect(obj)
  {
    if (!::checkObj(obj))
      return

    local mapId = obj.mapId
    if (!mapsTbl[mapId].isActive())
      return

    local value = obj.getValue()
    local countryId = obj.countryId
    local selected = countryData[countryId].selected + (value ? 1 : -1)
    countryData[countryId].selected = selected

    if (isCountryCheckBoxesUpdating)
      return

    isCountryCheckBoxesUpdating = true
    local objChk = scene.findObject(objIdPrefixSelectAllCountry + countryId)
    if (::checkObj(objChk))
    {
      local total = countryData[countryId].total
      objChk.setValue(total && selected >= total)
    }

    isCountryCheckBoxesUpdating = false
    updateButtons()
  }

  function onCountrySelectAll(obj)
  {
    if (isCountryCheckBoxesUpdating)
      return

    local countryId = obj.countryId
    local newValue = obj.getValue()
    isCountryCheckBoxesUpdating = true
    foreach (mapId, map in mapsTbl)
    {
      local objChk = scene.findObject(::format(formatCheckboxMapCountry, mapId, countryId))
      if (::checkObj(objChk))
      {
        if (objChk.getValue() != newValue && map.isActive())
          objChk.setValue(newValue)
      }
    }

    isCountryCheckBoxesUpdating = false
    updateButtons()
  }

  function onTimerStatusCheck(obj, dt)
  {
    ::g_ww_global_status.refreshData()
  }

  function updateWindow()
  {
    updateQueueElementsInList()

    updateDescription()
    updateButtons()
  }

  function updateDescription()
  {
    local obj = scene.findObject("item_status_text")
    if (::checkObj(obj))
      obj.setValue(getMapStatusText())

    local item = selMap
    if (selMap && mode == WW_OM_WND_MODE.CLAN)
      item = item.getQueue()

    if (descHandlerWeak)
      return descHandlerWeak.setDescItem(item)

    if (!item)
      return

    local handler = ::gui_handlers.WwMapDescription.link(scene.findObject("item_desc"), item, item)
    descHandlerWeak = handler.weakref()
    registerSubHandler(handler)
  }

  function isClanQueueAvaliable()
  {
    return mode == WW_OM_WND_MODE.PLAYER &&
           ::has_feature("WorldWarClansQueue") &&
           ::has_feature("Clans") &&
           ::is_in_clan() && selMap && selMap.isActive()
  }

  function updateButtons()
  {
    local isModePlayer = mode == WW_OM_WND_MODE.PLAYER
    local isModeClan  = mode == WW_OM_WND_MODE.CLAN

    showSceneBtn("gamercard_logo", isModeClan)
    showSceneBtn("gamercard_tobattle", isModePlayer)

    local hasMap = selMap != null
    local isInQueue = ::g_ww_global_status.isMyClanInQueue()
    local isQueueJoiningEnabled = isModeClan && ::WwQueue.getCantJoinAnyQueuesReasonData().canJoin

    showSceneBtn("btn_clans_queue", isClanQueueAvaliable())
    local joinOpBtn = showSceneBtn("btn_join_operation", isModePlayer && hasMap)
    joinOpBtn.inactiveColor = isModePlayer && hasMap && selMap.getOpGroup().hasActiveOperations() ? "no" : "yes"

    local cantJoinReasonObj = showSceneBtn("cant_join_queue_reason", isModeClan && !isInQueue)
    local joinQueueBtn = showSceneBtn("btn_join_queue", isQueueJoiningEnabled && !isInQueue)
    showSceneBtn("btn_leave_queue", isModeClan && hasRightsToQueueClan && isInQueue)

    if ((queuesJoinTime > 0) != isInQueue)
      queuesJoinTime = isInQueue ? getLatestQueueJoinTime() : 0
    showSceneBtn("queues_wait_time_div", isInQueue)
    onTimerQueuesWaitTime()

    if (::show_console_buttons)
    {
      local selectedMapObj = getSelectedMapObj()
      local isMapActionVisible = !hasMap ||
        (selMap.isActive() && isQueueJoiningEnabled && !isInQueue)
      local btnMapActionObj = showSceneBtn("btn_map_action", isMapActionVisible)
      btnMapActionObj.setValue(getSelectedMapEditBtnText(selectedMapObj))
    }

    if (!isModeClan)
      return

    local reasonData = getCantJoinAllQueuesReasonData()
    joinQueueBtn.inactiveColor = reasonData.canJoin ? "no" : "yes"
    cantJoinReasonObj.setValue(reasonData.reasonText)
  }

  function getLatestQueueJoinTime()
  {
    local res = 0
    foreach (map in mapsTbl)
    {
      local queue = map.getQueue()
      local t = queue.isMyClanJoined() ? queue.getMyClanQueueJoinTime() : 0
      if (t > 0)
        res = (res == 0) ? t : ::min(res, t)
    }
    return res
  }

  function onTimerQueuesWaitTime()
  {
    if (!queuesJoinTime)
      return

    ::g_ww_global_status.refreshData()

    local obj = scene.findObject("queues_wait_time_text")
    if (!::checkObj(obj))
      return
    local timeInQueue = ::g_ww_global_status.getTimeSec() - queuesJoinTime
    obj.setValue(::loc("worldwar/mapStatus/yourClanInQueue") + ::loc("ui/colon") + time.secondsToString(timeInQueue, false))
  }

  function updateQueueElementsInList()
  {
    local isModeClan = mode == WW_OM_WND_MODE.CLAN

    foreach (mapId, map in mapsTbl)
      ::showBtn("wait_icon_" + mapId, isModeClan && map.getQueue().isMyClanJoined(), mapsListObj)

    local show = isModeClan
    local isQueueJoiningEnabled = isModeClan && ::WwQueue.getCantJoinAnyQueuesReasonData().canJoin

    foreach (mapId, map in mapsTbl)
    {
      local canJoin = map.isActive() && map.getQueue().getCantJoinQueueReasonData().canJoin
      local obj = ::showBtn(objIdPrefixCountriesOfMap + mapId, show, mapsListObj)
      if (obj)
        obj.enable(isQueueJoiningEnabled && canJoin)

      local membersIconObj = scene.findObject("queue_members_" + mapId)
      if (::check_obj(membersIconObj))
        membersIconObj.show(map.getQueue().getArmyGroupsAmountTotal() > 0)
    }

    local obj = ::showBtn("select_all_countries", isSelectAllCountriesBlockVisible(), scene)
      if (obj)
        obj.enable(isQueueJoiningEnabled)
  }

  function switchMode(newMode)
  {
    mode = newMode
    local isModeClan = mode == WW_OM_WND_MODE.CLAN

    setSceneTitle(::loc(isModeClan ? "worldwar/btnClansQueue" : "mainmenu/btnWorldwar"))
    descHandlerWeak = null

    local flagsWidth = 0
    if (isModeClan)
      foreach (mapId, map in mapsTbl)
      {
        local obj = mapsListObj.findObject(objIdPrefixCountriesOfMap + mapId)
        if (::checkObj(obj))
          flagsWidth = ::max(flagsWidth, obj.getSize()[0])
      }

    local containerObj = scene.findObject("panel_right")
    if (::checkObj(containerObj))
    {
      local modeId = "Mode" + (isSelectAllCountriesBlockVisible() ? "Clans" : "Normal")
      foreach (p in [ "height", "pos" ])
        containerObj[p] = containerObj[p + modeId]
      containerObj["width"] = containerObj["widthModeNormal"] + "+" + flagsWidth
    }

    updateWindow()
  }

  function isSelectAllCountriesBlockVisible()
  {
    return hasSelectAllCountriesBlock && mode == WW_OM_WND_MODE.CLAN
  }

  function getMapStatusText()
  {
    if (!selMap)
      return ""

    if (mode == WW_OM_WND_MODE.PLAYER)
    {
      return selMap.getOpGroup().hasActiveOperations() ? "" :
        ::colorize("badTextColor", ::loc("worldwar/msg/noActiveOperations"))
    }
    else if (mode == WW_OM_WND_MODE.CLAN)
    {
      local operation = ::g_ww_global_status.getMyClanOperation()
      if (operation && operation.getMapId() == selMap.getId())
        return ::colorize("userlogColoredText",
          ::loc("worldwar/mapStatus/yourClanInOperation", { name = operation.getNameText(false) }))
      local queue = selMap.getQueue()
      if (queue.isMyClanJoined())
        return  ::colorize("userlogColoredText", ::loc("worldwar/mapStatus/yourClanInQueue"))

      if (operation)
        return ""

      local cantJoinReason = queue.getCantJoinQueueReasonData()
      return cantJoinReason.canJoin ? "" :
        ::colorize("badTextColor", cantJoinReason.reasonText)
    }

    return ""
  }

  function getChapterObjId(map)
  {
    return "chapter_" + map.getChapterId()
  }

  function onClansQueue()
  {
    if (!::has_feature("WorldWarClansQueue"))
      return
    switchMode(WW_OM_WND_MODE.CLAN)
  }

  function getCantJoinAllQueuesReasonData()
  {
    local res = ::WwQueue.getCantJoinAnyQueuesReasonData()
    if (! res.canJoin)
      return res

    res.canJoin = false

    foreach (data in countryData)
      if (data.selected > 0)
      {
        res.canJoin = true
        break
      }
    if (!res.canJoin)
      res.reasonText = ::loc("worldWar/chooseCountriesInOperations")

    return res
  }

  function onJoinQueue()
  {
    local reasonData = getCantJoinAllQueuesReasonData()
    if (!reasonData.canJoin)
    {
      ::showInfoMsgBox(reasonData.reasonText)
      return
    }

    foreach (mapId, map in mapsTbl)
    {
      local queue = map.getQueue()
      foreach (countryId in map.getCountries())
      {
        local obj = scene.findObject(::format(formatCheckboxMapCountry, mapId, countryId))
        if (::checkObj(obj) && obj.getValue())
          queue.joinQueue(countryId)
      }
    }
  }

  function onLeaveQueue()
  {
    if (!::g_ww_global_status.isMyClanInQueue())
      return

    foreach (map in mapsTbl)
      map.getQueue().leaveQueue()
  }

  function onJoinOperation()
  {
    openOperationsListModal()
  }

  function onStart()
  {
    if (::has_feature("WorldWarGlobalBattles"))
      openGlobalBattlesModal()
    else
      openOperationsListModal()
  }

  function openGlobalBattlesModal()
  {
    ::gui_handlers.WwGlobalBattlesModal.open()
  }

  function openOperationsListModal()
  {
    if (!selMap || mode != WW_OM_WND_MODE.PLAYER)
      return

    openOperationsListByMap(selMap)
  }

  function openOperationsListByMap(map)
  {
    ::handlersManager.loadHandler(::gui_handlers.WwOperationsListModal,
      { map = map })
  }

  function goBack()
  {
    if (mode == WW_OM_WND_MODE.CLAN)
    {
      if (isSelectedMapEditMode(getSelectedMapObj()))
        onLeaveCountriesBlock()
      else
        switchMode(WW_OM_WND_MODE.PLAYER)
    }
    else if (mode == WW_OM_WND_MODE.PLAYER)
      base.goBack()
  }

  function onDestroy()
  {
    seenWWMapsAvailable.markSeen()
  }

  function updateUnseen()
  {
    if (!selMap)
      return

    seenWWMapsAvailable.markSeen(selMap.name)
  }

  function onEventWWGlobalStatusChanged(p)
  {
    if (p.changedListsMask & (WW_GLOBAL_STATUS_TYPE.MAPS | WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS))
      reinitScreen()
    else if (p.changedListsMask & WW_GLOBAL_STATUS_TYPE.QUEUE)
      updateWindow()
    else
      updateButtons()

    checkAndJoinClanOperation()
  }

  function checkAndJoinClanOperation()
  {
    if (hasClanOperation)
      return

    local newClanOperation = ::g_ww_global_status.getMyClanOperation()
    if (!newClanOperation)
      return
    hasClanOperation = true

    local myClanCountry = newClanOperation.getMyClanCountry()
    if (myClanCountry)
      newClanOperation.join(myClanCountry)
    else
    {
      local msg = ::format("Error: WWar: Bad country for my clan group in just created operation %d:\n%s",
                           newClanOperation.id,
                           ::toString(newClanOperation.getMyClanGroup())
                          )
      ::script_net_assert_once("badClanCountry/" + newClanOperation.id, msg)
    }
  }

  function onEventClanInfoUpdate(params)
  {
    updateDescription()
    updateButtons()
  }

  function onEventWWGlobeMarkerClick(params)
  {
    selectMapById(params.id)
  }

  function onEventWWGlobeMarkerHover(params)
  {
    local obj = scene.findObject("globe_hint")
    if (!::check_obj(obj))
      return
    local map = params.hover ? ::g_ww_global_status.getMapByName(params.id) : null
    local show = map != null
    obj.show(show)
    if (!show)
      return
    local item = mode == WW_OM_WND_MODE.CLAN ? map.getQueue() : map
    obj.findObject("title").setValue(item.getNameText())
    obj.findObject("desc").setValue(item.getGeoCoordsText())
    placeHint(obj)
  }

  function onEventWWCreateOperation(params)
  {
    onClansQueue()
  }

  function onGlobeHintTimer(obj, dt)
  {
    placeHint(obj)
  }

  function placeHint(obj)
  {
    if(!::checkObj(obj))
      return
    local cursorPos = ::get_dagui_mouse_cursor_pos_RC()
    cursorPos[0] += "+0.04sh"
    ::g_dagui_utils.setObjPosition(obj, cursorPos, ["@bw", "@bh"])
  }

  function getWndHelpConfig()
  {
    local res = {
      textsBlk = "gui/worldWar/wwOperationsMapsModalHelp.blk"
      objContainer = scene.findObject("root-box")
    }

    local links = [
      { obj = ["to_battle_button"]
        msgId = "hint_to_battle_button"
      }

      { obj = ["item_desc"]
        msgId = "hint_item_desc"
      }

      { obj = ["maps_list"]
        msgId = "hint_maps_list"
      }

      { obj = ["trophy_list"]
        msgId = "trophy_list_list"
      }

      { obj = ["btn_join_operation"]
        msgId = "hint_btn_join_operation"
      }

      { obj = ["btn_clans_queue"]
        msgId = "hint_btn_clans_queue"
      }

      { obj = ["btn_join_queue"]
        msgId = "hint_btn_join_queue"
      }
    ]

    res.links <- links
    return res
  }
}

function on_globe_marker_hover(id, hover) // called from client
{
  ::ww_event("GlobeMarkerHover", { id = id, hover = hover })
}

function on_globe_marker_click(id) // called from client
{
  ::ww_event("GlobeMarkerClick", { id = id })
}
