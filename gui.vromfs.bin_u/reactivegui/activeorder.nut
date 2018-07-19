local orderState = require("orderState.nut")
local colors = require("style/colors.nut")
local teamColors = require("style/teamColors.nut")




local pilotIcon = Picture("!ui/gameuiskin#player_in_queue")


local colorTable = {
  userlogColoredText = colors.menu.userlogColoredText
  unlockActiveColor = colors.menu.unlockActiveColor
}


local scoresTable = @() {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  watch = orderState.scoresTable
  children = orderState.scoresTable.value.map(@(item) {
    size = [hdpx(400), SIZE_TO_CONTENT]
    flow = FLOW_HORIZONTAL
    valign = VALIGN_BOTTOM
    children = [
      {
        rendObj = ROBJ_IMAGE
        size = [hdpx(24), hdpx(24)]
        image = pilotIcon
      }
      @(){
        rendObj = ROBJ_TEXTAREA
        behavior = Behaviors.TextArea
        watch = teamColors.trigger
        text = item.player
        size = [flex(15), SIZE_TO_CONTENT]
        font = Fonts.tiny_text_hud
        color = colors.menu.commonTextColor
        colorTable = function () {
          local res = teamColors()
          res.hudColorHero <- colors.hud.mainPlayerColor
          res.userlogColoredText <- colors.menu.userlogColoredText
          res.unlockActiveColor <- colors.menu.unlockActiveColor
          res.hudColorRed <- teamColors.teamRedColor
          res.hudColorBlue <- teamColors.teamBlueColor
          res.hudColorSquad <- teamColors.squadColor
          return res
        }()
      }
      {
        rendObj = ROBJ_TEXTAREA
        behavior = Behaviors.TextArea
        text = item.score
        size = [flex(6), SIZE_TO_CONTENT]
        font = Fonts.tiny_text_hud
        color = colors.menu.commonTextColor
        halign = HALIGN_RIGHT
      }
    ]
  })
}


local updateFunction = function () {
  ::cross_call.active_order_request_update()
}


return function() {
  return {
    flow = FLOW_VERTICAL
    size = [sw(30), SIZE_TO_CONTENT]
    watch = orderState.showOrder
    isHidden = !orderState.showOrder.value
    onAttach = function (elem) {
      ::cross_call.active_order_enable()
      ::gui_scene.setInterval(1, updateFunction) }
    onDetach = function (elem) { ::gui_scene.clearTimer(updateFunction) }
    children = [
      @() {
        watch = orderState.statusText
        rendObj = ROBJ_TEXTAREA
        behavior = Behaviors.TextArea
        size = [flex(), SIZE_TO_CONTENT]
        text = orderState.statusText.value
        font = Fonts.tiny_text_hud
        color = colors.menu.commonTextColor
        colorTable = colorTable
      }
      scoresTable
      @() {
        watch = orderState.statusTextBottom
        rendObj = ROBJ_TEXTAREA
        behavior = Behaviors.TextArea
        size = [flex(), SIZE_TO_CONTENT]
        text = orderState.statusTextBottom.value
        font = Fonts.tiny_text_hud
        color = colors.menu.commonTextColor
        colorTable = colorTable
      }
    ]
  }
}
