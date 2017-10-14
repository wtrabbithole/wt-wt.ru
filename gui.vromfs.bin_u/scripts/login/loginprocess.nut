enum LOGIN_PROGRESS
{
  NOT_STARTED
  IN_LOGIN_WND
  CONNECT_TO_MATCHING_AND_INIT_CONFIGS
  FINISHED
}

class ::LoginProcess
{
  curProgress = LOGIN_PROGRESS.NOT_STARTED

  constructor()
  {
    if (::g_login.isAuthorized()) //if scripts was reloaded from code
      curProgress = LOGIN_PROGRESS.IN_LOGIN_WND

    ::subscribe_handler(this, ::g_listener_priority.LOGIN_PROCESS)
    nextStep()
  }

  function isValid()
  {
    return curProgress != LOGIN_PROGRESS.NOT_STARTED
        && curProgress < LOGIN_PROGRESS.FINISHED
  }

  function nextStep()
  {
    curProgress++

    if (curProgress == LOGIN_PROGRESS.IN_LOGIN_WND)
      ::g_login.loadLoginHandler()
    else if (curProgress == LOGIN_PROGRESS.CONNECT_TO_MATCHING_AND_INIT_CONFIGS)
    {
      //initConfigs
      local cb = ::Callback(function()
                 {
                   ::g_login.addState(LOGIN_STATE.CONFIGS_INITED)
                 }, this)
      ::g_login.initConfigs(cb)

      //connect to matching
      local successCb = ::Callback(function()
                        {
                          ::g_login.addState(LOGIN_STATE.MATCHING_CONNECTED)
                        }, this)
      local errorCb   = ::Callback(function()
                        {
                          destroy()
                        }, this)

      ::g_matching_connect.connect(successCb, errorCb, false)
    }
  }

  function checkNextStep()
  {
    if (curProgress == LOGIN_PROGRESS.IN_LOGIN_WND)
    {
      if (::g_login.isAuthorized())
        nextStep()
    }
    else if (curProgress == LOGIN_PROGRESS.CONNECT_TO_MATCHING_AND_INIT_CONFIGS)
    {
      if (::g_login.isLoggedIn())
        nextStep()
    }
  }

  function onEventLoginStateChanged(p)
  {
    checkNextStep()
  }

  function onEventProfileUpdated(p)
  {
    ::g_login.addState(LOGIN_STATE.PROFILE_RECEIVED | LOGIN_STATE.CONFIGS_RECEIVED)
  }

  function destroy()
  {
    if (isValid())
      curProgress = LOGIN_PROGRESS.NOT_STARTED
  }
}
