enum BATTLE_LOG_FILTER
{
  HERO      = 0x0001
  SQUADMATE = 0x0002
  ALLY      = 0x0004
  ENEMY     = 0x0008
  OTHER     = 0x0010

  SQUAD     = 0x0003
  ALL       = 0x001F
}

enum UNIT_TYPE
{
  AIRCRAFT
  TANK
  SHIP
}

::HudBattleLog <- {
  [PERSISTENT_DATA_PARAMS] = ["battleLog", "unitTypesCache"]

  battleLog = []
  unitTypesCache = {}

  logMaxLen = 2000
  skipDuplicatesSec = 10

  supportedMsgTypes = [
    ::HUD_MSG_MULTIPLAYER_DMG
    ::HUD_MSG_STREAK
  ]

  unitTypeSuffix = {
    [UNIT_TYPE.AIRCRAFT] = "_a",
    [UNIT_TYPE.TANK]     = "_t",
    [UNIT_TYPE.SHIP]     = "_s",
  }

  actionVerbs = {
    kill = {
      [UNIT_TYPE.AIRCRAFT] = "NET_UNIT_KILLED_FM",
      [UNIT_TYPE.TANK]     = "NET_UNIT_KILLED_GM",
      [UNIT_TYPE.SHIP]     = "NET_UNIT_KILLED_GM",
    }
    crash = {
      [UNIT_TYPE.AIRCRAFT] = "NET_PLAYER_HAS_CRASHED",
      [UNIT_TYPE.TANK]     = "NET_PLAYER_GM_HAS_DESTROYED",
      [UNIT_TYPE.SHIP]     = "NET_PLAYER_GM_HAS_DESTROYED",
    }
    crit = {
      [UNIT_TYPE.AIRCRAFT] = "NET_UNIT_CRITICAL_HIT",
      [UNIT_TYPE.TANK]     = "NET_UNIT_CRITICAL_HIT",
      [UNIT_TYPE.SHIP]     = "NET_UNIT_CRITICAL_HIT",
    }
    burn = {
      [UNIT_TYPE.AIRCRAFT] = "NET_UNIT_CRITICAL_HIT_BURN",
      [UNIT_TYPE.TANK]     = "NET_UNIT_CRITICAL_HIT_BURN",
      [UNIT_TYPE.SHIP]     = "NET_UNIT_CRITICAL_HIT_BURN",
    }
  }

  playerUnitTypes = {
    [::ES_UNIT_TYPE_AIRCRAFT] = UNIT_TYPE.AIRCRAFT,
    [::ES_UNIT_TYPE_TANK]     = UNIT_TYPE.TANK,
  }

  aiUnitTypes = {
    warShip         = UNIT_TYPE.SHIP
    fortification   = UNIT_TYPE.TANK
    heavyVehicle    = UNIT_TYPE.TANK
    lightVehicle    = UNIT_TYPE.TANK
    infantry        = UNIT_TYPE.TANK
    radar           = UNIT_TYPE.TANK
    walker          = UNIT_TYPE.TANK
    barrageBalloon  = UNIT_TYPE.AIRCRAFT
  }

  aiUnitBlkPaths = [
    "ships"
    "air_defence"
    "structures"
    "tankModels"
    "tracked_vehicles"
    "wheeled_vehicles"
    "infantry"
    "radars"
    "walkerVehicle"
  ]

  rePatternNumeric = ::regexp2("^\\d+$")

  // http://en.wikipedia.org/wiki/ANSI_escape_code#Colors
  escapeCodeToCssColor = [
    null                  //  0   ECT_BLACK
    "hudColorDarkRed"     //  1   ECT_DARK_RED        HC_DARK_RED
    null                  //  2   ECT_DARK_GREEN
    null                  //  3   ECT_DARK_YELLOW
    "hudColorDarkBlue"    //  4   ECT_DARK_BLUE       HC_DARK_BLUE
    null                  //  5   ECT_DARK_MAGENTA
    null                  //  6   ECT_DARK_CYAN
    null                  //  7   ECT_GREY
    null                  //  8   ECT_DARK_GREY
    "hudColorRed"         //  9   ECT_RED             HC_RED
    "hudColorSquad"       // 10   ECT_GREEN           HC_SQUAD
    "hudColorHero"        // 11   ECT_YELLOW          HC_HERO
    "hudColorBlue"        // 12   ECT_BLUE            HC_BLUE
    null                  // 13   ECT_MAGENTA
    null                  // 14   ECT_CYAN
    null                  // 15   ECT_WHITE
    "hudColorDeathAlly"   // 16   ECT_LIGHT_RED       HC_DEATH_ALLY
    null                  // 17   ECT_LIGHT_GREEN
    null                  // 18   ECT_LIGHT_YELLOW
    "hudColorDeathEnemy"  // 19   ECT_LIGHT_BLUE      HC_DEATH_ENEMY
    null                  // 20   ECT_LIGHT_MAGENTA
    null                  // 21   ECT_LIGHT_CYAN
  ]

  function init()
  {
    reset(true)

    ::g_hud_event_manager.subscribe("HudMessage", function(msg)
      {
        onHudMessage(msg)
      }, this)
  }

  function reset(safe = false)
  {
    if (safe && battleLog.len() && battleLog[battleLog.len() - 1].time < ::get_usefull_total_time())
      return
    battleLog = []
    unitTypesCache = {}
  }

  function onHudMessage(msg)
  {
    if (!::isInArray(msg.type, supportedMsgTypes))
      return

    if (!("id" in msg))
      msg.id <- -1
    if (!("text" in msg))
      msg.text <- ""

    local now = ::get_usefull_total_time()
    if (msg.id != -1)
      foreach (data in battleLog)
        if (data.msg.id == msg.id)
          return
    if (msg.id == -1 && msg.text != "")
    {
      local skipDupTime = now - skipDuplicatesSec
      for (local i = battleLog.len() - 1; i >= 0; i--)
      {
        if (battleLog[i].time < skipDupTime)
          break
        if (battleLog[i].msg.text == msg.text)
          return
      }
    }

    local filters = 0
    if (msg.type == ::HUD_MSG_MULTIPLAYER_DMG)
    {
      local p1 = ::get_mplayer_by_id(msg.playerId)
      local p2 = ::get_mplayer_by_id(msg.victimPlayerId)
      local t1Friendly = ::is_team_friendly(msg.team)
      local t2Friendly = ::is_team_friendly(msg.victimTeam)

      if (p1 && p1.isLocal || p2 && p2.isLocal)
        filters = filters | BATTLE_LOG_FILTER.HERO
      if (p1 && p1.isInHeroSquad || p2 && p2.isInHeroSquad)
        filters = filters | BATTLE_LOG_FILTER.SQUADMATE
      if (t1Friendly || t2Friendly)
        filters = filters | BATTLE_LOG_FILTER.ALLY
      if (!t1Friendly || !t2Friendly)
        filters = filters | BATTLE_LOG_FILTER.ENEMY
      if (filters == 0)
        filters = filters | BATTLE_LOG_FILTER.OTHER
    }
    else
    {
      if (msg.text.find("\x1B011") != null)
        filters = filters | BATTLE_LOG_FILTER.HERO
      if (msg.text.find("\x1B010") != null)
        filters = filters | BATTLE_LOG_FILTER.SQUADMATE
      if (msg.text.find("\x1B012") != null)
        filters = filters | BATTLE_LOG_FILTER.ALLY
      if (msg.text.find("\x1B009") != null)
        filters = filters | BATTLE_LOG_FILTER.ENEMY
      if (filters == 0)
        filters = filters | BATTLE_LOG_FILTER.OTHER
    }

    local timestamp = ::secondsToString(now, false) + " "
    local message = ""
    switch (msg.type)
    {
      // All players messages
      case ::HUD_MSG_MULTIPLAYER_DMG: // Any player unit damaged or destroyed
        local text = msgMultiplayerDmgToText(msg)
        message = timestamp + ::colorize("userlogColoredText", text)
        break
      case ::HUD_MSG_STREAK: // Any player got streak
        local text = msgEscapeCodesToCssColors(msg.text)
        message = timestamp + ::colorize("streakTextColor", ::loc("unlocks/streak") + ::loc("ui/colon") + text)
        break
      default:
        return
    }

    local data = {
      msg = msg
      time = now
      message = message
      filters = filters
    }

    if (battleLog.len() == logMaxLen)
      battleLog.remove(0)
    battleLog.append(data)
    ::broadcastEvent("BattleLogMessage", data)
  }

  function getFilters()
  {
    return [
      { id = BATTLE_LOG_FILTER.ALL,   title = "chat/all" },
      { id = BATTLE_LOG_FILTER.SQUAD, title = "chat/squad" },
      { id = BATTLE_LOG_FILTER.HERO,  title = "debriefing/battle_log/filter/local_player" },
    ]
  }

  function getLength()
  {
    return battleLog.len()
  }

  function getText(filter = BATTLE_LOG_FILTER.ALL, limit = 0)
  {
    filter = filter || BATTLE_LOG_FILTER.ALL
    local lines = []
    for (local i = battleLog.len() - 1; i >= 0 ; i--)
      if (battleLog[i].filters & filter)
      {
        lines.insert(0, battleLog[i].message)
        if (limit && lines.len() == limit)
          break
      }
    return ::implode(lines, "\n")
  }

  function getUnitNameEx(playerId, unitNameLoc = "", teamId = 0)
  {
    local player = ::get_mplayer_by_id(playerId)
    return player ? ::build_mplayer_name(player, true, true, true, unitNameLoc) : // Player
      ::colorize(::get_team_color(teamId), unitNameLoc) // AI
  }

  function getAiUnitBlk(unitId)
  {
    if (unitId == "")
      return ::DataBlock()

    local fn = ::get_unit_file_name(unitId)
    local blk = ::DataBlock(fn)
    if (!::u.isEqual(blk, ::DataBlock()))
      return blk

    foreach (path in aiUnitBlkPaths)
    {
      blk = ::DataBlock(::format("gameData/units/%s/%s.blk", path, unitId))
      if (!::u.isEqual(blk, ::DataBlock()))
        return blk
    }

    return ::DataBlock()
  }

  function getUnitTypeEx(unitId, isPlayer = true)
  {
    if (unitId == "")
      return UNIT_TYPE.TANK

    local unit = isPlayer ? ::getAircraftByName(unitId) : null
    if (unit)
      return ::isTank(unit) ? UNIT_TYPE.TANK : ::isShip(unit) ? UNIT_TYPE.SHIP : UNIT_TYPE.AIRCRAFT

    if (!(unitId in unitTypesCache))
    {
      local blk = getAiUnitBlk(unitId)
      local unitType = blk.subclass ? ::getTblValue(blk.subclass, aiUnitTypes, null) : null

      if (unitType == null)
        foreach (utype in blk % "type")
        {
          local unitClass = ::getTblValue(utype, ::unlock_condition_unitclasses, ::ES_UNIT_TYPE_INVALID)
          if (unitClass != ::ES_UNIT_TYPE_INVALID)
          {
            unitType = ::getTblValue(unitClass, playerUnitTypes)
            break
          }
        }

      if (unitType == null)
      {
        unitType = UNIT_TYPE.TANK
        dagor.debug("ERROR: HudBattleLog.getUnitTypeEx() detection failed: " + unitType)
      }
      unitTypesCache[unitId] <- unitType
    }

    return unitTypesCache[unitId]
  }

  function getActionTextIconic(msg)
  {
    local iconId = msg.action
    if (msg.action == "kill")
      iconId += unitTypeSuffix[getUnitTypeEx(msg.unitName, msg.playerId > 0)]
    if (msg.action == "kill" || msg.action == "crash")
      iconId += unitTypeSuffix[getUnitTypeEx(msg.victimUnitName, msg.victimPlayerId > 0)]
    local actionColor = msg.isKill ? "userlogColoredText" : "silver"
    return ::colorize(actionColor, ::loc("icon/hud_msg_mp_dmg/" + iconId))
  }

  function getActionTextVerbal(msg)
  {
    local victimUnitType = getUnitTypeEx(msg.victimUnitName, msg.victimPlayerId > 0)
    local verb = ::getTblValue(victimUnitType, ::getTblValue(msg.action, actionVerbs, {}), msg.action)
    local isLoss = msg.victimTeam == ::get_player_army_for_hud()
    local color = "hudColor" + (msg.isKill ? (isLoss ? "DeathAlly" : "DeathEnemy") : (isLoss ? "DarkRed" : "DarkBlue"))
    return ::colorize(color, ::loc(verb))
  }

  function msgMultiplayerDmgToText(msg, iconic = false)
  {
    local what = iconic ? getActionTextIconic(msg) : getActionTextVerbal(msg)
    local who  = getUnitNameEx(msg.playerId, msg.unitNameLoc, msg.team)
    local whom = getUnitNameEx(msg.victimPlayerId, msg.victimUnitNameLoc, msg.victimTeam)

    local isCrash = msg.action == "crash"
    local sequence = isCrash ? [whom, what] : [who, what, whom]
    return ::implode(sequence, " ")
  }

  function msgEscapeCodesToCssColors(sequence)
  {
    local ret = ""
    foreach (w in split(sequence, "\x1B"))
    {
      if (w.len() >= 3 && rePatternNumeric.match(w.slice(0, 3)))
      {
        local color = ::getTblValue(w.slice(0,3).tointeger(), escapeCodeToCssColor)
        w = w.slice(3)
        ret += color ? ::colorize(color, w) : w
      }
      else
        ret += w
    }
    return ret
  }
}

::g_script_reloader.registerPersistentDataFromRoot("HudBattleLog")