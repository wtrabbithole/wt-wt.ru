const PSN_MAPPER_UPDATE_DELAY = 60000
::g_psn_mapper <- {
  [PERSISTENT_DATA_PARAMS] = ["cache", "lastUpdate"]

  cache = {} // onlineId(nick) = accountId(psn id)

  lastUpdate = -PSN_MAPPER_UPDATE_DELAY
}

function g_psn_mapper::getAccountIdByOnlineId(onlineId)
{
  local res = ::getTblValue(onlineId, cache)
  if (res)
    return res

  ::dagor.debug("PSN Mapper: Error: cannot find accountId of player " + onlineId)
  ::debugTableData(cache)
  return null
}

function g_psn_mapper::canUpdate(forceUpdate = false)
{
  if (::ps4_console_friends.len() == 0)
    return false

  if (!forceUpdate && (::dagor.getCurTime() - lastUpdate < PSN_MAPPER_UPDATE_DELAY))
  {
    ::dagor.debug("PSN Mapper: Too often update call")
    return false
  }

  foreach (name, block in ::ps4_console_friends)
    if (!(name in cache))
      return true

  return false
}

function g_psn_mapper::updateAccountIdsList(forceUpdate = false)
{
  if (!canUpdate(forceUpdate))
    return

  lastUpdate = ::dagor.getCurTime()

  local names = []
  foreach (name, block in ::ps4_console_friends)
    if (!(name in cache))
      names.append(name)

  if (!names.len())
    return

  local blk = ::DataBlock()
  blk.apiGroup = "sdk:identityMapper"
  blk.method = ::HTTP_METHOD_POST
  blk.path = "/v2/accounts/map/onlineId2accountId"

  local prepStrings = ::u.map(names, @(name) ::format("\"%s\"", ::g_string.cutPrefix(name, "*", name)))
  blk.request = "[\r\n" + ::g_string.implode(prepStrings, ",\r\n") + "\r\n]"

  local ret = ::ps4_web_api_request(blk)
  if ("error" in ret)
  {
    ::dagor.debug("Error: " + ret.error)
    ::dagor.debug("Error text: " + ret.errorStr)
  }
  else if ("response" in ret)
  {
    ::dagor.debug("Response: " + ret.response)
    local response = ::parse_json(ret.response)
    foreach (idx, table in response)
      cache[table.onlineId] <- table.accountId
  }
}

function g_psn_mapper::onEventContactsGroupUpdate(params)
{
  if (params.groupName == ::EPLX_PS4_FRIENDS)
    ::g_psn_mapper.updateAccountIdsList(true)
}

::g_script_reloader.registerPersistentDataFromRoot("g_psn_mapper")
::subscribe_handler(::g_psn_mapper, ::g_listener_priority.DEFAULT_HANDLER)
