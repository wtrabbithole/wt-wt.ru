::g_dbg_hud_object_type <- {
  types = []
}

::g_dbg_hud_object_type.template <- {
  eventChance = 100
  hudEventsList = null //array
  isVisible = function(hudType) { return true }
  genNewEvent = function()
  {
    if (!hudEventsList)
      return
    local hudEventData = ::u.chooseRandom(hudEventsList)
    ::g_hud_event_manager.onHudEvent(hudEventData.eventId, hudEventData)
  }
}

::g_enum_utils.addTypesByGlobalName("g_dbg_hud_object_type", {
  REWARD_MESSAGE = { //visible by prioriy
    eventChance = 50
    genNewEvent = function() {
      local ignoreIdx = ::g_hud_reward_message.types.find(::g_hud_reward_message.UNKNOWN)
      ::g_hud_event_manager.onHudEvent("InBattleReward", {
        messageCode = ::u.chooseRandomNoRepeat(::g_hud_reward_message.types, ignoreIdx).code
        warpoints = 10 * (::math.rnd() % 40)
        experience = 10 * (::math.rnd() % 40)
        counter = 1
      })
    }
  }

  MISSION_COMPLETE = { //dosnt work in testflight
    eventChance = 20
    eventNames = ["MissionResult", "MissionContinue"]
    genNewEvent = function() {
      ::g_hud_event_manager.onHudEvent(::u.chooseRandom(eventNames), {
        resultNum = (::math.rnd() % 2) ? ::GO_FAIL : ::GO_WIN
      })
    }
  }

  STREAK = {
    eventChance = 50
    genNewEvent = ::hud_debug_streak
  }

  MISSION_OBJECTIVE = {
    eventChance = 20
    genNewEvent = function() {
      ::hud_message_objective_debug(true, false, ::dbg_msg_obj_counter)
    }
  }

  KILL_LOG = {
    eventChance = 50
    genNewEvent = ::hud_message_kill_log_debug
  }

  PLAYER_DAMAGE = {
    eventChance = 50
    genNewEvent = function() {
      ::hud_message_player_damage_debug(::dbg_player_damage_counter++)
    }
  }

  TANK_DEBUFFS_TIMERS = {
    eventChance = 100
    isVisible = function(hudType) { return hudType == HUD_TYPE.TANK }

    hudEventsList = [
      {
        eventName = "TankDebuffs:Repair"
        getEventData = function()
        {
          return {
            state = ::u.chooseRandom(["notInRepair", "prepareRepair", "repairing"])
            time = 2 + ::math.rnd() % 10
          }
        }
      }
      {
        eventName = "TankDebuffs:Rearm"
        getEventData = function()
        {
          return {
            state = ::u.chooseRandom(["notInRearm", "rearming"])
            timeToLoadOne = 1 + ::math.rnd() % 5
            currentLoadTime = 0.5 * (::math.rnd() % 3)
            object_name = "rearm_status"
          }
        }
      }
      {
        eventName = ["TankCrew:DriverState", "TankCrew:GunnerState"]
        getEventData = function()
        {
          return {
            state = ::u.chooseRandom(["takingPlace", "ok"])
            totalTakePlaceTime = 5 + ::math.rnd() % 10
            timeToTakePlace = 1 + ::math.rnd() % 4
          }
        }
      }
    ]
    genNewEvent = function() {
      local hudEvent = ::u.chooseRandom(hudEventsList)
      local eventName = hudEvent.eventName
      if (::u.isArray(eventName))
        eventName = ::u.chooseRandom(eventName)
      ::g_hud_event_manager.onHudEvent(eventName, hudEvent.getEventData())
    }
  }

  ZONE_CAPTURE = {
    eventChance = 30

    hudEventsList = [
      {
        locId = "NET_YOU_CAPTURING_LA"
        eventId = ::MISSION_CAPTURING_ZONE
        isMyTeam = true
        isHeroAction = true
        captureProgress = 0.7
      }
      {
        locId = "NET_TEAM1_CAPTURING_LA"
        eventId = ::MISSION_CAPTURING_ZONE
        isMyTeam = true
        isHeroAction = false
        captureProgress = -0.6
      }
      {
        locId = "NET_TEAM1_CAPTURED_LA"
        eventId = ::MISSION_CAPTURED_ZONE
        isMyTeam = true
        isHeroAction = false
        captureProgress = 0.4
      }
      {
        locId = "NET_TEAM2_CAPTURED_LA"
        eventId = ::MISSION_CAPTURED_ZONE
        isMyTeam = false
        isHeroAction = false
        captureProgress = -0.3
      }
    ]

    genNewEvent = function() {
      local hudEventData = ::u.chooseRandom(hudEventsList)
      hudEventData.zoneName <- ::u.chooseRandom(["A", "B", "C"])
      hudEventData.text <- format(::loc(hudEventData.locId), hudEventData.zoneName)
      ::g_hud_event_manager.onHudEvent("zoneCapturingEvent", hudEventData)
    }
  }

  REPAIR = {
    eventChance = 10

    hudEventsList = [
      { eventId = "tankRepair:offerRepair" }
      { eventId = "tankRepair:cantRepair" }
    ]
  }

  HUD_HINT = {
    eventChance = 10

    hudEventsList = [
      {
        eventId = "hint:bailout:startBailout"
        lifeTime = 15
        offenderName = "<offenderName>"
      }
      { eventId = "hint:bailout:offerBailout" }
      { eventId = "hint:bailout:notBailouts" }
      { eventId = "hint:xrayCamera:showSkipHint" }
      { eventId = "hint:xrayCamera:hideSkipHint" }
    ]
  }

  HUD_MISSION_HINT = {
    eventChance = 50

    hudEventsList = [
      {
        eventId = "hint:missionHint:set"
        shortcuts = [
          "@ID_ZOOM",
          "@ID_ZOOM_MORE",
          "ID_ZOOM_TOGGLE",
          "@zoom=max",
        ]
        priority = 200
        locId = "hints/tutorialB_zoom_in"
        hintType = "standard"
      }
      {
        eventId = "hint:missionHint:set"
        priority = 0
        locId = "hints/enemy_base_destroyed_no_respawn"
        hintType = "standard"
      }
      {
        eventId = "hint:missionHint:set"
        priority = 0
        locId = "hints/enemy_base_destroyed"
        isOverFade = true
        hintType = "standard"
      }
      { eventId = "hint:missionHint:objectiveSuccess", objectiveType = ::OBJECTIVE_TYPE_PRIMARY }
      { eventId = "hint:missionHint:objectiveAdded" }
      { eventId = "hint:missionHint:objectiveFail" }
      { eventId = "hint:missionHint:remove", hintType = "standard" }
    ]
  }

  AIR_STREAK_HINT = {
    eventChance = 50
    iconsList = ["aircraft_fighter", "aircraft_attacker", "aircraft_bomber"]
    textsList = ["hints/event_start_time", "hints/event_can_join_ally", "hints/event_can_join_enemy"]
    genNewEvent = function()
    {
      local eventData = {
        participant = []
        timeSeconds = ::math.rnd() % 15 + 1
        locId = ::u.chooseRandom(textsList)
        shortcut = "ID_KILLSTREAK_WHEEL_MENU"
        slotsCount = 3
      }

      if (eventData.locId != "hints/event_start_time")
        eventData.playerId <- 0

      local pTotal = ::math.rnd() % 6 + 1
      for(local i = 0; i < pTotal; i++)
        eventData.participant.append({
          image = ::u.chooseRandom(iconsList)
          participantId = i
        })

      //override function get_mplayer_by_id to simulate colors for not exist players
      local _get_mplayer_by_id = ::get_mplayer_by_id
      ::get_mplayer_by_id = @(id) {
        name = "somebodyName"
        clanTag = "<WWWWW>"
        isLocal = id == 1
        team = 2 - (id % 2)
        isInHeroSquad = (id % 4) == 1
      }
      ::g_hud_event_manager.onHudEvent("hint:event_start_time:show", eventData)
      ::get_mplayer_by_id = _get_mplayer_by_id
    }
  }
})
