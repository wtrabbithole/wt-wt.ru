local enums = ::require("std/enums.nut")
local platformModule = require("scripts/clientState/platform.nut")

::g_clan_log_type <- {
  types = []
}

::g_clan_log_type_cache <- {
  byName = {}
}

function g_clan_log_type::_getLogHeader(logEntry)
{
  return ""
}

function g_clan_log_type::_getLogDetailsCommonFields()
{
  local fields = ["admin"]
  fields.extend(logDetailsCommonFields)
  return fields
}

function g_clan_log_type::_getLogDetailsIndividualFields()
{
  local fields = []
  fields.extend(logDetailsIndividualFields)
  return fields
}

function g_clan_log_type::_getSignText(logEntry)
{
  if (!("uN" in logEntry))
    return null

  if (::getTblValue("admin", logEntry, false))
    return ::loc("clan/log/initiated_by_admin", { nick = logEntry.uN })
  else
    return ::loc("clan/log/initiated_by", { nick = logEntry.uN })
}

::g_clan_log_type.template <- {
  name = ""
  showDetails = true
  logDetailsCommonFields = []
  logDetailsIndividualFields = []
  getLogHeader = ::g_clan_log_type._getLogHeader
  getLogDetailsCommonFields = ::g_clan_log_type._getLogDetailsCommonFields
  getLogDetailsIndividualFields = ::g_clan_log_type._getLogDetailsIndividualFields
  getSignText = ::g_clan_log_type._getSignText
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
    showDetails = false
    function getLogHeader(logEntry)
    {
      return ::loc("clan/log/add_new_member_log", {nick = platformModule.getPlayerName(logEntry.nick)})
    }
  }
  REMOVE = {
    name = "rem"
    showDetails = false
    logDetailsCommonFields = [
      "uid"
      "nick"
    ]
    function getLogHeader(logEntry)
    {
      return ::loc("clan/log/remove_member_log", {nick = platformModule.getPlayerName(logEntry.nick)})
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
      "new"
    ]
    function getLogHeader(logEntry)
    {
      return ::loc("clan/log/change_role_log", {nick = platformModule.getPlayerName(logEntry.nick)})
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
