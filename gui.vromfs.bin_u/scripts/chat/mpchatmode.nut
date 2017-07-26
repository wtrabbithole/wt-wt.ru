enum mpChatModeSort {
  TEAM
  SQUAD
  ALL
  PRIVATE
}

::g_mp_chat_mode <- {
  types = []
  cache = {
    byId = {}
  }
}

::g_mp_chat_mode.template <- {
  id = ::CHAT_MODE_ALL
  name = ""
  sortOrder = mpChatModeSort.ALL
  textColor = ""

  getNameText = function() { return ::loc("chat/" + name) }
  getDescText = function() { return ::loc("chat/" + name + "/desc") }
  isEnabled   = function() { return false }
}

::g_enum_utils.addTypesByGlobalName("g_mp_chat_mode", {
  ALL = {
    id = ::CHAT_MODE_ALL
    name = "all"
    sortOrder = mpChatModeSort.ALL
    textColor = "@chatTextAllColor"

    isEnabled = function() { return true }
  }

  TEAM = {
    id = ::CHAT_MODE_TEAM
    name = "team"
    sortOrder = mpChatModeSort.TEAM
    textColor = "@chatTextTeamColor"

    isEnabled = function() { return !::isPlayerDedicatedSpectator() && ::is_mode_with_teams() }
  }

  SQUAD = {
    id = ::CHAT_MODE_SQUAD
    name = "squad"
    sortOrder = mpChatModeSort.SQUAD
    textColor = "@chatTextSquadColor"

    isEnabled = function() { return ::g_squad_manager.isInSquad(true) && !::isPlayerDedicatedSpectator() }
  }

  PRIVATE = { //dosnt work atm, but still exist in enum
    id = ::CHAT_MODE_PRIVATE
    name = "private"
    sortOrder = mpChatModeSort.PRIVATE
    textColor = "@chatTextPrivateColor"

    isEnabled = function() { return false }
  }
})

::g_mp_chat_mode.types.sort(function(a, b) {
  if (a.sortOrder != b.sortOrder)
    return a.sortOrder < b.sortOrder ? -1 : 1
  return 0
})

function g_mp_chat_mode::getModeById(modeId)
{
  return ::g_enum_utils.getCachedType("id", modeId, cache.byId, this, ALL)
}