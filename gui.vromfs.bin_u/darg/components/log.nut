local makeLog = function (log_state) {
  local scrollHandler = ::ScrollHandler()
  local scrolledTo = null
  return {
    state = log_state
    scrollHandler = scrollHandler
    log = function (container_ctor, message_component) {
      local containerInst = container_ctor()
      return containerInst.patchComponent(function (comp) {
        return function () {
          local result = comp
          if (typeof comp == "function") {
            result = comp()
          }

          local messages = log_state.value.map(message_component)
          result.flow <- FLOW_VERTICAL
          result.children <- extend_to_array(result?.children, messages)
          result.watch <- extend_to_array(result?.watch, log_state)
          result.behavior <- Behaviors.RecalcHandler
          result.onRecalcLayout <- function(elem, initial) {
            local scrollTo = log_state.value.len() ? log_state.value.top() : null
            if (scrollTo && scrollTo != scrolledTo) {
              scrolledTo = scrollTo
              scrollHandler.scrollToChildren(@(desc) desc?.key == scrollTo, 2, false, true)
            }
          }
          return result
        }
      })
    }
  }
}


return {
  makeLog = makeLog
}
