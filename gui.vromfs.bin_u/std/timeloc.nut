/*
!!!!!
This is bad module cause it depends on loc global function and on specific localization keys
and it kept here only for migration period

These functions also has very poor API:
  secondsToString(time, true, false, 2) - guess what is it for
  hoursToString(time / 3600.0, true, true, true, false) ??

!!!!
*/

local timeBase = require("time.nut")
local stdStr = require("string")
local math = require("math")

local {TIME_MINUTE_IN_SECONDS, TIME_HOUR_IN_SECONDS} = timeBase

local function hoursToString(time, full = true, useSeconds = false, dontShowZeroParam = false, fullUnits = false, i18n = ::loc) {
  local res = []
  local sign = time >= 0 ? "" : i18n("ui/minus")
  time = math.fabs(time.tofloat())

  local dd = (time / 24).tointeger()
  local hh = (time % 24).tointeger()
  local mm = (time * TIME_MINUTE_IN_SECONDS % TIME_MINUTE_IN_SECONDS).tointeger()
  local ss = (time * TIME_HOUR_IN_SECONDS % TIME_MINUTE_IN_SECONDS).tointeger()

  if (dd>0) {
    res.append(fullUnits ? i18n("measureUnits/full/days", { n = dd }) :
      "{0}{1}".subst(dd,i18n("measureUnits/days")))
    if (dontShowZeroParam && hh == 0) {
      return "".join([sign].extend(res))
    }
  }

  if (hh && (full || time<24*7)) {
    if (res.len()>0)
      res.append(" ")
    res.append(fullUnits ? i18n("measureUnits/full/hours", { n = hh }) :
      stdStr.format((time >= 24)? "%02d%s" : "%d%s", hh, i18n("measureUnits/hours")))
    if (dontShowZeroParam && mm == 0) {
      return "".join([sign].extend(res))
    }
  }

  if ((mm || (!res.len() && !useSeconds)) && (full || time<24)) {
    if (res.len()>0)
      res.append(" ")
    res.append(fullUnits ? i18n("measureUnits/full/minutes", { n = mm }) :
      stdStr.format((time >= 1)? "%02d%s" : "%d%s", mm, i18n("measureUnits/minutes")))
  }

  if ((((ss > 0 || !dontShowZeroParam) && useSeconds) || res.len()==0) && (time < 1.0 / 6)) { // < 10min
    if (res.len()>0)
      res.append(" ")
    res.append(fullUnits ? i18n("measureUnits/full/seconds", { n = ss }) :
      stdStr.format("%02d%s", ss, i18n("measureUnits/seconds")))
  }

  if (res.len()==0)
    return ""
  return "".join([sign].extend(res))
}


local function secondsToString(value, useAbbreviations = true, dontShowZeroParam = false, secondsFraction = 0, i18n = ::loc) {
  value = value != null ? value.tofloat() : 0.0
  local s = (math.fabs(value) + 0.5).tointeger()
  local res = []
  local separator = useAbbreviations ? " " : ":"
  local sign = value >= 0 ? "" : i18n("ui/minus")

  local hoursNum = s / TIME_HOUR_IN_SECONDS
  local minutesNum = (s % TIME_HOUR_IN_SECONDS) / TIME_MINUTE_IN_SECONDS
  local secondsNum = (secondsFraction > 0 ? value : s) % TIME_MINUTE_IN_SECONDS

  if (hoursNum != 0) {
    res.append(stdStr.format("%d%s", hoursNum, useAbbreviations ? i18n("measureUnits/hours") : ""))
  }

  if (!dontShowZeroParam || minutesNum != 0) {
    local fStr = res.len() > 0 ? "%02d%s" : "%d%s"
    if (res.len()>0)
      res.append(separator)
    res.append(
      stdStr.format(fStr, minutesNum, useAbbreviations ? i18n("measureUnits/minutes") : "")
    )
  }

  if (!dontShowZeroParam || secondsNum != 0 || res.len()==0) {
    local symbolsNum = res.len() ? 2 : 1
    local fStr = secondsFraction > 0
      ? $"%0{secondsFraction + 1 + symbolsNum}.{secondsFraction}f%s"
      : $"%0{symbolsNum}d%s"
    if (res.len()>0)
      res.append(separator)
    res.append(
      stdStr.format(fStr, secondsNum, useAbbreviations ? i18n("measureUnits/seconds") : "")
    )
  }

  if (res.len()==0)
    return ""
  return "".join([sign].extend(res))
}


local function buildDateStr(timeTable) {
  local year = timeTable?.year ?? -1
  local locId = year > 0 ? "date_format" : "date_format_short"
  return ::loc(locId, {
    year = year
    day = timeTable?.day ?? -1
    month = ::loc("sm_month_{0}".subst((timeTable?.month ?? -1)+1))
    dayOfWeek = ::loc("weekday_{0}".subst((timeTable?.dayOfWeek ?? -1)+1))
  })
}

local function buildTimeStr(timeTable, showZeroSeconds = false, showSeconds = true) {
  local sec = timeTable?.sec ?? -1
  if (showSeconds && (sec > 0 || (showZeroSeconds && sec == 0)))
    return stdStr.format("%d:%02d:%02d", timeTable.hour, timeTable.min, timeTable.sec)
  else
    return stdStr.format("%d:%02d", timeTable.hour, timeTable.min)
}

local buildDateTimeStr = @(timeTable, showZeroSeconds = false, showSeconds = true, formatStr = "{date}.{time}") //warning disable: -forgot-subst
  formatStr.subst({ date = buildDateStr(timeTable), time = buildTimeStr(timeTable, showZeroSeconds, showSeconds)})

return timeBase.__merge({
  secondsToString = secondsToString
  hoursToString = hoursToString
  buildDateStr = buildDateStr
  buildTimeStr = buildTimeStr
  buildDateTimeStr = buildDateTimeStr
})
