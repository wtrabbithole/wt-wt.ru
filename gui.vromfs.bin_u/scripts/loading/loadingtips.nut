const GLOBAL_LOADING_TIP_BIT = 0x8000
const MISSING_TIPS_IN_A_ROW_ALLOWED = 3

::g_script_reloader.loadOnce("scripts/loading/bhvLoadingTip.nut")

::g_tips <- {
  TIP_LIFE_TIME_MSEC = 10000

  tipsIndexes = { [GLOBAL_LOADING_TIP_BIT] = [] }
  existTipsMask = GLOBAL_LOADING_TIP_BIT

  curTip = ""
  curTipIdx = -1
  curTipUnitTypeMask = -1
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
  tipsIndexes[GLOBAL_LOADING_TIP_BIT] = loadTipsIndexesByTypeName(null)
  existTipsMask = GLOBAL_LOADING_TIP_BIT

  if (!("g_unit_type" in ::getroottable()))
    return

  foreach(unitType in ::g_unit_type.types)
  {
    if (unitType == ::g_unit_type.INVALID)
      continue
    local indexes = loadTipsIndexesByTypeName(unitType.name)
    if (!indexes.len())
      continue
    tipsIndexes[unitType.bit] <- indexes
    existTipsMask = existTipsMask | unitType.bit
  }
}

//for global tips typeName = null
function g_tips::getKeyFormat(typeName)
{
  return typeName ? "loading/" + typeName.tolower() + "/tip%d" : "loading/tip%d"
}

function g_tips::loadTipsIndexesByTypeName(typeName)
{
  local res = []
  local keyFormat = getKeyFormat(typeName)
  local notExistInARow = 0
  for(local idx = 0; notExistInARow <= MISSING_TIPS_IN_A_ROW_ALLOWED; idx++)
  {
    local tip = ::loc(::format(keyFormat, idx), "")
    if (!tip.len())
    {
      notExistInARow++
      continue
    }

    res.append(idx)
    notExistInARow = 0
  }
  return res
}

function g_tips::getDefaultUnitTypeMask()
{
  if (!::g_login.isLoggedIn() || ::isInMenu())
    return existTipsMask

  local res = 0
  local gm = ::get_game_mode()
  if (gm == ::GM_DOMINATION || gm == ::GM_SKIRMISH)
    res = ::SessionLobby.getUnitTypesMask()
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
  validate()

  if (curTipUnitTypeMask != unitTypeMask)
  {
    curTipIdx = -1
    curTipUnitTypeMask = unitTypeMask
  }

  if (!(unitTypeMask & existTipsMask))
    unitTypeMask = getDefaultUnitTypeMask()

  local totalTips = 0
  foreach(unitTypeBit, indexes in tipsIndexes)
    if (unitTypeBit & unitTypeMask)
      totalTips += indexes.len()
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
  foreach(unitTypeBit, indexes in tipsIndexes)
  {
    if (!(unitTypeBit & unitTypeMask))
      continue
    if (tipIdx >= indexes.len())
    {
      tipIdx -= indexes.len()
      continue
    }

    //found tip
    local typeName = null
    if (unitTypeBit != GLOBAL_LOADING_TIP_BIT)
      typeName = ::g_unit_type.getByBit(unitTypeBit).name
    curTip = ::loc(::format(getKeyFormat(typeName), indexes[tipIdx]))
    break
  }
}

function g_tips::onEventAuthorizeComplete(p) { isTipsValid = false }
function g_tips::onEventGameLocalizationChanged(p) { isTipsValid = false }

::subscribe_handler(::g_tips, ::g_listener_priority.DEFAULT_HANDLER)