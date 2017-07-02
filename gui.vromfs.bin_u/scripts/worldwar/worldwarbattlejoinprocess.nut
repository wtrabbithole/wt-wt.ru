class WwBattleJoinProcess
{
  wwBattle = null

  static PROCESS_TIME_OUT = 60000

  static activeJoinProcesses = []   //cant modify staic self
  processStartTime = -1

  constructor (_wwBattle)
  {
    if (!_wwBattle || !_wwBattle.isValid())
      return

    if (activeJoinProcesses.len())
      if (::dagor.getCurTime() - activeJoinProcesses[0].processStartTime < PROCESS_TIME_OUT)
        return ::dagor.assertf(false, "Error: trying to use 2 join world war operation battle processes at once")
      else
        activeJoinProcesses[0].remove()

    activeJoinProcesses.append(this)
    processStartTime = ::dagor.getCurTime()

    wwBattle = _wwBattle
    joinStep1_squad()
  }

  function remove()
  {
    foreach(idx, process in activeJoinProcesses)
      if (process == this)
        activeJoinProcesses.remove(idx)
  }

  function onDone()
  {
    remove()
  }

  function joinStep1_squad()
  {
    if (!::g_squad_utils.canJoinFlightMsgBox(
          {
            isLeaderCanJoin = true,
            showOfflineSquadMembersPopup = true
          }
        )
      )
      return remove()

    joinStep2_external()
  }

  function joinStep2_external()
  {
    if (!::is_loaded_model_high_quality())
    {
      ::check_package_and_ask_download("pkg_main", null, joinStep3_internal, this, "event", remove)
      return
    }

    joinStep3_internal()
  }

  function joinStep3_internal()
  {
    if (wwBattle.isTanksCompatible() && !::check_tanks_available())
      return remove()

    if (::queues.isAnyQueuesActive(QUEUE_TYPE_BIT.WW_BATTLE))
      return remove()

    local availableUnitTypes = wwBattle.getAvailableUnitTypes()
    if (availableUnitTypes.len() > 0)
    {
      local baseGuiHandler = ::get_cur_base_gui_handler()
      foreach(idx, unitType in availableUnitTypes)
        if (baseGuiHandler.checkDiffTutorial(::DIFFICULTY_REALISTIC, unitType))
          return remove()
    }

    ::queues.checkAndStart(
      ::Callback(joinStep4_repairInfo, this),
      ::Callback(remove, this),
      "isCanNewflight"
    )
  }

  function joinStep4_repairInfo()
  {
    local team = wwBattle.getTeamBySide(::ww_get_player_side())
    local remainUnits = wwBattle.getTeamRemainUnits(team)
    local repairInfo = ::getBrokenAirsInfo(
                         [team.country],
                         true,
                         (@(remainUnits) function(airName) {
                           return airName in remainUnits
                         })(remainUnits)
                       )

    ::checkBrokenAirsAndDo(repairInfo, this, joinStep5_paramsForQueue, false, remove)
  }

  function joinStep5_paramsForQueue()
  {
    local params = {
      operationId = ::ww_get_operation_id()
      battleId    = wwBattle.id
      country     = wwBattle.getCountryNameBySide()
      team        = wwBattle.getTeamNameBySide()
      clusters    = ::get_current_clusters()
    }

    ::queues.joinQueue(params)
    onDone()
  }
}
