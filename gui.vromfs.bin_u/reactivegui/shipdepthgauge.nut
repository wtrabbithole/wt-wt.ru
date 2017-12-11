local state = require("shipState.nut")
local colors = require("style/colors.nut")

local color = @() state.depthUnderShipIsCritical.value
                        ? colors.hud.damageModule.alert
                        : colors.hud.damageModule.active
return @(){
  watch = [
    state.showDepthUnderShip
    state.depthUnderShipIsCritical
  ]
  isHidden = !state.showDepthUnderShip.value
  size = SIZE_TO_CONTENT
  flow = FLOW_HORIZONTAL
  children = [
    {
      rendObj = ROBJ_STEXT
      font = Fonts.small_text_hud
      fontSize = hdpx(22)
      text = ::loc("hud_ship_depth_on_course_warning") + ::loc("ui/colon")
      color = color()
    }
    @() {
      watch = state.depthUnderShip
      rendObj = ROBJ_DTEXT
      font = Fonts.small_text_hud
      text = state.depthUnderShip.value
      color = color()
    }
    {
      rendObj = ROBJ_STEXT
      font = Fonts.small_text_hud
      fontSize = hdpx(22)
      text = ::cross_call.measureTypes.DEPTH.getMeasureUnitsName()
      color = color()
    }
  ]
}
