class ::gui_handlers.LoginWndHandlerXboxOne extends ::BaseGuiHandler
{
  sceneBlkName = "gui/loginBoxSimple.blk"

  function initScreen()
  {
    ::g_anim_bg.load()
    ::setVersionText()
    ::setProjectAwards(this)
    ::show_title_logo(true, scene, "128")
    ::set_gui_options_mode(::OPTIONS_MODE_GAMEPLAY)

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
        id = "change_profile"
        text = "#mainmenu/btnProfileChange"
        shortcut = "Y"
        visualStyle = "secondary"
        func = "onChangeGamertag"
      }
    ]

    local data = ""
    foreach (view in buttonsView)
      data += ::handyman.renderCached("gui/commonParts/button", view)

    guiScene.prependWithBlk(scene.findObject("authorization_button_place"), data, this)
    showSceneBtn("text_req_connection",  true)
    updateGamertag()
  }

  function onOk()
  {
    local ret = ::xbox_on_login();
    if (ret == -1)
    {
      msgBox("no_internet_connection", ::loc("ps4/noInternetConnection"), [["ok", function() {} ]], "ok")
    }
    else
    {
      //::g_login.addState(LOGIN_STATE.AUTHORIZED)
    }
  }

  function onChangeGamertag()
  {
    ::xbox_account_picker()
  }

  function updateGamertag()
  {
    local text = ::xbox_get_active_user_gamertag()
    if (text != "")
      text = ::loc("xbox/playAs", {name = text})

    scene.findObject("xbox_active_usertag").setValue(text)
  }

  function onEventXboxActiveUserGamertagChanged(params)
  {
    updateGamertag()
  }

  function goBack(obj) {}
}

//Calling from C++
function on_change_active_xbox_user_gamertag()
{
  ::broadcastEvent("XboxActiveUserGamertagChanged")
}