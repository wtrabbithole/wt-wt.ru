local time = require("scripts/time.nut")


class ::gui_handlers.QiHandlerBase extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName   = "gui/events/eventQueue.blk"

  queueTypeMask = QUEUE_TYPE_BIT.EVENT
  hasTimerText = true
  timerUpdateObjId = null
  timerTextObjId = null

  queue = null
  event = null
  needAutoDestroy = true //auto destroy when no queue

  isStatsCreated = false

  function initScreen()
  {
    initTimer()
    checkCurQueue(true)
  }

  function initTimer()
  {
    if (!hasTimerText || !timerUpdateObjId)
      return

    local timerObj = scene.findObject(timerUpdateObjId)
    timerObj.setUserData(this)
    timerObj.timer_handler_func = "onUpdate"
  }

  function destroy()
  {
    if (!isValid())
      return
    scene.show(false)
    guiScene.replaceContentFromText(scene, "", 0, null)
    scene = null
  }

  function checkCurQueue(forceUpdate = false)
  {
    local q = ::queues.findQueue({}, queueTypeMask)
    if (q && !::queues.isQueueActive(q))
      q = null

    if (needAutoDestroy && !q)
      return destroy()

    local isQueueChanged = q != queue
    if (!isQueueChanged && !forceUpdate)
      return isQueueChanged

    queue = q
    event = queue && ::queues.getQueueEvent(queue)
    if (!isStatsCreated)
    {
      createStats()
      isStatsCreated = true
    }
    onQueueChange()
    return isQueueChanged
  }

  function onQueueChange()
  {
    scene.show(queue != null)
    if (!queue)
      return

    updateTimer()
    updateStats()
  }

  function onUpdate(obj, dt)
  {
    if (queue)
      updateTimer()
  }

  function updateTimer()
  {
    if (!hasTimerText || !timerTextObjId)
      return
    local textObj = scene.findObject(timerTextObjId)
    if(!::check_obj(textObj))
      return

    local msg = ::loc("yn1/waiting_for_game_query")
    local waitTime = ::queues.getQueueActiveTime(queue)
    if (waitTime > 0)
    {
      local minutes = time.secondsToMinutes(waitTime).tointeger()
      local seconds = waitTime - time.minutesToSeconds(minutes).tointeger()
      local timetext = ::format(::loc("yn1/wait_time"), minutes, seconds)
      msg = msg + "\n" + timetext
    }
    textObj.setValue(msg)
  }

  function onEventQueueChangeState(queue) { checkCurQueue() }
  function onEventQueueInfoUpdated(p)     { if (queue) updateStats() }

  function createStats() {}
  function updateStats() {}
}
