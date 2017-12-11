class ::gui_handlers.WaitForLoginWnd extends ::BaseGuiHandler
{
  sceneBlkName = "gui/login/waitForLoginWnd.blk"
  isBgVisible = false

  function initScreen()
  {
    updateText()
    updateBg()
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

  function updateBg()
  {
    local shouldBgVisible = !(::g_login.curState & LOGIN_STATE.HANGAR_LOADED)
    if (isBgVisible == shouldBgVisible)
      return

    isBgVisible = shouldBgVisible
    local obj = ::showBtn("animated_bg_picture", isBgVisible, scene)
    if (isBgVisible)
      ::g_anim_bg.load("", obj)
  }

  function onEventLoginStateChanged(p)
  {
    updateText()
    updateBg()
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
