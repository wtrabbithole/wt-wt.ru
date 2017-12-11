local log = require("log.nut")


local makeInputField = function (form_state, send_function) {
  local send = function () {
    send_function(form_state.value)
    form_state.update("")
  }
  return function (text_input_ctor) {
    return text_input_ctor(form_state, send)
  }
}


local makeChatBlock = function (log_state, send_message_fn) {
  local chatMessageState = Watched("")
  local logInstance = log.makeLog(log_state)

  return {
    form = chatMessageState
    state = log_state
    inputField = makeInputField(chatMessageState, send_message_fn)
    log = logInstance.log
    scrollHandler = logInstance.scrollHandler
  }
}


return makeChatBlock
