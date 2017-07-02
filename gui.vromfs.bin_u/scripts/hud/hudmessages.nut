::g_hud_messages <- {
  types = []
}

::g_hud_messages.template <- {
  nestId = ""
  nest = null
  messagesMax = 0
  showSec = 0
  stack = null //[] in constructor
  messageEvent = ""
  hudEvents = null

  scene = null
  guiScene = null
  timersNest = null

  setScene = function(inScene, inGuiScene, inTimersNest)
  {
    scene = inScene
    guiScene = inGuiScene
    timersNest = inTimersNest
    nest = scene.findObject(nestId)
  }
  reinit  = @(inScene, inGuiScene, inTimersNest) setScene(inScene, inGuiScene, inTimersNest)
  clearStack    = @() stack.clear()
  onMessage     = function() {}
  removeMessage = function(inMessage)
  {
    foreach (idx, message in stack)
      if (inMessage == message)
        return stack.remove(idx)
  }

  findMessageById = function(id) {
    return ::u.search(stack, (@(id) function(m) { return ::getTblValue("id", m.messageData, -1) == id })(id))
  }

  subscribeHudEvents = function()
  {
    ::g_hud_event_manager.subscribe(messageEvent, onMessage, this)
    if (hudEvents)
      foreach(name, func in hudEvents)
        ::g_hud_event_manager.subscribe(name, func, this)
  }

  heightPID = ::dagui_propid.add_name_id("height")
}

::g_enum_utils.addTypesByGlobalName("g_hud_messages", {
  MAIN_NOTIFICATIONS = {
    nestId = "hud_message_center_main_notification"
    messagesMax = 5
    messageEvent = "HudMessage"

    onMessage = function(messageData)
    {
      if (messageData.type != ::HUD_MSG_OBJECTIVE)
        return

      local curMsg = findMessageById(messageData.id)
      if (curMsg)
        updateMessage(curMsg, messageData)
      else
        createMessage(messageData)
    }

    getMsgObjId = function(messageData)
    {
      return "main_msg_" + messageData.id
    }

    createMessage = function(messageData)
    {
      if (!::getTblValue("show", messageData, true))
        return

      cleanUp()
      local mainMessage = {
        obj         = null
        messageData = messageData
        timer       = null
      }
      stack.insert(0, mainMessage)

      if (!::checkObj(nest))
        return
      showNest(true)
      local view = {
        id = getMsgObjId(messageData)
        text = messageData.text
      }
      local blk = ::handyman.renderCached("gui/hud/messageStack/mainCenterMessage", view)
      guiScene.prependWithBlk(nest, blk, this)
      mainMessage.obj = nest.getChild(0)

      if (nest.isVisible())
      {
        mainMessage.obj["height-end"] = mainMessage.obj.getSize()[1]
        mainMessage.obj.setIntProp(heightPID, 0)
        mainMessage.obj.slideDown = "yes"
        guiScene.setUpdatesEnabled(true, true)
      }

      if (!::getTblValue("alwaysShow", mainMessage.messageData, false))
        setDestroyTimer(mainMessage)
    }

    updateMessage = function(message, messageData)
    {
      if (!::getTblValue("show", messageData, true))
      {
        animatedRemoveMessage(message)
        return
      }

      local msgObj = message.obj
      if (!::checkObj(msgObj))
      {
        removeMessage(message)
        createMessage(messageData)
        return
      }

      message.messageData = messageData
      msgObj.findObject("text").setValue(messageData.text)
      msgObj.state = "old"
      if (::getTblValue("alwaysShow", message.messageData, false))
      {
        if (message.timer)
          message.timer.destroy()
      } else if (!message.timer || !message.timer.isValid())
        setDestroyTimer(message)
    }

    cleanUp = function()
    {
      if (stack.len() < messagesMax)
        return

      local lastId = stack.len() - 1
      if (::checkObj(stack[lastId].obj))
        stack[lastId].obj.remove = "yes"
      if ("destroy" in stack[lastId].timer)
        stack[lastId].timer.destroy()
      stack.remove(lastId)
    }

    showNest = function(show)
    {
      if (::checkObj(nest))
        nest.show(show)
    }

    setDestroyTimer = function(message)
    {
      message.timer = Timer(message.obj, 8, (@(message) function () {
        animatedRemoveMessage(message)
      })(message).bindenv(this))
    }

    animatedRemoveMessage = function(message)
    {
      removeMessage(message)
      onNotificationRemoved(message.obj)
      if (::checkObj(message.obj))
        message.obj.remove = "yes"
    }

    onNotificationRemoved = function(obj)
    {
      if (stack.len() || !::checkObj(nest))
        return

      Timer(nest, 0.5, function () {
        if (stack.len() == 0)
          showNest(false)
      }.bindenv(this))
    }
  }

  PLAYER_DAMAGE = {
    nestId = "hud_message_player_damage_notification"
    showSec = 5
    messageEvent = "HudMessage"

    onMessage = function (messageData)
    {
      if (messageData.type != ::HUD_MSG_DAMAGE && messageData.type != ::HUD_MSG_EVENT)
        return
      if (!::checkObj(nest))
        return

      local checkField = (messageData.id != -1) ? "id" : "text"
      local oldMessage = ::u.search(stack, (@(messageData, checkField) function (message) {
        return message.messageData[checkField] == messageData[checkField]
      })(messageData, checkField))
      if (oldMessage)
        refreshMessage(messageData, oldMessage)
      else
        addMessage(messageData)
    }

    addMessage = function (messageData)
    {
      local message = {
        timer = null
        messageData = messageData
        obj = null
      }
      stack.append(message)
      local view = {
        text = messageData.text
      }
      local blk = ::handyman.renderCached("gui/hud/messageStack/playerDamageMessage", view)
      guiScene.appendWithBlk(nest, blk, blk.len(), this)
      message.obj = nest.getChild(nest.childrenCount() - 1)

      if (nest.isVisible())
      {
        message.obj["height-end"] = message.obj.getSize()[1]
        message.obj.setIntProp(heightPID, 0)
        message.obj.slideDown = "yes"
        guiScene.setUpdatesEnabled(true, true)
      }

      message.timer = Timer(timersNest, showSec, (@(message) function () {
        message.obj.remove = "yes"
        removeMessage(message)
      })(message).bindenv(this))
    }

    refreshMessage = function (messageData, message)
    {
      local updateText = message.messageData.text != messageData.text
      message.messageData = messageData
      if (message.timer)
        message.timer.setDelay(showSec)
      if (updateText && ::checkObj(message.obj))
        message.obj.findObject("text").setValue(messageData.text)
    }
  }

  KILL_LOG = {
    nestId = "hud_message_kill_log_notification"
    messagesMax = 5
    showSec = 11
    messageEvent = "HudMessage"

    reinit = function (inScene, inGuiScene, inTimersNest)
    {
      setScene(inScene, inGuiScene, inTimersNest)
      if (!::checkObj(nest))
        return
      nest.deleteChildren()

      local timeDelete = ::dagor.getCurTime() - showSec * 1000
      local killLogNotificationsOld = stack
      stack = []

      foreach (killLogMessage in killLogNotificationsOld)
        if (killLogMessage.timestamp > timeDelete)
          addMessage(killLogMessage.messageData, killLogMessage.timestamp)
    }

    clearStack = function () {}

    onMessage = function (messageData)
    {
      if (messageData.type != ::HUD_MSG_MULTIPLAYER_DMG)
        return
      if (!::checkObj(nest))
        return
      if (!messageData.isKill && ::mission_settings.maxRespawns != 1)
        return
      if (!::g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.KILLLOG))
        return
      addMessage(messageData)
    }

    addMessage = function (messageData, timestamp = null)
    {
      cleanUp()
      local message = {
        timer = null
        timestamp = timestamp || ::dagor.getCurTime()
        messageData = messageData
        obj = null
      }
      stack.append(message)
      local view = {
        text = ::HudBattleLog.msgMultiplayerDmgToText(messageData, true)
      }

      message.timer = ::Timer(timersNest, showSec, (@(message) function () {
        if (::checkObj(message.obj))
          message.obj.remove = "yes"
        removeMessage(message)
      })(message).bindenv(this))

      if (timestamp)
        message.timer.setDelay(showSec - (::dagor.getCurTime() - timestamp) / 1000.0)

      if (!::checkObj(nest))
        return

      local blk = ::handyman.renderCached("gui/hud/messageStack/playerDamageMessage", view)
      guiScene.appendWithBlk(nest, blk, blk.len(), this)
      message.obj = nest.getChild(nest.childrenCount() - 1)

      if (nest.isVisible() && !timestamp && ::checkObj(message.obj))
      {
        message.obj["height-end"] = message.obj.getSize()[1]
        message.obj.setIntProp(heightPID, 0)
        message.obj.appear = "yes"
        guiScene.setUpdatesEnabled(true, true)
      }
    }

    cleanUp = function ()
    {
      if (stack.len() < messagesMax)
        return

      local lastId = 0
      if (::checkObj(stack[lastId].obj))
        stack[lastId].obj.remove = "yes"
      if ("destroy" in stack[lastId].timer)
        stack[lastId].timer.destroy()
      stack.remove(lastId)
    }
  }

  ZONE_CAPTURE = {
    nestId = "hud_message_zone_capture_notification"
    showSec = 3
    messageEvent = "zoneCapturingEvent"

    onMessage = function (eventData)
    {
      if (eventData.isHeroAction)
      {
        local lastHeroNotification = ::u.search(stack, function (notification) {
          return notification.messageData.isHeroAction
        })
        if (lastHeroNotification)
          updateHeroMessage(lastHeroNotification, eventData)
        else
          addHeroMessage(eventData)
      }
      else
        addNotification(eventData)
    }

    addHeroMessage = function (eventData)
    {
      if (!::checkObj(nest))
        return
      if (!::g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.CAPTURE_ZONE_INFO))
        return

      local message = createMessage(eventData)
      local zoneCaptureing = eventData.eventId == ::MISSION_CAPTURE_ZONE_START ||
                             eventData.eventId == ::MISSION_CAPTURING_ZONE

      local view = {
        text = eventData.text
        team = eventData.isMyTeam ? "ally" : "enemy"
        zoneCaptureing = zoneCaptureing
        zoneNameText = eventData.zoneName
        captureProgress = calculateProgress(eventData)
        zoneOwner = isZoneMy(eventData) ? "ally" : "enemy"
        heroAction = "yes"
      }

      createSceneObjectForMessage(view, message)

      setAnimationStartValues(message)
      setTimer(message)
    }

    updateHeroMessage = function (oldMessage, eventData)
    {
      if (!::checkObj(oldMessage.obj))
        return

      local captureProgressObj = oldMessage.obj.findObject("capture_progress")

      oldMessage.obj.findObject("text").setValue(eventData.text)
      captureProgressObj["sector-angle-2"] = calculateProgress(eventData)
      captureProgressObj.zone_owner = isZoneMy(eventData) ? "ally" : "enemy"
      oldMessage.messageData = eventData
      oldMessage.timer.setDelay(::g_hud_messages.ZONE_CAPTURE.showSec)
    }

    calculateProgress = function (eventData)
    {
      local catureFinished = eventData.eventId == ::MISSION_CAPTURED_ZONE
      local progress = eventData.captureProgress
      if (catureFinished)
        progress = 1
      return (fabs(progress) * 360).tointeger()
    }

    isZoneMy = function (eventData)
    {
      return (::get_mp_local_team() == Team.A) == (eventData.captureProgress < 0)
    }

    addNotification = function (eventData)
    {
      if (!::checkObj(::g_hud_messages.ZONE_CAPTURE.nest))
        return
      if (!::g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.CAPTURE_ZONE_INFO))
        return

      local message = createMessage(eventData)
      local view = {
        text = eventData.text
        team = eventData.isMyTeam ? "ally" : "enemy"
      }

      createSceneObjectForMessage(view, message)

      setAnimationStartValues(message)
      setTimer(message)
    }

    createMessage = function (eventData)
    {
      local message = {
        obj         = null
        messageData = eventData
        timer       = null
      }
      stack.insert(0, message)
      return stack[0]
    }

    setTimer = function (message)
    {
      message.timer = ::Timer(timersNest, showSec,
        (@(message) function () {
          if (::checkObj(message.obj))
            message.obj.remove = "yes"
          removeMessage(message)
        })(message).bindenv(this))
    }

    function createSceneObjectForMessage(view, message)
    {
      local blk = ::handyman.renderCached("gui/hud/messageStack/zoneCaptureNotification", view)
      guiScene.prependWithBlk(nest, blk, this)
      message.obj = nest.getChild(0)
    }

    function setAnimationStartValues(message)
    {
      if (!nest.isVisible() || !::checkObj(message.obj))
        return

      message.obj["height-end"] = message.obj.getSize()[1]
      message.obj.setIntProp(heightPID, 0)
      message.obj.slideDown = "yes"
      guiScene.setUpdatesEnabled(true, true)
    }
  }

  REWARDS = {
    nestId = "hud_messages_reward_messages"
    messagesMax = 5
    showSec = 2
    messageEvent = "InBattleReward"
    hudEvents = {
      LocalPlayerDead  = @(ed) clearRewardMessage()
      ReinitHud        = @(ed) clearRewardMessage()
    }

    rewardForSeries = ::Cost()
    rewardClearTimer = null
    curRewardPriority = REWARD_PRIORITY.noPriority

    _animTimerPid = ::dagui_propid.add_name_id("_transp-timer")

    reinit = function (inScene, inGuiScene, inTimersNest)
    {
      setScene(inScene, inGuiScene, inTimersNest)
      rewardClearTimer = null
    }

    onMessage = function (messageData)
    {
      if (!::checkObj(::g_hud_messages.REWARDS.nest))
        return
      if (!::g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.REWARDS_MSG))
        return

      local isSeries = curRewardPriority != REWARD_PRIORITY.noPriority
      rewardForSeries.wp += messageData.warpoints
      rewardForSeries.frp += messageData.experience

      local newPriority = ::g_hud_reward_message.getMessageByCode(messageData.messageCode).priority
      if (newPriority >= curRewardPriority)
      {
        curRewardPriority = newPriority
        showNewRewardMessage(messageData)
      }

      updateRewardValue(isSeries)

      if (rewardClearTimer)
        rewardClearTimer.setDelay(showSec)
      else
        rewardClearTimer = ::Timer(timersNest, showSec, function () {
            clearRewardMessage()
          }, this)
    }

    showNewRewardMessage = function (newRewardMessage)
    {
      local messageObj = ::showBtn("reward_message", true, nest)
      local textObj = messageObj.findObject("reward_message_text")
      local rewardType = ::g_hud_reward_message.getMessageByCode(newRewardMessage.messageCode)

      textObj.setValue(rewardType.getText(newRewardMessage.warpoints, newRewardMessage.counter))
      textObj.view_class = rewardType.getViewClass(newRewardMessage.warpoints)

      messageObj.setFloatProp(_animTimerPid, 0.0)
    }

    updateRewardValue = function (isSeries)
    {
      nest.findObject("reward_message").setFloatProp(_animTimerPid, 0.0)
      nest.findObject("reward_total").setValue(rewardForSeries.getUncoloredText())

      if (isSeries)
        nest.findObject("reward_value_container")._blink = "yes"
    }

    clearRewardMessage = function ()
    {
      if (::check_obj(nest))
      {
        ::showBtn("reward_message", false, nest)
        nest.findObject("reward_message_text").setValue("")
        nest.findObject("reward_total").setValue("")
        nest.findObject("reward_value_container")._blink = "no"
      }
      curRewardPriority = REWARD_PRIORITY.noPriority
      rewardForSeries = ::Cost()
      rewardClearTimer = null
    }
  }

  MISSION_RESULT = {
    nestId = "hud_message_center_mission_result"
    messageEvent = "MissionResult"
    hudEvents = {
      MissionContinue = @(ed) destroy()
    }

    clearStack = function () { stack = {} }

    onMessage = function (eventData)
    {
      if (!::checkObj(nest)
          || ::get_game_mode() == ::GM_TEST_FLIGHT)
        return

      local oldResultIdx = ::getTblValue("resultIdx", stack, ::GO_NONE)

      local resultIdx = ::getTblValue("resultNum", eventData, ::GO_NONE)
      local waitingForResult = ::getTblValue("waitingForResult", eventData, false)

      /*Have to check this, because, on guiStateChange GUI_STATE_FINISH_SESSION
        send waitingForResult=true after real mission result sended.
        But call saved in code, if it'll be needed to use somewhere else.
        For now it's working as if we already receive result WIN OR FAIL.
      */
      if (waitingForResult && (oldResultIdx == ::GO_WIN || oldResultIdx == ::GO_FAIL))
        return

      local noLives = ::getTblValue("noLives", eventData, false)
      local place = ::getTblValue("place", eventData, -1)
      local total = ::getTblValue("total", eventData, -1)

      local resultLocId = getMissionResultLocId(resultIdx, waitingForResult, noLives)
      local text = ::loc(resultLocId)
      if (place >= 0 && total >= 0)
        text += "\n" + ::loc("HUD_RACE_PLACE", {place = place, total = total})

      stack = {
        text = text
        resultIdx = resultIdx
        useMoveOut = resultIdx == ::GO_WIN || resultIdx == ::GO_FAIL
      }

      local blk = ::handyman.renderCached("gui/hud/messageStack/missionResultMessage", stack)
      guiScene.replaceContentFromText(nest, blk, blk.len(), this)

      local objTarget = nest.findObject("mission_result_box")
      if (!::check_obj(objTarget))
        return
      objTarget.show(true)

      if (stack.useMoveOut && nest.isVisible()) //no need animation when scene invisible
      {
        local objStart = scene.findObject("mission_result_box_start")
        ::create_ObjMoveToOBj(scene, objStart, objTarget, { time = 0.5, bhvFunc = "elasticSmall" })
      }
    }

    getMissionResultLocId = function (resultNum, waitingForResult, noLives)
    {
      if (noLives)
        return "MF_NoAttempts"

      switch(resultNum)
      {
        case ::GO_NONE:
          return ""
        case ::GO_WIN:
          return "MISSION_SUCCESS"
        case ::GO_FAIL:
          return "MISSION_FAIL"
        case ::GO_EARLY:
          return "MISSION_IN_PROGRESS"
        default:
          if (waitingForResult)
            return "FINALIZING"
          return ::getTblValue("result", stack, "")
      }
    }

    destroy = function()
    {
      if (!::checkObj(nest))
        return
      local msgObj = nest.findObject("mission_result_box")
      if (!::checkObj(msgObj))
        return

      msgObj["_transp-timer"] = "1"
      msgObj["color-factor"] = "255"
      msgObj["move_out"] = "yes"
      msgObj["anim_transparency"] = "yes"
    }
  }
},
function()
{
  stack = []
})
