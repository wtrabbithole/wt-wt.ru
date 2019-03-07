local math = require("math")
local timeBase = require("std/time.nut")


/**
 * Native API:
 * int ::get_charserver_time_sec() - gets UTC_posix_timestamp from char server clock.
 * int ::get_t_from_utc_time(timeTbl) - converts UTC_timeTable to UTC_posix_timestamp.
 * timeTbl ::get_utc_time_from_t(int) - converts UTC_posix_timestamp to UTC_timeTable.
 * int (::get_local_time_sec() - charToLocalUtcDiff()) - gets UTC_posix_timestamp from client machine clock.
 * int (::mktime(timeTbl) - charToLocalUtcDiff()) - converts local_timeTable to UTC_posix_timestamp.
 * timeTbl ::get_time_from_t(int + charToLocalUtcDiff()) - converts UTC_posix_timestamp to local_timeTable.
 */


local timeOrder = ["year", "month", "day", "hour", "min", "sec"]
const DAYS_TO_YEAR_1970 = 719528

const TIME_MINUTE_IN_SECONDS = 60
const TIME_MINUTE_IN_SECONDS_F = 60.0
const TIME_HOUR_IN_SECONDS = 3600
const TIME_HOUR_IN_SECONDS_F = 3600.0
const TIME_DAY_IN_SECONDS = 86400
const TIME_DAY_IN_SECONDS_F = 86400.0
const TIME_WEEK_IN_SECONDS = 604800
const TIME_WEEK_IN_SECONDS_F = 604800.0


local charToLocalUtcDiff = function() {
  return ::get_local_time_sec() - ::get_charserver_time_sec()
}


local getFullTimeTable = function(time, fillMissedByTimeTable = null) {
  foreach(p in timeOrder) {
    if (!(p in time)) {
      time[p] <- ::getTblValue(p, fillMissedByTimeTable)
    } else {
      fillMissedByTimeTable = null  //only higher part from utc
    }
  }
  return time
}

local getUtcDays = @() DAYS_TO_YEAR_1970 + ::get_charserver_time_sec() / TIME_DAY_IN_SECONDS

local buildTabularDateTimeStr = function(t, showSeconds = false)
{
  local tm = ::get_time_from_t(t + charToLocalUtcDiff())
  return showSeconds ?
    ::format("%04d-%02d-%02d %02d:%02d:%02d", tm.year, tm.month+1, tm.day, tm.hour, tm.min, tm.sec) :
    ::format("%04d-%02d-%02d %02d:%02d", tm.year, tm.month+1, tm.day, tm.hour, tm.min)
}


local buildDateStr = function(t) {
  local timeTable = ::get_time_from_t(t + charToLocalUtcDiff())
  local date_str = ""

  local year = ::getTblValue("year", timeTable, -1)
  local month = ::getTblValue("month", timeTable, -1)
  local day = ::getTblValue("day", timeTable, -1)

  local monthLoc = ::loc("sm_month_" + (month+1))

  if (year > 0)
    date_str = ::format(::loc("date_format", {year = year, day = day, month = monthLoc}))
  else
    date_str = ::format(::loc("date_format_short", {day = day, month = monthLoc}))

  return date_str
}


local buildTimeStr = function(t, showZeroSeconds = false, showSeconds = true) {
  local timeTable = ::get_time_from_t(t + charToLocalUtcDiff())
  local sec = timeTable?.sec ?? -1
  if (showSeconds && (sec > 0 || (showZeroSeconds && sec == 0)))
    return ::format("%d:%02d:%02d", timeTable.hour, timeTable.min, timeTable.sec)
  else
    return ::format("%d:%02d", timeTable.hour, timeTable.min)
}


local buildDateTimeStr = function (t, showZeroSeconds = false, showSeconds = true) {
  local timeTable = ::get_time_from_t(t + charToLocalUtcDiff())
  local time_str = buildTimeStr(t, showZeroSeconds, showSeconds)
  local localTime = ::get_time_from_t(::get_local_time_sec())
  local year = ::getTblValue("year", timeTable, -1)
  local month = ::getTblValue("month", timeTable, -1)
  local day = ::getTblValue("day", timeTable, -1)

  if ((localTime.year == year && localTime.month == month && localTime.day == day)
      || (day <= 0 && month < 0))
    return time_str

  return buildDateStr(t) + " " + time_str
}

local getUtcMidnight = function() {
  return ::get_charserver_time_sec() / TIME_DAY_IN_SECONDS * TIME_DAY_IN_SECONDS
}


local validateTime = function (timeTbl) {
  timeTbl.year = ::clamp(timeTbl.year, 1970, 2037)
  timeTbl.month = ::clamp(timeTbl.month, 0, 11)
  timeTbl.day = ::clamp(timeTbl.day, 1, 31)
  timeTbl.hour = ::clamp(timeTbl.hour, 0, 23)
  timeTbl.min = ::clamp(timeTbl.min, 0, 59)
  timeTbl.sec = ::clamp(timeTbl.sec, 0, 59)
  local check = ::get_utc_time_from_t(::get_t_from_utc_time(timeTbl))
  timeTbl.day -= (timeTbl.day == check.day) ? 0 : check.day
}

local reDateYmdAtStart = regexp2(@"^\d+-\d+-\d+")
local reTimeHmsAtEnd = regexp2(@"\d+:\d+:\d+$")
local reNotNumeric = regexp2(@"\D+")

local getTimeFromString = function(str, fillMissedByTimeTable = null) {
  local timeOrderLen = timeOrder.len()
  local timeArray = ::split(str, ":- ")
  if (timeArray.len() < timeOrderLen)
  {
    if (reDateYmdAtStart.match(str))
      timeArray.resize(timeOrderLen, "0")
    else if (!reTimeHmsAtEnd.match(str))
      timeArray.append("0")
  }

  local res = {}
  local lenDiff = ::min(0, timeArray.len() - timeOrderLen)
  for(local p = timeOrderLen - 1; p >= 0; --p) {
    local i = p + lenDiff
    if (i < 0) {
      break
    }

    if (! reNotNumeric.match(timeArray[i])) {
      res[timeOrder[p]] <- timeArray[i].tointeger()
    } else {
      return null
    }
  }

  if ("month" in res) {
    res.month -= 1
  }

  local timeTbl = getFullTimeTable(res, fillMissedByTimeTable)
  if (fillMissedByTimeTable) {
    validateTime(timeTbl)
  }
  return timeTbl
}


local getTimestampFromStringUtc = function(str) {
  return ::get_t_from_utc_time(getTimeFromString(str, ::get_utc_time_from_t(::get_charserver_time_sec())))
}

local getTimestampFromStringLocal = function(str, fillMissedByTimestamp) {
  local fillMissedTimeTbl = ::get_time_from_t(fillMissedByTimestamp + charToLocalUtcDiff())
  return ::mktime(getTimeFromString(str, fillMissedTimeTbl)) - charToLocalUtcDiff()
}


local reIso8601FullUtc = ::regexp2(@"^\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?Z$")


local getIso8601FromTimestamp = function(timestamp) {
  local t = ::get_utc_time_from_t(timestamp)
  return format("%04d-%02d-%02dT%02d:%02d:%02dZ", t.year, t.month + 1, t.day, t.hour, t.min, t.sec)
}

local getTimestampFromIso8601 = function(str) {
  if (!str || !reIso8601FullUtc.match(str))
    return -1
  local timeArray = ::split(str, "-T:Z")
  local timeTbl = {}
  foreach (i, k in timeOrder)
    timeTbl[k] <- timeArray[i].tointeger()
  timeTbl.month -= 1
  return ::get_t_from_utc_time(timeTbl)
}


local isInTimerangeByUtcStrings = function(beginDateStr, endDateStr) {
  if (!::u.isEmpty(beginDateStr) &&
    getTimestampFromStringUtc(beginDateStr) > ::get_charserver_time_sec())
    return false
  if (!::u.isEmpty(endDateStr) &&
    getTimestampFromStringUtc(endDateStr) < ::get_charserver_time_sec())
    return false
  return true
}


local processTimeStamps = function(text) {
  foreach (idx, time in ["{time=", "{time_countdown="]) {
    local startPos = 0
    local startTime = time
    local endTime = "}"

    local continueSearch = true
    do {
      local startIdx = text.find(startTime, startPos)
      continueSearch = (startIdx != null)
      if (!continueSearch) {
        break
      }

      startIdx += startTime.len()
      local endIdx = text.find(endTime, startIdx)
      if (endIdx == null) {
        break
      }

      startPos++
      local t = getTimestampFromStringUtc(text.slice(startIdx, endIdx))
      if (t < 0)
        continue

      local textTime = ""
      if (time == "{time_countdown=") {
        textTime = timeBase.hoursToString(::max( 0, t - ::get_charserver_time_sec() ) / TIME_HOUR_IN_SECONDS_F, true, true)
      } else {
        textTime = buildDateTimeStr(t)
      }
      text = text.slice(0, startIdx - startTime.len()) + textTime + text.slice(endIdx+1)
    } while(continueSearch)
  }

  return text
}


local preciseSecondsToString = function(value, canShowZeroMinutes = true) {
  value = value != null ? value.tofloat() : 0.0
  local sign = value >= 0 ? "" : ::loc("ui/minus")
  local ms = (math.fabs(value) * 1000.0 + 0.5).tointeger()
  local mm = ms / 60000
  local ss = ms % 60000 / 1000
  ms = ms % 1000

  if (!canShowZeroMinutes && mm == 0)
    return ::format("%s%02d.%03d", sign, ss, ms)

  return ::format("%s%d:%02d.%03d", sign, mm, ss, ms)
}


local getRaceTimeFromSeconds = function(value, zeroIsValid = false) {
  if (typeof value != "float" && typeof value != "integer") {
    return ""
  }
  if (value < 0 || !zeroIsValid && value == 0) {
    return ::loc("leaderboards/notAvailable")
  }
  return preciseSecondsToString(value)
}


local getExpireText = function(expireMin)
{
  if (expireMin < TIME_MINUTE_IN_SECONDS)
    return expireMin + ::loc("measureUnits/minutes")

  local showMin = expireMin < 3 * TIME_MINUTE_IN_SECONDS
  local expireHours = math.floor(expireMin / TIME_MINUTE_IN_SECONDS_F + (showMin? 0.0 : 0.5))
  if (expireHours < 24)
    return expireHours + ::loc("measureUnits/hours") +
           (showMin? " " + (expireMin - TIME_MINUTE_IN_SECONDS * expireHours) + ::loc("measureUnits/minutes") : "")

  local showHours = expireHours < 3*24
  local expireDays = math.floor(expireHours / 24.0 + (showHours? 0.0 : 0.5))
  return expireDays + ::loc("measureUnits/days") +
         (showHours? " " + (expireHours - 24*expireDays) + ::loc("measureUnits/hours") : "")
}


timeBase.__update({
  getUtcDays = getUtcDays
  buildDateTimeStr = buildDateTimeStr
  buildDateStr = buildDateStr
  buildTimeStr = buildTimeStr
  buildTabularDateTimeStr = buildTabularDateTimeStr
  getUtcMidnight = getUtcMidnight
  getTimestampFromStringUtc = getTimestampFromStringUtc
  getTimestampFromStringLocal = getTimestampFromStringLocal
  isInTimerangeByUtcStrings = isInTimerangeByUtcStrings
  processTimeStamps = processTimeStamps
  getExpireText = getExpireText

  preciseSecondsToString = preciseSecondsToString
  getRaceTimeFromSeconds = getRaceTimeFromSeconds

  getIso8601FromTimestamp = getIso8601FromTimestamp
  getTimestampFromIso8601 = getTimestampFromIso8601
})

return timeBase
