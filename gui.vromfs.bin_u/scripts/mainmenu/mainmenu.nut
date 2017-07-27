::dbg_mainmenu_start_check <- 0
::_is_first_mainmenu_call <- true //only for comatible with 1.59.2.X executable
function gui_start_mainmenu(allowMainmenuActions = true)
{
  if (::_is_first_mainmenu_call)
  {
    ::_is_first_mainmenu_call = false
    if (!::disable_network() && !::g_login.isLoggedIn()) //old executable reload scripts detected
    {
      ::gui_start_after_scripts_reload()
      return
    }
  }

  if (::dbg_mainmenu_start_check++)
  {
    local msg = "Error: recursive start mainmenu call. loginState = " + ::g_login.curState
    dagor.debug(msg)
    callstack()
    ::script_net_assert_once("mainmenu recursion", msg)
  }

  ::mainmenu_preFunc()

  local handler = ::handlersManager.loadHandler(::gui_handlers.MainMenu)
  ::handlersManager.setLastBaseHandlerStartFunc(::gui_start_mainmenu)

  if (allowMainmenuActions)
    ::on_mainmenu_return(handler, false)

  ::dbg_mainmenu_start_check--
  return handler
}

function gui_start_mainmenu_reload(showShop = false)
{
  dagor.debug("Forced reload mainmenu")
  if (::dbg_mainmenu_start_check)
  {
    local msg = "Error: recursive start mainmenu call. loginState = " + ::g_login.curState
    dagor.debug(msg)
    callstack()
    ::script_net_assert_once("mainmenu recursion", msg)
  }

  ::handlersManager.clearScene()
  ::top_menu_shop_active = showShop
  ::gui_start_mainmenu()
}

function gui_start_menuShop()
{
  ::gui_start_mainmenu_reload(true)
}

function mainmenu_preFunc()
{
  ::back_from_replays = null
  ::set_in_save_dialogs(false)

  ::dynamic_clear();
  ::mission_desc_clear();
  ::mission_settings.dynlist <- []

  ::handlersManager.setLastBaseHandlerStartFunc(::gui_start_mainmenu)

  return true
}

 //called after all first mainmenu actions
function on_mainmenu_return(handler, isAfterLogin)
{
  if (!handler)
    return
  local isAllowPopups = !::getFromSettingsBlk("debug/skipPopups")
  local guiScene = handler.guiScene
  if (isAllowPopups)
    ::SessionLobby.checkSessionReconnect()

  update_news()
  if (!isAfterLogin)
  {
    ::checkUnlockedCountriesByAirs()
    ::showBannedStatusMsgBox(true)
    if (isAllowPopups && !::disable_network())
    {
      handler.doWhenActive(::check_tutorial_on_mainmenu)
      handler.doWhenActive(::check_joystick_thustmaster_hotas)
    }
  }
//      if (!::g_login.isLoggedIn() && ::top_menu_handler)
//        ::init_slotbar(::top_menu_handler, guiScene["nav-topMenu"])
//        ::init_slotbar(handler)

  check_logout_scheduled()

  ::ItemsManager.updateGamercardIcons()
  ::sysopt.configMaintain()

  ::checkNonApprovedResearches(true, true)
  if (isAllowPopups)
  {
    handler.doWhenActive(function() { checkSquadInvitesFromPS4Friends(false) })
    handler.doWhenActive(@() ::g_psn_session_invitations.checkReceievedInvitation() )
    handler.doWhenActive(@() ::g_play_together.checkAfterFlight() )
  }

  if(isAllowPopups && ::has_feature("Invites") && !guiScene.hasModalObject())
  {
    local invitedPlayersBlk = ::DataBlock()
    ::get_invited_players_info(invitedPlayersBlk)
    if(invitedPlayersBlk.blockCount() == 0)
    {
      local cdb = ::get_local_custom_settings_blk()
      local time = ::get_local_time()
      local days = ::get_days_by_time(time)
      if(!cdb.viralAcquisition)
        cdb.viralAcquisition = ::DataBlock()

      local gmBlk = ::get_game_settings_blk()
      local resetTime = false
      if (gmBlk && gmBlk.resetViralAcquisitionDaysCounter)
      {
        local num = gmBlk.resetViralAcquisitionDaysCounter
        if (!cdb.viralAcquisition.resetDays)
          cdb.viralAcquisition.resetDays = 0
        if (num > cdb.viralAcquisition.resetDays)
        {
          cdb.viralAcquisition.resetDays = num
          resetTime = true
        }
      }

      if(!cdb.viralAcquisition.lastShowTime || resetTime)
        cdb.viralAcquisition.lastShowTime = 0

      if(!cdb.viralAcquisition.lastLoginDay)
        cdb.viralAcquisition.lastLoginDay = days

      if((cdb.viralAcquisition.lastLoginDay - cdb.viralAcquisition.lastShowTime) > 10)
      {
        ::show_viral_acquisition_wnd()
        cdb.viralAcquisition.lastShowTime = days
        ::save_profile_offline_limited()
      }
      cdb.viralAcquisition.lastLoginDay = days
    }
  }

  if (!guiScene.hasModalObject() && isAllowPopups)
  {
    handler.doWhenActive(::g_user_utils.checkAutoShowPS4EmailRegistration)
    handler.doWhenActive(::g_user_utils.checkAutoShowSteamEmailRegistration)
  }

  if (isAllowPopups && !guiScene.hasModalObject() && !::is_platform_ps4 && ::has_feature("Facebook"))
    handler.doWhenActive(show_facebook_login_reminder)
  if (isAllowPopups)
    handler.doWhenActive(function () { ::checkRemnantPremiumAccount() })
  if (handler.unitInfoPanel == null)
  {
    handler.unitInfoPanel = ::create_slot_info_panel(handler.scene, true)
    handler.registerSubHandler(handler.unitInfoPanel)
  }
  ::g_user_presence.init()

  if (isAllowPopups)
  {
    handler.doWhenActiveOnce("checkNoviceTutor")
    //handler.doWhenActiveOnce("checkUpgradeCrewTutor") // TODO: Fix the bug 58031
    handler.doWhenActiveOnce("initPromoBlock")

    local hasModalObjectVal = guiScene.hasModalObject()
    handler.doWhenActive((@(hasModalObjectVal) function() { ::g_popup_msg.showPopupWndIfNeed(hasModalObjectVal) })(hasModalObjectVal))
  }

  handler.doWhenActive(::pop_gblk_error_popups)

  guiScene.initCursor("gui/cursor.blk", "normal")
}


class ::gui_handlers.MainMenu extends ::gui_handlers.InstantDomination
{
  rootHandlerClass = ::gui_handlers.TopMenu

  onlyDevicesChoice    = true
  startControlsWizard  = false
  timeToAutoQuickMatch = 0.0
  timeToChooseCountry  = 0.0

  unitInfoPanel = null
  promoHandler = null

  visibleUnitInfoName = ""

  //custom functions
  function initScreen()
  {
    ::set_presence_to_player("menu")
    ::enableHangarControls(true)

    if (::g_login.isAuthorized())
      base.initScreen()

    if (::check_tutorial_reward())
      ::reinitAllSlotbars()

    updateLowQualityModelWarning()

    if (::g_login.isAuthorized())
    {
      showOnlineInfo()
      updateClanRequests()
    }

    if (::SessionLobby.isInRoom())
    {
      dagor.debug("after main menu, uid " + ::my_user_id_str + ", " + ::my_user_name + " is in room")
      ::callstack()
      ::SessionLobby.leaveRoom()
    }
    ::stop_gui_sound("deb_count") //!!Dirty hack: after inconsistent leave debriefing from code.
    restoreFocus()
  }

  function onEventOnlineInfoUpdate(params)
  {
    showOnlineInfo()
  }

  function showOnlineInfo()
  {
    if (::is_vietnamese_version() || ::is_vendor_tencent() )
      return

    local text = ::loc("mainmenu/online_info",
                    { playersOnline = ::online_stats.players_total,
                      battles = ::online_stats.rooms_total
                    })

    ::set_menu_title(text, ::top_menu_handler.scene, "online_info")
  }

  function onEventClanInfoUpdate(params)
  {
    updateClanRequests()
  }

  function updateClanRequests()
  {
    local haveRights = ::g_clans.isHaveRightsToReviewCandidates()
    local isReqButtonDisplay = haveRights && ::g_clans.getMyClanCandidates().len() > 0
    local obj = showSceneBtn("btn_main_menu_showRequests", isReqButtonDisplay)
    if (::checkObj(obj) && isReqButtonDisplay)
      obj.setValue(::loc("clan/btnShowRequests") + ::loc("ui/parentheses/space",
        {text = ::g_clans.getMyClanCandidates().len()}))
  }

  function on_show_clan_requests()
  {
    if (::g_clans.isHaveRightsToReviewCandidates())
      showClanRequests(::g_clans.getMyClanCandidates(), ::clan_get_my_clan_id(), false);
  }

  function onExit()
  {
    if (!::is_platform_pc && !::is_platform_android)
      return

    msgBox("question_quit_game", ::loc("mainmenu/questionQuitGame"),
      [
        ["yes", ::exit_game],
        ["no", function() { }]
      ], "no", { cancel_fn = function() {}})
  }

  function onProfileChange() {}  //changed country
  function activateSelectedBlock(obj) {}

  function onLoadModels()
  {
    if (::is_platform_ps4)
    {
      local perc = ps4_get_chunk_progress_percent(PS4_CHUNK_FULL_CLIENT_DOWNLOADED)
      showInfoMsgBox(::loc("msgbox/downloadPercent", {percent = perc}))
    }
    else
      ::check_package_and_ask_download("pkg_main", ::loc("msgbox/ask_package_download"))
  }

  function initPromoBlock()
  {
    if (promoHandler != null)
      return

    promoHandler = ::create_promo_blocks(this)
    registerSubHandler(promoHandler)
  }

  function onEventHangarModelLoading(p)
  {
    doWhenActiveOnce("updateSelUnitInfo")
  }

  function onEventHangarModelLoaded(p)
  {
    doWhenActiveOnce("updateSelUnitInfo")
  }

  function updateSelUnitInfo()
  {
    local unitName = ::hangar_get_current_unit_name()
    if (unitName == visibleUnitInfoName)
      return
    visibleUnitInfoName = unitName

    local unit = ::getAircraftByName(unitName)
    local lockObj = scene.findObject("crew-notready-topmenu")
    lockObj.tooltip = ::format(::loc("msgbox/no_available_aircrafts"), ::secondsToString(::lockTimeMaxLimitSec))
    ::setCrewUnlockTime(lockObj, unit)

    updateUnitRentInfo(unit)
  }

  function updateUnitRentInfo(unit)
  {
    local rentInfoObj = scene.findObject("rented_unit_info_text")
    local messageTemplate = ::loc("mainmenu/unitRentTimeleft") + ::loc("ui/colon") + "%s"
    ::secondsUpdater(rentInfoObj, function(obj, params) {
      local isVisible = !!unit && unit.isRented()
      obj.show(isVisible)
      if (isVisible)
      {
        local sec = unit.getRentTimeleft()
        local time = (sec < TIME_HOUR_IN_SECONDS) ?
          ::secondsToString(sec) :
          ::hoursToString(sec / TIME_HOUR_IN_SECONDS_F, false, true, true)
        obj.setValue(::format(messageTemplate, time))
      }
      return !isVisible
    })
  }
}
