const MATCHING_CONNECT_TIMEOUT = 30

enum REASON_DOMAIN {
  MATCHING = "matching"
  CHAR = "char"
  AUTH = "auth"
}

::g_matching_connect <- {
  progressBox = null

  //callbacks for single connect request
  onConnectCb = null
  onDisconnectCb = null
}

function g_matching_connect::onConnect(params = null)
{
  destroyProgressBox()
  if (onConnectCb) onConnectCb()
  resetCallbacks()

  //matching not save player info on diconnect (lobby, squad, queue)
  ::broadcastEvent("MatchingConnect")
}

function g_matching_connect::onDisconnect(params = null)
{
  //we still trying to reconnect after this event
  ::broadcastEvent("MatchingDisconnect")
}

function g_matching_connect::onFailToReconnect()
{
  destroyProgressBox()
  if (onDisconnectCb) onDisconnectCb()
  resetCallbacks()
}

function g_matching_connect::connect(successCb = null, errorCb = null, needProgressBox = true)
{
  if (::is_connected_to_matching())
  {
    if (successCb) successCb()
    return
  }

  onConnectCb = successCb
  onDisconnectCb = errorCb

  if (needProgressBox)
  {
    local cancelFunc = function()
    {
      ::scene_msg_box("no_online_warning", null, ::loc("mainmenu/noOnlineWarning"),
        [["ok", function() { ::g_matching_connect.onDisconnect() }]],
        "ok")
    }
    showProgressBox(cancelFunc)
  }
  ::connect_to_matching()
}

function g_matching_connect::resetCallbacks()
{
  onConnectCb = null
  onDisconnectCb = null
}

function g_matching_connect::showProgressBox(cancelFunc = null)
{
  if (::checkObj(progressBox))
    return
  progressBox = ::scene_msg_box("matching_connect_progressbox",
                                null,
                                ::loc("yn1/connecting_msg"),
                                [["cancel", cancelFunc || function(){}]],
                                "cancel",
                                { waitAnim = true,
                                  delayedButtons = MATCHING_CONNECT_TIMEOUT
                                })
}

function g_matching_connect::destroyProgressBox()
{
  if(::checkObj(progressBox))
  {
    progressBox.getScene().destroyElement(progressBox)
    ::broadcastEvent("ModalWndDestroy")
  }
  progressBox = null
}

// special handlers for char errors that require more complex actions than
// showing message box and logout
function g_matching_connect::checkSpecialCharErrors(error)
{
  if (error == ::ERRCODE_EMPTY_NICK)
  {
    if (::is_vendor_tencent())
    {
      ::change_nickname(::Callback(
                          function() {
                            connect(onConnectCb, onDisconnectCb)
                          },
                          this
                        )
                       )
      return true
    }
  }
  return false
}

function g_matching_connect::logoutWithMsgBox(reason, message, reasonDomain, forceExit = false)
{
  if (reasonDomain == REASON_DOMAIN.CHAR)
    if (checkSpecialCharErrors(reason))
      return

  onFailToReconnect()

  local needExit = forceExit
  if (!needExit) //logout
  {
    local handler = ::handlersManager.getActiveBaseHandler()
    if (!("isDelayedLogoutOnDisconnect" in handler)
        || !handler.isDelayedLogoutOnDisconnect())
      needExit = !doLogout()
  }

  local btnName = needExit ? "exit" : "ok"
  local msgCb = needExit ? ::exit_game : function() {}

  ::error_message_box("yn1/connect_error", reason,
    [[ btnName, msgCb]], btnName,
    { saved = true, cancel_fn = msgCb}, message)
}

function g_matching_connect::exitWithMsgBox(reason, message, reasonDomain)
{
  logoutWithMsgBox(reason, message, reasonDomain, true)
}

function g_matching_connect::doLogout()
{
  if (!::can_logout())
    return false

  ::gui_start_logout()
  return true
}