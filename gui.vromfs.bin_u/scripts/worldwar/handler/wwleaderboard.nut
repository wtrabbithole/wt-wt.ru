local wwLeaderboardData = require("scripts/worldWar/operations/model/wwLeaderboardData.nut")
local wwRewards = ::require("scripts/worldWar/handler/wwRewards.nut")
local time = require("scripts/time.nut")

::ww_leaderboards_list <- [
  ::g_lb_category.UNIT_RANK
  ::g_lb_category.WW_EVENTS_PERSONAL_ELO
  ::g_lb_category.OPERATION_COUNT
  ::g_lb_category.OPERATION_WINRATE
  ::g_lb_category.BATTLE_COUNT
  ::g_lb_category.BATTLE_WINRATE
  ::g_lb_category.FLYOUTS
  ::g_lb_category.DEATHS
  ::g_lb_category.PLAYER_KILLS
  ::g_lb_category.AI_KILLS
  ::g_lb_category.AVG_PLACE
  ::g_lb_category.AVG_SCORE
]


class ::gui_handlers.WwLeaderboard extends ::gui_handlers.LeaderboardWindow
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/leaderboard/leaderboard.blk"

  beginningMode = null
  needDayOpen = false

  lbDay = null
  lbMode = null
  lbModeData = null
  lbMap = null
  lbCountry = null

  lbModesList = null
  lbDaysList = null
  lbMapsList = null
  lbCountriesList = null

  wwMapsList = null
  requestData = null

  rewardsBlk = null
  rewardsTimeData = null

  function initScreen()
  {
    if (!lbModel)
    {
      lbModel = ::leaderboardModel
      lbModel.reset()
    }
    if (!lb_presets)
      lb_presets = ::ww_leaderboards_list

    initTable()
    fillMapsList()
    initModes()
    updateButtons()
    fetchRewardsData()
    fetchRewardsTimeData()
  }

  function fetchRewardsData()
  {
    local requestBlk = ::DataBlock()
    requestBlk.configname = "ww_rewards"
    ::g_tasker.charRequestBlk("cmn_get_config_bin", requestBlk, null,
      ::Callback(function(res) {
        rewardsBlk = ::DataBlock()
        local curCircuitRewardsBlk = res?.body?[::get_cur_circuit_name()]
        if (curCircuitRewardsBlk)
          rewardsBlk.setFrom(curCircuitRewardsBlk)
        updateButtons()
      }, this),
      ::Callback(function(res) {
        rewardsBlk = null
        updateButtons()
      }, this))
  }

  function fetchRewardsTimeData()
  {
    local userstatRequestData = {
      add_token = true
      headers = { appid = "1134" }
      action = "GetTablesInfo"
    }

    local callback = ::Callback(function(userstatTbl) {
      rewardsTimeData = {}
      foreach (key, val in userstatTbl)
      {
        local rewardTimeStr = val?.interval?.index == 0 && val?.prevInterval?.index != 0 ?
          val?.prevInterval?.end : val?.interval?.end
        rewardsTimeData[key] <- rewardTimeStr ? time.getTimestampFromIso8601(rewardTimeStr) : 0
      }
    }, this)

    ::userstat.request(userstatRequestData, @(userstatTbl) callback(userstatTbl))
  }

  function fillMapsList()
  {
    wwMapsList = []
    foreach (map in ::g_ww_global_status_type.MAPS.getList())
      if (map.isVisible())
        wwMapsList.append(map)
  }

  function initModes()
  {
    lbModeData = null
    lbMode = null
    lbModesList = []

    local data = ""
    foreach(modeData in wwLeaderboardData.modes)
    {
      if (!modeData?.isInLeaderboardModes ||
        (modeData?.needFeature && !::has_feature(modeData.needFeature)))
        continue

      lbModesList.append(modeData)
      local optionText = ::g_string.stripTags(
        ::loc("worldwar/leaderboard/" + modeData.mode))
      data += format("option {text:t='%s'}", optionText)
    }

    local modesObj = showSceneBtn("modes_list", true)
    guiScene.replaceContentFromText(modesObj, data, data.len(), this)

    local modeIdx = lbModesList.findindex((@(m) m.mode == beginningMode).bindenv(this)) ?? 0
    modesObj.setValue(modeIdx)
  }

  function updateDaysComboBox(seasonDays)
  {
    local seasonDay = wwLeaderboardData.getSeasonDay(seasonDays)
    lbDaysList = [null]
    for (local i = 0; i < seasonDay; i++)
    {
      local dayNumber = seasonDay - i
      if (::isInArray(wwLeaderboardData.getDayIdByNumber(dayNumber), seasonDays))
        lbDaysList.append(dayNumber)
    }

    local data = ""
    foreach(day in lbDaysList)
    {
      local optionText = ::g_string.stripTags(
        day ? ::loc("enumerated_day", {number = day}) : ::loc("worldwar/allSeason"))
      data += format("option {text:t='%s'}", optionText)
    }

    local hasDaySelection = isUsersLeaderboard()
    local daysObj = showSceneBtn("days_list", hasDaySelection)
    guiScene.replaceContentFromText(daysObj, data, data.len(), this)

    daysObj.setValue(needDayOpen && lbDaysList.len() > 1 ? 1 : 0)
  }

  function updateMapsComboBox()
  {
    lbMapsList = getWwMaps()

    local data = ""
    foreach(wwMap in lbMapsList)
    {
      local optionText = ::g_string.stripTags(
        wwMap ? wwMap.getNameTextByMapName(wwMap.getId()) : ::loc("worldwar/allMaps"))
      data += format("option {text:t='%s'}", optionText)
    }

    local mapsObj = showSceneBtn("maps_list", true)
    guiScene.replaceContentFromText(mapsObj, data, data.len(), this)

    local mapObjValue = 0
    if (lbMap)
    {
      local selectedMapId = lbMap.getId()
      mapObjValue = lbMapsList.findindex(@(m) m && m.getId() == selectedMapId) ?? 0
    }
    lbMap = null
    mapsObj.setValue(mapObjValue)
  }

  function updateCountriesComboBox(filterMap = null, isVisible = true)
  {
    lbCountriesList = getWwCountries(filterMap)

    local data = ""
    foreach(country in lbCountriesList)
    {
      local optionText = ::g_string.stripTags(
        country ? ::loc(country) : ::loc("worldwar/allCountries"))
      data += format("option {text:t='%s'}", optionText)
    }

    local countriesObj = showSceneBtn("countries_list", isVisible)
    guiScene.replaceContentFromText(countriesObj, data, data.len(), this)

    local countryObjValue = 0
    if (lbCountry)
    {
      local selectedCountry = lbCountry
      countryObjValue = lbCountriesList.findindex(@(c) c && c == selectedCountry) ?? 0
    }
    lbCountry = null
    countriesObj.setValue(countryObjValue)
  }

  function fetchLbData(isForce = false)
  {
    local newRequestData = getRequestData()
    if (!newRequestData)
      return

    local isRequestDifferent = requestData?.modeName != newRequestData.modeName ||
                               requestData?.modePostFix != newRequestData.modePostFix ||
                               requestData?.day != newRequestData.day
    if (!isRequestDifferent && !isForce)
      return

    if (isRequestDifferent)
      pos = 0

    lbField = curLbCategory.field
    requestData = newRequestData
    local requestParams = {
      gameMode = requestData.modeName + requestData.modePostFix
      table    = requestData.day && requestData.day > 0 ? "day" + requestData.day : "season"
      category = lbField
    }

    local cb = function(hasSelfRow = false)
    {
      local callback = ::Callback(
        function(lbPageData) {
          if (!hasSelfRow)
            selfRowData = []
          pageData = wwLeaderboardData.convertWwLeaderboardData(lbPageData, isCountriesLeaderboard())
          fillLeaderboard(pageData)
        }, this)
      wwLeaderboardData.requestWwLeaderboardData(
        requestData.modeName,
        requestParams.__update({
          start    = pos
          count    = rowsInPage
        }),
        @(lbPageData) callback(lbPageData))
    }

    if (isUsersLeaderboard() || (forClans && ::is_in_clan()))
    {
      local callback = ::Callback(
        function(lbSelfData) {
          selfRowData = wwLeaderboardData.convertWwLeaderboardData(lbSelfData, isCountriesLeaderboard()).rows
          if(isRequestDifferent)
            requestSelfPage(getSelfPos())
          cb(true)
        }, this)
      wwLeaderboardData.requestWwLeaderboardData(
        requestData.modeName,
        requestParams.__update({
          start = null
          count = 0
        }),
        @(lbSelfData) callback(lbSelfData),
        { userId = isUsersLeaderboard() ? ::my_user_id_int64
          : ::clan_get_my_clan_id() })
    }
    else
      cb()
  }

  function onModeSelect(obj)
  {
    local modeObjValue = obj.getValue()
    if (modeObjValue < 0 || modeObjValue >= lbModesList.len())
      return

    lbModeData = lbModesList[modeObjValue]
    lbMode = lbModeData.mode
    forClans = lbMode == "ww_clans"

    checkLbCategory()

    local mode = wwLeaderboardData.getModeByName(lbMode)
    local callback = ::Callback(
      function(modesData) {
        updateModeComboBoxes(modesData?.tables)
      }, this)
    if (mode.hasDaysData)
      wwLeaderboardData.requestWwLeaderboardModes(
        lbMode,
        @(modesData) callback(modesData))
    else
      updateModeComboBoxes()
  }

  function updateModeComboBoxes(seasonDays = null)
  {
    if (isCountriesLeaderboard())
    {
      lbCountry = null
      updateCountriesComboBox(null, false)
    }
    else
      updateMapsComboBox()

    updateDaysComboBox(seasonDays)
  }

  function checkLbCategory()
  {
    if (!curLbCategory || !lbModel.checkLbRowVisibility(curLbCategory, this))
      curLbCategory = ::u.search(lb_presets, (@(row) lbModel.checkLbRowVisibility(row, this)).bindenv(this))
  }

  function onDaySelect(obj)
  {
    local dayObjValue = obj.getValue()
    if (dayObjValue < 0 || dayObjValue >= lbDaysList.len())
      return

    lbDay = lbDaysList[dayObjValue]

    fetchLbData()
  }

  function onMapSelect(obj)
  {
    local mapObjValue = obj.getValue()
    if (mapObjValue < 0 || mapObjValue >= lbMapsList.len())
      return

    lbMap = lbMapsList[mapObjValue]

    if (!isCountriesLeaderboard())
      updateCountriesComboBox(lbMap)
    else
      fetchLbData()
  }

  function onCountrySelect(obj)
  {
    local countryObjValue = obj.getValue()
    if (countryObjValue < 0 || countryObjValue >= lbCountriesList.len())
      return

    lbCountry = lbCountriesList[countryObjValue]

    if (!isCountriesLeaderboard())
      fetchLbData()
  }

  function onUserDblClick()
  {
    if (isCountriesLeaderboard())
      return

    base.onUserDblClick()
  }

  function getRequestData()
  {
    if (!lbModeData)
      return null

    local mapId = lbMap ? "__" + lbMap.getId() : ""
    local countryId = lbCountry ? "__" + lbCountry : ""
    return {
      modeName = lbModeData.mode
      modePostFix = mapId + countryId
      day = lbDay
    }
  }

  function getWwMaps()
  {
    local maps = [null]
    foreach (map in wwMapsList)
      maps.append(map)

    return maps
  }

  function getWwCountries(filterMap)
  {
    local countrries = [null]
    if (filterMap)
    {
      foreach (country in filterMap.getCountries())
        countrries.append(country)

      return countrries
    }

    local countrriesData = {}
    foreach (map in wwMapsList)
      foreach (country in map.getCountries())
        if (!(country in countrriesData))
          countrriesData[country] <- country

    foreach (country in countrriesData)
      countrries.append(country)

    return countrries
  }

  function isUsersLeaderboard()
  {
    return lbMode == "ww_users"
  }

  function isCountriesLeaderboard()
  {
    return lbMode == "ww_countries"
  }

  function onRewards()
  {
    local curRewardsBlk = getCurModeAwards()
    if (!curRewardsBlk)
      return ::showInfoMsgBox(::loc("leaderboards/has_no_rewards"))

    wwRewards.open({
      isPlayerRewards = isUsersLeaderboard()
      rewardsBlk = curRewardsBlk
      rewardsTime = getCurRewardsTime()
      lbMode    = lbMode
      lbDay     = lbDay
      lbMap     = lbMap
      lbCountry = lbCountry
    })
  }

  function updateWwRewardsButton()
  {
    local curRewardsBlk = getCurModeAwards()
    local rewardsBtn = showSceneBtn("btn_ww_rewards", true)
    rewardsBtn.inactiveColor = curRewardsBlk ? "no" : "yes"
  }

  function getCurModeAwards()
  {
    local rewardTableName = wwLeaderboardData.getModeByName(lbMode)?.rewardsTableName
    if (!rewardTableName || !rewardsBlk || !requestData)
      return null

    local day = lbDay ? wwLeaderboardData.getDayIdByNumber(lbDay) : "season"
    local awardTableName = requestData.modeName + requestData.modePostFix

    return rewardsBlk?[rewardTableName]?[day]?.awards?[awardTableName]
  }

  function getCurRewardsTime()
  {
    local day = lbDay ? wwLeaderboardData.getDayIdByNumber(lbDay) : "season"
    return rewardsTimeData?[day] ?? 0
  }
}
