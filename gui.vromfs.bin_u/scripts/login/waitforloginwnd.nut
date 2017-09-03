class ::gui_handlers.WaitForLoginWnd extends ::BaseGuiHandler
{
  sceneBlkName = "gui/login/waitForLoginWnd.blk"

  function initScreen()
  {
    updateText()
  }

  function updateText()
  {
    local text = ""
    if (!(::g_login.curState & LOGIN_STATE.MATCHING_CONNECTED))
      text = ::loc("yn1/connecting_msg")
    else if (!(::g_login.curState & LOGIN_STATE.CONFIGS_INITED))
      text = ::loc("loading")
    scene.findObject("msgText").setValue(text)
  }

  function updateVisibility()
  {
    local isVisible = isSceneActiveNoModals()
    scene.findObject("root-box").show(isVisible)
  }

  function onEventLoginStateChanged(p)
  {
    updateText()
  }

  function onEventHangarModelLoaded(params)
  {
    ::enableHangarControls(true)
  }

  function onEventActiveHandlersChanged(p)
  {
    updateVisibility()
  }
}
