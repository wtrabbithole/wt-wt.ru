local state = require("shipState.nut")
local colors = require("style/colors.nut")

return @(){
  watch = state.obstacleIsNear
  isHidden = !state.obstacleIsNear.value
  size = SIZE_TO_CONTENT
  flow = FLOW_HORIZONTAL
  children = [
    {
      rendObj = ROBJ_STEXT
      font = Fonts.small_text_hud
      fontSize = hdpx(15)
      text = ::loc("hud_ship_depth_on_course_warning") + ::loc("ui/colon")
      color = colors.hud.damageModule.alert
    }
    @() {
      watch = state.distanceToObstacle
      rendObj = ROBJ_DTEXT
      font = Fonts.small_text_hud
      text = state.distanceToObstacle.value
      color = colors.hud.damageModule.alert
    }
    {
      rendObj = ROBJ_STEXT
      font = Fonts.small_text_hud
      fontSize = hdpx(15)
      text = ::cross_call.measureTypes.DEPTH.getMeasureUnitsName()
      color = colors.hud.damageModule.alert
    }
  ]
}
