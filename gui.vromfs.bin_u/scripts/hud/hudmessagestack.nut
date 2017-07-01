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
    {
      ::g_hud_event_manager.subscribe(hudMessage.messageEvent, (@(hudMessage) function (eventData) {
        hudMessage.onMessage(eventData)
      })(hudMessage), this)

      if (hudMessage.destroyEvent)
        ::g_hud_event_manager.subscribe(hudMessage.destroyEvent, (@(hudMessage) function (eventData) {
          hudMessage.onDestroy(eventData)
        })(hudMessage), this)
    }

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
      hudMessage.init(scene, guiScene, timersNest)
  }

  function clearMessageStacks()
  {
    foreach (hudMessage in ::g_hud_messages.types)
      hudMessage.clearStack()
  }
}