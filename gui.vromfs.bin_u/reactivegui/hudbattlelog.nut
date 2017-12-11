local state = require("battleLogState.nut")
local log = require("daRg/components/log.nut")
local hudLog = require("components/hudLog.nut")
local colors = require("style/colors.nut")
local teamColors = require("style/teamColors.nut")
local background = require("style/hudBackground.nut")
local scrollbar = require("components/scrollbar.nut")
local hudState = require("hudState.nut")


local logEntryComponent = function (log_entry) {
  return function () {
    local colorTable = teamColors()
    return  {
      watch = teamColors.trigger
      size = [flex(), SIZE_TO_CONTENT]
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      text = log_entry.message
      font = Fonts.tiny_text_hud
      key = log_entry
      colorTable = {
        hudColorDarkRed = teamColors.teamRedDarkColor
        hudColorDarkBlue = teamColors.teamBlueDarkColor
        hudColorRed = teamColors.teamRedColor
        hudColorBlue = teamColors.teamBlueColor
        hudColorSquad = teamColors.squadColor
        hudColorHero = colors.hud.mainPlayerColor
        hudColorDeathAlly = teamColors.teamRedLightColor
        hudColorDeathEnemy = teamColors.teamBlueLightColor
        userlogColoredText = colors.menu.userlogColoredText
        streakTextColor = colors.menu.streakTextColor
        silver = colors.menu.silver
      }
    }
  }
}


local battleLogVisible = Watched(false)
local logBox = hudLog({
  visibleState = battleLogVisible
  logComponent = log.makeLog(state.log)
  messageComponent = logEntryComponent
})

return {
  size = flex()
  children = logBox
}
