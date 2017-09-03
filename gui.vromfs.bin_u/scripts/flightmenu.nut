::quit_from_show_stat <- false

function gui_start_flight_menu()
{
  ::flight_menu_handler = ::handlersManager.loadHandler(::gui_handlers.FlightMenu)
}

function gui_start_flight_menu_failed()
{
  ::flight_menu_handler = ::handlersManager.loadHandler(::gui_handlers.FlightMenu, { isMissionFailed = true })
}

function gui_start_flight_menu_psn() {} //unused atm, but still have a case in code

class ::gui_handlers.FlightMenu extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "gui/flightMenu.blk"
  shouldBlurSceneBg = true
  keepLoaded = true
  wndControlsAllowMask = CtrlsInGui.CTRL_ALLOW_FLIGHT_MENU

  haveSecDevice = false
  isMissionFailed = false
  isShowStat = false
  usePause = true


  function initScreen()
  {
    usePause = !::is_game_paused()
    if (!::handlersManager.isFullReloadInProgress)
    {
      ::in_flight_menu(true)
      if (usePause)
        ::pause_game(true)
    }
    setSceneTitle(getCurMpTitle())
    local items = []

    local resumeItem = { name = "Resume", brAfter = true};

    if (isMissionFailed)
      items=["Restart","QuitMission"]
    else
    {
      items=[resumeItem]
      if (::get_game_mode() != ::GM_BENCHMARK)
        items.extend(["Options", "Controls", "ControlsHelp"])
      items.extend(["Restart", "Bailout", "Stats", "QuitMission"])
    }

    local blkItems =  ::build_menu_blk(items,"#flightmenu/btn", true)
    guiScene.replaceContentFromText(scene.findObject("menu-buttons"), blkItems,
                                     blkItems.len(), this)

    refreshScreen()
  }

  function reinitScreen(params)
  {
    usePause = !::is_game_paused()
    ::in_flight_menu(true)
    if (usePause)
      ::pause_game(true)
    setParams(params)
    refreshScreen()
    restoreFocus()
  }

  function refreshScreen()
  {
    if (!::checkObj(scene))
      return

    local status = ::get_mission_status()
    local gm = ::get_game_mode()
    local isMp = ::is_multiplayer()

    local restartBtnObj = scene.findObject("btn_Restart")
    local quitMisBtnObj = scene.findObject("btn_QuitMission")

    if (isMissionFailed)
    {
      if (::checkObj(restartBtnObj))
      {
        restartBtnObj.show(true)
        restartBtnObj.select()
      }

      if (::checkObj(quitMisBtnObj))
        quitMisBtnObj.show(true)

      ::showBtnTable(scene, {
          btn_back          = false
          btn_resume        = false
          btn_options       = false
          btn_controlshelp  = false
          btn_bailout       = false
      })

      return
    }

    restartBtnObj.show(!::is_replay_playing()
                                  && !isMp
                                  && gm != ::GM_DYNAMIC
                                  && gm != ::GM_BENCHMARK
                                  && status != ::MISSION_STATUS_SUCCESS
                                  && !(::get_game_type() & ::GT_COOPERATIVE)
                                )

    local btnBailout = scene.findObject("btn_Bailout")
    if (::checkObj(btnBailout))
    {
      if (::get_mission_restore_type() != ::ERT_MANUAL
          && gm != ::GM_BENCHMARK
          && !::is_camera_not_flight()
          && ::is_player_can_bailout()
          && (status != ::MISSION_STATUS_SUCCESS || !::isInArray(gm, [::GM_CAMPAIGN, ::GM_SINGLE_MISSION, ::GM_DYNAMIC, ::GM_TRAINING, ::GM_BUILDER]))
         )
      {
        local txt = ::loc(::is_tank_interface() ? "flightmenu/btnLeaveTheTank" : "flightmenu/btnBailout")
        if (!isMp && ::get_mission_restore_type() == ::ERT_ATTEMPTS)
        {
          local numLeft = ::get_num_attempts_left()
          if (status == ::MISSION_STATUS_SUCCESS && ::get_game_mode() == ::GM_DYNAMIC)
          {
            txt = ::loc("flightmenu/btnCompleteMission")
          }
  //        else if (gm == ::GM_DYNAMIC || gm == ::GM_BUILDER) - we have attempts there now!
  //        {
  //        }
          else if (numLeft < 0)
            txt += " (" + ::loc("options/attemptsUnlimited") + ")"
          else
            txt += " (" + ::get_num_attempts_left() + " " +
            (numLeft == 1 ? ::loc("options/attemptLeft") : ::loc("options/attemptsLeft")) + ")"
        }
        btnBailout.setValue(txt)
        btnBailout.show(true)
      }
      else
        btnBailout.show(false)
    }

    local statsBtnObj = scene.findObject("btn_Stats")
    if (::checkObj(statsBtnObj))
      statsBtnObj.show(false)

    local quitMissionText = ::loc("flightmenu/btnQuitMission")
    if (::is_replay_playing())
      quitMissionText = ::loc("flightmenu/btnQuitReplay")
    else if (status == ::MISSION_STATUS_SUCCESS && ::get_game_mode() == ::GM_DYNAMIC)
      quitMissionText = ::loc("flightmenu/btnCompleteMission")

    if (::checkObj(quitMisBtnObj))
      quitMisBtnObj.setValue(quitMissionText)

    local resumeBtnObj = scene.findObject("btn_Resume")
    if (::checkObj(resumeBtnObj))
      resumeBtnObj.select()

    if (isShowStat)
    {
      isShowStat = false
      ::quit_from_show_stat = true
      onStats(null);
    }
    else if (::quit_from_show_stat)
    {
      ::quit_from_show_stat = false
      onResumeRaw()
    }
  }

  function onCompleteMpSession()
  {

  }

  function onCompleteMpMission()
  {

  }

  function onResume(obj)
  {
    if (isMissionFailed)
      return
    onResumeRaw()
  }

  function onResumeRaw()
  {
    if (isMissionFailed)
      return

    ::in_flight_menu(false) //in_flight_menu will call closeScene which call stat chat
    if (usePause)
      ::pause_game(false)
  }

  function onCancel(obj)
  {
    onResume(obj)
  }

  function onOptions(obj)
  {
    ::gui_start_options(this)
  }

  function onControls(obj)
  {
    goForward(::gui_start_controls);
  }

  function onCustomShortcuts()
  {
    goForward(::gui_start_hotkeys)
  }

  function onCustomSettings()
  {
    goForward(::gui_start_joystick_settings)
  }

  function onStats(obj)
  {
    goForward(::gui_start_mpstatscreen)
  }

  function selectRestartMissionBtn()
  {
    local obj = scene.findObject("btn_restart")
    if (::checkObj(obj))
      obj.select()
  }

  function restartBriefing()
  {
    if (("is_offline_version" in getroottable()) && ::is_offline_version)
      return ::restart_mission();

    local gm = ::get_game_mode()
    if (gm == ::GM_CAMPAIGN || gm == ::GM_SINGLE_MISSION || gm == ::GM_DYNAMIC)
    {
       goForward(::gui_start_briefing_restart)
    }
    else
      ::restart_current_mission()
  }

  function onRestart(obj)
  {
    if (("is_offline_version" in getroottable()) && ::is_offline_version)
      return ::restart_mission();

    if (isMissionFailed)
      restartBriefing()
    else
    if (::get_mission_status() == ::MISSION_STATUS_RUNNING)
    {
      msgBox("question_restart_mission", ::loc("flightmenu/questionRestartMission"),
      [
        ["yes", restartBriefing],
        ["no", selectRestartMissionBtn]
      ], "no")
    }
    else
      ::restart_current_mission()
  }

  function selectQuitMissionBtn()
  {
    local obj = scene.findObject("btn_quitmission")
    if (::checkObj(obj))
      obj.select()
  }

  function sendDisconnectMessage()
  {
    ::broadcastEvent("PlayerQuitMission")
    if (::is_multiplayer())
    {
      ::leave_mp_session()
      onResumeRaw()
    }
    else
      quitToDebriefing()
  }

  function quitToDebriefing()
  {
    ::g_orders.disableOrders()
    ::quit_to_debriefing()
    ::interrupt_multiplayer(true)
    onResumeRaw()
  }

  function onQuitMission(obj)
  {
    if (("is_offline_version" in getroottable()) && ::is_offline_version)
      return ::restart_mission();

    if (::is_replay_playing())
    {
      quitToDebriefing()
    }
    else if ((::get_mission_status() == ::MISSION_STATUS_RUNNING) && !isMissionFailed)
    {
      local text = ""
      if (::is_mplayer_host())
        text = ::loc("flightmenu/questionQuitMissionHost")
      else if (::get_game_mode() == ::GM_DOMINATION)
      {
        local unitsData = ::g_mis_custom_state.getCurMissionRules().getAvailableToSpawnUnitsData()
        local unitsTexts = ::u.map(unitsData,
                                   function(ud)
                                   {
                                     local res = ::colorize("userlogColoredText", ::getUnitName(ud.unit))
                                     if (ud.comment.len())
                                       res += ::loc("ui/parentheses/space", { text = ud.comment })
                                     return res
                                   })
        if (unitsTexts.len())
          text = ::loc("flightmenu/haveAvailableCrews") + "\n" + ::g_string.implode(unitsTexts, ", ") + "\n\n"

        text += ::loc("flightmenu/questionQuitMissionInProgress")
      } else
        text = ::loc("flightmenu/questionQuitMission")
      msgBox("question_quit_mission", text,
      [
        ["yes", sendDisconnectMessage],
        ["no", selectQuitMissionBtn]
      ], "yes", { cancel_fn = function() {}})
    }
    else if (isMissionFailed)
    {
      local text = ::loc("flightmenu/questionQuitMission")
      msgBox("question_quit_mission", text,
      [
        ["yes", function()
        {
          ::quit_to_debriefing()
          ::interrupt_multiplayer(true)
          ::in_flight_menu(false)
          if (usePause)
            ::pause_game(false)
        }],
        ["no", selectQuitMissionBtn]
      ], "yes", { cancel_fn = function() {}})
    }
    else
    {
      ::quit_mission_after_complete()
      onResumeRaw()
    }
  }

  function onCompleteMission(obj)
  {
    onQuitMission(obj)
  }

  function selectQuitBtn()
  {
    local obj = scene.findObject("btn_quitgame")
    if (::checkObj(obj))
      obj.select()
  }

  function onQuitGame(obj)
  {
    msgBox("question_quit_game", ::loc("flightmenu/questionQuitGame"),
      [
        ["yes", ::exit_game],
        ["no", selectQuitBtn]
      ], "no")
  }

  function selectBailoutBtn()
  {
    local obj = scene.findObject("btn_bailout")
    if (::checkObj(obj))
      obj.select()
  }

  function doBailout()
  {
    ::do_player_bailout()

    onResume(null)
  }

  function onBailout(obj)
  {
    if (::is_player_can_bailout())
    {
      msgBox("question_bailout", ::loc(::is_tank_interface() ? "flightmenu/questionLeaveTheTank" : "flightmenu/questionBailout"),
        [
          ["yes", doBailout],
          ["no", selectBailoutBtn]
        ], "no", { cancel_fn = function() {}})
    }
  }

  function getCurSecDevice()
  {
    local num = ::get_second_joy_number()
    if (num < 0)
    {
      haveSecDevice = false
      return "?"
    }
    haveSecDevice = true
    return (num+1).tostring()
  }

  function onControlsHelp()
  {
    ::gui_modal_help(false, HELP_CONTENT_SET.MISSION)
  }

  function onActivateOrder()
  {
    ::g_orders.openOrdersInventory(true)
  }

  function onOrderTimerUpdate(obj, dt)
  {
    ::g_orders.updateActiveOrder()
    if (::checkObj(obj))
      obj.text = ::g_orders.getActivateButtonLabel()
  }

  function onInactiveItem(obj)
  {
    // Parameter 'obj' is null so we have to assume it's "Activate Order".
    msgBox("no_orders_available", ::loc("items/order/noOrdersAvailable"),
      [["ok", function () {}]], "ok")
  }
}

function quit_mission()
{
  ::in_flight_menu(false)
  ::pause_game(false)
  gui_start_hud()
  ::broadcastEvent("PlayerQuitMission")

  if (::is_multiplayer())
    return ::leave_mp_session()

  ::quit_to_debriefing()
  ::interrupt_multiplayer(true)
}
