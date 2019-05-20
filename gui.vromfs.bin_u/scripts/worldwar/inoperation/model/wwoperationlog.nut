enum WW_LOG_CATEGORIES
{
  SYSTEM
  EXISTING_BATTLES
  FINISHED_BATTLES
  ARMY_ACTIVITY
  ZONE_CAPTURE
}

enum WW_LOG_ICONS
{
  SYSTEM = "icon_type_log_systems"
  EXISTING_BATTLES = "icon_type_log_battles"
  FINISHED_BATTLES = "icon_type_log_battles"
  ARMY_ACTIVITY = "icon_type_log_army"
  ZONE_CAPTURE = "icon_type_log_sectors"
}

enum WW_LOG_COLORS
{
  NEUTRAL_EVENT = "@commonTextColor"
  GOOD_EVENT = "@wwTeamAllyColor"
  BAD_EVENT = "@wwTeamEnemyColor"
  SYSTEM = "@operationLogSystemMessage"
  EXISTING_BATTLES = "@operationLogBattleInProgress"
  FINISHED_BATTLES = "@operationLogBattleCompleted"
  ARMY_ACTIVITY = "@operationLogArmyInfo"
  ZONE_CAPTURE = "@operationLogBattleCompleted"
}

enum WW_LOG_TYPES
{
  UNKNOWN = "UNKNOWN"
  OPERATION_CREATED = "operation_created"
  OPERATION_STARTED = "operation_started"
  OBJECTIVE_COMPLETED = "objective_completed"
  OPERATION_FINISHED = "operation_finished"
  BATTLE_STARTED = "battle_started"
  BATTLE_FINISHED = "battle_finished"
  BATTLE_JOIN = "battle_join"
  ZONE_CAPTURED = "zone_captured"
  ARMY_RETREAT = "army_retreat"
  ARMY_DIED = "army_died"
  ARMY_FLYOUT = "army_flyout"
  ARMY_LAND_ON_AIRFIELD = "army_landOnAirfield"
  ARTILLERY_STRIKE_DAMAGE = "artillery_strike_damage"
  REINFORCEMENT = "reinforcement"
}

enum WW_LOG_BATTLE
{
  DEFAULT_ARMY_INDEX = 0
  MIN_ARMIES_PER_SIDE = 1
  MAX_ARMIES_PER_SIDE = 2
  MAX_DAMAGED_ARMIES = 5
}

const WW_LOG_REQUEST_DELAY = 1
const WW_LOG_MAX_LOAD_AMOUNT = 20
const WW_LOG_EVENT_LOAD_AMOUNT = 10
const WW_LOG_MAX_DISPLAY_AMOUNT = 40

::g_ww_logs <- {
  loaded = []
  filter = [ true, true, true, true, true ]
  filtered = []
  logsBattles = {}
  logsArmies = {}
  logsViews = {}
  lastMark = ""
  viewIndex = 0
  lastReadLogMark = ""
  objectivesStaticBlk = null

  logCategories = [
    {
      value = WW_LOG_CATEGORIES.SYSTEM
      selected = false
      show = true
      text = ::loc("worldwar/log/filter/show_system_message")
      icon = "#ui/gameuiskin#" + WW_LOG_ICONS.SYSTEM
      color = WW_LOG_COLORS.SYSTEM
      size = "veryTiny"
    },
    {
      value = WW_LOG_CATEGORIES.EXISTING_BATTLES
      selected = false
      show = true
      text = ::loc("worldwar/log/filter/show_existing_battles")
      icon = "#ui/gameuiskin#" + WW_LOG_ICONS.EXISTING_BATTLES
      color = WW_LOG_COLORS.EXISTING_BATTLES
      size = "veryTiny"
    },
    {
      value = WW_LOG_CATEGORIES.FINISHED_BATTLES
      selected = false
      show = true
      text = ::loc("worldwar/log/filter/show_finished_battles")
      icon = "#ui/gameuiskin#" + WW_LOG_ICONS.EXISTING_BATTLES
      color = WW_LOG_COLORS.FINISHED_BATTLES
      size = "veryTiny"
    },
    {
      value = WW_LOG_CATEGORIES.ARMY_ACTIVITY
      selected = false
      show = true
      text = ::loc("worldwar/log/filter/show_army_activity")
      icon = "#ui/gameuiskin#" + WW_LOG_ICONS.ARMY_ACTIVITY
      color = WW_LOG_COLORS.ARMY_ACTIVITY
      size = "veryTiny"
    },
    {
      value = WW_LOG_CATEGORIES.ZONE_CAPTURE
      selected = false
      show = true
      text = ::loc("worldwar/log/filter/show_zone_capture")
      icon = "#ui/gameuiskin#" + WW_LOG_ICONS.ZONE_CAPTURE
      color = WW_LOG_COLORS.ZONE_CAPTURE
      size = "veryTiny"
    }
  ]
}

function g_ww_logs::getObjectivesBlk()
{
  local objectivesBlk = ::g_world_war.getOperationObjectives()
  return objectivesBlk ? ::u.copy(objectivesBlk.data) : ::DataBlock()
}

function g_ww_logs::requestNewLogs(loadAmount, useLogMark, handler = null)
{
  if (useLogMark && !::g_ww_logs.lastMark)
    return

  ::g_ww_logs.changeLogsLoadStatus(true)
  local cb = ::Callback(function() {
    getNewLogs(useLogMark, handler)
    changeLogsLoadStatus()
  }, this)
  local errorCb = ::Callback(changeLogsLoadStatus, this)
  ::g_world_war.requestLogs(loadAmount, useLogMark, cb, errorCb)
}

function g_ww_logs::changeLogsLoadStatus(isLogsLoading = false)
{
  ::ww_event("LogsLoadStatusChanged", {isLogsLoading = isLogsLoading})
}

function g_ww_logs::getNewLogs(useLogMark, handler)
{
  local logsBlk = ::ww_operation_get_log()
  if (useLogMark)
    ::g_ww_logs.lastMark = logsBlk.lastMark

  saveLoadedLogs(logsBlk, useLogMark, handler)
}

function g_ww_logs::saveLoadedLogs(loadedLogsBlk, useLogMark, handler)
{
  if (!objectivesStaticBlk)
    objectivesStaticBlk = getObjectivesBlk()

  ::ww_event("NewLogsLoaded")

  local addedLogsNumber = 0
  if (!loadedLogsBlk)
    return

  local freshLogs = []
  local firstLogId = ::g_ww_logs.loaded.len() ?
    ::g_ww_logs.loaded[::g_ww_logs.loaded.len() - 1].id : ""

  local isStrengthUpdateNeeded = false
  local isToBattleUpdateNeeded = false
  local unknownLogType = ::g_ww_log_type.getLogTypeByName(WW_LOG_TYPES.UNKNOWN)
  for (local i = 0; i < loadedLogsBlk.blockCount(); i++)
  {
    local logBlk = loadedLogsBlk.getBlock(i)

    if (!useLogMark && logBlk.thisLogId == firstLogId)
      break

    local logType = ::g_ww_log_type.getLogTypeByName(logBlk.type)
    if (logType == unknownLogType)
      continue

    local logTable = {
      id = logBlk.thisLogId
      blk = ::u.copy(logBlk)
      time = logBlk.time
      category = logType.category
      isReaded = false
    }

    ::g_ww_logs.saveLogBattle(logTable.blk)
    ::g_ww_logs.saveLogArmies(logTable.blk, logTable.id)
    ::g_ww_logs.saveLogView(logTable)

    // on some fresh logs - we need to play sound or update strength
    if (!useLogMark)
    {
      isStrengthUpdateNeeded = logBlk.type == WW_LOG_TYPES.ARTILLERY_STRIKE_DAMAGE ||
                               logBlk.type == WW_LOG_TYPES.BATTLE_FINISHED ||
                               logBlk.type == WW_LOG_TYPES.REINFORCEMENT ||
                               isStrengthUpdateNeeded
      isToBattleUpdateNeeded = logBlk.type == WW_LOG_TYPES.OPERATION_CREATED ||
                               logBlk.type == WW_LOG_TYPES.OPERATION_FINISHED ||
                               logBlk.type == WW_LOG_TYPES.BATTLE_STARTED ||
                               logBlk.type == WW_LOG_TYPES.BATTLE_FINISHED ||
                               isToBattleUpdateNeeded
      playLogSound(logBlk)
    }

    addedLogsNumber++
    if (useLogMark)
      ::g_ww_logs.loaded.insert(0, logTable)
    else
      freshLogs.insert(0, logTable)
  }
  if (!useLogMark)
    ::g_ww_logs.loaded.extend(freshLogs)

  if (!addedLogsNumber)
  {
    ::ww_event("NoLogsAdded")
    return
  }

  local isLastReadedLogFounded = false
  for (local i = ::g_ww_logs.loaded.len() - 1; i >= 0; i--)
  {
    if (::g_ww_logs.loaded[i].isReaded)
      break

    if (!isLastReadedLogFounded && ::g_ww_logs.loaded[i].id == lastReadLogMark)
      isLastReadedLogFounded = true

    if (isLastReadedLogFounded)
      ::g_ww_logs.loaded[i].isReaded = true
  }

  applyLogsFilter()
  ::ww_event("NewLogsAdded", {
    isLogMarkUsed = useLogMark
    isStrengthUpdateNeeded = isStrengthUpdateNeeded
    isToBattleUpdateNeeded = isToBattleUpdateNeeded })
  ::ww_event("NewLogsDisplayed", { amount = getUnreadedNumber() })
}

function g_ww_logs::saveLogView(log)
{
  if (!(log.id in logsViews))
    logsViews[log.id] <- ::WwOperationLogView(log)
}

function g_ww_logs::saveLogBattle(blk)
{
  if (!blk.battle)
    return
  local savedData = ::getTblValue(blk.battle.id, logsBattles)
  if (savedData && savedData.time >= blk.time)
    return

  logsBattles[blk.battle.id] <- {
    battle = ::WwBattle(blk.battle)
    time = blk.time
    logBlk = blk
  }
}

function g_ww_logs::saveLogArmies(blk, logId)
{
  if ("armies" in blk)
    foreach (armyBlk in blk.armies)
    {
      local armyId = getLogArmyId(logId, armyBlk.name)
      if (!(armyId in logsArmies))
        logsArmies[armyId] <- ::WwArmy(armyBlk.name, armyBlk)
    }
}

function g_ww_logs::getLogArmyId(logId, armyName)
{
  return "log_" + logId + "_" + armyName
}

function g_ww_logs::saveLastReadLogMark()
{
  lastReadLogMark = getLastReadLogMark()
  ::saveLocalByAccount(::g_world_war.getSaveOperationLogId(), lastReadLogMark)
}

function g_ww_logs::getLastReadLogMark()
{
  return ::u.search(::g_ww_logs.loaded, @(l) l.isReaded, true)?.id ?? ""
}

function g_ww_logs::getUnreadedNumber()
{
  local unreadedNumber = 0
  foreach (log in loaded)
    if (!log.isReaded)
      unreadedNumber ++

  return unreadedNumber
}

function g_ww_logs::applyLogsFilter()
{
  filtered.clear()
  for (local i = 0; i < loaded.len(); i++)
    if (filter[loaded[i].category])
      filtered.append(i)
}

function g_ww_logs::playLogSound(logBlk)
{
  switch (logBlk.type)
  {
    case WW_LOG_TYPES.ARTILLERY_STRIKE_DAMAGE:
      local wwArmy = getLogArmy(logBlk)
      if (wwArmy && !wwArmy.isMySide(::ww_get_player_side()))
        ::play_gui_sound("ww_artillery_enemy")
      break

    case WW_LOG_TYPES.ARMY_FLYOUT:
      local wwArmy = getLogArmy(logBlk)
      if (wwArmy && !wwArmy.isMySide(::ww_get_player_side()))
        ::play_gui_sound("ww_enemy_airplane_incoming")
      break

    case WW_LOG_TYPES.BATTLE_STARTED:
      ::play_gui_sound("ww_battle_start")
      break

    case WW_LOG_TYPES.BATTLE_FINISHED:
      ::play_gui_sound(isPlayerWinner(logBlk) ?
        "ww_battle_end_win" : "ww_battle_end_fail")
      break
  }
}

function g_ww_logs::isPlayerWinner(logBlk)
{
  local mySideName = ::ww_side_val_to_name(::ww_get_player_side())
  if (logBlk.type == WW_LOG_TYPES.BATTLE_FINISHED)
    for (local i = 0; i < logBlk.battle.teams.blockCount(); i++)
      if (logBlk.battle.teams.getBlock(i).side == mySideName)
        return logBlk.battle.teams.getBlock(i).isWinner

  return logBlk.winner == mySideName
}

function g_ww_logs::getLogArmy(logBlk)
{
  local wwArmyId = getLogArmyId(logBlk.thisLogId, logBlk.army)
  return ::getTblValue(wwArmyId, logsArmies)
}

function g_ww_logs::clear()
{
  saveLastReadLogMark()
  loaded.clear()
  filtered.clear()
  logsBattles.clear()
  logsArmies.clear()
  logsViews.clear()
  lastMark = ""
  viewIndex = 0
  objectivesStaticBlk = null
}
