::g_lb_data_type <- {
  types = []
}

::g_lb_data_type_cache <- {
  byId = {}
}

function g_lb_data_type::_getStandartTooltip(type, value)
{
  local shortText = type.getShortTextByValue(value)
  local fullText = type.getFullTextByValue(value)
  return fullText != shortText ? (::loc("leaderboards/exactValue") + ::loc("ui/colon") + ::stripTags(fullText)) : ""
}

::g_lb_data_type.template <- {
  getFullTextByValue = function (value, allowNegative = false) {
    return value.tostring()
  }

  getShortTextByValue = function (value, allowNegative = false) {
    return getFullTextByValue(value, allowNegative)
  }

  getPrimaryTooltipText = function (value, allowNegative = false) {
    return ""
  }

  getAdditionalTooltipPartValueText = function (value, hideIfZero)
  {
    return ""
  }
}

::g_enum_utils.addTypesByGlobalName("g_lb_data_type", {
  NUM = {

    getFullTextByValue = function (value, allowNegative = false) {
      if (typeof value == "string")
        value = ::to_integer_safe(value)

      return (!allowNegative && value < 0) ? ::loc("leaderboards/notAvailable") : value.tostring()
    }

    getShortTextByValue = function (value, allowNegative = false) {
      if (typeof value == "string")
        value = ::to_integer_safe(value)

      return (!allowNegative && value < 0) ? ::loc("leaderboards/notAvailable") : ::getShortTextFromNum(::to_integer_safe(value))
    }

    getPrimaryTooltipText = function (value, allowNegative = false) {
      if (typeof value == "string")
        value = ::to_integer_safe(value)

      return (allowNegative || value >= 0) ? ::g_lb_data_type._getStandartTooltip(this, value) : ""
    }

    getAdditionalTooltipPartValueText = function (value, hideIfZero)
    {
      if (typeof value == "string")
        value = ::to_integer_safe(value)

      return hideIfZero
        ? (value >  0) ? value.tostring () : ""
        : (value >= 0) ? value.tostring () : ""
    }
  }

  FLOAT = {
    getFullTextByValue = function (value, allowNegative = false) {
      if (typeof value == "string")
        value = ::to_float_safe(value)

      return (!allowNegative && value < 0)
        ? ::loc("leaderboards/notAvailable")
        : round_by_value(value, 0.01)
    }
  }

  TIME = {
    getFullTextByValue = function (value, allowNegative = false) {
      value = value.tofloat() / TIME_HOUR_IN_SECONDS_F
      local res = ::hoursToString(value)
      return res
    }

    getShortTextByValue = function (value, allowNegative = false) {
      value = value.tofloat() / TIME_HOUR_IN_SECONDS_F
      local res = ::hoursToString(value, false)
      return res
    }

    getPrimaryTooltipText = function (value, allowNegative = false)
    {
      return ::g_lb_data_type._getStandartTooltip(this, value)
    }
  }

  TIME_MIN = {
    getFullTextByValue = function (value, allowNegative = false) {
      value = value.tofloat() / TIME_MINUTE_IN_SECONDS_F
      local res = ::hoursToString(value)
      return res
    }

    getShortTextByValue = function (value, allowNegative = false) {
      value = value.tofloat() / TIME_MINUTE_IN_SECONDS_F
      local res = ::hoursToString(value, false)
      return res
    }

    getPrimaryTooltipText = function (value, allowNegative = false)
    {
      return ::g_lb_data_type._getStandartTooltip(this, value)
    }
  }

  TIME_MSEC = {
    getFullTextByValue = function (value, allowNegative = false) {
      value = value.tofloat() / 1000.0
      return ::getRaceTimeFromSeconds(value)
    }
  }

  PERCENT = {
    getFullTextByValue = function (value, allowNegative = false) {
      return value < 0 ? loc("leaderboards/notAvailable") : roundToDigits(100.0 * value, 3) + "%"
    }

    getPrimaryTooltipText = function (value, allowNegative = false) {
      return value < 0 ? ::loc("multiplayer/victories_battles_na_tooltip") : ""
    }
  }

  PLACE = {

    getFullTextByValue = function (value, allowNegative = false) {
      if (typeof value == "string")
        value = ::to_integer_safe(value)

      return (!allowNegative && value < 0) ? ::loc("leaderboards/notAvailable") : value.tostring()
    }

    getPrimaryTooltipText = function (value, allowNegative = false) {
      if (typeof value == "string")
        value = ::to_integer_safe(value)

      return (!allowNegative && value < 0) ? ::loc("leaderboards/not_in_leaderboard") : ""
    }
  }

  DATE = {
    getFullTextByValue = function (value, allowNegative = false) {
      return ::build_date_str(::get_time_from_t(value))
    }
  }

  ROLE = {
    getFullTextByValue = function (value,  allowNegative = false) {
      return ::loc("clan/" + ::clan_get_role_name(value))
    }

    getPrimaryTooltipText = function (value, allowNegative =false) {
      local res = ::loc("clan/roleRights")+" \n"
      local rights = ::clan_get_role_rights(value)

      if (rights.len() > 0)
        foreach(right in rights)
          res += "* "+::loc("clan/"+right+"_right")+" \n"
      else
        res = ::loc("clan/noRights")

      return res
    }
  }

  TEXT = {
  }

  UNKNOWN = {
  }
})

function g_lb_data_type::getTypeById(id)
{
  return ::g_enum_utils.getCachedType("id", id, ::g_lb_data_type_cache.byId,
                                       ::g_lb_data_type, ::g_lb_data_type.UNKNOWN)
}
