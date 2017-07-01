::tips_list <- {
  lastIdx = -1
  lastTypeNode = -1
  lastTip = ""
}

function init_all_tips()
{
  if ("unitTypesList" in ::getroottable())
    foreach (type in ::unitTypesList)
      ::tips_list[getUnitTypeText(type)] <- getTipsListByType(getUnitTypeText(type))
  ::tips_list.Globals <- getTipsListByType()
}

function getTipsListByType(type="")
{
  local list = []
  local idx = 0
  local errNotExists = 0
  local keyTip = ""
  local capStr = (type != "") ? "loading/%s/tip%d" : "loading/%stip%d"
  local tip = ""
  do {
    keyTip = ::format(capStr, type.tolower(), idx)
    tip = ::loc(keyTip, "")
    if (tip.len() > 0) {
      list.append(idx)
      errNotExists = 0
    }
    else
      errNotExists++
    idx++
  } while (errNotExists < 3)
  return list
}

function get_last_rnd_tip() //used from code
{
  return ::tips_list.lastTip
}

function get_rnd_tip(unitType=-1) //used from code
{
  local keyTip = ""
  if (::tips_list.lastTypeNode != unitType)
  {
    ::tips_list.lastIdx = -1
    ::tips_list.lastTypeNode = unitType
  }
  local numTips = ::tips_list.Globals.len()
  if ("unitTypesList" in ::getroottable())
    foreach (type in ::unitTypesList)
      if (type == unitType || unitType < 0)
        numTips += ::getTblValue(getUnitTypeText(type), ::tips_list, []).len()
  if (numTips == 0)
    return ""
  numTips = (::tips_list.lastIdx >= 0 && ::tips_list.lastIdx < numTips) ? numTips-1 : numTips
  local idx = (::math.rnd() % numTips)
  if (::tips_list.lastIdx >= 0 && numTips > 0 && idx == ::tips_list.lastIdx)
    idx++
  ::tips_list.lastIdx = idx
  if (idx >= ::tips_list.Globals.len())
  {
    idx -= ::tips_list.Globals.len()
    foreach (type in ::unitTypesList)
    {
      local nameType = getUnitTypeText(type)
      if (type == unitType || unitType < 0)
        if (idx < ::tips_list[nameType].len())
        {
          keyTip = ::format("loading/%s/tip%d", nameType.tolower(), ::tips_list[nameType][idx])
          break
        }
        else
          idx -= ::tips_list[nameType].len()
    }
  }
  else
    keyTip = ::format("loading/tip%d", ::tips_list.Globals[idx])
  ::tips_list.lastTip = ::loc(keyTip, "")
  return ::tips_list.lastTip
}

::init_all_tips()