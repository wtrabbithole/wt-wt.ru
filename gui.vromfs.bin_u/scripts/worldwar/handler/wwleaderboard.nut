local wwLeaderboardData = require("scripts/worldWar/operations/model/wwLeaderboardData.nut")

::ww_leaderboards_list <- [
  ::g_lb_category.EVENTS_PERSONAL_ELO
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
  sceneBlkName = "gui/leaderboard.blk"

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

  function initScreen()
  {
    if (!lbModel)
    {
      lbModel = ::leaderboardModel
      lbModel.reset()
    }
    if (!lb_presets)
      lb_presets = ::ww_leaderboards_list

    fillMapsList()
    initModes()
    updateButtons()
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
      if (modeData?.needFeature && !::has_feature(modeData.needFeature))
        continue

      lbModesList.push(modeData)
      local optionText = ::g_string.stripTags(
        ::loc("worldwar/leaderboard/" + modeData.mode))
      data += format("option {text:t='%s'}", optionText)
    }

    local modesObj = showSceneBtn("modes_list", true)
    guiScene.replaceContentFromText(modesObj, data, data.len(), this)

    local modeIdx = ::u.searchIndex(wwLeaderboardData.modes,
      (@(m) m.mode == beginningMode).bindenv(this))

    modesObj.setValue(::max(modeIdx, 0))
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
      mapObjValue = ::u.searchIndex(lbMapsList, @(m) m && m.getId() == selectedMapId)
    }
    lbMap = null
    mapsObj.setValue(::max(mapObjValue, 0))
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
      countryObjValue = ::u.searchIndex(lbCountriesList, @(c) c && c == selectedCountry)
    }
    lbCountry = null
    countriesObj.setValue(::max(countryObjValue, 0))
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
    {
      afterLoadSelfRow = requestSelfPage
      pos = 0
    }

    lbField = curLbCategory.field
    requestData = newRequestData

    local cb = function(hasSelfRow = false)
    {
      wwLeaderboardData.requestWwLeaderboardData(
        requestData.modeName,
        requestData.modePostFix,
        requestData.day,
        pos, rowsInPage, lbField,
        function(lbPageData) {
          if (!isValid())
            return

          if (!hasSelfRow)
            selfRowData = []
          pageData = wwLeaderboardData.convertWwLeaderboardData(lbPageData, isCountriesLeaderboard())
          fillLeaderboard(pageData)
        }.bindenv(this))
    }

    if (isUsersLeaderboard())
      wwLeaderboardData.requestWwLeaderboardData(
        requestData.modeName,
        requestData.modePostFix,
        requestData.day,
        null, 0, lbField,
        function(lbSelfData) {
          if (!isValid())
            return

          selfRowData = wwLeaderboardData.convertWwLeaderboardData(lbSelfData, isCountriesLeaderboard()).rows
          if(afterLoadSelfRow)
            afterLoadSelfRow(getSelfPos())
          afterLoadSelfRow = null
          cb(true)
        }.bindenv(this))
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
    if (mode.hasDaysData)
      wwLeaderboardData.requestWwLeaderboardModes(
        lbMode,
        function(modesData) {
          if (!isValid())
            return

          updateModeComboBoxes(modesData?.tables)
        }.bindenv(this))
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
}
