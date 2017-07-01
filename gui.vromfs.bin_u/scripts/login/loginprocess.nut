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
    {
      local hClass = ::gui_handlers.LoginWndHandler
      if (::is_platform_ps4)
        hClass = ::gui_handlers.LoginWndHandlerPs4
      else if (::use_tencent_login())
        hClass = ::gui_handlers.LoginWndHandlerTencent
      else if (::use_dmm_login())
        hClass = ::gui_handlers.LoginWndHandlerDMM
      /*
        else if (::steam_is_running()
            && (!::load_local_custom_settings("loggedInOnce", false) //new user
                || ::load_local_custom_settings("showNewSteamLogin", false))) //old, with activation
          hClass = ::gui_handlers.LoginWndHandlerSteam
      */
      ::handlersManager.loadHandler(hClass)
    }
    else if (curProgress == LOGIN_PROGRESS.CONNECT_TO_MATCHING_AND_INIT_CONFIGS)
    {
      //initConfigs
      local cb = ::Callback(function()
                 {
                   addState(LOGIN_STATE.CONFIGS_INITED)
                 }, ::g_login)
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
