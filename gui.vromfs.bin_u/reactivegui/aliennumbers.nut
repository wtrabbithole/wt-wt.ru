local math = require("std/math.nut")

const numeralSystemBase = 7

local digits = null

local initDigits = function()
{
  digits = {
    ["."] = ::loc("HUD/alien/comma", "."),
    ["-"] = ::loc("HUD/alien/minus", "-"),
  }
  for (local i = 0; i < numeralSystemBase; i++)
    digits[i.tostring()] <- ::loc("HUD/alien/digit" + i, i.tostring())
}

local getNumStr = function(num)
{
  num = num.tointeger()
  local res = ""

  if (!digits)
    initDigits()

  local isNegative = num < 0
  num = math.abs(num)
  local dig = math.floor((num > 0 ? math.log(num) : 0) / math.log(numeralSystemBase) + 1).tointeger()
  for (local d = dig - 1; d >= 0; d--)
  {
    local digitWeight = math.pow(numeralSystemBase, d).tointeger()
    local digitVal = num / digitWeight
    local digitIdx = digitVal % numeralSystemBase
    res += digits[digitIdx.tostring()]
    num -= digitVal * digitWeight
  }
  if (isNegative)
    res += digits["-"]

  return res
}

local getCompassParams = @() {
  grad = math.pow(numeralSystemBase, 3)
  pole = math.pow(numeralSystemBase, 2)
  step = numeralSystemBase * 1.0
}

local convPercentage = @(p) math.round(p * numeralSystemBase * numeralSystemBase / 100.0).tointeger()

return {
  getNumStr = getNumStr
  getCompassParams = getCompassParams
  convPercentage = convPercentage
}
