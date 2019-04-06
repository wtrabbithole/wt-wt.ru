local stdMath = require("std/math.nut")

class EventJoinProcess
{
  event = null // Event to join.
  room = null
  onComplete = null
  cancelFunc = null

  static PROCESS_TIME_OUT = 60000

  static activeEventJoinProcess = []   //cant modify staic self
  processStartTime = -1

  constructor (_event, _room = null, _onComplete = null, _cancelFunc = null)
  {
    if (!_event)
      return

    if (activeEventJoinProcess.len())
      if (::dagor.getCurTime() - activeEventJoinProcess[0].processStartTime < PROCESS_TIME_OUT)
        return ::dagor.assertf(false, "Error: trying to use 2 join event processes at once")
      else
        activeEventJoinProcess[0].remove()

    activeEventJoinProcess.append(this)
    processStartTime = ::dagor.getCurTime()

    event = _event
    room = _room
    onComplete = _onComplete
    cancelFunc = _cancelFunc
    joinStep1_squadMember()
  }

  function remove(needCancelFunc = true)
  {
    foreach(idx, process in activeEventJoinProcess)
      if (process == this)
        activeEventJoinProcess.remove(idx)

    if (needCancelFunc && cancelFunc != null)
      cancelFunc()
  }

  function onDone()
  {
    if (onComplete != null)
      onComplete(event)
    remove(false)
  }

  function joinStep1_squadMember()
  {
    if (::g_squad_manager.isSquadMember())
    {
      //Don't allow to change ready status, leader don't know about members balance
      if (!::events.haveEventAccessByCost(event))
        ::showInfoMsgBox(::loc("events/notEnoughMoney"))
      else if (::events.eventRequiresTicket(event) && ::events.getEventActiveTicket(event) == null)
        ::events.checkAndBuyTicket(event)
      else
        ::g_squad_manager.setReadyFlag()
      return remove()
    }
    // Same as checkedNewFlight in gui_handlers.BaseGuiHandlerWT.
    ::queues.checkAndStart(
                    ::Callback(joinStep2_external, this),
                    ::Callback(remove, this),
                    "isCanNewflight"
                    { isSilentLeaveQueue = !!room }
                   )
  }

  function joinStep2_external()
  {
    if (::events.getEventDiffCode(event) == ::DIFFICULTY_HARDCORE &&
        !::check_package_and_ask_download("pkg_main"))
      return remove()

    if (!::events.checkEventFeature(event))
      return remove()

    if (!::events.isEventAllowedByComaptibilityMode(event))
    {
      ::showInfoMsgBox(::loc("events/noCompatibilityMode/msg"))
      remove()
      return
    }

    if (!::g_squad_utils.isEventAllowedForAllMembers(::events.getEventEconomicName(event)))
      return remove()

    if (!::events.checkEventFeaturePacks(event))
      return remove()

    if (!::is_loaded_model_high_quality())
    {
      ::check_package_and_ask_download("pkg_main", null, joinStep3_internal, this, "event", remove)
      return
    }

    joinStep3_internal()
  }

  function joinStep3_internal()
  {
    local mGameMode = ::events.getMGameMode(event, room)
    if (::events.isEventTanksCompatible(event.name) && !::check_tanks_available())
      return remove()
    if (::queues.isAnyQueuesActive(QUEUE_TYPE_BIT.EVENT) ||
        !::g_squad_utils.canJoinFlightMsgBox({ isLeaderCanJoin = true, showOfflineSquadMembersPopup = true }))
      return remove()
    if (::events.checkEventDisableSquads(this, event.name))
      return remove()
    if (!checkEventTeamSize(mGameMode))
      return remove()
    local diffCode = ::events.getEventDiffCode(event)
    local unitTypeMask = ::events.getEventUnitTypesMask(event)
    local checkTutorUnitType = (stdMath.number_of_set_bits(unitTypeMask)==1) ? stdMath.number_of_set_bits(unitTypeMask - 1) : null
    if(checkDiffTutorial(diffCode, checkTutorUnitType))
      return remove()

    joinStep4_cantJoinReason()
  }

  function joinStep4_cantJoinReason()
  {
    local reasonData = ::events.getCantJoinReasonData(event, room,
                          { continueFunc = function() { if (this) joinStep5_repairInfo() }.bindenv(this)
                            isFullText = true
                          })
    if (reasonData.checkStatus)
      return joinStep5_repairInfo()

    reasonData.actionFunc(reasonData)
    remove()
  }

  function joinStep5_repairInfo()
  {
    local repairInfo = ::events.getCountryRepairInfo(event, room, ::get_profile_country_sq())
    ::checkBrokenAirsAndDo(repairInfo, this, joinStep6_membersForQueue, false, remove)
  }

  function joinStep6_membersForQueue()
  {
    ::events.checkMembersForQueue(event, room,
      ::Callback(@(membersData) joinStep7_joinQueue(membersData), this),
      ::Callback(remove, this)
    )
  }

  function joinStep7_joinQueue(membersData = null)
  {
    //join room
    if (room)
      ::SessionLobby.joinRoom(room.roomId)
    else
    {
      local joinEventParams = {
        mode    = event.name
        //team    = team //!!can choose team correct only with multiEvents support
        country = ::get_profile_country_sq()
      }
      if (membersData)
        joinEventParams.members <- membersData
      ::queues.joinQueue(joinEventParams)
    }

    onDone()
  }

  //
  // Helpers
  //

  function checkEventTeamSize(event)
  {
    local squadSize = ::g_squad_manager.getSquadSize()
    local maxTeamSize = ::events.getMaxTeamSize(event)
    if (squadSize > maxTeamSize)
    {
      local locParams = {
        squadSize = squadSize.tostring()
        maxTeamSize = maxTeamSize.tostring()
      }
      msgBox("squad_is_too_big", ::loc("events/squad_is_too_big", locParams),
        [["ok", function() {}]], "ok")
      return false
    }
    return true
  }

  function checkDiffTutorial(diff, unitType, needMsgBox = true, cancelFunc = null)
  {
    if (!::check_diff_pkg(diff, !needMsgBox))
      return true
    if (!::is_need_check_tutorial(diff))
      return false
    if (::g_squad_manager.isNotAloneOnline())
      return false

    if (::isDiffUnlocked(diff, unitType))
      return false

    local reqName = ::get_req_tutorial(unitType)
    local mData = ::get_uncompleted_tutorial_data(reqName, diff)
    if (!mData)
      return false

    local msgText = ::loc((diff==2)? "msgbox/req_tutorial_for_real" : "msgbox/req_tutorial_for_hist")
    msgText += "\n\n" + format(::loc("msgbox/req_tutorial_for_mode"), ::loc("difficulty" + diff))

    msgText += "\n<color=@userlogColoredText>" + ::loc("missions/" + mData.mission.name) + "</color>"

    if(needMsgBox)
      ::scene_msg_box("req_tutorial_msgbox", null, msgText,
        [
          ["startTutorial", (@(mData, diff) function() {
            mData.mission.setStr("difficulty", ::get_option(::USEROPT_DIFFICULTY).values[diff])
            ::select_mission(mData.mission, true)
            ::current_campaign_mission = mData.mission.name
            ::save_tutorial_to_check_reward(mData.mission)
            ::handlersManager.animatedSwitchScene(::gui_start_flight)
          })(mData, diff)],
          ["cancel", cancelFunc]
        ], "cancel")
    else if(cancelFunc)
      cancelFunc()
    return true
  }

  //
  // Delegates from current base gui handler.
  //

  function msgBox(id, text, buttons, def_btn, options = {})
  {
    ::scene_msg_box(id, null, text, buttons, def_btn, options)
  }
}
