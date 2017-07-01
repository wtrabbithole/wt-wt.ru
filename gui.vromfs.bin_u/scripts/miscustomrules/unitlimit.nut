::g_unit_limit_classes <- {
}

class ::g_unit_limit_classes.LimitBase
{
  name = ""
  respawnsLeft = 0
  distributed = ::RESPAWNS_UNLIMITED

  constructor(_name, _respawnsLeft, _distributed = ::RESPAWNS_UNLIMITED)
  {
    name = _name
    respawnsLeft = _respawnsLeft
    distributed = _distributed
  }

  function isSame(unitLimit)
  {
    return name == unitLimit.name && getclass() == unitLimit.getclass()
  }

  function getRespawnsLeftText()
  {
    return respawnsLeft == ::RESPAWNS_UNLIMITED ? ::loc("options/resp_unlimited") : respawnsLeft
  }

  function getText()
  {
    return name
  }
}

class ::g_unit_limit_classes.LimitByUnitName extends ::g_unit_limit_classes.LimitBase
{
  function getText()
  {
    local res = ::getUnitName(name) + ::loc("ui/colon") + ::colorize("activeTextColor", getRespawnsLeftText())
    if (distributed != ::RESPAWNS_UNLIMITED)
    {
      local text = distributed > 0 ? ::colorize("userlogColoredText", distributed) : distributed
      res += ::loc("ui/parentheses/space", { text = text })
    }
    return res
  }
}

class ::g_unit_limit_classes.LimitByUnitRole extends ::g_unit_limit_classes.LimitBase
{
  function getText()
  {
    local fontIcon = ::colorize("activeTextColor", ::get_unit_role_icon(name))
    return fontIcon + ::get_role_text(name) + ::loc("ui/colon") + ::colorize("activeTextColor", getRespawnsLeftText())
  }
}

class ::g_unit_limit_classes.ActiveLimitByUnitRole extends ::g_unit_limit_classes.LimitBase
{
  function getText()
  {
    local fontIcon = ::colorize("activeTextColor", ::get_unit_role_icon(name))
    local amountText = ""
    if (distributed == ::RESPAWNS_UNLIMITED || respawnsLeft == ::RESPAWNS_UNLIMITED)
      amountText = ::colorize("activeTextColor", getRespawnsLeftText())
    else
    {
      local color = (distributed < respawnsLeft) ? "userlogColoredText" : "activeTextColor"
      amountText = ::colorize(color, distributed) + "/" + getRespawnsLeftText()
    }
    return ::loc("multiplayer/active_at_once", { nameOrIcon = fontIcon }) + ::loc("ui/colon") + amountText
  }
}

class ::g_unit_limit_classes.LimitByUnitType extends ::g_unit_limit_classes.LimitBase
{
  function getText()
  {
    local unitType = ::g_unit_type[name]
    local fontIcon = ::colorize("activeTextColor", unitType.fontIcon)
    return fontIcon + unitType.getArmyLocName() + ::loc("ui/colon") + ::colorize("activeTextColor", getRespawnsLeftText())
  }
}