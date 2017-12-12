::g_script_reloader.loadOnce("sqStdLibs/common/u.nut") //!!FIX ME: better to make this modules too
::g_script_reloader.loadOnce("sqDagui/daguiUtil.nut")

local SecondsUpdater = class
{
  timer = 0.0
  updateFunc = null
  params = null
  nestObj = null
  timerObj = null
  destroyTimerObjOnFinish = false

  static function getUpdaterByNestObj(nestObj)
  {
    local userData = nestObj.getUserData()
    if (::u.isSecondsUpdater(userData))
      return userData

    local timerObj = nestObj.findObject(getTimerObjIdByNestObj(nestObj))
    if (timerObj == null)
      return null

    userData = timerObj.getUserData()
    if (::u.isSecondsUpdater(userData))
      return userData

    return null
  }

  function constructor(_nestObj, _updateFunc, useNestAsTimerObj = true, _params = {})
  {
    if (!_updateFunc)
      return ::dagor.assertf(false, "Error: no updateFunc in seconds updater.")

    nestObj    = _nestObj
    updateFunc = _updateFunc
    params     = _params
    local lastUpdaterByNestObject = getUpdaterByNestObj(_nestObj)
    if (lastUpdaterByNestObject != null)
      lastUpdaterByNestObject.remove()

    if (updateFunc(nestObj, params))
      return

    timerObj = useNestAsTimerObj ? nestObj : createTimerObj(nestObj)
    if (!timerObj)
      return

    destroyTimerObjOnFinish = !useNestAsTimerObj
    timerObj.timer_handler_func = "onUpdate"
    timerObj.timer_interval_msec = "1000"
    timerObj.setUserData(this)
  }

  function createTimerObj(nestObj)
  {
    local blkText = "dummy {id:t = '" + getTimerObjIdByNestObj(nestObj) + "' behavior:t = 'Timer' }"
    nestObj.getScene().appendWithBlk(nestObj, blkText, null)
    local index = nestObj.childrenCount() - 1
    local resObj = index >= 0 ? nestObj.getChild(index) : null
    if (resObj && resObj.tag == "dummy")
      return resObj
    return null
  }

  function onUpdate(obj, dt)
  {
    if (updateFunc(nestObj, params))
      remove()
  }

  function remove()
  {
    if (!::check_obj(timerObj))
      return

    timerObj.setUserData(null)
    if (destroyTimerObjOnFinish)
      timerObj.getScene().destroyElement(timerObj)
  }

  function getTimerObjIdByNestObj(nestObj)
  {
    return "seconds_updater_" + nestObj.id
  }
}

::u.registerClass("SecondsUpdater", SecondsUpdater)

return SecondsUpdater