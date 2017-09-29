local bg = Picture("!ui/gameuiskin#debriefing_bg_grad@@ss")
local setHudBg = function (component) {
  local result = component
  if (typeof component == "function") {
    result = component()
  }
  result.rendObj <- ROBJ_9RECT
  result.texOffs <- [0,30]
  result.screenOffs <- [0,sh(10.0/1080*100)]
  result.color <- Color(0, 0, 0, 128)
  result.image <- bg
  return result
}

return setHudBg
