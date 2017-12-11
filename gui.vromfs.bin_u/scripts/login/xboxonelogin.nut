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
    scene.findObject("user_notify_text").setValue(::loc("xbox/reqInstantConnection"))
    updateGamertag()
  }

  function onOk()
  {
    updateAuthorizeButton(false) // do not allow to push ok button twice

    ::xbox_on_login(
      function(result, err_code)
      {
        if (result == XBOX_LOGIN_STATE_SUCCESS)
        {
          ::g_login.addState(LOGIN_STATE.AUTHORIZED)
          return
        }

        if (result == XBOX_LOGIN_STATE_FAILED)
          msgBox("no_internet_connection", ::loc("xbox/noInternetConnection"), [["ok", function() {} ]], "ok")

        updateAuthorizeButton(true)
      }.bindenv(this)
    )
  }

  function updateAuthorizeButton(isEnable = false)
  {
    local btnObj = scene.findObject("authorization_button")
    if (::check_obj(btnObj))
      btnObj.enable(isEnable)
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
    if (::getTblValue("autologin", params, false))
      onOk()
  }

  function goBack(obj) {}
}

//Calling from C++
function xbox_on_gamertag_changed()
{
  ::broadcastEvent("XboxActiveUserGamertagChanged")
}

function xbox_on_gamertag_choosed()
{
  ::broadcastEvent("XboxActiveUserGamertagChanged", {autologin = true})
}