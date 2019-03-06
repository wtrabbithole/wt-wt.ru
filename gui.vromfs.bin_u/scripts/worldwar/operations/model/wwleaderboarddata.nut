local function requestWwLeaderboardData(appId, mode, type, start, amount, category, cb)
{
  local requestData = {
    add_token = true
    headers = { appid = appId }
    action = "cln_get_leaderboard_json"
    data = {
      gameMode = mode,
      table = type,
      start = start,
      count = amount,
      category = category,
      valueType = "value_total"
      resolveNick = true
    }
  }

  ::ww_leaderboard.request(requestData, cb)
}

local wwLeaderboardValueFactors = {
  rating = 0.0001
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
  requestWwLeaderboardData = requestWwLeaderboardData
  convertWwLeaderboardData = convertWwLeaderboardData
}
