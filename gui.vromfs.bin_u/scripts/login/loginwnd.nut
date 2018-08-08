const MAX_GET_2STEP_CODE_ATTEMPTS = 10

class ::gui_handlers.LoginWndHandler extends ::BaseGuiHandler
{
  sceneBlkName = "gui/loginBox.blk"

  check2StepAuthCode = false
  availableCircuitsBlockName = "multipleAvailableCircuits"
  paramName = "circuit"
  shardItems = null
  localizationInfo = null

  initial_autologin = false
  stoken = "" //note: it's safe to keep it here even if it's dumped to log
  was_using_stoken = false
  isLoginRequestInprogress = false
  requestGet2stepCodeAtempt = 0

  tabFocusArray = [
    "loginbox_username",
    "loginbox_password",
    "loginbox_code"
  ]

  focusArray = [
    "loginbox_username",
    "loginbox_password",
    "loginbox_code",
    "loginbox_code_remember_this_device",
    "login_boxes_block",
    "sharding_dropright_block",
    "login_action",
    "links_block"
  ]
  currentFocusItem = 0

  function initScreen()
  {
    ::g_anim_bg.load()
    ::setVersionText()
    ::setProjectAwards(this)
    ::show_title_logo(true, scene, "128")
    initLanguageSwitch()
    checkShardingCircuits()
    ::set_gui_options_mode(::OPTIONS_MODE_GAMEPLAY)

    ::enable_keyboard_layout_change_tracking(true)
    ::enable_keyboard_locks_change_tracking(true)

    local bugDiscObj = scene.findObject("browser_bug_disclaimer")
    if (::checkObj(bugDiscObj))
      bugDiscObj.show(::target_platform == "linux64" && ::is_steam_big_picture()) //STEAM_OS

    local lp = ::get_login_pass()
    local isVietnamese = ::is_vietnamese_version()
    if (isVietnamese)
      lp.autoSave = lp.autoSave & 1

    local disableSSLCheck = lp.autoSave & 8

    local unObj = scene.findObject("loginbox_username")
    if (::checkObj(unObj))
      unObj.setValue(lp.login)

    local psObj = scene.findObject("loginbox_password")
    if (::checkObj(psObj))
      psObj.setValue(lp.password)

    local alObj = scene.findObject("loginbox_autosave_login")
    if (::checkObj(alObj))
      alObj.setValue(lp.autoSave & 1)

    local spObj = scene.findObject("loginbox_autosave_password")
    if (::checkObj(spObj))
    {
      spObj.show(!isVietnamese)
      spObj.setValue(lp.autoSave & 2)
      spObj.enable(lp.autoSave & 1 && !isVietnamese)
      local text = ::loc("mainmenu/savePassword")
      if (!::is_platform_shield_tv())
        text += " " + ::loc("mainmenu/savePassword/unsecure")
      spObj.findObject("loginbox_autosave_password_text").setValue(text)
    }

    setDisableSslCertBox(disableSSLCheck)
    showSceneBtn("steam_login_action_button", ::steam_is_running())

    if (lp.login != "")
      currentFocusItem = 1
    initFocusArray()

    initial_autologin = ::is_autologin_enabled()

    local autoLoginEnable = lp.autoSave & 1 && lp.autoSave & 2
    local autoLogin = initial_autologin && autoLoginEnable
    local autoLoginObj = scene.findObject("loginbox_autologin")
    if (::checkObj(autoLoginObj))
    {
      autoLoginObj.show(!isVietnamese)
      autoLoginObj.enable(autoLoginEnable)
      autoLoginObj.setValue(autoLogin)
    }

    showSceneBtn("links_block", !::is_platform_shield_tv())

    if ("dgs_get_argv" in ::getroottable())
    {
      local s = ::dgs_get_argv("stoken")
      if (!::u.isEmpty(s))
        lp.stoken <- s
    }
    else if ("dgs_argc" in ::getroottable())
      for (local i = 1; i < ::dgs_argc(); i++)
      {
        local str = ::dgs_argv(i);
        local idx = str.find("-stoken:")
        if (idx != null)
          lp.stoken <- str.slice(idx+8)
      }

    if (("stoken" in lp) && lp.stoken != null && lp.stoken != "")
    {
      stoken = lp.stoken
      doLoginDelayed()
      return
    }

    if ("disable_autorelogin_once" in ::getroottable())
      autoLogin = autoLogin && !disable_autorelogin_once
    if (autoLogin)
      doLoginDelayed()
  }

  function onDestroy()
  {
    ::enable_keyboard_layout_change_tracking(false)
    ::enable_keyboard_locks_change_tracking(false)
  }

  function setDisableSslCertBox(value)
  {
    local dcObj = showSceneBtn("loginbox_disable_ssl_cert", value)
    if (::checkObj(dcObj))
      dcObj.setValue(value)
  }

  function checkShardingCircuits()
  {
    local defValue = 0
    local networkBlk = ::get_network_block()
    local avCircuits = networkBlk.getBlockByName(availableCircuitsBlockName)

    local configCircuitName = ::get_cur_circuit_name()
    shardItems = [{
                    item = configCircuitName
                    text = ::loc("circuit/" + configCircuitName)
                 }]

    if (avCircuits && avCircuits.paramCount() > 0)
    {
      local defaultCircuit = ::loc("default_circuit", "")
      if (defaultCircuit == "")
        defaultCircuit = configCircuitName

      shardItems = []
      for(local i = 0; i < avCircuits.paramCount(); ++i)
      {
        local param = avCircuits.getParamName(i)
        local value = avCircuits.getParamValue(i)
        if (param == paramName && typeof(value) == "string")
        {
          if (value == defaultCircuit)
            defValue = i

          shardItems.append({
                              item = value
                              text = ::loc("circuit/" + value)
                           })
        }
      }
    }

    local show = shardItems.len() > 1
    local shardObj = showSceneBtn("sharding_block", show)
    if (show && ::checkObj(shardObj))
    {
      local dropObj = shardObj.findObject("sharding_dropright_block")
      local shardData = ::create_option_combobox("sharding_list", shardItems, defValue, null, true)
      guiScene.replaceContentFromText(dropObj, shardData, shardData.len(), this)
    }
  }

  function onChangeAutosave()
  {
    local remoteCompObj = scene.findObject("loginbox_remote_comp")
    local rememberDeviceObj = scene.findObject("loginbox_code_remember_this_device")
    local savePassObj = scene.findObject("loginbox_autosave_password")
    local saveLoginObj = scene.findObject("loginbox_autosave_login")
    local autoLoginObj = scene.findObject("loginbox_autologin")
    local disableCertObj = scene.findObject("loginbox_disable_ssl_cert")

    if (rememberDeviceObj.isVisible())
      remoteCompObj.setValue(!rememberDeviceObj.getValue())
    else
      rememberDeviceObj.setValue(!remoteCompObj.getValue())

    local isRemoteComp = remoteCompObj.getValue()
    local isAutosaveLogin = saveLoginObj.getValue()
    local isAutosavePass = savePassObj.getValue()

    setDisableSslCertBox(disableCertObj.getValue())

    saveLoginObj.enable(!isRemoteComp)
    savePassObj.enable(!isRemoteComp && isAutosaveLogin && !::is_vietnamese_version())
    autoLoginObj.enable(!isRemoteComp && isAutosaveLogin && isAutosavePass)

    if (isRemoteComp)
      saveLoginObj.setValue(false)
    if (isRemoteComp || !isAutosaveLogin)
      savePassObj.setValue(false)
    if (isRemoteComp || !isAutosavePass || !isAutosaveLogin)
      autoLoginObj.setValue(false)

    restoreFocus() //In case, if user leave focus on disabled checkBox
  }

  function initLanguageSwitch()
  {
    local canSwitchLang = ::canSwitchGameLocalization()
    showSceneBtn("language_selector", canSwitchLang)
    if (!canSwitchLang)
      return

    localizationInfo = localizationInfo || ::g_language.getGameLocalizationInfo()
    local curLangId = ::get_current_language()
    local lang = localizationInfo[0]
    foreach (l in localizationInfo)
      if (l.id == curLangId)
        lang = l

    local objLangLabel = scene.findObject("label_language")
    if (::checkObj(objLangLabel))
    {
      local title = ::loc("profile/language")
      local titleEn = ::loc("profile/language/en")
      title += (title == titleEn ? "" : ::loc("ui/parentheses/space", { text = titleEn })) + ":"
      objLangLabel.setValue(title)
    }
    local objLangIcon = scene.findObject("btn_language_icon")
    if (::checkObj(objLangIcon))
      objLangIcon["background-image"] = lang.icon
    local objLangName = scene.findObject("btn_language_text")
    if (::checkObj(objLangName))
      objLangName.setValue(lang.title)
  }

  function onPopupLanguages(obj)
  {
    if (::gui_handlers.ActionsList.hasActionsListOnObject(obj))
      return onClosePopups()

    localizationInfo = localizationInfo || ::g_language.getGameLocalizationInfo()
    if (!::checkObj(obj) || localizationInfo.len() < 2)
      return

    local curLangId = ::get_current_language()
    local menu = {
      handler = this
      actions = []
    }
    for (local i = 0; i < localizationInfo.len(); i++)
    {
      local lang = localizationInfo[i]
      menu.actions.append({
        actionName  = lang.id
        text        = lang.title
        icon        = lang.icon
        action      = (@(lang) function () { onChangeLanguage(lang.id) })(lang)
        selected    = lang.id == curLangId
      })
    }
    ::gui_handlers.ActionsList.open(obj, menu)
  }

  function onClosePopups()
  {
    local obj = scene.findObject("btn_language")
    if (::checkObj(obj))
      ::gui_handlers.ActionsList.removeActionsListFromObject(obj, true)
  }

  function onChangeLanguage(langId)
  {
    local no_dump_login = scene.findObject("loginbox_username").getValue() || ""
    local no_dump_pass = scene.findObject("loginbox_password").getValue() || ""
    local no_dump_code = scene.findObject("loginbox_code").getValue() || ""
    local isRemoteComp = scene.findObject("loginbox_remote_comp").getValue()
    local code_remember_this_device = scene.findObject("loginbox_code_remember_this_device").getValue()
    local isAutosaveLogin = scene.findObject("loginbox_autosave_login").getValue()
    local isAutosavePass = scene.findObject("loginbox_autosave_password").getValue()
    local autologin = scene.findObject("loginbox_autologin").getValue()
    local shardingListObj = scene.findObject("sharding_list")
    local shard = shardingListObj ? shardingListObj.getValue() : -1

    ::g_language.setGameLocalization(langId, true, true)

    local handler = ::handlersManager.findHandlerClassInScene(::gui_handlers.LoginWndHandler)
    scene = handler ? handler.scene : null
    if (!::checkObj(scene))
      return

    scene.findObject("loginbox_username").setValue(no_dump_login)
    scene.findObject("loginbox_password").setValue(no_dump_pass)
    scene.findObject("loginbox_code").setValue(no_dump_code)
    scene.findObject("loginbox_remote_comp").setValue(isRemoteComp)
    scene.findObject("loginbox_code_remember_this_device").setValue(code_remember_this_device)
    scene.findObject("loginbox_autosave_login").setValue(isAutosaveLogin)
    scene.findObject("loginbox_autosave_password").setValue(isAutosavePass)
    scene.findObject("loginbox_autologin").setValue(autologin)
    handler.onChangeAutosave()
    if (shardingListObj)
      shardingListObj.setValue(shard)

    restoreFocus()
  }

  function isTryLinkSteamAccount()
  {
    return ::steam_is_running() && !::load_local_account_settings("usedSteamLinkAccountOnce", false)
  }

  function requestLogin(no_dump_login)
  {
    return requestLoginWithCode(no_dump_login, check2StepAuthCode? ::get_object_value(scene, "loginbox_code", "") : "");
  }

  function requestLoginWithCode(no_dump_login, code)
  {
    ::statsd_counter("gameStart.request_login.regular")
    ::dagor.debug("Login: check_login_pass")
    return ::check_login_pass(no_dump_login,
                              ::get_object_value(scene, "loginbox_password", ""),
                              check2StepAuthCode? "" : stoken, //after trying use stoken it's set to "", but to be sure - use "" for 2stepAuth
                              code,
                              check2StepAuthCode
                                ? ::get_object_value(scene, "loginbox_code_remember_this_device", false)
                                : !::get_object_value(scene, "loginbox_disable_ssl_cert", false),
                              ::get_object_value(scene, "loginbox_remote_comp", false)
                             )
  }

  function checkSteamActivation(no_dump_login)
  {
    local loggedInOnce = ::load_local_account_settings("loggedInOnce", false)
    if (loggedInOnce != true)
    {
      ::save_local_account_settings("loggedInOnce", true)
      ::skip_steam_confirmations = true
    }

    if (::steam_is_running())
      ::save_local_account_settings("showNewSteamLogin", true)

    if (::check_account_tag("wt_steam"))
      ::skip_steam_confirmations = true

    local activate = (@(no_dump_login) function() {
      local ret = ::steam_do_activation()
      if (ret > 0)
      {
        local errorText = ""
        if (ret == ::YU2_NOT_OWNER)
          errorText = ::loc("steam/dlc_activated_error")
        else if (ret == ::YU2_PSN_RESTRICTED)
          errorText = ::loc("yn1/error/PSN_RESTRICTED")
        else
          errorText = ::loc("charServer/notAvailableYet")

        msgBox("steam", errorText,
          [["ok", (@(no_dump_login) function() {continueLogin(no_dump_login)})(no_dump_login) ]], "ok")
        ::dagor.debug("steam_do_activation have returned " + ret)
      }
      else
        continueLogin(no_dump_login)
    })(no_dump_login)

    if (::steam_is_running() && ::steam_need_activation() &&
      (!("is_gui_about_to_reload" in getroottable()) || ! ::is_gui_about_to_reload()))
    {
      if (::skip_steam_confirmations)
      {
        activate()
      }
      else msgBox("steam", ::loc("steam/ask_dlc_activate"),
        [
          ["yes", (@(activate) function() {
            activate()
          })(activate) ],
          ["no", (@(no_dump_login) function() { continueLogin(no_dump_login) })(no_dump_login) ]
        ], "yes")
    }
    else
      continueLogin(no_dump_login)
  }

  function continueLogin(no_dump_login)
  {
    if (shardItems)
    {
      if (shardItems.len() == 1)
        ::set_network_circuit(shardItems[0].item)
      else if (shardItems.len() > 1)
        ::set_network_circuit(shardItems[scene.findObject("sharding_list").getValue()].item)
    }

    local autoSaveLogin = ::get_object_value(scene, "loginbox_autosave_login", false)
    local autoSavePassword = ::get_object_value(scene, "loginbox_autosave_password", false)
    local disableSSLCheck = ::get_object_value(scene, "loginbox_disable_ssl_cert", false)
    local autoSave = (autoSaveLogin ? 1 : 0) + (autoSavePassword  ? 2 : 0) + (disableSSLCheck ? 8 : 0)

    if (was_using_stoken)
      autoSave = autoSave | 4

    ::set_login_pass(no_dump_login.tostring(), ::get_object_value(scene, "loginbox_password", ""), autoSave)

    if (!::checkObj(scene)) //set_login_pass start onlineJob
      return

    local autoLogin = (autoSaveLogin && autoSavePassword) ? scene.findObject("loginbox_autologin").getValue() : false
    ::set_autologin_enabled(autoLogin)
    if (initial_autologin != autoLogin)
      ::save_profile(false)

    ::g_login.addState(LOGIN_STATE.AUTHORIZED)
  }

  function onOk()
  {
    isLoginRequestInprogress = true
    requestGet2stepCodeAtempt = MAX_GET_2STEP_CODE_ATTEMPTS
    doLoginWaitJob()
  }

  function doLoginDelayed()
  {
    isLoginRequestInprogress = true
    guiScene.performDelayed(this, doLoginWaitJob)
  }

  function doLoginWaitJob()
  {
    ::disable_autorelogin_once <- false
    local no_dump_login = ::get_object_value(scene, "loginbox_username", "")

    no_dump_login = ::validate_email(no_dump_login)

    if (no_dump_login == null) //can be null after validate_email
      no_dump_login = ""

    if (no_dump_login == "" && (stoken == ""))  //invalid email
    {
      local locId = "msgbox/invalidEmail"
      msgBox("invalid_email", ::loc(locId),
        [["ok", ::Callback(function()
                {
                  local focusObj = scene.findObject("loginbox_username")
                  if (::check_obj(focusObj))
                    focusObj.select()
                }, this)
        ]], "ok")
      return
    }

    local result = requestLogin(no_dump_login)
    proceedAuthorizationResult(result, no_dump_login)
  }

  function onSteamAuthorization()
  {
    isLoginRequestInprogress = true
    ::disable_autorelogin_once <- false
    ::statsd_counter("gameStart.request_login.steam")
    ::dagor.debug("Steam Login: check_login_pass")
    local result = ::check_login_pass("", "", "steam", "steam", false, false)
    proceedAuthorizationResult(result, "")
  }

  function proceedGetTwoStepCode(data)
  {
    if (!isValid() || isLoginRequestInprogress)
    {
      return
    }

    local result = data.status
    local code = data.code
    local codeInBox = ::get_object_value(scene, "loginbox_code", "");
    local no_dump_login = ::get_object_value(scene, "loginbox_username", "")

    if (result == YU2_TIMEOUT && codeInBox == "" && requestGet2stepCodeAtempt-- > 0)
    {
      doLoginDelayed()
      return
    }

    if (result == ::YU2_OK)
    {
      isLoginRequestInprogress = true
      local loginResult = requestLoginWithCode(no_dump_login, code)
      proceedAuthorizationResult(loginResult, no_dump_login)
    }
  }

  function proceedAuthorizationResult(result, no_dump_login)
  {
    isLoginRequestInprogress = false
    if (!::checkObj(scene)) //check_login_pass is not instant
      return

    was_using_stoken = (stoken != "")
    stoken = ""
    switch (result)
    {
      case ::YU2_OK:
        if (isTryLinkSteamAccount())
        {
          local isRemoteComp = scene.findObject("loginbox_remote_comp").getValue()
          ::statsd_counter("gameStart.request_login.steam_link")
          ::dagor.debug("Steam Link Login: check_login_pass")
          local res = ::check_login_pass("", "", "steam", "steam", true, isRemoteComp)
          ::dagor.debug("Steam: link existing account, result = " + res)
          if (res == ::YU2_OK || res == ::YU2_ALREADY)
            ::save_local_account_settings("usedSteamLinkAccountOnce", true)
        }
        checkSteamActivation(no_dump_login)
        break

      case ::YU2_2STEP_AUTH: //error, received if user not logged, because he have 2step authorization activated
        {
          check2StepAuthCode = true
          showSceneBtn("authorization_code_block", true)
          showSceneBtn("loginbox_code_remember_this_device", true)
          showSceneBtn("loginbox_remote_comp", false)
          onChangeAutosave()
          guiScene.performDelayed(this, (@(scene) function() {
            if (!::checkObj(scene))
              return

            scene.findObject("loginbox_code").select();
            currentFocusItem = 2
            ::get_two_step_code_async(this, proceedGetTwoStepCode)
          })(scene))
        }
        break

      case ::YU2_PSN_RESTRICTED:
        {
          msgBox("psn_restricted", ::loc("yn1/login/PSN_RESTRICTED"),
             [["exit", ::exit_game ]], "exit")
        }
        break;

      case ::YU2_WRONG_LOGIN:
      case ::YU2_WRONG_PARAMETER:
        if (was_using_stoken)
          return;
        ::error_message_box("yn1/connect_error", result, // auth error
        [
          ["recovery", function() {::open_url(::loc("url/recovery"), false, false, "login_wnd")}],
          ["exit", ::exit_game],
          ["tryAgain", function(){}]
        ], "tryAgain")
        break

      case ::YU2_SSL_CACERT:
        if (was_using_stoken)
          return;
        ::error_message_box("yn1/connect_error", result,
        [
          ["disableSSLCheck", ::Callback(function() { setDisableSslCertBox(true) }, this)],
          ["exit", ::exit_game],
          ["tryAgain", function(){}]
        ], "tryAgain")
        break

        break

      default:
        if (was_using_stoken)
          return;
        ::error_message_box("yn1/connect_error", result,
        [
          ["exit", ::exit_game],
          ["tryAgain", function(){}]
        ], "tryAgain")
    }
  }

  function onSelectAction(obj)
  {
    local value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return

    local chObj = obj.getChild(value)
    local func = chObj._on_click
    if (func in this)
      this[func]()
  }

  function switchTabFocus()
  {
    checkCurrentFocusItem(guiScene.getSelectedObject())

    local focusIdx = tabFocusArray.len() - 1
    foreach(idx, id in tabFocusArray)
    {
      if (tabFocusArray[idx] == focusArray[currentFocusItem])
      {
        focusIdx = idx
        break
      }
    }

    switchFocusOnNextObj(focusIdx)
  }

  function switchFocusOnNextObj(focusIdx = 0)
  {
    if (focusIdx >= tabFocusArray.len() - 1)
      focusIdx = 0
    else
      focusIdx++

    if (!::check_obj(scene))
      return

    local focusObj = scene.findObject(tabFocusArray[focusIdx])
    if (!::checkObj(focusObj) || !focusObj.isVisible())
      return switchFocusOnNextObj(focusIdx)

    focusObj.select()
  }

  function onEventKeyboardLayoutChanged(params)
  {
    local layoutIndicator =
      scene.findObject("loginbox_password_layout_indicator")

    if (!::checkObj(layoutIndicator))
      return

    local layoutCode = params.layout.toupper()
    if (layoutCode.len() > 2)
      layoutCode = layoutCode.slice(0, 2)

    layoutIndicator.setValue(layoutCode)
  }

  function onEventKeyboardLocksChanged(params)
  {
    local capsIndicator =
      scene.findObject("loginbox_password_caps_indicator")

    capsIndicator.show((params.locks & 1) == 1)
  }

  function onSignUp()
  {
    local urlLocId
    if (::steam_is_running())
      urlLocId = "url/signUpSteam"
    else if (::is_platform_shield_tv())
      urlLocId = "url/signUpShieldTV"
    else
      urlLocId = "url/signUp"

    ::open_url(::loc(urlLocId), false, false, "login_wnd")
  }

  function onForgetPassword()
  {
    ::open_url(::loc("url/recovery"), false, false, "login_wnd")
  }

  function onDoneEnter()
  {
    if (check2StepAuthCode)
    {
      local cObj = scene.findObject("loginbox_code")
      if (::checkObj(cObj))
        cObj.select()
      return
    }
    doLoginWaitJob()
  }

  function onDoneCode()
  {
    doLoginWaitJob()
  }

  function onExit()
  {
    /*
    if (::steam_is_running())
      return ::handlersManager.loadHandler(::gui_handlers.LoginWndHandlerSteam)
*/
    msgBox("login_question_quit_game", ::loc("mainmenu/questionQuitGame"),
      [
        ["yes", ::exit_game],
        ["no"]
      ], "no", { cancel_fn = function() {}})
  }

  function goBack()
  {
    onExit()
  }
}
