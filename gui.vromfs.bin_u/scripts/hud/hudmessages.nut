local enums = ::require("std/enums.nut")
local time = require("scripts/time.nut")

local heightPID = ::dagui_propid.add_name_id("height")

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
  timers = null

  setScene = function(inScene, inTimers)
  {
    scene = inScene
    guiScene = scene.getScene()
    timers = inTimers
    nest = scene.findObject(nestId)
  }
  reinit  = @(inScene, inTimers) setScene(inScene, inTimers)
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

  getCleanUpId = @(total) 0

  cleanUp = function()
  {
    if (stack.len() < messagesMax)
      return

    local lastId = getCleanUpId(stack.len())
    local obj = stack[lastId].obj
    if (::check_obj(obj))
    {
      if (obj.isVisible())
        stack[lastId].obj.remove = "yes"
      else
        obj.getScene().destroyElement(obj)
    }
    if (stack[lastId].timer)
      timers.removeTimer(stack[lastId].timer)
    stack.remove(lastId)
  }
}

enums.addTypesByGlobalName("g_hud_messages", {
  MAIN_NOTIFICATIONS = {
    nestId = "hud_message_center_main_notification"
    messagesMax = 2
    messageEvent = "HudMessage"

    getCleanUpId = @(total) total - 1

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
      }
      else if (!message.timer)
        setDestroyTimer(message)
    }

    showNest = function(show)
    {
      if (::checkObj(nest))
        nest.show(show)
    }

    setDestroyTimer = function(message)
    {
      message.timer = timers.addTimer(8, (@() animatedRemoveMessage(message)).bindenv(this)).weakref()
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

      timers.addTimer(0.5, function () {
        if (stack.len() == 0)
          showNest(false)
      }.bindenv(this))
    }
  }

  PLAYER_DAMAGE = {
    nestId = "hud_message_player_damage_notification"
    showSec = 5
    messagesMax = 2
    messageEvent = "HudMessage"

    onMessage = function (messageData)
    {
      if (messageData.type != ::HUD_MSG_DAMAGE && messageData.type != ::HUD_MSG_EVENT)
        return
      if (!::checkObj(nest))
        return

      local checkField = (messageData.id != -1) ? "id" : "text"
      local oldMessage = ::u.search(stack, @(message) message.messageData[checkField] == messageData[checkField])
      if (oldMessage)
        refreshMessage(messageData, oldMessage)
      else
        addMessage(messageData)
    }

    addMessage = function (messageData)
    {
      cleanUp()
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

      message.timer = timers.addTimer(showSec, function () {
        if (::check_obj(message.obj))
          message.obj.remove = "yes"
        removeMessage(message)
      }.bindenv(this)).weakref()
    }

    refreshMessage = function (messageData, message)
    {
      local updateText = message.messageData.text != messageData.text
      message.messageData = messageData
      if (message.timer)
        timers.setTimerTime(message.timer, showSec)
      if (updateText && ::checkObj(message.obj))
        message.obj.findObject("text").setValue(messageData.text)
    }
  }

  KILL_LOG = {
    nestId = "hud_message_kill_log_notification"
    messagesMax = 5
    showSec = 11
    messageEvent = "HudMessage"

    reinit = function (inScene, inTimers)
    {
      setScene(inScene, inTimers)
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

    clearStack = function ()
    {
      if (!::checkObj(nest))
        return
      nest.deleteChildren()
    }

    onMessage = function (messageData)
    {
      if (messageData.type != ::HUD_MSG_MULTIPLAYER_DMG)
        return
      if (!::checkObj(nest))
        return
      if (!(messageData?.isKill ?? true) && ::mission_settings.maxRespawns != 1)
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

      local timeToShow = timestamp
       ? showSec - (::dagor.getCurTime() - timestamp) / 1000.0
       : showSec

      message.timer = timers.addTimer(timeToShow, function () {
        if (::checkObj(message.obj))
          message.obj.remove = "yes"
        removeMessage(message)
      }.bindenv(this)).weakref()

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
  }

  ZONE_CAPTURE = {
    nestId = "hud_message_zone_capture_notification"
    showSec = 3
    messagesMax = 2
    messageEvent = "zoneCapturingEvent"

    getCleanUpId = @(total) total - 1

    onMessage = function (eventData)
    {
      if (eventData.isHeroAction
        && eventData.eventId != ::MISSION_CAPTURED_ZONE
        && eventData.eventId != ::MISSION_TEAM_LEAD_ZONE)
        return

      cleanUp()
      addNotification(eventData)
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
      if (message.timer)
        timers.setTimerTime(message.timer, showSec)
      else
        message.timer = timers.addTimer(showSec,
          function () {
            if (::checkObj(message.obj))
              message.obj.remove = "yes"
            removeMessage(message)
          }.bindenv(this)).weakref()
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

    rewardWp = 0.0
    rewardXp = 0.0
    rewardClearTimer = null
    curRewardPriority = REWARD_PRIORITY.noPriority

    _animTimerPid = ::dagui_propid.add_name_id("_transp-timer")

    reinit = function (inScene, inTimers)
    {
      setScene(inScene, inTimers)
      timers.removeTimer(rewardClearTimer)
      clearRewardMessage()
    }

    onMessage = function (messageData)
    {
      if (!::checkObj(::g_hud_messages.REWARDS.nest))
        return
      if (!::g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.REWARDS_MSG))
        return

      local isSeries = curRewardPriority != REWARD_PRIORITY.noPriority
      rewardWp += messageData.warpoints
      rewardXp += messageData.experience

      local newPriority = ::g_hud_reward_message.getMessageByCode(messageData.messageCode).priority
      if (newPriority >= curRewardPriority)
      {
        curRewardPriority = newPriority
        showNewRewardMessage(messageData)
      }

      updateRewardValue(isSeries)

      if (rewardClearTimer)
        timers.setTimerTime(rewardClearTimer, showSec)
      else
        rewardClearTimer = timers.addTimer(showSec, clearRewardMessage.bindenv(this)).weakref()
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

    roundRewardValue = @(val) val > 10 ? (val.tointeger() / 10 * 10) : val.tointeger()

    updateRewardValue = function (isSeries)
    {
      local reward = ::Cost(roundRewardValue(rewardWp), 0, roundRewardValue(rewardXp))
      nest.findObject("reward_message").setFloatProp(_animTimerPid, 0.0)
      nest.findObject("reward_total").setValue(reward.getUncoloredText())

      if (isSeries)
        nest.findObject("reward_value_container")._blink = "yes"
    }

    clearRewardMessage = function ()
    {
      if (::check_obj(nest))
      {
        ::showBtn("reward_message", false, nest)
        nest.findObject("reward_message_text").setValue("")
        nest.findObject("reward_message_text").view_class = ""
        nest.findObject("reward_total").setValue("")
        nest.findObject("reward_value_container")._blink = "no"
      }
      curRewardPriority = REWARD_PRIORITY.noPriority
      rewardWp = 0.0
      rewardXp = 0.0
      timers.removeTimer(rewardClearTimer)
      rewardClearTimer = null
    }
  }

  RACE_SEGMENT_UPDATE = {
    nestId = "hud_messages_race_messages"
    eventName = "RaceSegmentUpdate"
    messageEvent = "RaceSegmentUpdate"

    onMessage = function (eventData)
    {
      if (!::checkObj(nest) || !(::get_game_type() & ::GT_RACE))
        return

      if (!::g_hud_vis_mode.getCurMode().isPartVisible(HUD_VIS_PART.RACE_INFO))
        return

      local statusObj = nest.findObject("race_status")
      if (::check_obj(statusObj))
      {
        local text = ::loc("HUD_RACE_FINISH")
        if (!eventData.isRaceFinishedByPlayer)
        {
          text = ::loc("HUD_RACE_CHECKPOINT") + " "
          text += eventData.passedCheckpointsInLap + ::loc("ui/slash")
          text += eventData.checkpointsPerLap + "  "
          text += ::loc("HUD_RACE_LAP") + " "
          text += eventData.currentLap + ::loc("ui/slash") + eventData.totalLaps
        }
        statusObj.setValue(text)
      }

      local playerTime = ::getTblValue("time", ::getTblValue("player", eventData, {}), 0.0)

      foreach (blockName in ["beforePlayer", "leader", "afterPlayer", "player"])
      {
        local textBlockObj = nest.findObject(blockName)
        if (!::check_obj(textBlockObj))
          continue

        local data = ::getTblValue(blockName, eventData)
        local showBlock = data != null
        textBlockObj.show(showBlock)
        if (showBlock)
        {
          foreach (param, value in data)
          {
            if (param == "isPlayer")
              textBlockObj.isPlayer = value? "yes" : "no"
            else
            {
              local textObj = textBlockObj.findObject(param)
              if (!::check_obj(textObj))
                continue

              local text = value
              if (param == "time")
              {
                local prefix = ""
                local isPlayerBlock = blockName != "player"
                if (isPlayerBlock)
                {
                  value -= playerTime
                  if (value > 0)
                    prefix = ::loc("keysPlus")
                }
                text = prefix + time.preciseSecondsToString(value, isPlayerBlock)
              }
              else if (param == "place")
                text = value > 0? value.tostring() : ""
              textObj.setValue(text)
            }
          }
        }
      }
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

  HUD_DEATH_REASON_MESSAGE = {
    nestId = "hud_messages_death_reason_notification"
    showSec = 5
    messagesMax = 2
    messageEvent = "HudMessage"
    hudEvents = {
      HudMessageHide = @(ed) destroy()
    }

    onMessage = function (messageData)
    {
      if (messageData.type != ::HUD_MSG_UNDER_RADAR && messageData.type != ::HUD_MSG_DEATH_REASON)
        return
      if (!::checkObj(nest))
        return

      local oldMessage = findMessageById(messageData.id)
      if (oldMessage)
        refreshMessage(messageData, oldMessage)
      else
        addMessage(messageData)
    }

    addMessage = function (messageData, timestamp = null, needAnimations = true)
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
        text = messageData.text
      }
      local blk = ::handyman.renderCached("gui/hud/messageStack/deathReasonMessage", view)
      guiScene.appendWithBlk(nest, blk, blk.len(), this)
      message.obj = nest.getChild(nest.childrenCount() - 1)

      if (nest.isVisible() && needAnimations)
      {
        message.obj["height-end"] = message.obj.getSize()[1]
        message.obj.setIntProp(heightPID, 0)
        message.obj.slideDown = "yes"
        guiScene.setUpdatesEnabled(true, true)
      }

      local timeToShow = timestamp
       ? showSec - (::dagor.getCurTime() - timestamp) / 1000.0
       : showSec

      message.timer = timers.addTimer(timeToShow, function () {
        if (::check_obj(message.obj))
          message.obj.remove = "yes"
        removeMessage(message)
      }.bindenv(this)).weakref()
    }

    refreshMessage = function (messageData, message)
    {
      local shouldUpdateText = message.messageData.text != messageData.text
      message.messageData = messageData
      if (message.timer)
        timers.setTimerTime(message.timer, showSec)
      if (shouldUpdateText && ::checkObj(message.obj))
        message.obj.findObject("text").setValue(messageData.text)
    }

    clearStack = function () {}

    destroy = function () {
      stack.clear()
      if (!::checkObj(nest))
        return
      nest.deleteChildren()
    }

    reinit = function (inScene, inTimers)
    {
      setScene(inScene, inTimers)
      if (!::checkObj(nest))
        return
      nest.deleteChildren()

      local timeDelete = ::dagor.getCurTime() - showSec * 1000
      local oldStack = stack
      stack = []

      foreach (message in oldStack)
        if (message.timestamp > timeDelete)
          addMessage(message.messageData, message.timestamp, false)
    }
  }
},
function()
{
  stack = []
})
