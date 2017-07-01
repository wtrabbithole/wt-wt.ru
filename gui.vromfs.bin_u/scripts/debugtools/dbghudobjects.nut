::g_hud_debug_objects <- {
  eventsPerSec = 0
  curTimerObj = null

  activeObjectTypes = []
  totalChance = 0
}

function g_hud_debug_objects::start(newEventsPerSec = 10.0)
{
  eventsPerSec = newEventsPerSec

  if (eventsPerSec == 0)
    stop()
  else
    createTimerObjOnce()

  updateActiveObjectsTypes()
}

function g_hud_debug_objects::stop()
{
  if (::checkObj(curTimerObj))
    curTimerObj.getScene().destroyElement(curTimerObj)
}

function g_hud_debug_objects::createTimerObjOnce()
{
   if (::checkObj(curTimerObj))
     return

  local hudHandler = ::handlersManager.findHandlerClassInScene(::gui_handlers.Hud)
  if (!hudHandler)
  {
    dlog("Error: not found active hud")
    return
  }

  local blkText = "dummy { id:t = 'g_hud_debug_objects_timer'; behavior:t = 'Timer'; timer_handler_func:t = 'onUpdate' }"
  hudHandler.guiScene.appendWithBlk(hudHandler.scene, blkText, null)
  curTimerObj = hudHandler.scene.findObject("g_hud_debug_objects_timer")
  curTimerObj.setUserData(this)
}

function g_hud_debug_objects::getCurHudType()
{
  local hudHandler = ::handlersManager.findHandlerClassInScene(::gui_handlers.Hud)
  if (!hudHandler)
    return HUD_TYPE.NONE
  return hudHandler.hudType
}

function g_hud_debug_objects::updateActiveObjectsTypes()
{
  local hudType = getCurHudType()
  activeObjectTypes.clear()
  totalChance = 0.0
  foreach(oType in ::g_dbg_hud_object_type.types)
  {
    if (!oType.isVisible(hudType))
      continue
    activeObjectTypes.append(oType)
    totalChance += oType.eventChance
  }
}

function g_hud_debug_objects::onUpdate(obj, dt)
{
  if (!eventsPerSec || dt < 0.0001)
    return

  local eventChance = dt * eventsPerSec
  for(eventChance; eventChance > 0; eventChance--)
    if (eventChance >= 1 || eventChance > ::math.frnd())
      genRandomEvent()
}

function g_hud_debug_objects::genRandomEvent()
{
  if (!totalChance)
    return

  local chance = ::math.frnd() * totalChance
  foreach(oType in activeObjectTypes)
  {
    chance -= oType.eventChance
    if (chance > 0)
      continue
    oType.genNewEvent()
    break
  }
}
