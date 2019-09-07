local state = require("battleLogState.nut")
local scrollableData = require("daRg/components/scrollableData.nut")
local hudLog = require("components/hudLog.nut")
local colors = require("style/colors.nut")
local teamColors = require("style/teamColors.nut")
local fontsState = require("reactiveGui/style/fontsState.nut")


local logEntryComponent = function (log_entry) {
  return function () {
    return  {
      watch = teamColors.trigger
      size = [flex(), SIZE_TO_CONTENT]
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      text = log_entry.message
      font = fontsState.get("small")
      key = log_entry
      colorTable = {
        hudColorDarkRed = teamColors.teamRedInactiveColor
        hudColorDarkBlue = teamColors.teamBlueInactiveColor
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
  logComponent = scrollableData.make(state.log)
  messageComponent = logEntryComponent
})

return {
  size = [flex(), SIZE_TO_CONTENT]
  children = logBox
}
