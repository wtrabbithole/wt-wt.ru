local time = require("scripts/time.nut")
const DEFAULT_MISSION_HINT_PRIORITY = 100

local animTimerPid = ::dagui_propid.add_name_id("_transp-timer")

enum MISSION_HINT_TYPE {
  STANDARD   = "standard"
  TUTORIAL   = "tutorialHint"
  BOTTOM     = "bottom"
}

::g_hud_hints <- {
  types = []
  cache = { byName = {} }
}

function g_hud_hints::_buildMarkup(eventData, hintObjId)
{
  return ::g_hints.buildHintMarkup(buildText(eventData), getHintMarkupParams(eventData, hintObjId))
}

function g_hud_hints::_getHintMarkupParams(eventData, hintObjId)
{
  return {
    id = hintObjId || name
    style = getHintStyle()
    time = getTimerTotalTimeSec(eventData)
    timeoffset = getTimerCurrentTimeSec(eventData, ::dagor.getCurTime()) //creation time right now
  }
}

function g_hud_hints::_buildText(data)
{
  local shortcuts = getShortcuts(data)
  if (shortcuts == null)
  {
    local res = ::loc(getLocId(data))
    if (image)
      res = ::g_hints.hintTags[0] + ::g_hint_tag.IMAGE.makeTag(image) + ::g_hints.hintTags[1] + res
    return res
  }

  local rawShortcutsArray = ::u.isArray(shortcuts) ? shortcuts : [shortcuts]

  local notMapped = true
  local shouldPickOne = ::g_hud_hints.shouldPickFirstValid(rawShortcutsArray)

  if (shouldPickOne)
  {
    local rawShortcut = ::g_hud_hints.pickFirstValidShortcut(rawShortcutsArray)
    rawShortcutsArray = rawShortcut != null ? [rawShortcut] : []
  }
  else
    rawShortcutsArray = ::g_hud_hints.removeUnmappedShortcuts(rawShortcutsArray)

  local assigned = rawShortcutsArray.len() > 0
  if (!assigned)
  {
    local noKeyLocId = getNoKeyLocId()
    if (noKeyLocId != "")
      return ::loc(noKeyLocId)
  }

  local expandedShortcutArray = ::g_shortcut_type.expandShortcuts(rawShortcutsArray)
  local shortcutTag = ::g_hud_hints._wrapShortsCutIdWithTags(expandedShortcutArray)
  local result = ::loc(getLocId(data), { shortcut = shortcutTag })

  //If shortcut not specified in localization string it should
  //be placed at the beginig
  if (result.find(shortcutTag) == null)
    result = shortcutTag + " " + result

  return result
}

/**
 * Return true if only one shortcut should be picked from @shortcutArray
 */
function g_hud_hints::shouldPickFirstValid(shortcutArray)
{
  foreach (shortcutId in shortcutArray)
    if (::g_string.startsWith(shortcutId, "@"))
      return true
  return false
}

function g_hud_hints::pickFirstValidShortcut(shortcutArray)
{
  foreach (shortcutId in shortcutArray)
  {
    local localShortcutId = shortcutId //to avoid changes in original array
    if (::g_string.startsWith(localShortcutId, "@"))
      localShortcutId = localShortcutId.slice(1)
    local shortcutType = ::g_shortcut_type.getShortcutTypeByShortcutId(localShortcutId)
    if (shortcutType.isAssigned(localShortcutId))
      return localShortcutId
  }

  return null
}

function g_hud_hints::removeUnmappedShortcuts(shortcutArray)
{
  for (local i = shortcutArray.len() - 1; i >= 0; --i)
  {
    local shortcutType = ::g_shortcut_type.getShortcutTypeByShortcutId(shortcutArray[i])
    if (!shortcutType.isAssigned(shortcutArray[i]))
      shortcutArray.remove(i)
  }

  return shortcutArray
}

function g_hud_hints::_getLocId(data)
{
  return locId
}

function g_hud_hints::_getNoKeyLocId()
{
  return noKeyLocId
}

function g_hud_hints::_getLifeTime(data)
{
  return lifeTime || ::getTblValue("lifeTime", data, 0)
}

function g_hud_hints::_getShortcuts(data)
{
  return shortcuts
}

function g_hud_hints::_wrapShortsCutIdWithTags(shortNamesArray)
{
  local result = ""
  local separator = ::loc("hints/shortcut_separator")
  foreach (shortcutName in shortNamesArray)
  {
    if (result.len())
      result += separator

    result += ::g_hints.hintTags[0] + shortcutName + ::g_hints.hintTags[1]
  }
  return result
}

function g_hud_hints::_getHintNestId()
{
  return hintType.nestId
}

function g_hud_hints::_getHintStyle()
{
  return hintType.hintStyle
}

//all obsolette hinttype names must work as standard mission hint
local isStandardMissionHint = @(hintTypeName)
  hintTypeName != MISSION_HINT_TYPE.TUTORIAL && hintTypeName != MISSION_HINT_TYPE.BOTTOM

local genMissionHint = @(hintType, checkHintTypeNameFunc)
{
  hintType = hintType
  showEvent = "hint:missionHint:set"
  hideEvent = "hint:missionHint:remove"
  selfRemove = true

  _missionTimerTotalMsec = 0
  _missionTimerStartMsec = 0

  updateCbs = {
    ["mission:timer:start"] = function(hintData, eventData)
    {
      local totalSec = ::getTblValue("totalTime", eventData)
      if (!totalSec)
        return false

      _missionTimerTotalMsec = 1000 * totalSec
      _missionTimerStartMsec = ::dagor.getCurTime()
      return true
    },
    ["mission:timer:stop"] = function(hintData, eventData) {
      _missionTimerTotalMsec = 0
      return true
    }
  }

  isCurrent = function(eventData, isHideEvent)
  {
    if (isHideEvent && !("hintType" in eventData))
      return true
    return checkHintTypeNameFunc(::getTblValue("hintType", eventData, MISSION_HINT_TYPE.STANDARD))
  }

  getLocId = function (hintData)
  {
    return ::getTblValue("locId", hintData, "")
  }

  getShortcuts = function (hintData)
  {
    return ::getTblValue("shortcuts", hintData)
  }

  buildText = function (hintData) {
    local res = ::g_hud_hints._buildText.call(this, hintData)
    if (!getShortcuts(hintData))
      return res
    res = ::g_hints.hintTags[0] + ::g_hints.timerMark + ::g_hints.hintTags[1] + " " + res
    return res
  }

  getHintMarkupParams = function(eventData, hintObjId)
  {
    local res = ::g_hud_hints._getHintMarkupParams.call(this, eventData, hintObjId)
    res.hideWhenStopped <- true
    res.timerOffsetX <- "-w" //to timer do not affect message position.
    res.isOrderPopup <- ::getTblValue("isOverFade", eventData, false)

    res.animation <- ::getTblValue("shouldBlink", eventData, false) ? "wink"
      : ::getTblValue("shouldFadeout", eventData, false) ? "show"
      : null
    return res
  }

  getTimerTotalTimeSec = function(eventData)
  {
    if (_missionTimerTotalMsec <= 0
        || (::dagor.getCurTime() > _missionTimerTotalMsec + _missionTimerStartMsec))
      return 0
    return time.millisecondsToSeconds(_missionTimerTotalMsec)
  }
  getTimerCurrentTimeSec = function(eventData, hintAddTime)
  {
    return time.millisecondsToSeconds(::dagor.getCurTime() - _missionTimerStartMsec)
  }

  getLifeTime = @(eventData) ::getTblValue("time", eventData, 0)

  isInstantHide = @(eventData) !::getTblValue("shouldFadeout", eventData, true)
  hideHint = function(hintObject, isInstant)
  {
    if (isInstant)
      hintObject.getScene().destroyElement(hintObject)
    else
    {
      hintObject.animation = "hide"
      hintObject.selfRemoveOnFinish = "-1"
      hintObject.setFloatProp(animTimerPid, 1.0)
    }
    return !isInstant
  }
}

::g_hud_hints.template <- {
  name = "" //generated by typeName. Used as id in hud scene.
  typeName = "" //filled by typeName
  locId = ""
  noKeyLocId = ""
  image = null //used only when no shortcuts
  hintType = ::g_hud_hint_types.COMMON
  priority = 0

  getHintNestId = ::g_hud_hints._getHintNestId
  getHintStyle = ::g_hud_hints._getHintStyle

  getLocId = ::g_hud_hints._getLocId
  getNoKeyLocId = ::g_hud_hints._getNoKeyLocId

  getPriority = function(eventData) { return ::getTblValue("priority", eventData, priority) }
  isCurrent = @(eventData, isHideEvent) true

  //Some hints contain shortcuts. If there is only one shortuc in hint (common case)
  //just put shirtcut id in shortcuts field.
  //If there is more then one shortuc, the should be representd as table.
  //shortcut table format: {
  //  locArgumentName = shortcutid
  //}
  //locArgument will be used as wildcard id for locization text
  shortcuts = null
  getShortcuts         = ::g_hud_hints._getShortcuts
  buildMarkup          = ::g_hud_hints._buildMarkup
  buildText            = ::g_hud_hints._buildText
  getHintMarkupParams  = ::g_hud_hints._getHintMarkupParams
  getLifeTime          = ::g_hud_hints._getLifeTime

  selfRemove = false //will be true if lifeTime > 0
  lifeTime = 0.0
  getTimerTotalTimeSec    = function(eventData) { return getLifeTime(eventData) }
  getTimerCurrentTimeSec  = function(eventData, hintAddTime)
  {
    return time.millisecondsToSeconds(::dagor.getCurTime() - hintAddTime)
  }

  isInstantHide = @(eventData) true
  hideHint = function(hintObject, isInstant)  //return <need to instant hide when new hint appear>
  {
    hintObject.getScene().destroyElement(hintObject)
    return false
  }

  showEvent = null
  hideEvent = null
  updateCbs = null //{ <hudEventName> = function(hintData, eventData) { return <needUpdate (bool)>} } //hintData can be null

}

::g_enum_utils.addTypesByGlobalName("g_hud_hints", {
  UNKNOWN = {}

  OFFER_BAILOUT = {
    locId = "hints/ready_to_bailout"
    noKeyLocId = "hints/ready_to_bailout_nokey"
    shortcuts = "ID_BAILOUT"

    showEvent = "hint:bailout:offerBailout"
    hideEvent = ["hint:bailout:startBailout", "hint:bailout:notBailouts"]
  }

  START_BAILOUT = {
    awardGiveForLocId = "HUD_AWARD_GIVEN_FOR"

    getLocId = function (hintData)
    {
      return ::get_es_unit_type(::get_player_cur_unit()) == ::ES_UNIT_TYPE_AIRCRAFT
        ? "hints/bailout_in_progress"
        : "hints/leaving_the_tank_in_progress" //this localization is more general, then the "air" one
    }

    showEvent = "hint:bailout:startBailout"
    hideEvent = ["hint:bailout:offerBailout", "hint:bailout:notBailouts"]

    selfRemove = true
    buildText = function (data) {
      local res = ::g_hud_hints._buildText.call(this, data)
      res += " " + ::g_hints.hintTags[0] + ::g_hints.timerMark + ::g_hints.hintTags[1]
      local offenderName = ::getTblValue("offenderName", data, "")
      if (offenderName != "")
        res +=  "\n" + ::loc(awardGiveForLocId) + offenderName
      return res
    }
  }

  SKIP_XRAY_SHOT = {
    hintType = ::g_hud_hint_types.MINOR
    locId = "hints/skip"
    shortcuts = "ID_CONTINUE"
    showEvent = "hint:xrayCamera:showSkipHint"
    hideEvent = "hint:xrayCamera:hideSkipHint"
  }

  MISSION_HINT            = genMissionHint(::g_hud_hint_types.MISSION_STANDARD, isStandardMissionHint)
  MISSION_TUTORIAL_HINT   = genMissionHint(::g_hud_hint_types.MISSION_TUTORIAL,
    @(hintTypeName) hintTypeName == MISSION_HINT_TYPE.TUTORIAL)
  MISSION_BOTTOM_HINT     = genMissionHint(::g_hud_hint_types.MISSION_BOTTOM,
    @(hintTypeName) hintTypeName == MISSION_HINT_TYPE.BOTTOM)

  MISSION_BY_ID = {
    hintType = ::g_hud_hint_types.MISSION_STANDARD
    showEvent = "hint:missionHint:setById"
    hideEvent = "hint:missionHint:remove"
    lifeTime = 5.0
    priority = DEFAULT_MISSION_HINT_PRIORITY

    isCurrent = @(eventData, isHideEvent) !("hintType" in eventData) || isStandardMissionHint(eventData.hintType)
    getLocId = function(eventData)
    {
      return ::getTblValue("hintId", eventData, "hints/unknown")
    }
  }

  OBJECTIVE_ADDED = {
    hintType = ::g_hud_hint_types.MISSION_STANDARD
    showEvent = "hint:missionHint:objectiveAdded"
    hideEvent = "hint:missionHint:remove"
    locId = "hints/secondary_added"
    image = ::g_objective_status.RUNNING.missionObjImg
    lifeTime = 5.0
    priority = DEFAULT_MISSION_HINT_PRIORITY

    isCurrent = @(eventData, isHideEvent) !("hintType" in eventData) || isStandardMissionHint(eventData.hintType)
  }

  OBJECTIVE_SUCCESS = {
    hintType = ::g_hud_hint_types.MISSION_STANDARD
    showEvent = "hint:missionHint:objectiveSuccess"
    hideEvent = "hint:missionHint:remove"
    image = ::g_objective_status.SUCCEED.missionObjImg
    lifeTime = 5.0
    priority = DEFAULT_MISSION_HINT_PRIORITY

    isCurrent = @(eventData, isHideEvent) !("hintType" in eventData) || isStandardMissionHint(eventData.hintType)

    getLocId = function(hintData)
    {
      local objType = ::getTblValue("objectiveType", hintData, ::OBJECTIVE_TYPE_SECONDARY)
      if (objType == ::OBJECTIVE_TYPE_PRIMARY)
        return "hints/objective_success"
      if (objType == ::OBJECTIVE_TYPE_SECONDARY)
        return "hints/secondary_success"
      return ""
    }
  }

  OBJECTIVE_FAIL = {
    hintType = ::g_hud_hint_types.MISSION_STANDARD
    showEvent = "hint:missionHint:objectiveFail"
    hideEvent = "hint:missionHint:remove"
    image = ::g_objective_status.FAILED.missionObjImg
    lifeTime = 5.0
    priority = DEFAULT_MISSION_HINT_PRIORITY

    isCurrent = @(eventData, isHideEvent) !("hintType" in eventData) || isStandardMissionHint(eventData.hintType)

    getLocId = function(hintData)
    {
      local objType = ::getTblValue("objectiveType", hintData, ::OBJECTIVE_TYPE_PRIMARY)
      if (objType == ::OBJECTIVE_TYPE_PRIMARY)
        return "hints/objective_fail"
      if (objType == ::OBJECTIVE_TYPE_SECONDARY)
        return "hints/secondary_fail"
      return ""
    }
  }

  OFFER_REPAIR = {
    hintType = ::g_hud_hint_types.REPAIR
    getLocId = function (data) {
      if (::getTblValue("assist", data, false))
      {
        if (::get_es_unit_type(::get_player_cur_unit()) == ::ES_UNIT_TYPE_TANK)
          return "hints/repair_assist_tank_hold"
        return "hints/repair_assist_plane_hold"
      }
      return "hints/repair_tank_hold"
    }

    noKeyLocId = "hints/ready_to_bailout_nokey"
    shortcuts = "ID_REPAIR_TANK"

    showEvent = "tankRepair:offerRepair"
    hideEvent = "tankRepair:cantRepair"
  }

  CONTROLS_HELP = {
    hintType = ::g_hud_hint_types.REPAIR
    locId = "hints/help_controls"
    noKeyLocId = "hints/help_controls/nokey"
    shortcuts = "ID_HELP"
    showEvent = "hint:controlsHelp:offer"
    hideEvent = "hint:controlsHelp:remove"
    lifeTime = 30.0
  }
},
function() {
  name = "hint_" + typeName.tolower()
  if (lifeTime > 0)
    selfRemove = true
},
"typeName")

function g_hud_hints::getByName(hintName)
{
  return ::g_enum_utils.getCachedType("name", hintName, cache.byName, this, UNKNOWN)
}
