local math = require("math")

local function countdownTimer(secondsWatch, endTimeWatch, curTimeFunc, minOffset = 0.1) {
  local function update(t) {}
  update = function() {
    local leftTime = ::max(endTimeWatch.value - curTimeFunc(), 0)
    local leftTimeInt = math.ceil(leftTime).tointeger()
    if (leftTimeInt > 0) {
      local timeToUpdate = (leftTime % 1.0) + minOffset
      ::gui_scene.setTimeout(timeToUpdate, update)
    }
    secondsWatch(leftTimeInt)
  }
  endTimeWatch.subscribe(@(v) update())
  update()
}

return countdownTimer