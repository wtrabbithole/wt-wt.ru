local stdMath = require("std/math.nut")

class ::gui_handlers.LoadingUrlMissionModal extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/msgBox.blk"
  timeToShowCancel = 3
  timer = -1

  buttonCancelId = "btn_cancel"
  buttonOkId = "btn_ok"

  urlMission = null
  callback = null

  isCancel = false
  requestId = null
  requestSuccess = false
  loadingProgress = 0
  progressChanged = true

  function initScreen()
  {
    if (!urlMission)
      return goBack()

    createButton(buttonCancelId, "#msgbox/btn_cancel" ,"onCancel")
    createButton(buttonOkId, "#msgbox/btn_ok" ,"goBack")

    scene.findObject("msgWaitAnimation").show(true)
    scene.findObject("msg_box_timer").setUserData(this)

    resetTimer()
    loadUrlMission()
    onUpdate(null, 0.0)
  }

  function createButton(btnId, text, callbackName)
  {
    local data = format("Button_text { id:t='%s'; btnName:t='AB'; text:t='%s'; on_click:t='%s' }", btnId, text, callbackName)
    local holderObj = scene.findObject("buttons_holder")
    if (!holderObj)
      return

    guiScene.appendWithBlk(holderObj, data, this)
    showSceneBtn(btnId, false)
  }

  function loadUrlMission()
  {
    local requestCallback = ::Callback(function(success, blk) {
                                          onLoadingEnded(success, blk)
                                        }, this)

    local progressCallback = ::Callback(function(dltotal, dlnow) {
                                          onProgress(dltotal, dlnow)
                                        }, this)

    requestId = ::download_blk(urlMission.url, 0, (@(requestCallback) function(success, blk) {
                                                                 requestCallback(success, blk)
                                                               })(requestCallback),
                                                               (@(progressCallback) function(dltotal, dlnow) {
                                                                 progressCallback(dltotal, dlnow)
                                                               })(progressCallback))
  }

  function resetTimer()
  {
    timer = timeToShowCancel
    showSceneBtn(buttonCancelId, false)
  }

  function onUpdate(obj, dt)
  {
    if (progressChanged)
    {
      progressChanged = false
      if (loadingProgress >= 0)
      {
        updateText(::loc("wait/missionDownload", {name = urlMission.name, progress = loadingProgress.tostring()}))
      }
    }

    if (timer < 0)
      return

    timer -= dt
    if (timer < 0)
      showSceneBtn(buttonCancelId, true)
  }

  function onLoadingEnded(success, blk)
  {
    timer = -1
    requestSuccess = success
    progressChanged = false
    if (isCancel)
      return goBack()

    local errorText = ::loc("wait/ugm_download_failed")
    if (success)
    {
      errorText = ::validate_custom_mission(blk)
      requestSuccess = success = ::u.isEmpty(errorText)
      if (!success)
        errorText = ::loc("wait/ugm_not_valid", {errorText = errorText})
    }

    ::g_url_missions.setLoadingCompeteState(urlMission, !success, blk)

    if (success)
      return goBack()

    updateText(errorText)
    scene.findObject("msgWaitAnimation").show(false)
    showSceneBtn(buttonCancelId, false)
    showSceneBtn(buttonOkId, true)
  }

  function updateText(text)
  {
    scene.findObject("msgText").setValue(text)
  }

  function onProgress(dltotal, dlnow)
  {
    loadingProgress = dltotal ? (100.0 * dlnow / dltotal).tointeger() : 0
    progressChanged = true
  }

  function onCancel()
  {
    isCancel = true
    ::abort_download(requestId)
    showSceneBtn(buttonCancelId, false)
  }

  function onEventSignOut()
  {
    ::abort_all_downloads()
  }

  function afterModalDestroy()
  {
    if (callback != null)
      callback(requestSuccess)
  }
}
