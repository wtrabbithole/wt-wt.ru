const GLOBAL_LOADING_TIP_BIT = 0x8000
const MISSING_TIPS_IN_A_ROW_ALLOWED = 3

::g_script_reloader.loadOnce("scripts/loading/bhvLoadingTip.nut")

::g_tips <- {
  TIP_LIFE_TIME_MSEC = 10000
  TIP_LOC_KEY_PREFIX = "loading/"

  tipsKeys = { [GLOBAL_LOADING_TIP_BIT] = [] }
  existTipsMask = GLOBAL_LOADING_TIP_BIT

  curTip = ""
  curTipIdx = -1
  curTipUnitTypeMask = -1
  curNewbieUnitTypeMask = 0
  nextTipTime = -1

  isTipsValid = false
}

function g_tips::getTip(unitTypeMask = 0)
{
  if (unitTypeMask != curTipUnitTypeMask || nextTipTime <= ::dagor.getCurTime())
    genNewTip(unitTypeMask)
  return curTip
}

function g_tips::resetTipTimer()
{
  nextTipTime = -1
}

function g_tips::validate()
{
  if (isTipsValid)
    return
  isTipsValid = true

  tipsKeys.clear()
  tipsKeys[GLOBAL_LOADING_TIP_BIT] <- loadTipsKeysByUnitType(null, false)
  existTipsMask = GLOBAL_LOADING_TIP_BIT
  curNewbieUnitTypeMask = getNewbieUnitTypeMask()

  if (!("g_unit_type" in ::getroottable()))
    return

  foreach(unitType in ::g_unit_type.types)
  {
    if (unitType == ::g_unit_type.INVALID)
      continue
    local isMeNewbie = isMeNewbieOnUnitType(unitType.esUnitType)
    local keys = loadTipsKeysByUnitType(unitType, isMeNewbie)
    if (!keys.len() && isMeNewbie)
      keys = loadTipsKeysByUnitType(unitType, false)
    if (!keys.len())
      continue
    tipsKeys[unitType.bit] <- keys
    existTipsMask = existTipsMask | unitType.bit
  }
}

//for global tips typeName = null
function g_tips::getKeyFormat(typeName, isNewbie)
{
  local path = typeName ? [ typeName.tolower() ] : []
  if (isNewbie)
    path.append("newbie")
  path.append("tip%d")
  return ::g_string.implode(path, "/")
}

//for global tips unitType = null
function g_tips::loadTipsKeysByUnitType(unitType, isNeedOnlyNewbieTips)
{
  local res = []

  local configs = []
  foreach (isNewbieTip in [ true, false ])
    configs.append({
      isNewbieTip = isNewbieTip
      keyFormat   = getKeyFormat(unitType?.name, isNewbieTip)
      isShow      = !isNeedOnlyNewbieTips || isNewbieTip
    })

  local notExistInARow = 0
  for(local idx = 0; notExistInARow <= MISSING_TIPS_IN_A_ROW_ALLOWED; idx++)
  {
    local isShow = false
    local key = ""
    local tip = ""
    foreach (cfg in configs)
    {
      isShow = cfg.isShow
      key = ::format(cfg.keyFormat, idx)
      tip = ::loc(TIP_LOC_KEY_PREFIX + key, "")
      if (tip != "")
        break
    }

    if (tip == "")
    {
      notExistInARow++
      continue
    }
    notExistInARow = 0

    if (isShow)
      res.append(key)
  }
  return res
}

function g_tips::isMeNewbieOnUnitType(esUnitType)
{
  return ("my_stats" in ::getroottable()) && ::my_stats.isMeNewbieOnUnitType(esUnitType)
}

function g_tips::getNewbieUnitTypeMask()
{
  local mask = 0
  foreach(unitType in ::g_unit_type.types)
  {
    if (unitType == ::g_unit_type.INVALID)
      continue
    if (isMeNewbieOnUnitType(unitType.esUnitType))
      mask = mask | unitType.bit
  }
  return mask
}

function g_tips::getDefaultUnitTypeMask()
{
  if (!::g_login.isLoggedIn() || ::isInMenu())
    return existTipsMask

  local res = 0
  local gm = ::get_game_mode()
  if (gm == ::GM_DOMINATION || gm == ::GM_SKIRMISH)
    res = ::SessionLobby.getRequiredUnitTypesMask() || ::SessionLobby.getUnitTypesMask()
  else if (gm == ::GM_TEST_FLIGHT)
  {
    if (::show_aircraft)
      res = ::show_aircraft.unitType.bit
  }
  else if (::isInArray(gm, [::GM_SINGLE_MISSION, ::GM_CAMPAIGN, ::GM_DYNAMIC, ::GM_BUILDER, ::GM_DOMINATION]))
    res = ::g_unit_type.AIRCRAFT.bit

  return (res & existTipsMask) || existTipsMask
}

function g_tips::genNewTip(unitTypeMask = 0)
{
  nextTipTime = ::dagor.getCurTime() + TIP_LIFE_TIME_MSEC

  if (curNewbieUnitTypeMask && curNewbieUnitTypeMask != getNewbieUnitTypeMask())
    isTipsValid = false

  if (!isTipsValid || curTipUnitTypeMask != unitTypeMask)
  {
    curTipIdx = -1
    curTipUnitTypeMask = unitTypeMask
  }

  validate()

  if (!(unitTypeMask & existTipsMask))
    unitTypeMask = getDefaultUnitTypeMask()

  local totalTips = 0
  foreach(unitTypeBit, keys in tipsKeys)
    if (unitTypeBit & unitTypeMask)
      totalTips += keys.len()
  if (totalTips == 0)
  {
    curTip = ""
    curTipIdx = -1
    return
  }

  //choose new tip
  local newTipIdx = 0
  if (totalTips > 1)
  {
    local tipsToChoose = totalTips
    if (curTipIdx >= 0)
      tipsToChoose--
    newTipIdx = ::math.rnd() % tipsToChoose
    if (curTipIdx >= 0 && curTipIdx <= newTipIdx)
      newTipIdx++
  }
  curTipIdx = newTipIdx

  //get lang for chosen tip
  local tipIdx = curTipIdx
  foreach(unitTypeBit, keys in tipsKeys)
  {
    if (!(unitTypeBit & unitTypeMask))
      continue
    if (tipIdx >= keys.len())
    {
      tipIdx -= keys.len()
      continue
    }

    //found tip
    curTip = ::loc(TIP_LOC_KEY_PREFIX + keys[tipIdx])

    //add unit type icon if needed
    if (unitTypeBit != GLOBAL_LOADING_TIP_BIT && ::number_of_set_bits(unitTypeMask) > 1)
    {
      local icon = ::g_unit_type.getByBit(unitTypeBit).fontIcon
      curTip = ::colorize("fadedTextColor", icon) + " " + curTip
    }

    break
  }
}

function g_tips::onEventAuthorizeComplete(p) { isTipsValid = false }
function g_tips::onEventGameLocalizationChanged(p) { isTipsValid = false }

::subscribe_handler(::g_tips, ::g_listener_priority.DEFAULT_HANDLER)