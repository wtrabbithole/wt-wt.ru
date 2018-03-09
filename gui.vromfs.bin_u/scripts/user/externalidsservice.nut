local updateExternalIDsTable = function(request)
{
  local blk = ::DataBlock()
  ::get_player_external_ids(blk)

  local eIDtable = ::getTblValue("externalIds", blk, null)
  if (!eIDtable)
    return

  local table = {}
//STEAM
  if (::EPL_STEAM in eIDtable && "id" in eIDtable[::EPL_STEAM] && ::steam_is_running())
    table.steamName <- ::steam_get_name_by_id(blk.externalIds[::EPL_STEAM].id)

//FACEBOOK
  if (::EPL_FACEBOOK in eIDtable && "id" in eIDtable[::EPL_FACEBOOK] && ::facebook_is_logged_in() && ::no_dump_facebook_friends)
  {
    local fId = eIDtable[::EPL_FACEBOOK].id
    if (fId in ::no_dump_facebook_friends)
      table.facebookName <- ::no_dump_facebook_friends[fId]
  }

//PLAYSTATION NETWORK
  if (::EPL_PSN in eIDtable && "id" in eIDtable[::EPL_PSN])
    table.psnName <- eIDtable[::EPL_PSN].id

  ::broadcastEvent("UpdateExternalsIDsTexts", {externalIds = table, request = request})
}

local requestExternalIDsFromServer = function(taskId, request)
{
  ::g_tasker.addTask(taskId, null, @() updateExternalIDsTable(request))
}

local function reqPlayerExternalIDsByPlayerId(playerId)
{
  local taskId = ::req_player_external_ids_by_player_id(playerId)
  requestExternalIDsFromServer(taskId, {playerId = playerId})
}

local function reqPlayerExternalIDsByUserId(uid)
{
  local taskId = ::req_player_external_ids(uid)
  requestExternalIDsFromServer(taskId, {uid = uid})
}

local function getSelfExternalIds()
{
  local table = {}

//STEAM
  local steamId = ::get_my_external_id(::EPL_STEAM)
  if (steamId != null)
    table.steamName <- ::steam_get_name_by_id(steamId)

//FACEBOOK
  if (::facebook_is_logged_in() && ::no_dump_facebook_friends)
  {
    local fId = ::get_my_external_id(::EPL_FACEBOOK)
    if (fId in ::no_dump_facebook_friends)
      table.facebookName <- ::no_dump_facebook_friends[fId]
  }

//PLAYSTATION NETWORK
  local psnId = ::get_my_external_id(::EPL_PSN)
  if (psnId != null)
    table.psnName <- psnId

  return table
}

return {
  reqPlayerExternalIDsByPlayerId = reqPlayerExternalIDsByPlayerId
  reqPlayerExternalIDsByUserId = reqPlayerExternalIDsByUserId
  getSelfExternalIds = getSelfExternalIds
}