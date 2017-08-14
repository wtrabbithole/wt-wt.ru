local extendToArray = function (obj, key, val) {
  if ((key in obj) && obj[key] != null) {
    local arr = (typeof obj[key] == "array") ? obj[key] : [obj[key]]
    if (typeof val == "array") {
      arr.extend(val)
    } else {
      arr.append(val)
    }
    return arr
  } else {
    return typeof val == "array" ? val : [val]
  }
}


local makeInputField = function (form_state, send_function) {
  local send = function () {
    send_function(form_state.value)
    form_state.update("")
  }
  return function (text_input_ctor) {
    return text_input_ctor(form_state, send)
  }
}


local makeLogBox = function (log_state) {
  return function (background_ctor, message_component) {
    return background_ctor.patchComponent(function (comp) {
      return function () {
        local result = comp
        if (typeof comp == "function") {
          result = comp()
        }

        result.flow <- FLOW_VERTICAL
        result.children <- extendToArray(result, "children", log_state.value.map(message_component))
        result.watch <- extendToArray(result, "watch", log_state)
        return result
      }
    })
  }
}


local makeChatBlock = function (log_state, send_message_fn) {
  local chatMessageState = Watched("")

  return {
    form = chatMessageState
    inputField = makeInputField(chatMessageState, send_message_fn)
    logBox = makeLogBox(log_state)
  }
}


return makeChatBlock
