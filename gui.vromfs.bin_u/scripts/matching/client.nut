function on_online_unavailable()
{
  dagor.debug("on_online_unavailable")
  ::g_matching_connect.onDisconnect()
}

function on_online_available()
{
  dagor.debug("on_online_available")
  ::g_matching_connect.onConnect()
}

function logout_with_msgbox(params)
{
  local message = "message" in params ? params["message"] : null
  ::g_matching_connect.logoutWithMsgBox(params.reason, message, params.reasonDomain)
}

function exit_with_msgbox(params)
{
  local message = "message" in params ? params["message"] : null
  ::g_matching_connect.exitWithMsgBox(params.reason, message, params.reasonDomain)
}

function punish_show_tips(params)
{
  dagor.debug("punish_show_tips")
  if ("reason" in params)
    showInfoMsgBox(params.reason)
}

function punish_close_client(params)
{
  dagor.debug("punish_close_client")
  local message = ("reason" in params) ? ::g_language.addLineBreaks(params.reason) : ::loc("matching/hacker_kicked_notice")

  local needFlightMenu = ::is_in_flight() && !::get_is_in_flight_menu() && !::is_flight_menu_disabled()
  if (needFlightMenu)
    ::gui_start_flight_menu()

  ::scene_msg_box(
      "info_msg_box",
      null,
      message,
      [["ok", ::exit_game ]], "exit")
}

/**
requestOptions:
  - showError (defaultValue = true) - show error by checkMatchingError function if it is
**/
function request_matching(functionName, onSuccess = null, onError = null, params = null, requestOptions = null)
{
  local showError = ::getTblValue("showError", requestOptions, true)

  local callback = (@(onSuccess, onError, showError) function(response) {
                     if (!::checkMatchingError(response, showError))
                     {
                       if (onError != null)
                         onError(response)
                     }
                     else if (onSuccess != null)
                      onSuccess(response)
                   })(onSuccess, onError, showError)

  matching_api_func(functionName, callback, params)
}

function checkMatchingError(params, showError = true)
{
  if (params.error == OPERATION_COMPLETE)
    return true

  if (!showError || ::disable_network())
    return false

  local id = "sessionLobby_error"
  local handler = ::get_cur_base_gui_handler()
  local oldMsgBox = handler.guiScene[id]
  if (::checkObj(oldMsgBox))
    handler.guiScene.destroyElement(oldMsgBox)

  local errorId = ::getTblValue("error_id", params) || ::matching.error_string(params.error)

  local text = ::loc("matching/" + g_string.replace(errorId, ".", "_"))
  if ("error_message" in params)
    text = text + "\n<B>"+params.error_message+"</B>"

  local options = { saved = true, cancel_fn = function() {}}
  if ("LAST_SESSION_DEBUG_INFO" in getroottable())
    options["debug_string"] <- ::LAST_SESSION_DEBUG_INFO

  handler.msgBox(id, text,
      [["ok", function() {} ]], "ok", options)
  return false
}

