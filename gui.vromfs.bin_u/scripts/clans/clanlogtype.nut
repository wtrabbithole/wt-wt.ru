local enums = ::require("std/enums.nut")
local platformModule = require("modules/platform.nut")

::g_clan_log_type <- {
  types = []
}

::g_clan_log_type_cache <- {
  byName = {}
}

local isSelfLog = @(logEntry) logEntry?.uN == logEntry?.nick
local getColoredNick = @(logEntry)
  ::colorize(
    logEntry.uid == ::my_user_id_str ? "mainPlayerColor" : "userlogColoredText",
    platformModule.getPlayerName(logEntry.nick)
  )

::g_clan_log_type.template <- {
  name = ""
  logDetailsCommonFields = []
  logDetailsIndividualFields = []

  needDetails = @(logEntry) true
  getLogHeader = @(logEntry) ""

  getLogDetailsCommonFields = function()
  {
    local fields = ["admin"]
    fields.extend(logDetailsCommonFields)
    return fields
  }

  getLogDetailsIndividualFields = @() logDetailsIndividualFields

  getSignText = function(logEntry)
  {
    local name = logEntry?.uN
    if (!name)
      return null

    local locId = logEntry?.admin ? "clan/log/initiated_by_admin" : "clan/log/initiated_by"
    local color = logEntry?.uId == ::my_user_id_str ? "mainPlayerColor" : "userlogColoredText"
    return ::loc(locId, { nick = ::colorize(color, platformModule.getPlayerName(name)) })
  }
}

enums.addTypesByGlobalName("g_clan_log_type", {
  CREATE = {
    name = "create"
    logDetailsCommonFields = [
      "name"
      "type"
      "tag"
      "desc"
      "slogan"
      "region"
      "announcement"
    ]
    function getLogHeader(logEntry)
    {
      return ::loc("clan/log/create_log")
    }
  }
  INFO = {
    name = "info"
    logDetailsCommonFields = [
      "name"
      "tag"
      "desc"
      "slogan"
      "region"
      "announcement"
      "status"
    ]
    function getLogHeader(logEntry)
    {
      return ::loc("clan/log/change_info_log")
    }
  }
  UPGRADE = {
    name = "upgrade"
    logDetailsCommonFields = [
      "type"
      "tag"
      "desc"
    ]
    function getLogHeader(logEntry)
    {
      return ::loc("clan/log/upgrade_log")
    }
  }
  ADD = {
    name = "add"
    logDetailsCommonFields = [
      "uid"
      "nick"
      "role"
    ]
    needDetails = @(logEntry) !isSelfLog(logEntry)
    function getLogHeader(logEntry)
    {
      return ::loc("clan/log/add_new_member_log", {nick = getColoredNick(logEntry) })
    }
  }
  REMOVE = {
    name = "rem"
    logDetailsCommonFields = [
      "uid"
      "nick"
    ]
    needDetails = @(logEntry) !isSelfLog(logEntry)
    function getLogHeader(logEntry)
    {
      local locId = isSelfLog(logEntry) ? "clan/log/leave_member_log" :"clan/log/remove_member_log"
      return ::loc(locId, {nick = getColoredNick(logEntry) })
    }
  }
  ROLE = {
    name = "role"
    logDetailsCommonFields = [
      "uid"
      "nick"
    ]
    logDetailsIndividualFields = [
      "old"
    ]
    function getLogHeader(logEntry)
    {
      return ::loc("clan/log/change_role_log",
        { nick = getColoredNick(logEntry), role = ::colorize("@userlogColoredText", ::loc("clan/" + logEntry?.new)) })
    }
  }
  UPGRADE_MEMBERS = {
    name = "upgrade_members"
    logDetailsIndividualFields = [
      "old"
      "new"
    ]
    function getLogHeader(logEntry)
    {
      return ::loc("clan/log/upgrade_members_log", {nick = logEntry.uN})
    }
  }
  UNKNOWN = {}
})

function g_clan_log_type::getTypeByName(name)
{
  return enums.getCachedType("name", name, ::g_clan_log_type_cache.byName,
                                       ::g_clan_log_type, ::g_clan_log_type.UNKNOWN)
}
