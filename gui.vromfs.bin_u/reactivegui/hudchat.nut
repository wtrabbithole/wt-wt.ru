local colors = require("style/colors.nut")
local transition = require("style/hudTransition.nut")
local teamColors = require("style/teamColors.nut")
local chatBase = require("daRg/components/chat.nut")
local textInput =  require("components/textInput.nut")
local penalty = require("penitentiary/penalty.nut")
local time = require("std/time.nut")
local state = require("hudChatState.nut")
local hudState = require("hudState.nut")
local hudLog = require("components/hudLog.nut")

local chatLog = state.log


local modeColor = function (mode) {
  local colorName = ::cross_call.mp_chat_mode.getModeColorName(mode)
  return colors.hud?[colorName] ?? teamColors[colorName]
}


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
    ::toggle_ingame_chat(false)
  }

  local onReturn = function () {
    send()
    restoreControle()
  }

  local onEscape = function () {
    restoreControle()
  }

  local handlers = {
    onReturn = onReturn
    onEscape = onEscape
    onChange = function (new_val) {
      ::chat_on_text_update(new_val)
    }
  }
  local options = {
    font = Fonts.tiny_text_hud
    margin = 0
    hotkeys = [
      [ "J:A", onReturn],
      [ "J:B", onEscape],
    ]
  }
  return textInput.hud(field, options, handlers)
}


local getHintText = function () {
  local locId = ::cross_call.squad_manger.isInSquad() ?
      "chat/help/squad" :
      "chat/help/short"
  return ::cross_call.get_gamepad_specific_localization(locId)
}


local chatHint = @() {
  rendObj = ROBJ_9RECT
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_HORIZONTAL
  valign = VALIGN_MIDDLE
  padding = [hdpx(5), hdpx(15)]
  gap = { size = flex() }
  color = colors.hud.hudLogBgColor
  children = [
    {
      rendObj = ROBJ_DTEXT
      font = Fonts.tiny_text_hud
      text = getHintText()
    }
    @() {
      rendObj = ROBJ_DTEXT
      watch = state.modeId
      text = ::cross_call.mp_chat_mode.getModeNameText(state.modeId.value)
      color = modeColor(state.modeId.value)
      font = Fonts.small_text_hud
    }
  ]
}


local inputField = @() {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  children = [
    chat.inputField(chatInputCtor)
  ]
}


local getMessageColor = function(message)
{
  if (message.isBlocked)
    return colors.menu.chatTextBlockedColor
  if (message.isAutomatic)
  {
    if (::cross_call.squad_manger.isInMySquad(message.sender))
      return teamColors.squadColor
    else if (message.isEnemy)
      return teamColors.teamRedColor
    else
      return teamColors.teamBlueColor
  }
  return modeColor(message.mode) ?? colors.white
}


local getSenderColor = function (message)
{
  if (message.isMyself)
    return colors.hud.mainPlayerColor
  else if (::cross_call.isPlayerDedicatedSpectator(message.sender))
    return colors.hud.spectatorColor
  else if (message.isEnemy || !::cross_call.is_mode_with_teams())
    return teamColors.teamRedColor
  else if (::cross_call.squad_manger.isInMySquad(message.sender))
    return teamColors.squadColor
  return teamColors.teamBlueColor
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
      time.secondsToString(message.time, false),
      getSenderColor(message),
      ::cross_call.mp_chat_mode.getModeNameText(message.mode),
      ::cross_call.platform.getPlayerName(message.sender),
      getMessageColor(message),
      ::cross_call.filter_chat_message(message.text, message.isMyself)
    )
  }
  return @() {
    watch = teamColors.trigger
    size = [flex(), SIZE_TO_CONTENT]
    rendObj = ROBJ_TEXTAREA
    behavior = Behaviors.TextArea
    text = text
    font = Fonts.tiny_text_hud
    key = message
  }
}


local chatLogVisible = Watched(state.inputEnabled.value || hudState.cursorVisible.value)
local onInputTriggered = function (new_val) { chatLogVisible.update(new_val || hudState.cursorVisible.value) }
local logBox = hudLog({
  visibleState = chatLogVisible
  logComponent = chat
  messageComponent = messageComponent
  onAttach = function (elem) { state.inputEnabled.subscribe(onInputTriggered) }
  onDetach = function (elem) { state.inputEnabled.unsubscribe(onInputTriggered) }
  onCursorVisible = function (new_val) { chatLogVisible.update(new_val || state.inputEnabled.value) }
})


local onInputToggle = function (enable) {
  if (enable) {
    ::set_kb_focus(chat.form)
  } else {
    ::set_kb_focus(null)
  }
}


return function () {
  return {
    size = flex()
    flow = FLOW_VERTICAL
    gap = sh(0.5)

    children = [
      logBox
      @() {
        size = [flex(), SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        opacity = state.inputEnabled.value ? 1.0 : 0.0

        watch = state.inputEnabled

        children = [
          inputField
          chatHint
        ]

        onAttach = function (elem) {
          state.inputEnabled.subscribe(onInputToggle)
        }
        onDetach = function (elem) {
          state.inputEnabled.unsubscribe(onInputToggle)
        }
        transitions = [transition()]
      }
    ]
  }
}
