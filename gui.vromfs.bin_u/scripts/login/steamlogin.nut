::USE_STEAM_LOGIN_AUTO_SETTING_ID <- "useSteamLoginAuto"

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

    //Called init while in loading, so no need to call again authorization.
    //Just wait, when the loading will be over.
    if (::g_login.isAuthorized())
      return

    local useSteamLoginAuto = ::load_local_shared_settings(::USE_STEAM_LOGIN_AUTO_SETTING_ID)
    if (useSteamLoginAuto == true)
    {
      authorizeSteam("steam-known")
      return
    }
    else if (useSteamLoginAuto == false)
    {
      goToLoginWnd(false)
      return
    }

    showSceneBtn("button_exit", true)

    ::scene_msg_box("steam_link_method_question",
      guiScene,
      ::loc("steam/login/linkQuestion"),
      [["#mainmenu/loginWithGaijin", ::Callback(goToLoginWnd, this) ],
       ["#mainmenu/loginWithSteam", ::Callback(authorizeSteam, this)],
       ["exit", ::exit_game]
      ],
      "#mainmenu/loginWithGaijin"
    )
  }

  function proceedAuthorizationResult(result, no_dump_login)
  {
    switch(result)
    {
      case ::YU2_NOT_FOUND:
        goToLoginWnd()
        break
      default:
        base.proceedAuthorizationResult(result, no_dump_login)
    }
  }

  function authorizeSteam(steamKey = "steam")
  {
    onSteamAuthorization(steamKey)
  }

  function goToLoginWnd(disableAutologin = true)
  {
    if (disableAutologin)
      ::disable_autorelogin_once <- true
    ::handlersManager.loadHandler(::gui_handlers.LoginWndHandler)
  }

  function goBack(obj)
  {
    ::scene_msg_box("steam_question_quit_game",
      guiScene,
      ::loc("mainmenu/questionQuitGame"),
      [
        ["yes", ::exit_game],
        ["no", @() null]
      ],
      "no",
      { cancel_fn = @() null}
    )
  }
}
