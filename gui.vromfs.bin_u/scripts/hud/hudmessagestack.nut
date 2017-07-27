::g_hud_message_stack <- {
  scene = null
  guiScene = null
  timersNest = null

  function init(_scene)
  {
    if (!::checkObj(_scene))
      return
    scene = _scene
    guiScene = scene.getScene()
    ::g_hud_event_manager.subscribe("ReinitHud", function(eventData)
      {
        clearMessageStacks()
      }, this)

    foreach (hudMessage in ::g_hud_messages.types)
      hudMessage.subscribeHudEvents()

    initMessageNests()
  }

  function reinit()
  {
    initMessageNests()
  }

  function initMessageNests()
  {
    timersNest = scene.findObject("hud_message_timers")

    foreach (hudMessage in ::g_hud_messages.types)
      hudMessage.reinit(scene, guiScene, timersNest)
  }

  function clearMessageStacks()
  {
    foreach (hudMessage in ::g_hud_messages.types)
      hudMessage.clearStack()
  }
}