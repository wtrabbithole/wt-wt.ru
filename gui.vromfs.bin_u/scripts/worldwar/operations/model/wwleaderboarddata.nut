local modes = [
  {
    mode  = "ww_users"
    appId = "1134"
    mask  = WW_LB_MODE.WW_USERS
    field = ::g_lb_category.EVENTS_PERSONAL_ELO.field
    hasDaysData = true
  },
  {
    mode  = "ww_clans"
    appId = "1135"
    mask  = WW_LB_MODE.WW_CLANS
    field = ::g_lb_category.EVENTS_PERSONAL_ELO.field
    hasDaysData = false
  },
  {
    mode  = "ww_countries"
    appId = "1136"
    mask  = WW_LB_MODE.WW_COUNTRIES
    field = ::g_lb_category.OPERATION_COUNT.field
    hasDaysData = false
    needFeature = "WorldWarCountryLeaderboard"
  }
]

local function requestWwLeaderboardData(modeName, modePostFix, day, start, amount, category, cb)
{
  local mode = getModeByName(modeName)
  if (!mode)
    return

  local requestData = {
    add_token = true
    headers = { appid = mode.appId }
    action = "cln_get_leaderboard_json"
    data = {
      gameMode = modeName + modePostFix,
      table = day && day > 0 ? "day" + day : "season",
      start = start,
      count = amount,
      category = category,
      valueType = "value_total"
      resolveNick = true
    }
  }

  ::ww_leaderboard.request(requestData, cb)
}

local function requestWwLeaderboardModes(modeName, cb)
{
  local mode = getModeByName(modeName)
  if (!mode)
    return

  local requestData = {
    add_token = true
    headers = { appid = mode.appId }
    action = "cmn_get_global_leaderboard_modes"
  }

  ::ww_leaderboard.request(requestData, cb)
}

local function getSeasonDay(days)
{
  if (!days)
    return 0

  local seasonDay = 0
  foreach (dayId in days)
    if (dayId.slice(0, 3) == "day")
    {
      local dayNumberText = dayId.slice(3)
      if (::g_string.isStringInteger(dayNumberText))
        seasonDay = ::max(seasonDay, dayNumberText.tointeger())
    }

  return seasonDay
}

local wwLeaderboardValueFactors = {
  rating = 0.0001
  operation_winrate = 0.0001
  battle_winrate = 0.0001
  avg_place = 0.0001
  avg_score = 0.0001
}
local wwLeaderboardKeyCorrection = {
  idx = "pos"
  playerAKills = "air_kills_player"
  playerGKills = "ground_kills_player"
  aiAKills = "air_kills_ai"
  aiGKills = "ground_kills_ai"
}

local function convertWwLeaderboardData(result, applyLocalisationToName = false)
{
  local list = []
  foreach (rowId, rowData in result)
  {
    if (typeof(rowData) != "table")
      continue

    local lbData = {
      name = applyLocalisationToName ? ::loc(rowId) : rowId
    }
    foreach (columnId, columnData in rowData)
    {
      local key = wwLeaderboardKeyCorrection?[columnId] ?? columnId
      if (key in lbData && ::u.isEmpty(columnData))
        continue

      local valueFactor = wwLeaderboardValueFactors?[columnId]
      local value = typeof(columnData) == "table"
        ? columnData?.value_total
        : columnId == "name" && applyLocalisationToName
            ? ::loc(columnData)
            : columnData
      if (valueFactor)
        value = value * valueFactor

      lbData[key] <- value
    }
    list.append(lbData)
  }
  list.sort(@(a, b) a.pos < 0 <=> b.pos < 0 || a.pos <=> b.pos)

  return { rows = list }
}


return {
  modes = modes
  getSeasonDay = getSeasonDay
  getDayIdByNumber = @(number) "day" + number
  getModeByName = @(mName) ::u.search(modes, @(m) m.mode == mName)
  requestWwLeaderboardData = requestWwLeaderboardData
  requestWwLeaderboardModes = requestWwLeaderboardModes
  convertWwLeaderboardData = convertWwLeaderboardData
}
