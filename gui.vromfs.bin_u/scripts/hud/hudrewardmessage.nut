::g_hud_reward_message <- {
  types = []

  cache = {
    byCode = {}
  }
}

function g_hud_reward_message::getMessageByCode(code)
{
  return ::g_enum_utils.getCachedType("code", code, cache.byCode,
    ::g_hud_reward_message, ::g_hud_reward_message.UNKNOWN)
}


function g_hud_reward_message::_getViewClass(rewardValue)
{
  return rewardValue >= 0 ? viewClass : "penalty"
}

function g_hud_reward_message::_getText(rewardValue, counter)
{
  local result = ::loc(locId)
  if (rewardValue < 0)
    result += ::loc("warpoints/friendly_fire_penalty")

  if (counter > 1)
    result = ::loc("warpoints/counter", {counter = counter}) + result

  return result
}

enum REWARD_PRIORITY {
  noPriority, //for null message. any real type priority is higher
  common,
  scout,
  scout_hit,
  scout_kill,
  hit,
  critical,
  assist,
  kill
}

::g_hud_reward_message.template <- {
  code = -1
  locId = ""
  viewClass = ""
  priority = REWARD_PRIORITY.common //greater is better

  getViewClass = ::g_hud_reward_message._getViewClass
  getText = ::g_hud_reward_message._getText
}

::g_enum_utils.addTypesByGlobalName("g_hud_reward_message", {
  UNKNOWN = {}

  LANDING = {
    code = ::EXP_EVENT_LANDING
    locId = "exp_reasons/landing"
  }

  TAKEOFF = {
    code = ::EXP_EVENT_TAKEOFF
    locId = "exp_reasons/takeoff"
  }

  CAPTURE_ZONE = {
    code = ::EXP_EVENT_CAPTURE_ZONE
    locId = "exp_reasons/capture"
    viewClass = "kill"
    priority = REWARD_PRIORITY.hit
  }

  DESTROY_ZONE = {
    code = ::EXP_EVENT_DESTROY_ZONE
    locId = "exp_reasons/destroy"
    viewClass = "kill"
    priority = REWARD_PRIORITY.hit
  }

  SIGHT = {
    code = ::EXP_EVENT_SIGHT
    locId = "exp_reasons/sight"
    priority = REWARD_PRIORITY.hit
  }

  KILL = {
    code = ::EXP_EVENT_KILL
    locId = "exp_reasons/kill"
    viewClass = "kill"
    priority = REWARD_PRIORITY.kill
  }

  KILL_BY_TEAM = {
    code = ::EXP_EVENT_KILL_BY_TEAM
    locId = "exp_reasons/kill_by_team"
    viewClass = "kill"
    priority = REWARD_PRIORITY.assist
  }

  KILL_GROUND = {
    code = ::EXP_EVENT_KILL_GROUND
    locId = "exp_reasons/kill_gm"
    viewClass = "kill"
    priority = REWARD_PRIORITY.assist
  }

  ROUND_AWARD = {
    code = ::EXP_EVENT_ROUND_AWARD
  }

  SESSION_AWARD = {
    code = ::EXP_EVENT_SESSION_AWARD
  }

  BATTLETIME = {
    code = ::EXP_EVENT_BATTLETIME
  }

  STREAK = {
    code = ::EXP_EVENT_STREAK
  }

  CRITICAL_HIT = {
    code = ::EXP_EVENT_CRITICAL_HIT
    locId  = "exp_reasons/critical_hit"
    viewClass = "critical_hit"
    priority = REWARD_PRIORITY.critical
  }

  HIT = {
    code = ::EXP_EVENT_HIT
    locId  = "exp_reasons/hit"
    viewClass = "hit"
    priority = REWARD_PRIORITY.hit
  }

  ASSIST = {
    code = ::EXP_EVENT_ASSIST
    locId  = "exp_reasons/assist"
    viewClass = "kill"
    priority = REWARD_PRIORITY.assist
  }

  DAMAGE_ZONE = {
    code = ::EXP_EVENT_DAMAGE_ZONE
    locId  = "exp_reasons/damage_zone"
    viewClass = "hit"
    priority = REWARD_PRIORITY.hit
  }

  OVERKILL = {
    code = ::EXP_EVENT_OVERKILL
    locId  = "exp_reasons/overkill"
    viewClass = "kill"
    priority = REWARD_PRIORITY.assist
  }

  BATTLETROPHY = {
    code = ::EXP_EVENT_BATTLETROPHY
    locId  = "exp_reasons/battle_trophy"
    priority = REWARD_PRIORITY.assist
  }

  INEFFECTIVE_HIT = {
    code = ::EXP_EVENT_INEFFECTIVE_HIT
    locId  = "exp_reasons/ineffective_hit"
    priority = REWARD_PRIORITY.common
  }

  RESPAWN = {
    code = ::EXP_EVENT_RESPAWN
  }

  OBJECTIVE = {
    code = ::EXP_EVENT_OBJECTIVE
    locId  = "exp_reasons/objective"
    viewClass = "kill"
  }

  RACE_FINISHED = {
    code = ::EXP_EVENT_RACE_FINISHED
    viewClass = "kill"
    priority = REWARD_PRIORITY.kill
  }

  UNIT_DAMAGE = {
    code = ::EXP_EVENT_UNIT_DAMAGE
    viewClass = "hit"
    priority = REWARD_PRIORITY.hit
  }

  SCOUT = {
    code = ::EXP_EVENT_SCOUT
    locId  = "exp_reasons/scout"
    viewClass = "scout"
    priority = REWARD_PRIORITY.scout
  }

  SCOUT_CRITICAL_HIT = {
    code = ::EXP_EVENT_SCOUT_CRITICAL_HIT
    locId  = "exp_reasons/scout_critical_hit"
    viewClass = "scout"
    priority = REWARD_PRIORITY.scout_hit
  }

  SCOUT_KILL = {
    code = ::EXP_EVENT_SCOUT_KILL
    locId  = "exp_reasons/scout_kill"
    viewClass = "scout"
    priority = REWARD_PRIORITY.scout_kill
  }

})
