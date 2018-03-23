local crossplayModule = require("scripts/social/crossplay.nut")

local multiplayerSessionPrivelegeCallback = null
local function checkMultiplayerSessionsPrivilegeSq(showMarket, cb)
{
  multiplayerSessionPrivelegeCallback = cb
  ::check_multiplayer_sessions_privilege(showMarket)
}

function check_multiplayer_sessions_privilege_callback(isAllowed)
{
  if (multiplayerSessionPrivelegeCallback)
    multiplayerSessionPrivelegeCallback(isAllowed)
  multiplayerSessionPrivelegeCallback = null
}

class ::gui_handlers.LoginWndHandlerXboxOne extends ::BaseGuiHandler
{
  sceneBlkName = "gui/loginBoxSimple.blk"
  needAutoLogin = false

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
        funcName = "onChangeGamertag"
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
    loginStep1_checkGamercard()
  }

  function loginStep1_checkGamercard()
  {
    if (::xbox_get_active_user_gamertag() == "")
    {
      needAutoLogin = true
      onChangeGamertag()
      return
    }

    loginStep2_checkMultiplayerPrivelege()
  }

  function loginStep2_checkMultiplayerPrivelege()
  {
    checkMultiplayerSessionsPrivilegeSq(true,
      ::Callback(function(res)
      {
        if (res)
          ::get_gui_scene().performDelayed(this, loginStep3_checkCrossPlay)
      }, this))
    //callback check_multiplayer_sessions_privilege_callback
    //will call checkCrossPlay if allowed
  }

  function loginStep3_checkCrossPlay()
  {
    needAutoLogin = false

    if (!crossplayModule.isCrossPlayEnabled())
    {
      ::scene_msg_box("xbox_cross_play",
        guiScene,
        ::loc("xbox/login/crossPlayRequest") +
          "\n" +
          ::colorize("@warningTextColor", ::loc("xbox/login/crossPlayRequest/annotation")),
        [
          ["yes", ::Callback(@() performLogin(true), this) ],
          ["no", ::Callback(@() performLogin(), this) ],
          ["cancel", @() null ]
        ],
        "yes",
        {
          cancel_fn = @() null
        }
      )
    }
    else
      performLogin(true)
  }

  function performLogin(useCrossPlay = false)
  {
    crossplayModule.setIsCrossPlayEnabled(useCrossPlay)
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

      }.bindenv(this)
    )
  }

  function onChangeGamertag(obj = null)
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
    if (needAutoLogin && ::xbox_get_active_user_gamertag() != "")
      onOk()
  }

  function goBack(obj) {}
}

//Calling from C++
::xbox_on_gamertag_changed <- @() ::broadcastEvent("XboxActiveUserGamertagChanged")