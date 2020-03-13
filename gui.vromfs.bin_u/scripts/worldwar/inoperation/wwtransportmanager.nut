local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")

local cachedLoadedTransport = null
local function getLoadedTransport() {
  if (cachedLoadedTransport != null)
    return cachedLoadedTransport?.loadedTransport ?? {}

  local blk = ::DataBlock()
  ::ww_get_loaded_transport(blk)
  cachedLoadedTransport = blk
  return cachedLoadedTransport?.loadedTransport ?? {}
}

local clearCacheLoadedTransport = @() cachedLoadedTransport = null

local function isEmptyTransport(armyName) {
  return !(armyName in getLoadedTransport())
}

local function isFullLoadedTransport(armyName) {
  return armyName in getLoadedTransport()
}

subscriptions.addListenersWithoutEnv({
  WWLoadOperation = @(p) clearCacheLoadedTransport()
})

return {
  getLoadedTransport = getLoadedTransport
  isEmptyTransport = isEmptyTransport
  isFullLoadedTransport = isFullLoadedTransport
}