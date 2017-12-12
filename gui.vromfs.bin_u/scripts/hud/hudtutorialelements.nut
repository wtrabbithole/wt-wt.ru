local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
local time = require("scripts/time.nut")

::g_hud_tutorial_elements <- {
  [PERSISTENT_DATA_PARAMS] = ["visibleHTObjects", "isDebugMode", "debugBlkName"]

  active = false
  nest  = null
  scene = null
  timersNest = null
  timers = {}

  visibleHTObjects = {}

  aabbList = {
    map = ::get_ingame_map_aabb
    hitCamera = function() { return ::g_hud_hitcamera.getAABB() }
    multiplayerScore = ::get_ingame_multiplayer_score_progress_bar_aabb
  }
  needUpdateAabb = false

  isDebugMode = false
  debugBlkName = null
  debugLastModified = null
}

function g_hud_tutorial_elements::init(_nest)
{
  local blkPath = getCurBlkName()
  active = !!blkPath

  if (!::checkObj(_nest))
    return
  nest  = _nest

  initNestObjects()
  if (!::checkObj(scene))
    return

  scene.show(active)
  if (!active)
    return

  if (::u.isEmpty(::DataBlock(blkPath)))
  {
    local msg = "Hud_tutorial_elements: blk file is empty. (blkPath = " + blkPath + ")"
    dagor.debug(msg)
    ::dagor.assertf(false, msg)
    return
  }

  dagor.debug("Hud_tutorial_elements: loaded " + blkPath)

  local guiScene = scene.getScene()
  guiScene.replaceContent(scene, blkPath, this)

  for (local i = 0; i < scene.childrenCount(); i++)
  {
    local childObj = scene.getChild(i)
    if (isDebugMode && childObj.id)
      updateVisibleObject(childObj.id, childObj.isVisible(), -1)
    else
      childObj.show(false)
  }

  guiScene.performDelayed(this, function() { refreshObjects() })

  if (isDebugMode)
    addDebugTimer()
  else
    ::g_hud_event_manager.subscribe("hudElementShow", function(data) {
      onElementToggle(data)
    }, this)
}

function g_hud_tutorial_elements::initNestObjects()
{
  scene = nest.findObject("tutorial_elements_nest")
  timersNest = nest.findObject("hud_message_timers")
}

function g_hud_tutorial_elements::getCurBlkName()
{
  if (isDebugMode)
    return debugBlkName

  if (::get_game_mode() != ::GM_TRAINING)
    return null

  return getBlkNameByCurMission()
}

function g_hud_tutorial_elements::getBlkNameByCurMission()
{
  local misBlk = ::DataBlock()
  ::get_current_mission_desc(misBlk)

  local fullMisBlk = misBlk.mis_file && ::DataBlock(misBlk.mis_file)
  local res =  ::get_blk_value_by_path(fullMisBlk, "mission_settings/mission/tutorialObjectsFile")
  return ::u.isString(res) ? res : null
}

function g_hud_tutorial_elements::reinit()
{
  if (!active || !::checkObj(nest))
    return

  initNestObjects()
  refreshObjects()
}

function g_hud_tutorial_elements::updateVisibleObject(id, show, timeSec = -1)
{
  local htObj = ::getTblValue(id, visibleHTObjects)
  if (!show)
  {
    if (htObj)
    {
      htObj.show(false)
      delete visibleHTObjects[id]
    }
    return null
  }

  if (!htObj || !htObj.isValid())
  {
    htObj = ::HudTutorialObject(id, scene)
    if (!htObj.isValid())
      return null

    visibleHTObjects[id] <- htObj
  }

  if (timeSec >= 0)
    htObj.setTime(timeSec)
  return htObj
}

function g_hud_tutorial_elements::updateObjTimer(objId, htObj)
{
  local curTimer = ::getTblValue(objId, timers)
  if (!htObj || !htObj.hasTimer() || !htObj.isVisibleByTime())
  {
    if (curTimer)
    {
      curTimer.destroy()
      delete timers[objId]
    }
    return
  }

  local timeLeft = htObj.getTimeLeft()
  if (curTimer && curTimer.isValid())
  {
    curTimer.setDelay(timeLeft)
    return
  }

  if (!::checkObj(timersNest))
    return

  timers[objId] <- ::Timer(timersNest, timeLeft, (@(objId) function () {
    updateVisibleObject(objId, false)
    if (objId in timers)
      delete timers[objId]
  })(objId), this)
}

function g_hud_tutorial_elements::onElementToggle(data)
{
  if (!active || !::checkObj(scene))
    return

  local objId   = ::getTblValue("element", data, null)
  local show  = ::getTblValue("show", data, false)
  local timeSec = ::getTblValue("time", data, 0)

  local htObj = updateVisibleObject(objId, show, timeSec)
  updateObjTimer(objId, htObj)
}

function g_hud_tutorial_elements::getAABB(name)
{
  local getFunc = ::getTblValue(name, aabbList)
  return getFunc && getFunc()
}

function g_hud_tutorial_elements::refreshObjects()
{
  foreach(id, htObj in visibleHTObjects)
  {
    local isVisible = htObj.isVisibleByTime()
    if (isVisible)
      if (!htObj.isValid())
        htObj.refreshObj(id, scene)
      else if (needUpdateAabb)
        htObj.updateAabb()

    if (!isVisible || !htObj.isValid())
      delete visibleHTObjects[id]

    updateObjTimer(id, htObj)
  }

  needUpdateAabb = false
}

function g_hud_tutorial_elements::onEventHudIndicatorChangedSize(params)
{
  needUpdateAabb = true
}

function g_hud_tutorial_elements::onEventLoadingStateChange(params)
{
  if (::is_in_flight())
    return

  //all guiScenes destroy on loading so no need check objects one by one
  visibleHTObjects.clear()
  timers.clear()
  isDebugMode = false
}

function g_hud_tutorial_elements::addDebugTimer()
{
  SecondsUpdater(scene,
                   function(...)
                   {
                     return ::g_hud_tutorial_elements.onDbgUpdate()
                   }
                   false)
}

function g_hud_tutorial_elements::onDbgUpdate()
{
  if (!isDebugMode)
    return true
  local modified = ::get_file_modify_time(debugBlkName)
  if (!modified)
    return

  //modified = time.getFullTimeTable(modified)
  if (!debugLastModified)
  {
    debugLastModified = modified
    return
  }

  if (!time.cmpDate(debugLastModified, modified))
    return

  debugLastModified = modified
  init(nest)
}

 //blkName = null to switchOff, blkName = "" to autodetect
function g_hud_tutorial_elements::debug(blkName = "")
{
  if (blkName == "")
    blkName = getBlkNameByCurMission()

  isDebugMode = ::u.isString(blkName) && blkName.len()
  debugBlkName = blkName
  debugLastModified = null
  init(nest)
  return debugBlkName
}

::g_script_reloader.registerPersistentDataFromRoot("g_hud_tutorial_elements")
::subscribe_handler(::g_hud_tutorial_elements, ::g_listener_priority.DEFAULT_HANDLER)
