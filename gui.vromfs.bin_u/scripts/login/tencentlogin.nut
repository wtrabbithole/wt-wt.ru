class ::gui_handlers.LoginWndHandlerTencent extends ::BaseGuiHandler
{
  sceneBlkName = "gui/loginBoxSimple.blk"

  function initScreen()
  {
    ::g_anim_bg.load()
    ::setVersionText()
    ::setProjectAwards(this)

    guiScene.performDelayed(this, function() { doLogin() })
  }

  function afterLogin()
  {
    ::g_login.addState(LOGIN_STATE.AUTHORIZED)
  }

  function doLogin()
  {
    ::dagor.debug("Login: yuplay2_tencent_login")
    ::statsd_counter("gameStart.request_login.tencent")
    local res = ::yuplay2_tencent_login()
    if (res == ::YU2_OK)
      return afterLogin()

    dagor.debug("yuplay2_tencent_login returned " + res)

    local buttons = [["exit", ::exit_game]]
    local defBtn = "exit"

    if (!::isInArray(res, [::YU2_TENCENT_CLIENT_DLL_LOST, ::YU2_TENCENT_CLIENT_NOT_RUNNING]))
    {
      buttons.append(["tryAgain", ::Callback(doLogin, this)])
      defBtn = "tryAgain"
    }

    ::error_message_box("yn1/connect_error", res, buttons, defBtn, { saved = true,  cancel_fn = ::exit_game})
  }

  function onOk()
  {
    doLogin()
  }

  function goBack(obj) {}
}

function change_nickname(onSuccess, onCancel = null)
{
  ::gui_modal_editbox_wnd({
    title = ::loc("mainmenu/chooseName")
    maxLen = 16
    validateFunc = function(nick) {
      if (::is_chat_message_empty(nick))
        return ""
      return ::clearBorderSymbols(nick, [" "])
    }
    canCancel = false
    allowEmpty = false
    cancelFunc = onCancel
    okFunc = (@(onSuccess, onCancel) function(nick) {
      ::do_change_nickname(nick, onSuccess, onCancel)
    })(onSuccess, onCancel)
  })
}

function do_change_nickname(nick, onSuccess, onCancel = null)
{
  local taskId = ::char_change_nick(nick)
  local onError = (@(onSuccess, onCancel) function(res) {
    dagor.debug("Change nickname error: " + res)
    ::change_nickname(onSuccess, onCancel)
  })(onSuccess, onCancel)

  ::g_tasker.addTask(taskId, {showProgressBox = true}, onSuccess, onError)
}
