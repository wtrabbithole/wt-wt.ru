local math = require("math")
local timeBase = require("std/time.nut")


/**
 * Native API:
 * int ::get_charserver_time_sec() - gets UTC_posix_timestamp from char server clock.
 * timeTbl ::get_local_time() - gets local_timeTable from client machine clock.
 * timeTbl ::get_utc_time() - gets UTC_timeTable from char server clock.
 * int ::get_t_from_utc_time(timeTbl) - converts UTC_timeTable to UTC_posix_timestamp.
 * timeTbl ::get_utc_time_from_t(int) - converts UTC_posix_timestamp to UTC_timeTable.
 * int ::mktime(timeTbl) - converts local_timeTable to UTC_posix_timestamp.
 * timeTbl ::get_time_from_t(int) - converts UTC_posix_timestamp to local_timeTable.
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


local getDaysByTime = @(timeTbl) DAYS_TO_YEAR_1970 + ::get_t_from_utc_time(timeTbl) / TIME_DAY_IN_SECONDS
local getCharServerDays = @() ::get_charserver_time_sec() / TIME_DAY_IN_SECONDS
local getUtcDays = @() DAYS_TO_YEAR_1970 + getCharServerDays()
local cmpDate = @(timeTbl1, timeTbl2) ::get_t_from_utc_time(timeTbl1) <=> ::get_t_from_utc_time(timeTbl2)


local buildIso8601DateTimeStr = function(
    timeTable,
    dateTimeSeperator = "T",
    dateSeperator = "-",
    timeSeperator = ":")
{
  local date =
    timeTable.year == -1 ? ""
      : ::format("%04d", timeTable.year)
        + (timeTable.month == -1 ? ""
          : dateSeperator + ::format("%02d", timeTable.month + 1)
            + (timeTable.day == -1 ? ""
              : dateSeperator + ::format("%02d", timeTable.day)))

  local time =
    timeTable.hour == -1 ? ""
      : ::format("%02d", timeTable.hour)
        + (timeTable.min == -1 ? ""
          : timeSeperator + ::format("%02d", timeTable.min)
            + (timeTable.sec == -1 ? ""
              : timeSeperator + ::format("%02d", timeTable.sec)))

  return date + (date != "" && time != "" ? dateTimeSeperator : "") + time
}


local buildDateStr = function(timeTable)
{
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


local buildTimeStr = function(timeTable, showZeroSeconds = false, showSeconds = true)
{
  local sec = ::getTblValue("sec", timeTable, -1)
  if (showSeconds && (sec > 0 || (showZeroSeconds && sec == 0)))
    return ::format("%d:%02d:%02d", timeTable.hour, timeTable.min, timeTable.sec)
  else
    return ::format("%d:%02d", timeTable.hour, timeTable.min)
}


local buildDateTimeStr = function (timeTable, showZeroSeconds = false, showSeconds = true) {
  local time_str = buildTimeStr(timeTable, showZeroSeconds, showSeconds)
  local localTime = ::get_local_time()
  local year = ::getTblValue("year", timeTable, -1)
  local month = ::getTblValue("month", timeTable, -1)
  local day = ::getTblValue("day", timeTable, -1)

  if ((localTime.year == year && localTime.month == month && localTime.day == day)
      || (day <= 0 && month < 0))
    return time_str

  return buildDateStr(timeTable) + " " + time_str
}


local convertUtcToLocalTime = function(utcTimeTbl) {
  return ::get_time_from_t(::get_t_from_utc_time(utcTimeTbl) -
    ::get_charserver_time_sec() + ::mktime(::get_local_time()))
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

local reTimeHmsAtEnd = regexp2(@"\d:\d+:\d+$")
local reNotNumeric = regexp2(@"\D+")

local getTimeFromString = function(str, fillMissedByTimeTable = null) {
  local timeArray = ::split(str, ":- ")
  local haveSeconds = reTimeHmsAtEnd.match(str)
  if (!haveSeconds) {
    timeArray.append("0")
  }

  local res = {}
  local timeOrderLen = timeOrder.len()
  local lenDiff = timeArray.len() - timeOrderLen
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


local getTimeFromStringUtc = function(str) {
  return getTimeFromString(str, ::get_utc_time())
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


local getTimestampFromStringUtc = function(str) {
  return ::get_t_from_utc_time(getTimeFromStringUtc(str))
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
      local timeTable = getTimeFromStringUtc(text.slice(startIdx, endIdx))
      if (!timeTable) {
        continue
      }

      local textTime = ""
      if (time == "{time_countdown=") {
        textTime = timeBase.hoursToString(::max( 0, ::get_t_from_utc_time(timeTable) - ::get_charserver_time_sec() ) / TIME_HOUR_IN_SECONDS_F, true, true)
      } else {
        textTime = buildDateTimeStr(convertUtcToLocalTime(timeTable))
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
  getFullTimeTable = getFullTimeTable
  getDaysByTime = getDaysByTime
  getCharServerDays = getCharServerDays
  getUtcDays = getUtcDays
  cmpDate = cmpDate
  buildDateTimeStr = buildDateTimeStr
  buildDateStr = buildDateStr
  buildTimeStr = buildTimeStr
  convertUtcToLocalTime = convertUtcToLocalTime
  getTimeFromStringUtc = getTimeFromStringUtc
  getTimeFromString = getTimeFromString
  isInTimerangeByUtcStrings = isInTimerangeByUtcStrings
  processTimeStamps = processTimeStamps
  getExpireText = getExpireText

  preciseSecondsToString = preciseSecondsToString
  getRaceTimeFromSeconds = getRaceTimeFromSeconds

  getIso8601FromTimestamp = getIso8601FromTimestamp
  getTimestampFromIso8601 = getTimestampFromIso8601
  buildIso8601DateTimeStr = buildIso8601DateTimeStr
})

return timeBase
