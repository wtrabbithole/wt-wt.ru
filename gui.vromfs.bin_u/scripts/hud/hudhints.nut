local time = require("scripts/time.nut")
const DEFAULT_MISSION_HINT_PRIORITY = 100
const CATASTROPHIC_HINT_PRIORITY = 0

local animTimerPid = ::dagui_propid.add_name_id("_transp-timer")

enum MISSION_HINT_TYPE {
  STANDARD   = "standard"
  TUTORIAL   = "tutorialHint"
  BOTTOM     = "bottom"
}

enum HINT_INTERVAL {
  ALWAYS_VISIBLE = 0
  HIDDEN = -1
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
    animation = shouldBlink ? "wink" : shouldFadeOut ? "show" : null
  }
}

local getRawShortcutsArray = function(shortcuts)
{
  if(!shortcuts)
    return []
  local rawShortcutsArray = ::u.isArray(shortcuts) ? shortcuts : [shortcuts]
  local shouldPickOne = ::g_hud_hints.shouldPickFirstValid(rawShortcutsArray)
  if (shouldPickOne)
  {
    local rawShortcut = ::g_hud_hints.pickFirstValidShortcut(rawShortcutsArray)
    rawShortcutsArray = rawShortcut != null ? [rawShortcut] : []
  }
  else
    rawShortcutsArray = ::g_hud_hints.removeUnmappedShortcuts(rawShortcutsArray)
  return rawShortcutsArray
}

function g_hud_hints::_buildText(data)
{
  local shortcuts = getShortcuts(data)
  if (shortcuts == null)
  {
    local res = ::loc(getLocId(data))
    if (image)
      res = ::g_hint_tag.IMAGE.makeFullTag({ image = image }) + res
    return res
  }

  local rawShortcutsArray = getRawShortcutsArray(shortcuts)
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
    res = ::g_hint_tag.TIMER.makeFullTag() + " " + res
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
  getShortcuts          = ::g_hud_hints._getShortcuts
  buildMarkup           = ::g_hud_hints._buildMarkup
  buildText             = ::g_hud_hints._buildText
  getHintMarkupParams   = ::g_hud_hints._getHintMarkupParams
  getLifeTime           = ::g_hud_hints._getLifeTime
  isEnabledByDifficulty = @() !isAllowedByDiff || isAllowedByDiff?[::get_mission_difficulty()] ?? true

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
  isHideOnDeath = true

  showEvent = null
  hideEvent = null
  updateCbs = null //{ <hudEventName> = function(hintData, eventData) { return <needUpdate (bool)>} } //hintData can be null

  countIntervals = null // for example [{count = 5, timeInterval = 60.0 }, { ... }, ...]
  delayTime = 0.0
  isAllowedByDiff  = null
  totalCount = -1
  missionCount = -1
  maskId = -1
  mask = 0

  isShowedInVR = false

  shouldBlink = false
  shouldFadeOut = false

  isEnabled = @() (isShowedInVR || !::is_stereo_mode())
    && ::is_hint_enabled(mask)
    && isEnabledByDifficulty()

  getTimeInterval = function()
  {
    if (!countIntervals)
      return HINT_INTERVAL.ALWAYS_VISIBLE

    local interval = HINT_INTERVAL.HIDDEN
    local count = ::get_hint_seen_count(maskId)
    foreach(countInterval in countIntervals)
      if (count < countInterval.count)
      {
        interval = countInterval.timeInterval
        break
      }
    return interval
  }
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
      res += " " + ::g_hint_tag.TIMER.makeFullTag()
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
    isHideOnDeath = false
  }


  CREW_BUSY_EXTINGUISHING_HINT = {
    locId      = "hints/crew_busy_extinguishing"
    noKeyLocId = "hints/crew_busy_extinguishing_no_key"
    showEvent = "hint:extinguish:begin"
    hideEvent = "hint:extinguish:end"
    maskId = 25
  }

  TRACK_REPAIR_HINT = {
    hintType = ::g_hud_hint_types.REPAIR
    locId     = "hints/track_repair"
    showEvent = "hint:track_repair"
    lifeTime = 5.0
    maskId = 13
  }

  MORE_KILLS_FOR_KILL_STREAK_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/more_kills_for_kill_streak"
    showEvent = "hint:more_kills_for_kill_streak:show"
    lifeTime = 5.0
    priority = CATASTROPHIC_HINT_PRIORITY
    maskId = 16
  }

  NEED_KILLS_STREAK_EVENT_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/needs_kills_streak_event"
    showEvent = "hint:needs_kills_streak_event:show"
    lifeTime = 5.0
    priority = CATASTROPHIC_HINT_PRIORITY
    maskId = 17
  }

  ACTIVE_EVENT_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/active_event"
    showEvent = "hint:active_event:show"
    lifeTime = 5.0
    priority = CATASTROPHIC_HINT_PRIORITY
    maskId = 18
  }

  ALREADY_PARTICIPATING_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/already_participating"
    showEvent = "hint:already_participating:show"
    lifeTime = 5.0
    priority = CATASTROPHIC_HINT_PRIORITY
    maskId = 20
  }

  NO_EVENT_SLOTS_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/no_event_slots"
    showEvent = "hint:no_event_slots:show"
    lifeTime = 5.0
    priority = CATASTROPHIC_HINT_PRIORITY
    maskId = 19
  }

  INEFFECTIVE_HIT_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/ineffective_hit"
    showEvent = "hint:ineffective_hit:show"
    lifeTime = 5.0
    priority = CATASTROPHIC_HINT_PRIORITY
    countIntervals = [
      {
        count = 5
        timeInterval = 60.0
      }
      {
        count = 10
        timeInterval = 100000.0 //once per mission
      }
    ]
    maskId = 11
  }

  GUN_JAMMED_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/gun_jammed"
    showEvent = "hint:gun_jammed:show"
    lifeTime = 2.0
    priority = CATASTROPHIC_HINT_PRIORITY
    maskId = 30
  }

  AUTOTHROTTLE_HINT = {
    locId = "hints/autothrottle"
    showEvent = "hint:autothrottle:show"
    lifeTime = 10.0
    priority = CATASTROPHIC_HINT_PRIORITY
    maskId = 14
  }

  PILOT_LOSE_CONTROL_HINT = {
    locId = "hints/pilot_lose_control"
    showEvent = "hint:pilot_lose_control:show"
    lifeTime = 10.0
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 20
    maskId = 26
  }

  ATGM_AIM_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/atgm_aim"
    showEvent = "hint:atgm_aim:show"
    lifeTime = 10.0
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 5
    maskId = 28
  }

  ATGM_MANUAL_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/atgm_manual"
    showEvent = "hint:atgm_manual:show"
    lifeTime = 10.0
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 5
    maskId = 29
  }

  DEAD_PILOT_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/dead_pilot"
    showEvent = "hint:dead_pilot:show"
    lifeTime = 5.0
    isHideOnDeath = false
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 20
    maskId = 12
  }

  HAVE_ART_SUPPORT_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/have_art_support"
    noKeyLocId = "hints/have_art_support_no_key"
    getShortcuts = @(data) ::g_hud_action_bar_type.ARTILLERY_TARGET.getVisualShortcut()
    showEvent = "hint:have_art_support:show"
    hideEvent = "hint:have_art_support:hide"
    lifeTime = 10.0
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 10
    maskId = 27
  }

  TANK_REARM_PROCESS_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/tank_rearm_process"
    noKeyLocId = "hints/tank_rearm_process_no_key"
    shortcuts = "ID_REPAIR_TANK"
    showEvent = "hint:tank_rearm_process:show"
    hideEvent = "hint:tank_rearm_process:hide"
    lifeTime = 10.0
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 10
    isShowedInVR = true
    maskId = 21
  }

  AUTO_REARM_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/auto_rearm"
    showEvent = "hint:auto_rearm:show"
    hideEvent = "hint:auto_rearm:hide"
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 1
    isAllowedByDiff  = {
      [::g_difficulty.REALISTIC.name] = false,
      [::g_difficulty.SIMULATOR.name] = false
    }
    maskId = 9
  }

  WINCH_REQUEST_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/winch_request"
    noKeyLocId = "hints/winch_request_no_key"
    showEvent = "hint:winch_request:show"
    hideEvent = "hint:winch_request:hide"
    priority = DEFAULT_MISSION_HINT_PRIORITY
    getShortcuts = @(data) ::g_hud_action_bar_type.WINCH.getVisualShortcut()
    lifeTime = 10.0
    delayTime = 4.0
    maskId = 22
  }

  WINCH_USE_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/winch_use"
    noKeyLocId = "hints/winch_use_no_key"
    showEvent = "hint:winch_use:show"
    hideEvent = "hint:winch_use:hide"
    priority = DEFAULT_MISSION_HINT_PRIORITY
    getShortcuts = @(data) ::g_hud_action_bar_type.WINCH_ATTACH.getVisualShortcut()
    lifeTime = 10.0
    delayTime = 2.0
    maskId = 23
  }

  WINCH_DETACH_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/winch_detach"
    noKeyLocId = "hints/winch_detach_no_key"
    showEvent = "hint:winch_detach:show"
    hideEvent = "hint:winch_detach:hide"
    priority = DEFAULT_MISSION_HINT_PRIORITY
    getShortcuts = @(data) ::g_hud_action_bar_type.WINCH_DETACH.getVisualShortcut()
    lifeTime = 10.0
    delayTime = 4.0
    maskId = 24
  }

  F1_CONTROLS_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/f1_controls"
    showEvent = "hint:f1_controls:show"
    hideEvent = "helpOpened"
    priority = CATASTROPHIC_HINT_PRIORITY
    totalCount = 10
    lifeTime = 5.0
    delayTime = 10.0
    maskId = 0
  }

  FULL_THROTTLE_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/full_throttle"
    showEvent = "hint:full_throttle:show"
    hideEvent = "hint:full_throttle:hide"
    priority = CATASTROPHIC_HINT_PRIORITY
    lifeTime = 5.0
    delayTime = 10.0
    maskId = 7
  }

  DISCONNECT_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/disconnect"
    showEvent = "hint:disconnect:show"
    hideEvent = "hint:disconnect:hide"
    priority = CATASTROPHIC_HINT_PRIORITY
    lifeTime = 5.0
    delayTime = 3600.0
    maskId = 8
  }

  SHOT_TOO_FAR_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/shot_too_far"
    showEvent = "hint:shot_too_far:show"
    hideEvent = "hint:shot_too_far:hide"
    priority = CATASTROPHIC_HINT_PRIORITY
    countIntervals = [
      {
        count = 5
        timeInterval = 60.0
      }
      {
        count = 10
        timeInterval = 100000.0 //once per mission
      }
    ]
    lifeTime = 5.0
    delayTime = 5.0
    maskId = 10
  }

  SHOT_FORESTALL_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/shot_forestall"
    showEvent = "hint:shot_forestall:show"
    hideEvent = "hint:shot_forestall:hide"
    priority = CATASTROPHIC_HINT_PRIORITY
    countIntervals = [
      {
        count = 5
        timeInterval = 60.0
      }
      {
        count = 10
        timeInterval = 100000.0 //once per mission
      }
    ]
    isAllowedByDiff  = {
      [::g_difficulty.SIMULATOR.name] = false
    }
    lifeTime = 5.0
    delayTime = 5.0
    maskId = 10
  }

  PARTIAL_DOWNLOAD = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/partial_download"
    showEvent = "hint:partial_download:show"
    priority = CATASTROPHIC_HINT_PRIORITY
    lifeTime = 5.0
  }

  EXTINGUISH_FIRE_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/extinguish_fire"
    noKeyLocId = "hints/extinguish_fire_nokey"
    getShortcuts = @(data) ::g_hud_action_bar_type.EXTINGUISHER.getVisualShortcut()
    showEvent = "hint:extinguish_fire:show"
    hideEvent = "hint:extinguish_fire:hide"
    shouldBlink = true
  }

  CRITICAL_BUOYANCY_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/critical_buoyancy"
    noKeyLocId = "hints/critical_buoyancy_nokey"
    shortcuts = "ID_REPAIR_BREACHES"
    showEvent = "hint:critical_buoyancy:show"
    hideEvent = "hint:critical_buoyancy:hide"
    shouldBlink = true
  }

  CRITICAL_HEALING_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/critical_heeling"
    noKeyLocId = "hints/critical_heeling_nokey"
    shortcuts = "ID_REPAIR_BREACHES"
    showEvent = "hint:critical_heeling:show"
    hideEvent = "hint:critical_heeling:hide"
    shouldBlink = true
  }

  MOVE_SUSPENSION_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/move_suspension"
    noKeyLocId = "hints/move_suspension_nokey"
    shortcuts = "ID_SUSPENSION_RESET"
    showEvent = "hint:move_suspension:show"
    hideEvent = "hint:move_suspension:hide"
    shouldBlink = true
  }

  MOVE_SUSPENSION_ZERO_VEL_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/move_suspension_zero_vel"
    noKeyLocId = "hints/move_suspension_zero_vel_nokey"
    shortcuts = "ID_SUSPENSION_RESET"
    showEvent = "hint:move_suspension_zero_vel:show"
    hideEvent = "hint:move_suspension_zero_vel:hide"
    shouldBlink = true
  }

  YOU_CAN_EXIT_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/you_can_exit"
    noKeyLocId = "hints/you_can_exit_nokey"
    shortcuts = "ID_BAILOUT"
    showEvent = "hint:you_can_exit:show"
    hideEvent = "hint:you_can_exit:hide"
    shouldBlink = true
  }

  ARTILLERY_MAP_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "HUD/TXT_ARTILLERY_MAP"
    noKeyLocId = "HUD/TXT_ARTILLERY_MAP_NOKEY"
    shortcuts = "ID_CHANGE_ARTILLERY_TARGETING_MODE"
    showEvent = "hint:artillery_map:show"
    hideEvent = "hint:artillery_map:hide"
    shouldBlink = true
    delayTime = 1.0
  }

  USE_ARTILLERY_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/use_artillery"
    noKeyLocId = "hints/use_artillery_no_key"
    shortcuts = "ID_SHOOT_ARTILLERY"
    showEvent = "hint:artillery_map:show"
    hideEvent = "hint:artillery_map:hide"
    lifeTime = 10.0
    totalCount = 10
    maskId = 15
  }

  PRESS_A_TO_CONTINUE_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "HUD_PRESS_A_CNT"
    noKeyLocId = "HUD_PRESS_A_CNT"
    shortcuts = [
      "@ID_CONTINUE_SETUP"
      "@ID_CONTINUE"
      "@ID_FIRE"
    ]
    showEvent = "hint:press_a_continue:show"
    hideEvent = "hint:press_a_continue:hide"
    buildText = function(eventData)
    {
      local res = ::g_hud_hints._buildText.call(this, eventData)
      local timer = eventData?.timer
      if (timer)
        res += " (" + timer + ")"
      return res
    }
  }

  RELOAD_ON_AIRFIELD_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/reload_on_airfield"
    noKeyLocId = "hints/reload_on_airfield_nokey"
    shortcuts = "ID_RELOAD_GUNS"
    showEvent = "hint:reload_on_airfield:show"
    hideEvent = "hint:reload_on_airfield:hide"
    shouldBlink = true
  }

  EVENT_START_HINT = {
    hintType = ::g_hud_hint_types.ACTIONBAR
    showEvent = "hint:event_start_time:show"
    hideEvent = "hint:event_start_time:hide"
    getShortcuts = @(eventData) eventData?.shortcut

    makeSmallImageStr = @(image, color = null, sizeStyle = null) ::g_hint_tag.IMAGE.makeFullTag({
      image = image
      color = color
      sizeStyle = sizeStyle
    })

    buildText = function(eventData)
    {
      local res = ::g_hud_hints._buildText.call(this, eventData)
      local rawShortcutsArray = getRawShortcutsArray(getShortcuts(eventData))
      local player = "playerId" in eventData ? ::get_mplayer_by_id(eventData.playerId) : null
      local playerText = player ? ::build_mplayer_name(player) : null
      local locId = rawShortcutsArray.len() > 0 ? eventData?.locId : (eventData?.noKeyLocId ?? eventData?.locId)
      local hintText = locId ? ::loc(locId) : ""
      local timeSec = eventData?.timeSeconds ?? 0
      local secLocStr = ::loc("mainmenu/seconds")
      res += playerText ? ::format(hintText, playerText, timeSec, secLocStr)
      : ::format(hintText, timeSec, secLocStr)

      local participantsAStr = ""
      local participantsBStr = ""
      local reservedSlotsCountA = 0
      local reservedSlotsCountB = 0
      local totalSlotsPerCommand = eventData?.slotsCount ?? 0
      local spaceStr = "          "

      local participantList = []
      if(eventData?.participant)
        participantList = ::u.isArray(eventData.participant) ? eventData.participant : [eventData.participant]

      local playerTeam = ::get_local_team_for_mpstats()
      foreach (participant in participantList)
      {
        local pIdArray = ::u.isArray(participant.participantId)? participant.participantId : [participant.participantId]
        local imageArray = ::u.isArray(participant?.image)? participant?.image : [participant?.image]

        foreach (idx, participantId in pIdArray)
        {
          local participantPlayer = participantId ? ::get_mplayer_by_id(participantId) : null
          local image = imageArray[idx]
          if (image && participantPlayer)
          {
            local icon = "#ui/gameuiskin#" + image
            local color = "@" + (participantPlayer ? ::get_mplayer_color(participantPlayer) : "hudColorHero")
            local pStr = makeSmallImageStr(icon, color)
            if (playerTeam == participantPlayer.team)
            {
              participantsAStr += pStr + " "
              ++reservedSlotsCountA
            }
            else
            {
              participantsBStr = " " + pStr + participantsBStr
              ++reservedSlotsCountB
            }
          }
        }
      }

      local freeSlotIconName = "#ui/gameuiskin#btn_help"
      local freeSlotIconColor = "@minorTextColor"
      local freeSlotIconStr = makeSmallImageStr(freeSlotIconName, freeSlotIconColor, "small")
      for(local i = 0; i < totalSlotsPerCommand - reservedSlotsCountA; ++i)
        participantsAStr += freeSlotIconStr + " "

      for(local i = 0; i < totalSlotsPerCommand - reservedSlotsCountB; ++i)
        participantsBStr = " " + freeSlotIconStr + participantsBStr

      if (participantsAStr.len() > 0 && participantsBStr.len() > 0)
        res = participantsAStr
        + spaceStr + ::loc("country/VS").tolower() + spaceStr
        + participantsBStr
        + "\n" + res

      return res
    }
  }

  RESTORING_IN_HINT = {
    hintType = ::g_hud_hint_types.COMMON
    showEvent = "hint:restoring_in:show"
    hideEvent = "hint:restoring_in:hide"
    buildText = @(eventData) eventData?.text ?? ""
  }

  AVAILABLE_GUNNER_HINT = {
    locId = "hints/manual_change_crew_available_gunner"
    noKeyLocId ="hints/manual_change_crew_available_gunner_nokey"
    showEvent = "hint:available_gunner:show"
    hideEvent = "hint:available_gunner:hide"
  }

  AVAILABLE_DRIVER_HINT = {
    locId = "hints/manual_change_crew_available_driver"
    noKeyLocId ="hints/manual_change_crew_available_driver_nokey"
    showEvent = "hint:available_driver:show"
    hideEvent = "hint:available_driver:hide"
  }

  NECESSARY_GUNNER_HINT = {
    locId = "hints/manual_change_crew_necessary_gunner"
    noKeyLocId ="hints/manual_change_crew_necessary_gunner_nokey"
    showEvent = "hint:necessary_gunner:show"
    hideEvent = "hint:necessary_gunner:hide"
  }

  NECESSARY_DRIVER_HINT = {
    locId = "hints/manual_change_crew_necessary_driver"
    noKeyLocId ="hints/manual_change_crew_necessary_driver_nokey"
    showEvent = "hint:necessary_driver:show"
    hideEvent = "hint:necessary_driver:hide"
  }

  DIED_FROM_AMMO_EXPLOSION_HINT = {
    locId = "HUD/TXT_DIED_FROM_AMMO_EXPLOSION"
    showEvent = "hint:died_from_ammo_explosion:show"
    hideEvent = "hint:died_from_ammo_explosion:hide"
    lifeTime = 5.0
  }

  TORPEDO_DEADZONE_HINT = {
    locId = "hints/torpedo_deadzone"
    showEvent = "hint:torpedo_deadzone:show"
    hideEvent = "hint:torpedo_deadzone:hide"
  }

  TORPEDO_BROKEN_HINT = {
    locId = "hints/torpedo_broken"
    showEvent = "hint:torpedo_broken:show"
    hideEvent = "hint:torpedo_broken:hide"
  }

  MISSION_COMPLETE_HINT = {
    locId = "HUD_MISSION_COMPLETE_HDR"
    showEvent = "hint:mission_complete:show"
    hideEvent = "hint:mission_complete:hide"
    shortcuts = [
      "@ID_CONTINUE_SETUP"
      "@ID_CONTINUE"
    ]
    buildText = function(eventData)
    {
      local res = ::g_hud_hints._buildText.call(this, eventData)
      res += eventData?.count ? " " + eventData.count : ""
      return res
    }
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
    isShowedInVR = true

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
    isShowedInVR = true

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

  AMMO_DESTROYED = {
    hintType = ::g_hud_hint_types.COMMON
    locId = "hints/ammo_destroyed"
    showEvent = "hint:ammoDestroyed:show"
    priority = CATASTROPHIC_HINT_PRIORITY
    lifeTime = 5.0
  }

},
function() {
  name = "hint_" + typeName.tolower()
  if (lifeTime > 0)
    selfRemove = true

  if(maskId >= 0)
    mask = 1 << maskId
},
"typeName")

function g_hud_hints::getByName(hintName)
{
  return ::g_enum_utils.getCachedType("name", hintName, cache.byName, this, UNKNOWN)
}
