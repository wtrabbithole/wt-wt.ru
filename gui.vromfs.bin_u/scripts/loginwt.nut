::my_user_id_str <- ""
::my_user_id_int64 <- -1
::my_user_name <- ""
::player_lists <- null
::need_logout_after_session <- false

::g_script_reloader.registerPersistentData("LoginWTGlobals", ::getroottable(),
  [
    "my_user_id_str", "my_user_id_int64", "my_user_name"
  ])

::g_login.initOptionsPseudoThread <- null

function gui_start_startscreen()
{
  ::dagor.debug("target_platform is '" + ::target_platform + "'")
  ::pause_game(false);

  if (::disable_network())
    ::g_login.setState(LOGIN_STATE.AUTHORIZED)
  ::g_login.startLoginProcess()
}

function gui_start_after_scripts_reload()
{
  ::g_login.setState(LOGIN_STATE.AUTHORIZED) //already authorized to char
  ::g_login.startLoginProcess()
}

function on_sign_out()  //!!FIX ME: better to full replace this function by SignOut event
{
  if (!("resetChat" in getroottable())) //scripts not loaded
    return

  ::resetChat()
  ::clear_contacts()
  ::g_squad_manager.reset()
  ::SessionLobby.leaveRoom()
  ::my_stats.clearStats()
  if (::g_battle_tasks)
    ::g_battle_tasks.reset()
  if (::g_recent_items)
    ::g_recent_items.reset()
  ::abandoned_researched_items_for_session = []
  ::launched_tutorial_questions_peer_session = 0
}

function can_logout()
{
  return !::disable_network() && !::is_vendor_tencent()
}

function gui_start_logout()
{
  if (!::can_logout())
    return ::exit_game()

  if (::is_multiplayer()) //we cant logout from session instantly, so need to return "to debriefing"
  {
    if (::is_in_flight())
    {
      ::need_logout_after_session = true
      ::quit_mission()
      return
    }
    else
      ::destroy_session_scripted()
  }

  dagor.debug("gui_start_logout")
  ::disable_autorelogin_once <- true
  ::need_logout_after_session = false
  ::g_login.reset()
  ::on_sign_out()
  sign_out()
  ::handlersManager.startSceneFullReload(::gui_start_startscreen)
}

function go_to_account_web_page(bqKey = "")
{
  local urlBase = ::format("/user.php?skin_lang=%s", ::g_language.getShortName())
  ::open_url(get_authenticated_url(urlBase), false, false, bqKey)
}

function g_login::onAuthorizeChanged()
{
  if (!isAuthorized())
  {
    if (::g_login.initOptionsPseudoThread)
      ::g_login.initOptionsPseudoThread.clear()
    ::broadcastEvent("SignOut")
    return
  }

  if (!::disable_network())
    ::handlersManager.animatedSwitchScene(function() {
      ::handlersManager.loadHandler(::gui_handlers.WaitForLoginWnd)
    })
}

function g_login::initConfigs(cb)
{
  ::broadcastEvent("AuthorizeComplete")
  ::load_scripts_after_login()
  ::my_user_id_str = ::get_player_user_id_str()
  ::my_user_id_int64 = ::my_user_id_str.tointeger()

  initOptionsPseudoThread =  [
    function() { ::initEmptyMenuChat() }
  ]
  initOptionsPseudoThread.extend(::init_options_steps)
  initOptionsPseudoThread.extend(
  [
    function() {
      ::init_all_tips() //reload tips because of possible lang update
    }
    function() {
      if (!::g_login.hasState(LOGIN_STATE.PROFILE_RECEIVED | LOGIN_STATE.CONFIGS_RECEIVED))
        return PT_STEP_STATUS.SUSPEND

      ::ps4_is_client_full_downloaded = ::ps4_is_chunk_available(PS4_CHUNK_FULL_CLIENT_DOWNLOADED)
      ::get_profile_info() //update ::my_user_name
      ::init_selected_crews(true)
      ::set_show_attachables(::has_feature("AttachablesUse"))

      local fontsCss = ::get_gui_option_in_mode(::USEROPT_FONTS_CSS, ::OPTIONS_MODE_GAMEPLAY)
      if (!fontsCss)
      {
        fontsCss = ::get_default_fonts_css()
        ::set_gui_option_in_mode(::USEROPT_FONTS_CSS, fontsCss, ::OPTIONS_MODE_GAMEPLAY)
      }
      if (::can_change_fonts())
      {
        local pxFonts = (fontsCss == PX_FONTS_CSS)
        if (::getSystemConfigOption("video/pxFonts") != pxFonts)
          ::setSystemConfigOption("video/pxFonts", pxFonts)
      }
    }
    function() {
      if (!::g_login.hasState(LOGIN_STATE.MATCHING_CONNECTED))
        return PT_STEP_STATUS.SUSPEND

      local cdb = ::get_local_custom_settings_blk()
      if (!("initialContacts" in cdb) || !cdb.initialContacts)
      {
        cdb.initialContacts = true
        ::player_lists <- ::get_player_lists() //no update, just pointer to DB in profile

        //FIXME: maybe temporary, maybe not...
        local oldLists = ::get_obsolete_player_lists()
        local editBlk = ::DataBlock()
        local contactsChanged = false
        foreach (name, list in oldLists)
        {
          editBlk[name] <- ::DataBlock()
          local groupChanged = false
          foreach (uid, nick in list)
          {
            editBlk[name][uid] <- true
            dagor.debug("Adding player '"+nick+"' ("+uid+") to "+name);

            local player = ::getContact(uid, nick)
            if ((name in ::contacts) && !::isPlayerInContacts(uid, name))
            {
              ::contacts[name].append(player)
              groupChanged = true
            }
          }
          if (groupChanged)
          {
            ::contacts[name].sort(::sortContacts)
            contactsChanged = true
          }
        }

        ::request_edit_player_lists(editBlk)
      }
    }
    function() {
      ::shown_userlog_notifications.clear()
      ::collectOldNotifications()
      ::check_bad_weapons()
    }
    function() {
      ::updateDiscountData(true)
    }
    function() {
     ::slotbarPresets.init()
     ::g_chat.onCharConfigsLoaded()
    }
    function() {
      ::autobind_shortcuts()
     }
    function() {
      if (::steam_is_running())
        ::steam_process_dlc()
  
      if (::is_dev_version)
        ::checkShopBlk()

      foreach(c in ::shopCountriesList)
        ::debriefing_countries[c] <- ::get_player_rank_by_country(c)
    }
    function()
    {
      ::unlocked_countries = [] //reinit countries
      ::checkUnlockedCountries()
      ::checkUnlockedCountriesByAirs()
    }
    function()
    {
      ::g_login.initOptionsPseudoThread = null
      cb()
    }
  ])

  ::start_pseudo_thread(initOptionsPseudoThread)
}

function g_login::onLoggedInChanged()
{
  if (!isLoggedIn())
    return

   ::statsd_on_login()

  ::broadcastEvent("LoginComplete")

  //animatedSwitchScene sync function, so we need correct finish current call
  ::get_cur_gui_scene().performDelayed(::getroottable(), function()
  {
    ::handlersManager.markfullReloadOnSwitchScene()
    ::handlersManager.animatedSwitchScene(function() {
      ::g_login.firstMainMenuLoad()
    })
  })
}

function g_login::firstMainMenuLoad()
{
  local handler = ::gui_start_mainmenu(false)
  if (!handler)
    return //was error on load mainmenu, and was called signout on such error

  ::updateContentPacks()
  ::tribunal.checkComplaintCounts()

  ::update_start_mission_instead_of_queue()

  if (::is_need_first_country_choice())
  {
    ::my_stats.afterAccountReset()
    handler.doWhenActive(::gui_start_countryChoice)
  }

  handler.doWhenActive(checkAwardsOnStartFrom)

  if (!fetch_profile_inited_once())
  {
    if (get_num_real_devices() == 0 && !::is_platform_android)
      setControlTypeByID("ct_mouse")
    else if (::is_platform_shield_tv())
      setControlTypeByID("ct_xinput")
    else
      handler.doWhenActive(function() { ::gui_start_controls_type_choice(false) })
  }
  else if (!fetch_devices_inited_once())
    handler.doWhenActive(function() { ::gui_start_controls_type_choice() })

  if (::g_controls_presets.isNewerControlsPresetVersionAvailable())
  {
    local patchNoteText = ::g_controls_presets.getPatchNoteTextForCurrentPreset()
    ::scene_msg_box("new_controls_version_msg_box", null,
      ::loc("mainmenu/new_controls_version_msg_box", { patchnote = patchNoteText }),
      [["yes", function () { ::g_controls_presets.setHighestVersionOfCurrentPreset() }],
       ["no", function () { ::g_controls_presets.rejectHighestVersionOfCurrentPreset() }]
      ], "yes", { cancel_fn = function () { ::g_controls_presets.rejectHighestVersionOfCurrentPreset }})
  }

  if (
    ::show_console_buttons &&
    ::g_gamepad_cursor_controls.canChangeValue()
  )
  {
    if (
      !::gui_handlers.GampadCursorControlsSplash.isDisplayed() &&
      !::g_gamepad_cursor_controls.getValue()
    )
    {
      handler.doWhenActive(function() { ::gui_start_gamepad_cursor_controls_splash(
        function() {::statsd_counter("temp_test.gamepadCursorController.enabled") }
      ) })
    }
    else if (::g_gamepad_cursor_controls.getValue())
      ::statsd_counter("temp_test.gamepadCursorController.enabled")
    ::statsd_counter("temp_test.gamepadCursorController.asked")
  }

  if (!::disable_network() && !::getFromSettingsBlk("debug/skipPopups"))
    handler.doWhenActive(::check_tutorial_on_start)
  handler.doWhenActive(::check_joystick_thustmaster_hotas)

  // FIXME: it is better to get string from NDA text!
  local versions = ["nda_version", "nda_version_tanks", "eula_version"]
  foreach (sver in versions)
  {
    local l = ::loc(sver)
    try { getroottable()[sver] = l.tointeger() }
    catch(e) { dagor.assertf(0, "can't convert '"+l+"' to version "+sver) }
  }

  ::nda_version = ::check_feature_tanks() ? ::nda_version_tanks : ::nda_version

  if (should_agree_eula(::nda_version, ::TEXT_NDA))
    ::gui_start_eula(::TEXT_NDA)
  else
  if (should_agree_eula(::eula_version, ::TEXT_EULA))
    ::gui_start_eula(::TEXT_EULA)

  if (::has_feature("CheckEmailVerified"))
    if (!::check_account_tag("email_verified"))
      handler.doWhenActive(function () {
        msgBox(
        "email_not_verified_msg_box",
        ::loc("mainmenu/email_not_verified"),
        [
          ["later", function() {} ],
          ["verify", function() {::go_to_account_web_page("email_verification_popup")}]
        ],
        "later", { cancel_fn = function() {}}
      )})

  if (::has_feature("CheckTwoStepAuth"))
    if (!::check_account_tag("2step"))
      handler.doWhenActive(function () {
        ::g_popups.add(
          ::loc("mainmenu/two_step_popup_header"),
          ::loc("mainmenu/two_step_popup_text"),
          null,
          [{
            id = "acitvate"
            text = ::loc("msgbox/btn_activate")
            func = function() {::go_to_account_web_page("2step_auth_popup")}
          }]
        )
      })

  ::queues.init()
  ::set_host_cb(null, function(p) { ::SessionLobby.hostCb(p) })

  ::init_coop_flags()

  ::update_gamercards()
  ::showBannedStatusMsgBox()

  ::on_mainmenu_return(handler, true)
}
