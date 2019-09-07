local mapPreferencesParams = require("scripts/missions/mapPreferencesParams.nut")
local mapPreferences    = ::require_native("mapPreferences")

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
  countByType         = null
  mapsList            = null

  MAX_MAP_COUNT_X     = ::is_small_screen ? 5 : 7
  currentMapId        = 0

  function getSceneTplView()
  {
    validateCounters()
    mapsList = mapPreferencesParams.getMapsList(curEvent)
    local banList = getBanList()
    return {
      wndTitle = mapPreferencesParams.getPrefTitle(curEvent)
      maxCountX = MAX_MAP_COUNT_X
      premium = ::havePremium()
      maps = mapsList
      listTitle = banList.len() > 0 ? getListTitle() : ""
      mapStateBox = banList
      counterTitle = getCounterTitleText()
      hasMaxBanned = hasMaxCount("banned") ? "yes" : "no"
      hasMaxDisliked = hasMaxCount("disliked") ? "yes" : "no"
    }
  }

  function initScreen()
  {
    curBattleTypeName = mapPreferencesParams.getCurBattleTypeName(curEvent)
    local mlistObj = scene.findObject("maps_list")
    mlistObj.setValue(::math.rnd() % mapsList.len())
    mlistObj.select()
  }

  function updateMapPreview()
  {
    local mapObj = scene.findObject("map_preview")
    if (!::check_obj(mapObj))
      return

    mapObj.findObject("title").setValue(mapsList[currentMapId].title)
    mapObj.findObject("img_preview")["background-image"] = mapsList[currentMapId].image
    local checkBoxObj = mapObj.findObject("dislike")
    local banned = mapsList[currentMapId].banned
    local disliked = mapsList[currentMapId].disliked
    checkBoxObj.setValue(!banned && disliked)
    checkBoxObj.text = ::loc("maps/preferences/" + (disliked ? "removeDislike" : "dislike"))
    checkBoxObj.inactiveColor = banned || (hasMaxCount("disliked") && !disliked) ? "yes" : "no"

    checkBoxObj = mapObj.findObject("ban")
    checkBoxObj.setValue(banned)
    checkBoxObj.text = ::loc("maps/preferences/" + (banned ? "removeBan" : "ban"))
    checkBoxObj.inactiveColor = (hasMaxCount("banned") && !banned) ? "yes" : "no"
    showSceneBtn("btnReset", countByType.banned?.curCounter > 0
      || countByType.disliked?.curCounter > 0)
  }

  function hasMaxCount(typeName)
  {
    return countByType[typeName].curCounter >= countByType[typeName].maxCounter
  }

  function getCounterTextByType(typeName)
  {
    local hasPremium  = ::havePremium()
    local maxCountertextWithPremium = !hasPremium
      && countByType[typeName].maxCounter < countByType[typeName].maxCounterWithPremium
        ? " " + ::loc("ui/parentheses", { text = ::loc("maps/preferences/counter/withPremium",
                  { count = countByType[typeName].maxCounterWithPremium }) })
        : ""

    return ::loc("ui/parentheses",{text = countByType[typeName].curCounter + ::loc("ui/slash")
      + countByType[typeName].maxCounter + maxCountertextWithPremium})
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
    updateProfile(paramName == "banned", value, mapId)

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

    local count = countByType[objType]
    local isBannedMap = mapsList[mapId].banned
    count.curCounter += value ? 1 : -1
    if(value && (count.curCounter > count.maxCounter || (!isBanObj && isBannedMap))) //not dislike banned map
    {
      local needPremium  = isBanObj && !::havePremium()
      local msg_id = !isBanObj && isBannedMap ? "mapIsBanned"
        : needPremium ? "needPremiumAccount"
        : isBanObj ? "maxBannedCount"
        : "maxDislikedCount"
      local popupAction = needPremium ? (@() onOnlineShopPremium()).bindenv(this) : null
      local buttons = needPremium
        ? [{
            id = "buy",
            text = ::loc("mainmenu/btnBuy"),
            func = popupAction
          }]
        : null

      ::g_popups.add(
        null,
        (needPremium ? ::loc("mainmenu/onlyWithPremium") : ::loc(POPUP_PREFIX_LOC_ID + msg_id)),
        popupAction,
        buttons,
        null,
        msg_id
      )

      count.curCounter--
      obj.setValue(false)
      return
    }
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

  function updateProfile(isBan, value, mapId)
  {
    local actionType = isBan ? mapPreferences.BAN : mapPreferences.DISLIKE
    if(value)
      mapPreferences.add(curBattleTypeName, actionType, mapsList[mapId].mission)
    else
      mapPreferences.remove(curBattleTypeName, actionType, mapsList[mapId].mission)
  }

  function goBack()
  {
    base.goBack()
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

  function updateScreen()
  {
    mapsList = mapPreferencesParams.getMapsList(curEvent)
    updateMapsList()
    updateMapPreview()
    showSceneBtn("buyPremium", !::havePremium())
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
    foreach(inst in params)
    {
      mapPreferencesParams.resetProfilePreferences(curEvent, inst.isBan)
      inst.counter = 0
    }
    ::save_online_single_job(SAVE_ONLINE_JOB_DIGIT)
  }

  function validateCounters()
  {
    local counters = mapPreferencesParams.getCounters(curEvent)
    local params = []
    if(counters.dislikeCount.curCounter > counters.dislikeCount.maxCounter)
      params.append({counter = counters.dislikeCount.curCounter, isBan = false})
    if(counters.banCount.curCounter > counters.banCount.maxCounter)
      params.append({counter = counters.banCount.curCounter, isBan = true})
    if(params.len() > 0)
    {
      resetCounters(params)
      ::g_popups.add(null, ::loc(POPUP_PREFIX_LOC_ID + "resetPreferences"))
    }
    countByType = {
      disliked = counters.dislikeCount
      banned   = counters.banCount
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
    local list = mapsList.filter(@(idx, inst) inst.disliked || inst.banned).map(@(inst)
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
    local counters = mapPreferencesParams.getCounters(curEvent)
    resetCounters([
      {counter = counters.dislikeCount.curCounter, isBan = false},
      {counter = counters.banCount.curCounter, isBan = true}
    ])
    updateScreen()
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