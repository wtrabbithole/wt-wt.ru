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
    showSceneBtn("change_login", true)
    scene.findObject("version_text").setValue("Play as " + ::xbox_get_active_user_gamertag())
  }

  function onOk()
  {
    local ret = ::xbox_on_login();
    if (ret == -1)
    {
      msgBox("no_internet_connection", ::loc("ps4/noInternetConnection"), [["ok", function() {} ]], "ok")
    }
  }

  function onChangeLoginScreen()
  {
    ::xbox_account_picker();
  }

  function goBack(obj) {}
}
