function embedded_browser_event(event_type, url, error_desc, error_code,
  is_main_frame)
{
  ::broadcastEvent(
    "EmbeddedBrowser",
    { eventType = event_type, url = url, errorDesc = error_desc,
    errorCode = error_code, isMainFrame = is_main_frame }
  );
}

function is_builtin_browser_active()
{
  return ::isHandlerInScene(::gui_handlers.BrowserModalHandler)
}

function open_browser_modal(url="")
{
  ::gui_start_modal_wnd(::gui_handlers.BrowserModalHandler, {url = url})
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

class ::gui_handlers.BrowserModalHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/browser.blk"
  sceneNavBlkName = null
  url = ""

  function initScreen()
  {
    local browserObj = scene.findObject("browser_area")
    browserObj.url=url
    browserObj.select()
  }

  function browserCloseAndUpdateEntitlements()
  {
    taskId = ::update_entitlements_limited()

    if (taskId >= 0)
    {
      ::set_char_cb(this, slotOpCb)
      showTaskProgressBox(::loc("charServer/checking"))
      afterSlotOp = function()
      {
        ::update_gamercards()
        dagor.debug("Updated entitlements after embedded browser was closed")
      }
    }

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
    local url = ::browser_get_current_url();

    if (!url || url == "")
    {
      dagor.debug("Could not get URL from embedded browser");
      return;
    }

    ::open_url(url, true, false, "internal_browser")
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
        showInfoMsgBox(::loc("browser/error_cant_download"));
        break;
      case ::BROWSER_EVENT_BEGIN_LOADING_FRAME:
        if (params.isMainFrame)
          toggleWaitAnimation(true)
        break;
      case ::BROWSER_EVENT_FINISH_LOADING_FRAME:
        if (params.isMainFrame)
          toggleWaitAnimation(false)
        break;
      default:
        dagor.debug("onEventEmbeddedBrowser: unknown event type "
          + params.eventType);
        break;
    }
  }

  function toggleWaitAnimation(show)
  {
    local waitSpinner = scene.findObject("browserWaitAnimation");

    if (::checkObj(waitSpinner))
      waitSpinner.show(show);
  }

  function onDestroy()
  {
    ::on_facebook_destroy_waitbox()
    ::broadcastEvent("DestroyEmbeddedBrowser")
  }
}
