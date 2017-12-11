enum LOGIN_STATE //bit mask
{
  AUTHORIZED               = 0x0001 //succesfully connected to auth
  PROFILE_RECEIVED         = 0x0002
  CONFIGS_RECEIVED         = 0x0004
  MATCHING_CONNECTED       = 0x0008
  CONFIGS_INITED           = 0x0010
  ONLINE_BINARIES_INITED   = 0x0020
  HANGAR_LOADED            = 0x0040

  //masks
  NOT_LOGGED_IN            = 0x0000
  LOGGED_IN                = 0x003F //logged in to all hosts and all configs are loaded
}

::g_login <- {
  [PERSISTENT_DATA_PARAMS] = ["curState", "curLoginProcess"]

  curState = LOGIN_STATE.NOT_LOGGED_IN
  curLoginProcess = null

  onAuthorizeChanged = function() {}
  onLoggedInChanged  = function() {}
  loadLoginHandler   = function() {}
  initConfigs        = function(cb) { cb() }
}

function g_login::init()
{
  ::g_script_reloader.registerPersistentDataFromRoot("g_login")
  ::subscribe_handler(this, ::g_listener_priority.CONFIG_VALIDATION)
}

function g_login::isAuthorized()
{
  return (curState & LOGIN_STATE.AUTHORIZED) != 0
}

function g_login::isReadyToFullLoad()
{
  return hasState(LOGIN_STATE.AUTHORIZED | LOGIN_STATE.ONLINE_BINARIES_INITED)
}

function g_login::isLoggedIn()
{
  return (curState & LOGIN_STATE.LOGGED_IN) == LOGIN_STATE.LOGGED_IN
}

function g_login::isProfileReceived()
{
  return (curState & LOGIN_STATE.PROFILE_RECEIVED) != 0
}

function g_login::hasState(state)
{
  return (curState & state) == state
}

function g_login::startLoginProcess()
{
  if (curLoginProcess && curLoginProcess.isValid())
    return
  curLoginProcess = ::LoginProcess()
}

function g_login::setState(newState)
{
  if (curState == newState)
    return

  local wasAuthorized = isAuthorized()
  local wasLoggedIn = isLoggedIn()

  curState = newState
  ::second_mainmenu <- !isLoggedIn() //compatibility with 1.59.2.X and below

  if (wasAuthorized != isAuthorized())
    onAuthorizeChanged()
  if (wasLoggedIn != isLoggedIn())
    onLoggedInChanged()

  ::broadcastEvent("LoginStateChanged")
}

function g_login::addState(statePart)
{
  setState(curState | statePart)
}

function g_login::removeState(statePart)
{
  setState(curState & ~statePart)
}

function g_login::destroyLoginProgress()
{
  if (curLoginProcess)
    curLoginProcess.destroy()
  curLoginProcess = null
}

function g_login::reset()
{
  destroyLoginProgress()
  setState(LOGIN_STATE.NOT_LOGGED_IN)
}

function g_login::onEventScriptsReloaded(p)
{
  if (!isLoggedIn() && isAuthorized())
    startLoginProcess()
}


function is_logged_in() //used from code
{
  return ::g_login.isLoggedIn()
}

::cross_call_api.login <- ::g_login
