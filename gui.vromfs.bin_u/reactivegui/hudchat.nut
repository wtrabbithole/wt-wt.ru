local colors = require("style/colors.nut")
local chatBase = require("daRg/components/chat.nut")
local textInput =  require("components/textInput.nut")
local background = require("style/hudBackground.nut")
local penalty = require("penitentiary/penalty.nut")
local time = require("sqStdLibs/common/time.nut")
local state = require("hudChatState.nut")

local chatLog = state.log

const LOG_FADE_OUT_NEW_MESSAGE_TIME = 15.0
const LOG_TRANSITION_TIME = 0.2


local send = function (message) {
  if (!penalty.isDevoiced()) {
    ::chat_on_send()
  } else {
    state.pushSystemMessage(penalty.getDevoiceDescriptionText())
  }
}


local chat = chatBase(chatLog, send)
state.input.subscribe(function (new_val) {
  chat.form.update(new_val)
})


local chatInputCtor = function (field, send) {
  local restoreControle = function () {
    ::set_allowed_controls_mask(CtrlsInGui.CTRL_ALLOW_FULL)
    ::toggle_ingame_chat(false)
  }

  local handlers = {
    onReturn = function () {
      send()
      restoreControle()
    }
    onChange = function (new_val) {
      ::chat_on_text_update(new_val)
    }
    onEscape = function () {
      restoreControle()
    }
  }
  local options = {
    font = Fonts.small_text_hud
    margin = 0
  }
  return textInput.hud(field, options, handlers)
}


local getHintText = function () {
  local locId = ::cross_call.squad_manger.isInSquad() ?
      "chat/help/squad" :
      "chat/help/short"
  return ::cross_call.get_gamepad_specific_localization(locId)
}


local chatHint = {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_HORIZONTAL
  padding = [sh(7.0/1080*100) , sh(15.0/1080*100)]
  gap = { size = flex() }
  children = [
    {
      rendObj = ROBJ_STEXT
      text = getHintText()
      fontSize = 10
    }
    function () {
      return {
        rendObj = ROBJ_STEXT
        watch = state.modeId
        text = ::cross_call.mp_chat_mode.getModeNameText(state.modeId.value)
        fontSize = 10
      }
    }
  ]

  hotkeys = [
    [
      "Tab",
      function () {
        if (!state.inputEnabled.value) {
          return
        }
        ::chat_set_mode(::cross_call.mp_chat_mode.getNextMode(state.modeId.value), "")
      }
    ]
  ]
}.patchComponent(background)


local inputField = @() {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  children = [
    chat.inputField(chatInputCtor)
  ]
}


local chatFilters = {
}


local gotNewMessageRecently = function () {
  if (!chatLog.value.len()) {
    return false
  }
  return chatLog.value.top().time + LOG_FADE_OUT_NEW_MESSAGE_TIME > ::get_mission_time()
}

local chatLogVisible = Watched(false)
local chatLogAnimTime = function () {
  if (chatLogVisible.value)
    return LOG_TRANSITION_TIME
  return gotNewMessageRecently() ? LOG_FADE_OUT_NEW_MESSAGE_TIME : LOG_TRANSITION_TIME
}

local chatBackground = function() {
  local onInputTriggered = function (new_val) { chatLogVisible.update(new_val) }
  local onNewMessage = function (new_val) {
    if (!chatLog.value.len()) {
      return
    }

    local fadeOutFn = function () { chatLogVisible.update(false) }
    chatLogVisible.update(true)
    ::gui_scene.clearTimer(fadeOutFn)
    ::gui_scene.setTimeout(LOG_TRANSITION_TIME, fadeOutFn)
  }

  return @() {
    size = flex()
    gap = sh(0.5)
    padding = [sh(7.0/1080*100) , sh(15.0/1080*100)]
    watch = chatLogVisible
    opacity = chatLogVisible.value ? 1.0 : 0.0
    flow = FLOW_VERTICAL
    valign = VALIGN_BOTTOM
    clipChildren = true

    onAttach = function (elem) {
      chatLog.subscribe(onNewMessage)
      state.inputEnabled.subscribe(onInputTriggered)
    }
    onDetach = function (elem) {
      chatLog.unsubscribe(onNewMessage)
      state.inputEnabled.unsubscribe(onInputTriggered)
    }

    transitions = [{
      prop = AnimProp.opacity
      duration = chatLogAnimTime()
      easing = OutCubic
    }]
  }.patchComponent(background)
}


local getMessageColor = function(message)
{
  if (message.isBlocked)
    return colors.menu.chatTextBlockedColor
  if (message.isAutomatic)
  {
    if (::cross_call.squad_manger.isInMySquad(message.sender))
      return colors.hud.mySquadColor
    else if (message.isEnemy)
      return colors.hud.teamRedColor
    else
      return colors.hud.teamBlueColor
  }
  return colors.hud.get(
    ::cross_call.mp_chat_mode.getModeColorName(message.mode),
    Color(255, 255, 255)
  )
}


local getSenderColor = function (message)
{
  if (message.isMyself)
    return colors.hud.mainPlayerColor
  else if (::cross_call.isPlayerDedicatedSpectator(message.sender))
    return colors.hud.spectatorColor
  else if (message.isEnemy || !::cross_call.is_mode_with_teams())
    return colors.hud.teamRedColor
  else if (::cross_call.squad_manger.isInMySquad(message.sender))
    return colors.hud.mySquadColor
  return colors.hud.teamBlueColor
}


local messageComponent = function(message) {
  local text = ""
  if (message.sender == "") { //systme
    text = ::string.format(
      "<color=%d>%s</color>",
      colors.hud.chatActiveInfoColor,
      ::loc(message.text)
    )
  } else {
    text = ::string.format("%s <Color=%d>[%s] %s:</Color> <Color=%d>%s</Color>",
      time.secondsToString(message.time, false)
      getSenderColor(message),
      ::cross_call.mp_chat_mode.getModeNameText(message.mode),
      message.sender,
      getMessageColor(message),
      message.text
    )
  }
  return {
    size = [flex(), SIZE_TO_CONTENT]
    rendObj = ROBJ_TEXTAREA
    behavior = Behaviors.TextArea
    text = text
    font = Fonts.tiny_text_hud
  }
}


local onInputToggle = function (enable) {
  if (enable) {
    ::set_kb_focus(chat.form)
    ::set_allowed_controls_mask(CtrlsInGui.CTRL_IN_MP_CHAT | CtrlsInGui.CTRL_ALLOW_VEHICLE_MOUSE)
  } else {
    ::set_kb_focus(null)
    ::set_allowed_controls_mask(CtrlsInGui.CTRL_ALLOW_FULL)
  }
}


return function () {
  return {
    size = [sw(30), sh(30)]
    flow = FLOW_VERTICAL
    gap = sh(0.5)

    children = [
      chat.logBox(chatBackground, messageComponent)
      @() {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        opacity = state.inputEnabled.value ? 1.0 : 0.0

        watch = state.inputEnabled

        children = [
          inputField
          chatHint
          chatFilters
        ]

        onAttach = function (elem) {
          state.inputEnabled.subscribe(onInputToggle)
        }
        onDetach = function (elem) {
          state.inputEnabled.unsubscribe(onInputToggle)
        }
        transitions = [{
          prop = AnimProp.opacity
          duration = LOG_TRANSITION_TIME
          easing = OutCubic
        }]
      }
    ]
  }
}
