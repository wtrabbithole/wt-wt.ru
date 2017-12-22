local time = require("scripts/time.nut")


enum LIVE_STATS_MODE {
  WATCH
  SPAWN
  FINAL

  TOTAL
}

::g_hud_live_stats <- {
  [PERSISTENT_DATA_PARAMS] = ["spawnStartState"]

  scene     = null
  guiScene  = null
  parentObj = null
  nestObjId = ""

  isSelfTogglable = false
  isInitialized = false
  missionMode = ::GT_VERSUS
  missionObjectives = MISSION_OBJECTIVE.NONE
  isMissionTeamplay = false
  isMissionRace = false
  isMissionLastManStanding = false
  isAwaitingSpawn = false
  spawnStartState = null
  isMissionFinished = false
  gameType = 0

  hero = {
    streaks = []
    units   = []
  }

  curViewPlayerId = null
  curViewMode = LIVE_STATS_MODE.WATCH
  curColumnsOrder = []
  isActive = false
  visState  = null

  columnsOrder = {
    [::GT_VERSUS] = {
      [LIVE_STATS_MODE.SPAWN] = [ "captureZone", "damageZone", "missionAliveTime", "kills", "groundKills", "navalKills",
                                  "aiKills", "aiGroundKills", "aiNavalKills", "aiTotalKills", "assists", "score" ],
      [LIVE_STATS_MODE.FINAL] = [ "captureZone", "damageZone", "missionAliveTime", "kills", "groundKills", "navalKills",
                                  "aiKills", "aiGroundKills", "aiNavalKills", "aiTotalKills", "assists", "deaths", "score" ],
      [LIVE_STATS_MODE.WATCH] = [ "name", "score", "captureZone", "damageZone", "missionAliveTime", "kills", "groundKills", "navalKills",
                                  "aiKills", "aiGroundKills", "aiNavalKills", "aiTotalKills", "assists", "deaths" ],
    },
    [::GT_RACE] = {
      [LIVE_STATS_MODE.SPAWN] = [ "rowNo", "raceFinishTime", "raceBestLapTime" ],
      [LIVE_STATS_MODE.FINAL] = [ "rowNo", "raceFinishTime", "raceBestLapTime", "deaths" ],
      [LIVE_STATS_MODE.WATCH] = [ "rowNo", "name", "raceFinishTime", "raceBestLapTime", "deaths" ],
    },
  }
}

function g_hud_live_stats::init(_parentObj, _nestObjId, _isSelfTogglable)
{
  if (!::has_feature("LiveStats"))
    return
  if (!::checkObj(_parentObj))
    return
  parentObj = _parentObj
  nestObjId = _nestObjId
  guiScene  = parentObj.getScene()

  isSelfTogglable = _isSelfTogglable
  gameType = ::get_game_type()
  missionMode = (gameType & ::GT_RACE) ? ::GT_RACE : ::GT_VERSUS
  isMissionTeamplay = ::is_mode_with_teams(gameType)
  isMissionRace = !!(gameType & ::GT_RACE)
  isMissionFinished = false
  missionObjectives = ::g_mission_type.getCurrentObjectives()
  isMissionLastManStanding = !!(gameType & ::GT_LAST_MAN_STANDING)

  show(false)

  hero = {
    streaks = []
    units   = []
  }

  if (!isInitialized)
  {
    ::add_event_listener("StreakArrived", onEventStreakArrived, this)
    isInitialized = true
  }

  if (isSelfTogglable)
  {
    isAwaitingSpawn = true

    ::g_hud_event_manager.subscribe("MissionResult", function(data) {
      onMissionResult()
    }, this)
    ::g_hud_event_manager.subscribe("LocalPlayerAlive", function (data) {
      checkPlayerSpawned()
    }, this)
    ::g_hud_event_manager.subscribe("LocalPlayerDead", function (data) {
      checkPlayerDead()
    }, this)
  }

  reinit()
}

function g_hud_live_stats::reinit()
{
  local _scene = ::checkObj(parentObj) ? parentObj.findObject(nestObjId) : null
  if (!::checkObj(_scene))
    return

  scene = _scene

  checkPlayerSpawned()
}

function g_hud_live_stats::getState(playerId = null, diffState = null)
{
  local now = ::get_usefull_total_time()
  local isHero = playerId == null
  local player = isHero ? ::get_local_mplayer() : ::get_mplayer_by_id(playerId)

  local state = {
    player    = player || {}
    streaks   = isHero ? (clone hero.streaks) : []
    timestamp = now
    lifetime  = 0.0
  }

  if (isMissionRace)
    state.player["rowNo"] <- getPlayerPlaceInTeam(state.player)

  foreach (id in curColumnsOrder)
    if (!(id in state.player))
      state.player[id] <- ::g_mplayer_param_type.getTypeById(id).getVal(state.player)

  if (diffState)
  {
    local p1 = diffState.player
    local p2 = state.player
    foreach (id in curColumnsOrder)
      if (id in p1)
        p2[id] = ::g_mplayer_param_type.getTypeById(id).diffFunc(p1[id], p2[id])

    if (diffState.streaks.len())
      state.streaks = state.streaks.slice(min(diffState.streaks.len(), state.streaks.len()))

    if (!diffState.lifetime)
      diffState.lifetime = now - diffState.timestamp
    state.lifetime = diffState.lifetime
  }

  return state
}

function g_hud_live_stats::isVisible()
{
  return isSelfTogglable && isActive
}

function g_hud_live_stats::show(activate, viewMode = null, playerId = null)
{
  local isSceneValid = ::check_obj(scene)
  activate = activate && isSceneValid
  local isVisibilityToggle = isSelfTogglable && isActive != activate
  isActive = activate

  if (isSceneValid)
  {
    scene.show(isActive)

    curViewPlayerId = playerId
    curViewMode = (viewMode != null && viewMode >= 0 && viewMode < LIVE_STATS_MODE.TOTAL) ?
      viewMode : LIVE_STATS_MODE.WATCH
    curColumnsOrder = ::getTblValue(curViewMode, ::getTblValue(missionMode, columnsOrder, {}), [])

    local misObjs = missionObjectives
    local gt = gameType
    curColumnsOrder = ::u.filter(curColumnsOrder, @(id) ::g_mplayer_param_type.getTypeById(id).isVisible(misObjs, gt))

    fill()
  }

  if (isVisibilityToggle)
    ::g_hud_event_manager.onHudEvent("LiveStatsVisibilityToggled", { visible = isActive })
}

function g_hud_live_stats::fill()
{
  if (!::checkObj(scene))
    return

  if (!isActive)
  {
    guiScene.replaceContentFromText(scene, "", 0, this)
    return
  }

  local isCompareStates = curViewMode == LIVE_STATS_MODE.SPAWN
  local state = getState(curViewPlayerId, isCompareStates ? spawnStartState : null)

  local title = ""
  if (curViewMode == LIVE_STATS_MODE.WATCH)
    title = ""
  else if (curViewMode == LIVE_STATS_MODE.SPAWN && !isMissionLastManStanding)
  {
    local txtUnitName = ::getUnitName(::getTblValue("aircraftName", state.player, ""))
    local txtLifetime = time.secondsToString(state.lifetime, true)
    title = ::loc("multiplayer/lifetime") + ::loc("ui/parentheses/space", { text = txtUnitName }) + ::loc("ui/colon") + txtLifetime
  }
  else if (curViewMode == LIVE_STATS_MODE.FINAL || isMissionLastManStanding)
  {
    title = isMissionTeamplay ? ::loc("debriefing/placeInMyTeam") :
      (::loc("mainmenu/btnMyPlace") + ::loc("ui/colon"))
    title += ::colorize("userlogColoredText", ::getTblValue("rowNo", state.player, getPlayerPlaceInTeam(state.player)))
  }

  local isHeader = curViewMode == LIVE_STATS_MODE.FINAL

  local view = {
    title = title
    isHeader = isHeader
    player = []
    lifetime = isCompareStates && !isMissionLastManStanding
  }

  foreach (id in curColumnsOrder)
  {
    local param = ::g_mplayer_param_type.getTypeById(id)
    view.player.append({
      id      = id
      fontIcon = param.fontIcon
      label   = param.tooltip
      tooltip = param.tooltip
    })
  }

  if (curViewMode == LIVE_STATS_MODE.FINAL)
  {
    local unitNames = []
    foreach (unitId in hero.units)
      unitNames.append(::getUnitName(unitId))
    view["units"] <- ::loc("mainmenu/btnUnits") + ::loc("ui/colon") +
      ::g_string.implode(unitNames, ::loc("ui/comma"))
  }

  local template = isSelfTogglable ? "gui/hud/hudLiveStats" : "gui/hud/hudLiveStatsSpectator"
  local markup = ::handyman.renderCached(template, view)
  guiScene.replaceContentFromText(scene, markup, markup.len(), this)

  local timerObj = scene.findObject("update_timer")
  if (::checkObj(timerObj))
    timerObj.setUserData(this)

  visState = null
  update(null, 0.0)
}

function g_hud_live_stats::update(obj = null, dt = 0.0)
{
  if (!isActive || !::checkObj(scene))
    return

  local isCompareStates = curViewMode == LIVE_STATS_MODE.SPAWN
  local state = getState(curViewPlayerId, isCompareStates ? spawnStartState : null)

  foreach (id in curColumnsOrder)
  {
    local param = ::g_mplayer_param_type.getTypeById(id)

    local value = ::getTblValue(id, state.player, param.defVal)
    local visValue = visState ? ::getTblValue(id, visState.player, param.defVal) : param.defVal
    if (visValue == value && !param.isForceUpdate)
      continue

    local isValid = value != param.defVal || param.isForceUpdate
    local text = isValid ? param.printFunc(value, state.player) : ""
    local show = text != ""

    local plateObj = scene.findObject("plate_" + id)
    if (::checkObj(plateObj) && plateObj.isVisible() != show)
      plateObj.show(show)

    local txtObj = scene.findObject("txt_" + id)
    if (::checkObj(txtObj) && txtObj.getValue() != text)
      txtObj.setValue(text)
  }

  if (isCompareStates && (!visState || visState.lifetime != state.lifetime) && !isMissionLastManStanding)
  {
    local text = time.secondsToString(state.lifetime, true)
    local obj = scene.findObject("txt_lifetime")
    if (::checkObj(obj) && obj.getValue() != text)
      obj.setValue(text)
  }

  local visStreaksLen = visState ? visState.streaks.len() : 0
  if (state.streaks.len() != visStreaksLen)
  {
    local obj = scene.findObject("hero_streaks")
    if (::checkObj(obj))
    {
      local awardsList = []
      foreach (id in state.streaks)
        awardsList.append({unlockType = ::UNLOCKABLE_STREAK, unlockId = id})
      awardsList = ::combineSimilarAwards(awardsList)

      local view = { awards = [] }
      foreach (award in awardsList)
        view.awards.append({
          iconLayers = ::LayersIcon.getIconData("streak_" + award.unlockId)
          amount = award.amount > 1 ? "x" + award.amount : null
        })
      local markup = ::handyman.renderCached(("gui/statistics/statAwardIcon"), view)
      guiScene.replaceContentFromText(obj, markup, markup.len(), this)
    }
  }

  visState = state
}

function g_hud_live_stats::isValid()
{
  return true
}

function g_hud_live_stats::getPlayerPlaceInTeam(player)
{
  local playerId = ::getTblValue("id", player, -1)
  local teamId = isMissionTeamplay ? ::getTblValue("team", player, ::GET_MPLAYERS_LIST) : ::GET_MPLAYERS_LIST
  local players = ::get_mplayers_list(teamId, true)

  players.sort(::mpstat_get_sort_func(gameType))

  foreach (idx, p in players)
    if (::getTblValue("id", p) == playerId)
      return idx + 1
  return 0
}

function g_hud_live_stats::checkPlayerSpawned()
{
  if (!isAwaitingSpawn)
    return
  local player = ::get_local_mplayer()
  if (player.isDead || player.state != ::PLAYER_IN_FLIGHT)
    return
  local aircraftName = ::getTblValue("aircraftName", player, "")
  if (aircraftName == "" || aircraftName == "dummy_plane")
    return
  isAwaitingSpawn = false
  onPlayerSpawn()
}

function g_hud_live_stats::checkPlayerDead()
{
  if (isAwaitingSpawn)
    return
  if (!hero.units.len())
    return
  if (::get_local_mplayer().isTemporary)
    return
  isAwaitingSpawn = true
  onPlayerDeath()
}

function g_hud_live_stats::onEventStreakArrived(params)
{
  hero.streaks.append(::getTblValue("id", params))
}

function g_hud_live_stats::onMissionResult()
{
  if (!isSelfTogglable || isMissionFinished)
    return
  isMissionFinished = true
  show(true, LIVE_STATS_MODE.FINAL)
}

function g_hud_live_stats::onPlayerSpawn()
{
  if (!isSelfTogglable || isMissionFinished)
    return
  spawnStartState = getState()
  ::u.appendOnce(::getTblValue("aircraftName", spawnStartState.player), hero.units)
  show(false)
}

function g_hud_live_stats::onPlayerDeath()
{
  if (!isSelfTogglable || isMissionFinished)
    return
  show(true, LIVE_STATS_MODE.SPAWN)
}

::g_script_reloader.registerPersistentDataFromRoot("g_hud_live_stats")
