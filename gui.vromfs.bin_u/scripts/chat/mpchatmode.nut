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


function g_mp_chat_mode::getModeNameText(modeId)
{
  return getModeById(modeId).getNameText()
}


// To pass color name to daRg.
// daRg can't use text color constants
function g_mp_chat_mode::getModeColorName(modeId)
{
  local colorName = getModeById(modeId).textColor
  if (colorName.len())
    colorName = colorName.slice(1) //slice '@'
  return colorName
}


function g_mp_chat_mode::getNextMode(modeId)
{
  local isCurFound = false
  local newMode = null
  foreach(mode in types)
  {
    if (modeId == mode.id)
    {
      isCurFound = true
      continue
    }

    if (!mode.isEnabled())
      continue

    if (isCurFound)
      return mode.id
    if (newMode == null)
      newMode = mode.id
  }

  return newMode
}


::cross_call_api.mp_chat_mode <- ::g_mp_chat_mode
