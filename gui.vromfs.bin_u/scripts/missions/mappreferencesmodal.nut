local mapPreferencesParams = require("scripts/missions/mapPreferencesParams.nut")
local mapPreferences    = ::require_native("mapPreferences")
local daguiFonts = require("scripts/viewUtils/daguiFonts.nut")

const POPUP_PREFIX_LOC_ID = "maps/preferences/notice/"

::dagui_propid.add_name_id("hasPremium")
::dagui_propid.add_name_id("hasMaxBanned")
::dagui_propid.add_name_id("hasMaxDisliked")

class ::gui_handlers.mapPreferencesModal extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType             = handlerType.MODAL
  sceneTplName        = "gui/missions/mapPreferencesModal"
  curEvent            = null
  curBattleTypeName   = null
  counters            = null
  mapsList            = null
  inactiveMaps        = null
  currentMapId        = -1

  function getSceneTplView()
  {
    local maxCountX = ::max(::floor(
      ::to_pixels("0.8@rw - 1@mapPreferencePreviewFullWidth - 1@scrollBarSize")
      * 1.0 / ::to_pixels("1@mapPreferenceIconNestWidth")), 1)
    mapsList = mapPreferencesParams.getMapsList(curEvent)
    inactiveMaps = mapPreferencesParams.getInactiveMaps(curEvent, mapsList)
    counters = mapPreferencesParams.getCounters(curEvent)
    validateCounters()
    local banList = getBanList()
    local mapsCountY = ::ceil(mapsList.len() * 1.0 / maxCountX)
    local mapItemHeight = ::to_pixels("1@mapPreferenceIconSize + 3@blockInterval")
      + daguiFonts.getFontLineHeightPx("fontSmall")
    local mapsRowsHeight = mapsCountY * mapItemHeight

    return {
      wndTitle = mapPreferencesParams.getPrefTitle(curEvent)
      maxCountX = maxCountX
      premium = ::havePremium()
      maps = mapsList
      isListEmpty = mapsList.len() == 0
      listTitle = getListTitle()
      mapStateBox = banList
      counterTitle = getCounterTitleText()
      hasMaxBanned = hasMaxCount("banned") ? "yes" : "no"
      hasMaxDisliked = hasMaxCount("disliked") ? "yes" : "no"
      hasScroll = ::to_pixels("1@mapPreferenceListHeight") < (mapsRowsHeight + ::to_pixels("1@blockInterval"))
    }
  }

  function initScreen()
  {
    curBattleTypeName = mapPreferencesParams.getCurBattleTypeName(curEvent)
    local mlistObj = scene.findObject("maps_list")
    mlistObj.setValue(mapsList.len() ? (::math.rnd() % mapsList.len()) : -1)
    mlistObj.select()
  }

  function updateMapPreview()
  {
    local mapObj = scene.findObject("map_preview")
    if (!::check_obj(mapObj))
      return

    local isMapSelected = mapsList?[currentMapId] != null
    ::showBtnTable(mapObj, {
      title             = isMapSelected,
      img_preview       = isMapSelected,
      ["tactical-map"]  = false,
      dislike           = isMapSelected,
      ban               = isMapSelected,
      preview_separator = isMapSelected,
    })

    if (isMapSelected)
    {
      mapObj.findObject("title").setValue(mapsList[currentMapId].title)
      local curMission = ::get_mission_meta_info(mapsList[currentMapId].mission)
      if(curMission)
      {
        local config = ::g_map_preview.getMissionBriefingConfig({blk = curMission})
        ::g_map_preview.setMapPreview(scene.findObject("tactical-map"), config)
      }
      mapObj.findObject("img_preview")["background-image"] = curMission ? "" : mapsList[currentMapId].image
      local checkBoxObj = mapObj.findObject("dislike")
      local banned = mapsList[currentMapId].banned
      local disliked = mapsList[currentMapId].disliked
      checkBoxObj.setValue(!banned && disliked)
      checkBoxObj.findObject("title").setValue(::loc("maps/preferences/"
        + (disliked ? "removeDislike" : "dislike")))
      checkBoxObj.inactiveColor = banned || (hasMaxCount("disliked") && !disliked) ? "yes" : "no"

      checkBoxObj = mapObj.findObject("ban")
      checkBoxObj.setValue(banned)
      checkBoxObj.findObject("title").setValue(::loc("maps/preferences/"
        + (banned ? "removeBan" : "ban")))
      checkBoxObj.inactiveColor = (hasMaxCount("banned") && !banned) ? "yes" : "no"
    }

    local isBanListFilled = getBanList().len() > 0
    showSceneBtn("btnReset", isBanListFilled)
    showSceneBtn("listTitle", isBanListFilled)
  }

  function hasMaxCount(typeName)
  {
    return counters[typeName].curCounter >= counters[typeName].maxCounter
  }

  function getCounterTextByType(typeName)
  {
    local hasPremium  = ::havePremium()
    local maxCountertextWithPremium = !hasPremium
      && counters[typeName].maxCounter < counters[typeName].maxCounterWithPremium
        ? " " + ::loc("ui/parentheses", { text = ::loc("maps/preferences/counter/withPremium",
                  { count = counters[typeName].maxCounterWithPremium }) })
        : ""

    return ::loc("ui/parentheses",{text = counters[typeName].curCounter + ::loc("ui/slash")
      + counters[typeName].maxCounter + maxCountertextWithPremium})
  }

  function getCounterTitleText()
  {
    return ::loc("maps/preferences/counter/dislike", { counterText = getCounterTextByType("disliked") })
      + " " + ::loc("maps/preferences/counter/ban", { counterText = getCounterTextByType("banned") })
  }

  function updateCounterTitle()
  {
    scene.findObject("counters").setValue(getCounterTitleText())
  }

  function updateMapsListParams()
  {
    local mapListObj = scene.findObject("maps_list")
    local mapsObjParams = {
      hasPremium = ::havePremium() ? "yes" : "no"
      hasMaxBanned = hasMaxCount("banned") ? "yes" : "no"
      hasMaxDisliked = hasMaxCount("disliked") ? "yes" : "no"
    }
    foreach (paramName, value in mapsObjParams)
      mapListObj[paramName] = value
  }

  function updateMapsList()
  {
    validateCounters()
    updateCounterTitle()
    updateMapsListParams()
    refreshMapsCheckBox()
    updateBanList()
  }

  function updateMapState(mapId, paramName, value)
  {
    mapsList[mapId][paramName] = value
    local newState = mapPreferencesParams.getMapStateByBanParams(mapsList[mapId].banned, mapsList[mapId].disliked)
    mapsList[mapId].state = newState
    updateMapPreview()
    updateCounterTitle()
    updateMapsListParams()
    updateProfile(paramName == "banned", value, mapsList[mapId].mission)

    local iconObj = scene.findObject("icon_" + mapId)
    if (!::check_obj(iconObj))
      return

    iconObj.state = newState
    local chekboxObj = iconObj.findObject(paramName)
    if (::check_obj(chekboxObj))
      chekboxObj.setValue(value)
  }

  function onUpdateIcon(obj)
  {
    local mapId = obj?.mapId.tointeger() ?? currentMapId
    local value = obj.getValue()
    local objType = obj.type
    local isBanObj = objType == "banned"
    local curValue = mapsList[mapId][objType]
    if(curValue == value)
      return

    local count = counters[objType]
    local isBannedMap = mapsList[mapId].banned
    count.curCounter += value ? 1 : -1
    if(value && (count.curCounter > count.maxCounter || (!isBanObj && isBannedMap))) //not dislike banned map
    {
      local needPremium  = isBanObj && !::havePremium()
      if(needPremium)
        ::scene_msg_box("need_money", null, ::loc("mainmenu/onlyWithPremium"),
          [ ["purchase", (@() onOnlineShopPremium()).bindenv(this)],
            ["cancel", null]
          ], "purchase")
      else
      {
        local msg_id = !isBanObj && isBannedMap ? "mapIsBanned"
          : isBanObj ? "maxBannedCount"
          : "maxDislikedCount"
        ::g_popups.add(null, ::loc(POPUP_PREFIX_LOC_ID + msg_id), null, null, null, msg_id)
      }

      count.curCounter--
      obj.setValue(false)
      return
    }
    if(value && isBanObj)
      scene.findObject("cb_nest_" + mapId).findObject("disliked").setValue(false)
    updateMapState(mapId, objType, value)
    updateBanList()
  }

  function refreshMapsCheckBox()
  {
    for(local i=0; i < mapsList.len(); i++)
    {
      local iconObj = scene.findObject("icon_" + i)
      if (!::check_obj(iconObj))
        continue

      local disliked = mapsList[i].disliked
      local banned = mapsList[i].banned
      local mapState = mapPreferencesParams.getMapStateByBanParams(banned, disliked)

      iconObj.state = mapState
      local checkBoxObj = iconObj.findObject("disliked")
      checkBoxObj.setValue(disliked)

      checkBoxObj = iconObj.findObject("banned")
      checkBoxObj.setValue(banned)
    }
  }

  function updateProfile(isBan, value, missionName)
  {
    local actionType = isBan ? mapPreferences.BAN : mapPreferences.DISLIKE
    if(value)
      mapPreferences.add(curBattleTypeName, actionType, missionName)
    else
      mapPreferences.remove(curBattleTypeName, actionType, missionName)
  }

  function goBack()
  {
    base.goBack()
    foreach(name, list in inactiveMaps)
      if(counters[name].curCounter + list.len() > counters[name].maxCounter)
        foreach(mission in list)
          updateProfile(name == "banned", false, mission)
    ::save_online_single_job(SAVE_ONLINE_JOB_DIGIT)
  }

  function onSelect(obj)
  {
    local childrenCount = obj.childrenCount()
    local idx = obj.getValue()
    if (idx < 0 || idx >= childrenCount)
      return

    currentMapId = idx
    updateMapPreview()
  }

  function onMapClick()
  {
    scene.findObject("maps_list")?.select()
  }

  function updateScreen()
  {
    mapsList = mapPreferencesParams.getMapsList(curEvent)
    updateMapsList()
    updateMapPreview()
  }

  function onEventPurchaseSuccess(params)
  {
    updateScreen()
  }

  function onEventProfileUpdated(params)
  {
    updateMapsList()
  }

  function resetCounters(params)
  {
    foreach(pref in params)
    {
      mapPreferencesParams.resetProfilePreferences(curEvent, pref)
      counters[pref].curCounter = 0
    }
    ::save_online_single_job(SAVE_ONLINE_JOB_DIGIT)
  }

  function validateCounters()
  {
    foreach(name, list in inactiveMaps)
      counters[name].curCounter = ::max(counters[name].curCounter - list.len(), 0)
    local params = counters.filter(@(c) c.curCounter > c.maxCounter).keys()
    if(params.len() > 0)
    {
      resetCounters(params)
      ::showInfoMsgBox(::loc(POPUP_PREFIX_LOC_ID + "resetPreferences"))
    }
  }

  function getListTitle()
  {
    return ::loc("maps/preferences/banTitle",
      {
        listName = curEvent.missionsBanMode == "level" ? ::loc("maps/preferences/maps")
          : ::loc("maps/preferences/missions")
      }
    )
  }

  function getBanList()
  {
    local list = mapsList.filter(@(inst) inst.disliked || inst.banned).map(@(inst)
      {
        id = "cb_" + inst.mapId
        text = inst.title
        value = true
        funcName = "onUpdateIcon"
        sortParam = inst.banned ? 0 : 1
        specialParams = "smallFont:t='yes'; mapId:t='{mapId}'; type:t='{type}';".subst({
          mapId = inst.mapId
          type = inst.banned ? "banned" : "disliked"
        })
      }
    )

    list.sort(@(a, b) a.sortParam <=> b.sortParam || a.text <=> b.text)
    return list
  }

  function updateBanList()
  {
    local listObj = scene.findObject("ban_list")
    if (!::check_obj(listObj))
      return

    local data = ::handyman.renderCached("gui/missions/mapStateBox", {mapStateBox = getBanList()})
    guiScene.replaceContentFromText(listObj, data, data.len(), this)
  }

  function onResetPreferencess(obj)
  {
    ::scene_msg_box("reset_preferences", null, ::loc("maps/preferences/notice/request_reset"),
      [ ["ok", function() {
            resetCounters(counters.keys())
            updateScreen()
          }.bindenv(this)],
        ["cancel", null]
      ], "ok")
  }

  function onFilterEditBoxAccessKey()
  {
    scene.findObject("filter_edit_box")?.select()
  }

  function onFilterEditBoxActivate()
  {
    selectMapById(currentMapId)
  }

  function onFilterEditBoxCancel()
  {
    scene.findObject("filter_edit_box")?.setValue("")
    selectMapById(currentMapId)
  }

  function onFilterEditBoxChangeValue(obj)
  {
    local value = obj.getValue()
    scene.findObject("filter_edit_cancel_btn")?.show(value.len() != 0)

    local searchStr = ::g_string.utf8ToLower(::g_string.trim(value))
    local visibleMapsList = mapsList.filter(@(inst)
      ::g_string.utf8ToLower(inst.title).find(searchStr) != null)

    local mlistObj = scene.findObject("maps_list")
    foreach (inst in mapsList)
      mlistObj.findObject("nest_" + inst.mapId)?.show(visibleMapsList.find(inst) != null)

    local isFound = visibleMapsList.len() != 0
    currentMapId = isFound ? visibleMapsList[0].mapId : -1
    showSceneBtn("empty_list_label", !isFound)
    mlistObj.findObject("nest_" + currentMapId)?.scrollToView()
    updateMapPreview()
  }

  function selectMapById(mapId)
  {
    local mlistObj = scene.findObject("maps_list")
    mlistObj?.select()
    mlistObj?.setValue(mapId)
    guiScene.performDelayed(this, @() guiScene.performDelayed(this,
      @() mlistObj?.findObject("nest_" + mapId).scrollToView() ))
  }
}

return {
  open = function(params)
  {
    if(!mapPreferencesParams.hasPreferences(params.curEvent))
      return

    ::handlersManager.loadHandler(::gui_handlers.mapPreferencesModal, params)
  }
}