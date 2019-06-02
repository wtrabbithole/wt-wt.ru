local actions = persist("actions", @() {})
local refreshedActionsIds = {}

local function register(actionId, action) {
  if (actionId in refreshedActionsIds) {
    ::assert(false, "Persist action {0} already registered".subst(actionId))
    return
  }

  refreshedActionsIds[actionId] <- true
  actions[actionId] <- action
}

local function make(actionId, params) {
  ::assert(actionId in refreshedActionsIds, "Not registered persist action " + actionId)
  return @() actions?[actionId](params)
}

return {
  register = register
  make = make
}