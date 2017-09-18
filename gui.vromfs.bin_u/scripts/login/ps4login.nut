class ::gui_handlers.LoginWndHandlerPs4 extends ::BaseGuiHandler
{
  sceneBlkName = "gui/loginBoxSimple.blk"
  isLoggingIn = false

  function initScreen()
  {
    ::g_anim_bg.load()
    ::setVersionText()
    ::setProjectAwards(this)
    ::show_title_logo(true, scene, "128")
    ::set_gui_options_mode(::OPTIONS_MODE_GAMEPLAY)

    local data = ::handyman.renderCached("gui/commonParts/button", {
      id = "authorization_button"
      text = "#HUD_PRESS_A_CNT"
      shortcut = "SpaceA"
      funcName = "onOk"
      delayed = true
      isToBattle = true
      titleButtonFont = true
    })
    guiScene.prependWithBlk(scene.findObject("authorization_button_place"), data, this)
    showSceneBtn("text_req_connection",  true)

    guiScene.performDelayed(this, function() {
      ::ps4_initial_check_settings()
      ::ps4_initial_save_settings()
      ::checkSquadInvitesFromPS4Friends(true, false)
    })
  }

  function onOk()
  {
    if (isLoggingIn)
      return

    //TODO: real login
    //for now, revert to PC login scene
    if ((::ps4_initial_check_network() >= 0) && (::ps4_init_trophies() >= 0))
    {
      ::statsd_counter("gameStart.request_login.ps4")
      ::dagor.debug("PS4 Login: ps4_login")
      isLoggingIn = true
      local ret = ::ps4_login();
      if (ret >= 0)
      {
        local isProd = ::ps4_is_production_env()

        ::gui_start_modal_wnd(::gui_handlers.PS4UpdaterModal,
          {
            configPath = isProd ? "/app0/ps4/updater.blk" : "/app0/ps4/updater_dev.blk"
          })
      }
      else if (ret == -1)
      {
        isLoggingIn = false
        msgBox("no_internet_connection", ::loc("ps4/noInternetConnection"), [["ok", function() {} ]], "ok")
      }
    }
  }

  function onEventPS4AvailableNewInvite(p)
  {
    onOk()
  }

  function onChangeLoginScreen() {}
  function goBack(obj) {}
}
