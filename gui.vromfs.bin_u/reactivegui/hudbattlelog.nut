local state = require("battleLogState.nut")
local scrollableData = require("daRg/components/scrollableData.nut")
local hudLog = require("components/hudLog.nut")
local teamColors = require("style/teamColors.nut")
local fontsState = require("reactiveGui/style/fontsState.nut")

local logEntryComponent = function (log_entry) {
  return function () {
    return  {
      watch = teamColors
      size = [flex(), SIZE_TO_CONTENT]
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      text = log_entry.message
      font = fontsState.get("small")
      key = log_entry
      colorTable = teamColors.value
    }
  }
}

local logBox = hudLog({
  logComponent = scrollableData.make(state.log)
  messageComponent = logEntryComponent
})

return {
  size = [flex(), SIZE_TO_CONTENT]
  children = logBox
}
