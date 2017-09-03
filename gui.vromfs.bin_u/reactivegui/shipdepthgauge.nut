local state = require("shipState.nut")
return @(){
  watch = state.showDepthUnderShip
  isHidden = !state.showDepthUnderShip.value
  size = SIZE_TO_CONTENT
  flow = FLOW_HORIZONTAL
  children = [
    {
      rendObj = ROBJ_STEXT
      font = Fonts.small_text_hud
      fontSize = sh(18.0/1080*100)
      text = ::loc("hud_ship_depth_on_course_warning") + ::loc("ui/colon")
    }
    @() {
      watch = state.depthUnderShip
      rendObj = ROBJ_DTEXT
      font = Fonts.small_text_hud
      text = state.depthUnderShip.value
    }
    {
      rendObj = ROBJ_STEXT
      font = Fonts.small_text_hud
      fontSize = sh(18.0/1080*100)
      text = ::cross_call.measureTypes.DEPTH.getMeasureUnitsName()
    }
  ]
}
