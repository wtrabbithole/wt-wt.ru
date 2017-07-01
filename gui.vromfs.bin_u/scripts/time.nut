/*
int ::get_charserver_time_sec() - gets UTC_posix_timestamp from char server clock.
timeTbl ::get_local_time() - gets local_timeTable from client machine clock.
timeTbl ::get_utc_time() - gets UTC_timeTable from char server clock.
int ::get_t_from_utc_time(timeTbl) - converts UTC_timeTable to UTC_posix_timestamp.
timeTbl ::get_utc_time_from_t(int) - converts UTC_posix_timestamp to UTC_timeTable.
int ::mktime(timeTbl) - converts local_timeTable to UTC_posix_timestamp.
timeTbl ::get_time_from_t(int) - converts UTC_posix_timestamp to local_timeTable.
*/

::time_order <- ["year", "month", "day", "hour", "min", "sec"]
const DAYS_TO_YEAR_1970 = 719528

const TIME_SECOND_IN_MSEC = 1000
const TIME_SECONDS = 1
const TIME_MINUTE_IN_SECONDS = 60
const TIME_MINUTE_IN_SECONDS_F = 60.0
const TIME_HOUR_IN_SECONDS = 3600
const TIME_HOUR_IN_SECONDS_F = 3600.0
const TIME_DAY_IN_SECONDS = 86400
const TIME_DAY_IN_SECONDS_F = 86400.0
const TIME_WEEK_IN_SECONDS = 604800
const TIME_WEEK_IN_SECONDS_F = 604800.0

function get_full_time_table(time, fillMissedByTimeTable = null)
{
  foreach(p in ::time_order)
    if (!(p in time))
      time[p] <- ::getTblValue(p, fillMissedByTimeTable)
    else
      fillMissedByTimeTable = null  //only higher part from utc
  return time
}

function milliseconds_to_seconds(time)
{
  return time / 1000.0
}

function seconds_to_hours(seconds)
{
  return seconds / TIME_HOUR_IN_SECONDS_F
}

function get_days_by_time(timeTbl)
{
  return DAYS_TO_YEAR_1970 + ::get_t_from_utc_time(timeTbl) / TIME_DAY_IN_SECONDS
}

function get_utc_days()
{
  return DAYS_TO_YEAR_1970 + ::get_charserver_time_sec() / TIME_DAY_IN_SECONDS
}

function validate_time(timeTbl)
{
  timeTbl.year = ::clamp(timeTbl.year, 1970, 2037)
  timeTbl.month = ::clamp(timeTbl.month, 0, 11)
  timeTbl.day = ::clamp(timeTbl.day, 1, 31)
  timeTbl.hour = ::clamp(timeTbl.hour, 0, 23)
  timeTbl.min = ::clamp(timeTbl.min, 0, 59)
  timeTbl.sec = ::clamp(timeTbl.sec, 0, 59)
  local check = ::get_utc_time_from_t(::get_t_from_utc_time(timeTbl))
  timeTbl.day -= (timeTbl.day == check.day) ? 0 : check.day
}

function cmp_date(timeTbl1, timeTbl2)
{
  local t1 = ::get_t_from_utc_time(timeTbl1)
  local t2 = ::get_t_from_utc_time(timeTbl2)
  return t1 == t2 ? 0 : t1 < t2 ? -1 : 1
}

function debug_time(t)
{
  dlog("Time: " + build_iso8601_date_time_str(t, " "))
}

function build_iso8601_date_time_str(timeTable,
  dateTimeSeperator = "T", dateSeperator = "-", timeSeperator = ":")
{
  local date =
    timeTable.year == -1 ? ""
      : ::format("%04d", timeTable.year)
        + (timeTable.month == -1 ? ""
          : dateSeperator + ::format("%02d", timeTable.month)
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

function build_date_time_str(timeTable, showZeroSeconds = false, showSeconds = true)
{
  local time_str = build_time_str(timeTable, showZeroSeconds, showSeconds)
  local localTime = ::get_local_time()
  local year = ::getTblValue("year", timeTable, -1)
  local month = ::getTblValue("month", timeTable, -1)
  local day = ::getTblValue("day", timeTable, -1)

  if ((localTime.year == year && localTime.month == month && localTime.day == day)
      || (day <= 0 && month < 0))
    return time_str

  return build_date_str(timeTable) + " " + time_str
}

function build_date_str(timeTable)
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

function build_time_str(timeTable, showZeroSeconds = false, showSeconds = true)
{
  local sec = ::getTblValue("sec", timeTable, -1)
  if (showSeconds && (sec > 0 || (showZeroSeconds && sec == 0)))
    return ::format("%d:%02d:%02d", timeTable.hour, timeTable.min, timeTable.sec)
  else
    return ::format("%d:%02d", timeTable.hour, timeTable.min)
}

function convert_utc_to_local_time(utcTimeTbl)
{
  return ::get_time_from_t(::get_t_from_utc_time(utcTimeTbl) -
    ::get_charserver_time_sec() + ::mktime(::get_local_time()))
}

function get_time_from_string_utc(str)
{
  return ::get_time_from_string(str, ::get_utc_time())
}

function get_timestamp_from_string_utc(str)
{
  return ::mktime(::get_time_from_string_utc(str))
}

function is_in_timerange_by_utc_strings(beginDateStr, endDateStr)
{
  if (!::u.isEmpty(beginDateStr) &&
    ::get_timestamp_from_string_utc(beginDateStr) > ::get_charserver_time_sec())
    return false
  if (!::u.isEmpty(endDateStr) &&
    ::get_timestamp_from_string_utc(endDateStr) < ::get_charserver_time_sec())
    return false
  return true
}

function get_time_from_string(str, fillMissedByTimeTable = null)
{
  local timeArray = ::split(str, ":- ")
  local haveSeconds = regexp2(@"\d:\d+:\d+$").match(str)
  if (!haveSeconds)
    timeArray.append("0")

  local res = {}
  local lenDiff = timeArray.len() - ::time_order.len()
  for(local p = ::time_order.len() - 1; p >= 0; --p)
  {
    local i = p + lenDiff
    if (i < 0)
      break

    if (!(regexp2(@"\D+").match(timeArray[i])))
      res[::time_order[p]] <- timeArray[i].tointeger()
    else
      return null
  }

  if ("month" in res)
    res.month -= 1

  local timeTbl = ::get_full_time_table(res, fillMissedByTimeTable)
  if (fillMissedByTimeTable)
    ::validate_time(timeTbl)
  return timeTbl
}

function processTimeStamps(text)
{
  foreach (idx, time in ["{time=", "{time_countdown="])
  {
    local startPos = 0
    local startTime = time
    local endTime = "}"

    local continueSearch = true
    do {
      local startIdx = text.find(startTime, startPos)
      continueSearch = (startIdx != null)
      if (!continueSearch)
        break

      startIdx += startTime.len()
      local endIdx = text.find(endTime, startIdx)
      if (endIdx == null)
        break

      startPos++
      local timeTable = ::get_time_from_string_utc(text.slice(startIdx, endIdx))
      if (!timeTable)
        continue

      local textTime = ""
      if (time == "{time_countdown=")
        textTime = ::hoursToString(::max( 0, ::get_t_from_utc_time(timeTable) - ::get_charserver_time_sec() ) / TIME_HOUR_IN_SECONDS_F, true, true)
      else
        textTime = ::build_date_time_str(::convert_utc_to_local_time(timeTable))
      text = text.slice(0, startIdx - startTime.len()) + textTime + text.slice(endIdx+1)
    } while(continueSearch)
  }

  return text
}

function hoursToString(time, full=true, useSeconds = false, dontShowZeroParam = false, fullUnits = false)
{
  local res = []

  local sign = time >= 0 ? "" : ::loc("ui/minus")
  time = ::fabs(time.tofloat())

  local dd = (time / 24).tointeger()
  local hh = (time % 24).tointeger()
  local mm = (time * TIME_MINUTE_IN_SECONDS % TIME_MINUTE_IN_SECONDS).tointeger()
  local ss = (time * TIME_HOUR_IN_SECONDS % TIME_MINUTE_IN_SECONDS).tointeger()

  if (dd)
  {
    res.append(
      fullUnits ? ::loc("measureUnits/full/days", { n = dd }) :
      dd + ::loc("measureUnits/days")
    )
    if (dontShowZeroParam && hh == 0)
      return sign + ::implode(res, " ")
  }

  if (hh && (full || time<24*7))
  {
    res.append(
      fullUnits ? ::loc("measureUnits/full/hours", { n = hh }) :
      ::format((time >= 24)? "%02d%s" : "%d%s", hh, ::loc("measureUnits/hours"))
    )
    if (dontShowZeroParam && mm == 0)
      return sign + ::implode(res, " ")
  }

  if (mm && (full || time<24))
    res.append(
      fullUnits ? ::loc("measureUnits/full/minutes", { n = mm }) :
      ::format((time >= 1)? "%02d%s" : "%d%s", mm, ::loc("measureUnits/minutes"))
    )

  if (ss && useSeconds && time < 1.0/6) // < 10min
    res.append(
      fullUnits ? ::loc("measureUnits/full/seconds", { n = ss }) :
      ::format("%02d%s", ss, ::loc("measureUnits/seconds"))
    )

  if (!res.len())
    return ""
  return sign + ::implode(res, " ")
}

function secondsToString(value, useAbbreviations = true, dontShowZeroParam = false)
{
  value = value != null ? value.tofloat() : 0.0
  local s = (::fabs(value) + 0.5).tointeger()
  local timeArray = []

  local hoursNum = s / TIME_HOUR_IN_SECONDS
  local minutesNum = (s % TIME_HOUR_IN_SECONDS) / TIME_MINUTE_IN_SECONDS
  local secondsNum = s % TIME_MINUTE_IN_SECONDS

  if (hoursNum != 0)
    timeArray.append(::format("%d%s", hoursNum, useAbbreviations ? ::loc("measureUnits/hours") : ""))

  if (!dontShowZeroParam || minutesNum != 0)
  {
    local fStr = timeArray.len() ? "%02d%s" : "%d%s"
    timeArray.append(::format(fStr, minutesNum, useAbbreviations ? ::loc("measureUnits/minutes") : ""))
  }

  if (!dontShowZeroParam || secondsNum != 0)
    timeArray.append(::format("%02d%s", secondsNum, useAbbreviations ? ::loc("measureUnits/seconds") : ""))

  local separator = useAbbreviations ? ::nbsp : ":"
  local sign = value >= 0 ? "" : ::loc("ui/minus")
  return sign + ::implode(timeArray, separator)
}

function preciseSecondsToString(value)
{
  value = value != null ? value.tofloat() : 0.0
  local sign = value >= 0 ? "" : ::loc("ui/minus")
  local ms = (::fabs(value) * 1000.0 + 0.5).tointeger()
  return ::format("%s%d:%02d.%03d", sign, ms / 60000, ms % 60000 / 1000, ms % 1000)
}

function getRaceTimeFromSeconds(value, zeroIsValid = false)
{
  if (typeof value != "float" && typeof value != "integer")
    return ""
  if (value < 0 || !zeroIsValid && value == 0)
    return ::loc("leaderboards/notAvailable")
  return ::preciseSecondsToString(value)
}
