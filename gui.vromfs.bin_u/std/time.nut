const TIME_SECOND_IN_MSEC = 1000
const TIME_SECOND_IN_MSEC_F = 1000.0
const TIME_MINUTE_IN_SECONDS = 60
const TIME_MINUTE_IN_SECONDS_F = 60.0
const TIME_HOUR_IN_SECONDS = 3600
const TIME_HOUR_IN_SECONDS_F = 3600.0
const TIME_DAY_IN_HOURS = 24
const TIME_DAY_IN_SECONDS = 86400
const TIME_DAY_IN_SECONDS_F = 86400.0
const TIME_WEEK_IN_SECONDS = 604800
const TIME_WEEK_IN_SECONDS_F = 604800.0

local stdStr = require("string")
local math = require("math")


local millisecondsToSeconds = @(time) time / TIME_SECOND_IN_MSEC_F
local secondsToMilliseconds = @(time) time * TIME_SECOND_IN_MSEC_F
local millisecondsToSecondsInt = @(time) time / TIME_SECOND_IN_MSEC
local secondsToMinutes = @(time) time / TIME_MINUTE_IN_SECONDS_F
local minutesToSeconds = @(time) time * TIME_MINUTE_IN_SECONDS_F
local secondsToHours = @(seconds) seconds / TIME_HOUR_IN_SECONDS_F
local hoursToSeconds = @(seconds) seconds * TIME_HOUR_IN_SECONDS_F
local daysToSeconds = @(days) days * TIME_DAY_IN_SECONDS_F


local  hoursToString = function(time, full = true, useSeconds = false, dontShowZeroParam = false, fullUnits = false) {
  local res = ""
  local sign = time >= 0 ? "" : ::loc("ui/minus")
  time = math.fabs(time.tofloat())

  local dd = (time / 24).tointeger()
  local hh = (time % 24).tointeger()
  local mm = (time * TIME_MINUTE_IN_SECONDS % TIME_MINUTE_IN_SECONDS).tointeger()
  local ss = (time * TIME_HOUR_IN_SECONDS % TIME_MINUTE_IN_SECONDS).tointeger()

  if (dd) {
    res += fullUnits ? ::loc("measureUnits/full/days", { n = dd }) :
      dd + ::loc("measureUnits/days")
    if (dontShowZeroParam && hh == 0) {
      return sign + res
    }
  }

  if (hh && (full || time<24*7)) {
    res += (res.len() ? " " : "") +
      (fullUnits ? ::loc("measureUnits/full/hours", { n = hh }) :
      stdStr.format((time >= 24)? "%02d%s" : "%d%s", hh, ::loc("measureUnits/hours")))
    if (dontShowZeroParam && mm == 0) {
      return sign + res
    }
  }

  if (mm && (full || time<24)) {
    res += (res.len() ? " " : "") +
      (fullUnits ? ::loc("measureUnits/full/minutes", { n = mm }) :
      stdStr.format((time >= 1)? "%02d%s" : "%d%s", mm, ::loc("measureUnits/minutes")))
  }

  if (ss && useSeconds && time < 1.0/6) { // < 10min
    res += (res.len() ? " " : "") +
      (fullUnits ? ::loc("measureUnits/full/seconds", { n = ss }) :
      stdStr.format("%02d%s", ss, ::loc("measureUnits/seconds")))
  }

  return res.len() ? sign + res : ""
}


local secondsToString = function (value, useAbbreviations = true, dontShowZeroParam = false, secondsFraction = 0) {
  value = value != null ? value.tofloat() : 0.0
  local s = (math.fabs(value) + 0.5).tointeger()
  local res = ""
  local separator = useAbbreviations ? " " : ":"
  local sign = value >= 0 ? "" : ::loc("ui/minus")

  local hoursNum = s / TIME_HOUR_IN_SECONDS
  local minutesNum = (s % TIME_HOUR_IN_SECONDS) / TIME_MINUTE_IN_SECONDS
  local secondsNum = (secondsFraction > 0 ? value : s) % TIME_MINUTE_IN_SECONDS

  if (hoursNum != 0) {
    res += stdStr.format("%d%s", hoursNum, useAbbreviations ? ::loc("measureUnits/hours") : "")
  }

  if (!dontShowZeroParam || minutesNum != 0) {
    local fStr = res.len() ? "%02d%s" : "%d%s"
    res += (res.len() ? separator : "") +
      stdStr.format(fStr, minutesNum, useAbbreviations ? ::loc("measureUnits/minutes") : "")
  }

  if (!dontShowZeroParam || secondsNum != 0 || !res.len()) {
    local fStr = ""
    local symbolsNum = res.len() ? 2 : 1
    if (secondsFraction > 0)
      fStr += "%0" + (secondsFraction + 1 + symbolsNum) + "." + secondsFraction + "f%s"
    else
      fStr += "%0" + symbolsNum + "d%s"
    res += (res.len() ? separator : "") +
      stdStr.format(fStr, secondsNum, useAbbreviations ? ::loc("measureUnits/seconds") : "")
  }

  return res.len() ? sign + res : ""
}


local export = {
  millisecondsToSeconds = millisecondsToSeconds
  secondsToMilliseconds = secondsToMilliseconds
  millisecondsToSecondsInt = millisecondsToSecondsInt
  secondsToMinutes = secondsToMinutes
  minutesToSeconds = minutesToSeconds
  secondsToHours = secondsToHours
  hoursToSeconds = hoursToSeconds
  daysToSeconds = daysToSeconds

  hoursToString = hoursToString
  secondsToString = secondsToString
}


return export
