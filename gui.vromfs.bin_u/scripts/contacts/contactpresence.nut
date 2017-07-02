enum PRESENCE_SORT
{
  UNKNOWN
  OFFLINE
  ONLINE
  IN_QUEUE
  IN_GAME
  SQUAD_OFFLINE
  SQUAD_NOT_READY
  SQUAD_READY
  SQUAD_LEADER
}

::g_contact_presence <- {
  types = []
}


::g_contact_presence.template <- {
  sortOrder = PRESENCE_SORT.UNKNOWN
  iconName = ""
  iconColor = "white"
  presenceTooltip = ""
  textColor = ""
  transparencyPresence = 180

  function getText() { return ::colorize(textColor, ::loc(presenceTooltip)) }
  function getIcon() { return "#ui/gameuiskin#" + iconName }
  function getIconColor() { return ::get_main_gui_scene().getConstantValue(iconColor) || "" }
  function getTransparencyDegree() { return transparencyPresence }
}


::g_enum_utils.addTypesByGlobalName("g_contact_presence", {
  UNKNOWN = {
    sortOrder = PRESENCE_SORT.UNKNOWN
    iconName = "player_unknown"
    iconColor = "contactUnknownColor"
    presenceTooltip = "status/unknown"
  }

  OFFLINE = {
    sortOrder = PRESENCE_SORT.OFFLINE
    iconName = "player_offline"
    iconColor = "contactOfflineColor"
    presenceTooltip = "status/offline"
  }

  ONLINE = {
    sortOrder = PRESENCE_SORT.ONLINE
    iconName = "player_online"
    iconColor = "contactOnlineColor"
    presenceTooltip = "status/online"
  }

  IN_QUEUE = {
    sortOrder = PRESENCE_SORT.IN_QUEUE
    iconName = "player_in_queue"
    presenceTooltip = "status/in_queue"
  }

  IN_GAME = {
    sortOrder = PRESENCE_SORT.IN_GAME
    iconName = "player_in_game"
    presenceTooltip = "status/in_game"
  }

  SQUAD_OFFLINE = {
    sortOrder = PRESENCE_SORT.SQUAD_OFFLINE
    iconName = "squad_not_ready"
    iconColor = "contactOfflineColor"
    presenceTooltip = "status/offline"
  }

  SQUAD_NOT_READY = {
    sortOrder = PRESENCE_SORT.SQUAD_NOT_READY
    iconName = "squad_not_ready"
    presenceTooltip = "status/squad_not_ready"
    textColor = "@userlogColoredText"
  }

  SQUAD_READY = {
    sortOrder = PRESENCE_SORT.SQUAD_READY
    iconName = "squad_ready"
    presenceTooltip = "status/squad_ready"
    textColor = "@userlogColoredText"
  }

  SQUAD_LEADER = {
    sortOrder = PRESENCE_SORT.SQUAD_LEADER
    iconName = "squad_leader"
    presenceTooltip = "status/squad_leader"
    textColor = "@userlogColoredText"
  }
})
