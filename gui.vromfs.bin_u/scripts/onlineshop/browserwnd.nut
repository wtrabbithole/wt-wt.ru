function embedded_browser_event(event_type, url, error_desc, error_code,
  is_main_frame)
{
  ::broadcastEvent(
    "EmbeddedBrowser",
    { eventType = event_type, url = url, errorDesc = error_desc,
    errorCode = error_code, isMainFrame = is_main_frame, title = "" }
  );
}

function notify_browser_window(params)
{
  ::broadcastEvent("EmbeddedBrowser", params)
}

function is_builtin_browser_active()
{
  return ::isHandlerInScene(::gui_handlers.BrowserModalHandler)
}

function open_browser_modal(url="", tags=[])
{
  ::gui_start_modal_wnd(::gui_handlers.BrowserModalHandler, {url = url, urlTags = tags})
}

function close_browser_modal()
{
  local handler = ::handlersManager.findHandlerClassInScene(
    ::gui_handlers.BrowserModalHandler);

  if (handler == null)
  {
    dagor.debug("Couldn't find embedded browser modal handler");
    return
  }

  handler.goBack()
}

function browser_set_external_url(url)
{
  local handler = ::handlersManager.findHandlerClassInScene(
    ::gui_handlers.BrowserModalHandler);
  if (handler)
    handler.externalUrl = url;
}

class ::gui_handlers.BrowserModalHandler extends ::BaseGuiHandler
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/browser.blk"
  sceneNavBlkName = null
  url = ""
  externalUrl = ""
  originalUrl = ""
  needVoiceChat = false
  urlTags = []

  function initScreen()
  {
    local browserObj = scene.findObject("browser_area")
    browserObj.url=url
    browserObj.select()
    originalUrl = url
    browser_go(url)
  }

  function browserCloseAndUpdateEntitlements()
  {
    ::g_tasker.addTask(::update_entitlements_limited(),
                       {
                         showProgressBox = true
                         progressBoxText = ::loc("charServer/checking")
                       },
                       @() ::update_gamercards())
    goBack();
  }

  function browserGoBack()
  {
    ::browser_go_back();
  }

  function onBrowserBtnReload()
  {
    ::browser_reload_page();
  }

  function browserForceExternal()
  {
    local taggedUrl = ::browser_get_current_url()
    if (!u.isEmpty(urlTags))
        taggedUrl = ::g_string.implode(urlTags, " ") + " " + taggedUrl
    local url = u.isEmpty(externalUrl) ? taggedUrl : externalUrl
    ::open_url(u.isEmpty(url) ? originalUrl : url, true, false, "internal_browser")
  }

  function setTitle(title)
  {
    if (u.isEmpty(title))
      return;

    local titleObj = scene.findObject("wnd_title")
    if (::checkObj(titleObj))
      titleObj.setValue(title)
  }

  function onEventEmbeddedBrowser(params)
  {
    switch (params.eventType)
    {
      case ::BROWSER_EVENT_DOCUMENT_READY:
        toggleWaitAnimation(false)
        break;
      case ::BROWSER_EVENT_FAIL_LOADING_FRAME:
        if (params.isMainFrame)
        {
          toggleWaitAnimation(false)

          showInfoMsgBox(::loc("browser/error_load_url")
            + " (error code: " + params.errorCode + "): " + params.errorDesc
          );
        }
        break;
      case ::BROWSER_EVENT_NEED_RESEND_FRAME:
        toggleWaitAnimation(false)

        msgBox("error", ::loc("browser/error_should_resend_data"),
            [["#mainmenu/btnBack", browserGoBack()],
             ["#mainmenu/btnRefresh", (@(params) function() { ::browser_go(params.url) })(params)]],
             "#mainmenu/btnBack")
        break;
      case ::BROWSER_EVENT_CANT_DOWNLOAD:
        toggleWaitAnimation(false)
        showInfoMsgBox(::loc("browser/error_cant_download"))
        break;
      case ::BROWSER_EVENT_BEGIN_LOADING_FRAME:
        if (params.isMainFrame)
        {
          toggleWaitAnimation(true)
          setTitle(params.title)
        }
        break;
      case ::BROWSER_EVENT_FINISH_LOADING_FRAME:
        if (params.isMainFrame)
        {
          toggleWaitAnimation(false)
          setTitle(params.title)
        }
        break;
      case ::BROWSER_EVENT_BROWSER_CRASHED:
        statsd_counter("browser." + params.errorDesc)
        msgBox("error", ::loc("browser/crashed"),
            [["#browser/open_external", browserForceExternal],
             ["#mainmenu/btnBack", browserCloseAndUpdateEntitlements]],
             "#browser/open_external")
        break;
      default:
        dagor.debug("onEventEmbeddedBrowser: unknown event type "
          + params.eventType);
        break;
    }
  }

  function onEventWebPollAuthResult(param)
  {
    // WebPollAuthResult event may come before browser opens the page
    local currentUrl = ::u.isEmpty(::browser_get_current_url()) ? url : ::browser_get_current_url()
    if(::u.isEmpty(currentUrl))
      return
    // we have to update externalUrl for any pollId
    // so we don't care about pollId from param
    local pollId = ::g_webpoll.getPollIdByFullUrl(currentUrl)
    if( ! pollId)
      return
    externalUrl = ::g_webpoll.generatePollUrl(pollId, false)
  }

  function toggleWaitAnimation(show)
  {
    local waitSpinner = scene.findObject("browserWaitAnimation");

    if (::checkObj(waitSpinner))
      waitSpinner.show(show);
  }

  function onDestroy()
  {
    ::broadcastEvent("DestroyEmbeddedBrowser")
  }
}
