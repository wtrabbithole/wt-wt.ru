class ::gui_handlers.LoginWndHandlerSteam extends ::gui_handlers.LoginWndHandler
{
  sceneBlkName = "gui/loginBoxSimple.blk"

  function initScreen()
  {
    ::g_anim_bg.load()
    ::setVersionText()
    ::setProjectAwards(this)
    ::show_title_logo(true, scene, "128")
    ::set_gui_options_mode(::OPTIONS_MODE_GAMEPLAY)

    showSceneBtn("button_exit", true)

    local buttonsView = [
      {
        id = "authorization_button"
        text = "#HUD_PRESS_A_CNT"
        shortcut = "SpaceA"
        funcName = "onOk"
        delayed = true
        isToBattle = true
        titleButtonFont = true
      },
      {
        id = "change_login"
        text = "#mainmenu/alreadyHaveAccount"
        shortcut = "X"
        visualStyle = "secondary"
        func = "onChangeLoginScreen"
      }
    ]

    local data = ""
    foreach (view in buttonsView)
      data += ::handyman.renderCached("gui/commonParts/button", view)

    guiScene.prependWithBlk(scene.findObject("authorization_block"), data, this)

    if (!::getTblValue("disable_autorelogin_once", ::getroottable(), false))
      onOk()
  }

  function requestLogin(no_dump_login = "")
  {
    ::statsd_counter("gameStart.request_login.steam")
    ::dagor.debug("Steam Login: check_login_pass")
    return ::check_login_pass("", "", "steam", "steam", false, false)
  }

  function onOk()
  {
    local result = requestLogin()
    ::disable_autorelogin_once <- false

    switch (result)
    {
      case ::YU2_OK:
        checkSteamActivation("")
        break
      default:
        msgBox("steam_login_error",
               ::loc("steam/authorization_error"),
               [["ok", function() { ::handlersManager.loadHandler(::gui_handlers.LoginWndHandler) } ]],
               "ok")
    }
  }

  function onChangeLoginScreen()
  {
    ::handlersManager.loadHandler(::gui_handlers.LoginWndHandler)
  }

  function goBack(obj)
  {
    msgBox("steam_question_quit_game", ::loc("mainmenu/questionQuitGame"),
      [["yes", ::exit_game], ["no"]], "no", { cancel_fn = function() {}})
  }
}
