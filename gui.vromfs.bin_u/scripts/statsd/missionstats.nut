MissionStats <- {
  [PERSISTENT_DATA_PARAMS] = ["sendDelaySec", "_spawnTime"]

  sendDelaySec = 30

  _spawnTime = -1
}

function MissionStats::init()
{
  ::subscribe_handler(this)
  reset()
}

function MissionStats::reset()
{
  _spawnTime = -1
}

function MissionStats::onEventRoomJoined(p)
{
  reset()
}

function MissionStats::onEventPlayerSpawn(p)
{
  _spawnTime = ::dagor.getCurTime()
}

function MissionStats::onEventPlayerQuitMission(p)
{
  if (_spawnTime >= 0 && (::dagor.getCurTime() - _spawnTime > 1000 * sendDelaySec))
    return
  if (::get_game_mode() != ::GM_DOMINATION)
    return
  if (!::is_multiplayer())
    return

  statsd_counter("early_session_leave." + ::get_current_mission_name())
}

//!!must be atthe end of the file
::MissionStats.init()
::g_script_reloader.registerPersistentDataFromRoot("MissionStats")