enum MIS_LOAD { //bit enum
  //loading parts
  ECONOMIC_STATE      = 0x0001
  RESPAWN_BASES       = 0x0002

  //parts masks
  RESPAWN_DATA_LOADED = 0x0003
}

  //calls from c++ code.
function on_update_es_from_host()
{
  dagor.debug("on_update_es_from_host called")
  ::reinitAllSlotbars()
  ::broadcastEvent("UpdateEsFromHost")
}

  //calls from c++ code. Signals that something is changed in mission
  // for now it's only state of respawn bases
function on_mission_changed()
{
  ::broadcastEvent("ChangedMissionRespawnBasesStatus")
}

::g_mis_loading_state <- {
  [PERSISTENT_DATA_PARAMS] = ["curState"]

  curState = 0
}

function g_mis_loading_state::isReadyToShowRespawn()
{
  return (curState & MIS_LOAD.RESPAWN_DATA_LOADED) == MIS_LOAD.RESPAWN_DATA_LOADED
}

function g_mis_loading_state::isCrewsListReceived()
{
  return (curState & MIS_LOAD.ECONOMIC_STATE) != 0
}

function g_mis_loading_state::onEventUpdateEsFromHost(p)
{
  if (curState & MIS_LOAD.ECONOMIC_STATE)
    return

  dagor.debug("misLoadState: received initial  economicState")
  curState = curState | MIS_LOAD.ECONOMIC_STATE
  checkRespawnBases()
}

function g_mis_loading_state::onEventLoadingStateChange(p)
{
  if (!::is_in_flight())
  {
    if (curState != 0)
      dagor.debug("misLoadState: reset mision loading state")
    curState = 0
  }
}

function g_mis_loading_state::checkRespawnBases()
{
  if ((curState & MIS_LOAD.RESPAWN_BASES)
      || !(curState & MIS_LOAD.ECONOMIC_STATE))
    return

  local hasRespBases = false
  foreach(crew in ::get_country_crews(::get_local_player_country(), true))
  {
    local unit = ::g_crew.getCrewUnit(crew)
    if (!unit)
      continue

    if (!::get_available_respawn_bases(unit.tags).len())
      continue

    hasRespBases = true
    break
  }

  dagor.debug("misLoadState: check respawn bases. has available? " + hasRespBases)

  if (hasRespBases)
    curState = curState | MIS_LOAD.RESPAWN_BASES
}

function g_mis_loading_state::onEventChangedMissionRespawnBasesStatus(p)
{
  checkRespawnBases()
}

::g_script_reloader.registerPersistentDataFromRoot("g_mis_loading_state")
::subscribe_handler(::g_mis_loading_state ::g_listener_priority.CONFIG_VALIDATION)