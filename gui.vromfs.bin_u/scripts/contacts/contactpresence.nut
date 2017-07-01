::g_contact_presence <- {
  types = []
}


::g_contact_presence.template <- {
  presenceCode = -1
  presenceIcon = ""
  presenceTooltip = ""
  textColor = ""

  function getText() { return ::colorize(textColor, ::loc(presenceTooltip)) }
}


::g_enum_utils.addTypesByGlobalName("g_contact_presence", {
  UNKNOWN = {
    presenceCode = 0
    presenceIcon = "player_unknown"
    presenceTooltip = "status/unknown"
  }

  OFFLINE = {
    presenceCode = 1
    presenceIcon = "player_offline"
    presenceTooltip = "status/offline",
  }

  ONLINE = {
    presenceCode = 2
    presenceIcon = "player_online"
    presenceTooltip = "status/online",
  }

  IN_QUEUE = {
    presenceCode = 3
    presenceIcon = "player_in_queue"
    presenceTooltip = "status/in_queue"
  }

  IN_GAME = {
    presenceCode = 4
    presenceIcon = "player_in_game"
    presenceTooltip = "status/in_game"
  }

  SQUAD_NOT_READY = {
    presenceCode = 5
    presenceIcon = "squad_not_ready"
    presenceTooltip = "status/squad_not_ready"
    textColor = "@userlogColoredText"
  }

  SQUAD_READY = {
    presenceCode = 6
    presenceIcon = "squad_ready"
    presenceTooltip = "status/squad_ready"
    textColor = "@userlogColoredText"
  }

  SQUAD_LEADER = {
    presenceCode = 7
    presenceIcon = "squad_leader"
    presenceTooltip = "status/squad_leader"
    textColor = "@userlogColoredText"
  }
})


function g_contact_presence::getPresenceByCode(code)
{
  return ::g_enum_utils.getCachedType(
    "presenceCode",
    code,
    ::g_contact_presence_cache.byCode,
    ::g_contact_presence,
    ::g_contact_presence.UNKNOWN
  )
}


::g_contact_presence_cache <- {
  byCode = {}
}
