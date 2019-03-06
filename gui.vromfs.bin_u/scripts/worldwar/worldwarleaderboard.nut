local function request(app_id, action, headers, data, callback)
{
  headers.appid <- app_id
  local requestData = {
    add_token = true,
    headers = headers,
    action = action
  }

  if (data) {
    requestData["data"] <- data;
  }

  ::ww_leaderboard.request(requestData, callback)
}

::g_ww_leaderboard <- {}

function g_ww_leaderboard::get(app_id, table, mode, start, count, category)
{
  local req = {
    table = table,
    gameMode = mode,
    start = start,
    count = count,
    category = category,
    valueType = "value_total"
  }

  request(app_id,
      "cln_get_leaderboard_json",
      {},
      req,
      function(res)
      {
        debugTableData(res)
      })
}
