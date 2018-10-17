local function make(log_state) {
  local scrollHandler = ::ScrollHandler()
  local scrolledTo = null
  return {
    state = log_state
    scrollHandler = scrollHandler
    data = function (container_ctor, message_component) {
      local container = container_ctor()
      return function () {
        local result = (typeof container == "function") ? container() : container
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
    }
  }
}


return {
  make = make
}
