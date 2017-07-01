::g_top_menu_buttons <- {
  types = []

  template = {
    id = "unknown"
    text = ""
    link = null
    buttonClass = "topmenuList"
    isLink = false
    isFeatured = false
    funcName = null
    isHidden = function() { return false }
    isVisualDisabled = function() { return false }
    isInactiveInQueue = false
    isEmptyButton = false
    isLineSeparator = false
  }
}

::g_enum_utils.addTypesByGlobalName("g_top_menu_buttons", {
  SKIRMISH = {
    id = "skirmish"
    text = "#mainmenu/btnSkirmish"
    funcName = "onSkirmish"
    isHidden = function() { return !::is_custom_battles_enabled() }
    isVisualDisabled = function() { return !::is_custom_battles_enabled() }
    isInactiveInQueue = true
  }
  WORLDWAR = {
    id = "worldwar"
    text = "#mainmenu/btnWorldwar"
    funcName = "onWorldwar"
    isVisualDisabled = function() { return !::is_worldwar_enabled() }
  }
  TUTORIAL = {
    id = "tutorial"
    text = "#mainmenu/btnTutorial"
    funcName = "onTutorial"
    isInactiveInQueue = true
  }
  SINGLE_MISSION = {
    id = "SingleMission"
    text = "#mainmenu/btnSingleMission"
    funcName = "onSingleMission"
    isVisualDisabled = function() {return !::has_feature("ModeSingleMissions") }
    isInactiveInQueue = true
  }
  DYNAMIC = {
    id = "Dynamic"
    text = "#mainmenu/btnDynamic"
    funcName = "onDynamic"
    isVisualDisabled = function() {return !::has_feature("ModeDynamic") }
    isInactiveInQueue = true
  }
  CAMPAIGN = {
    id = "campaign"
    text = "#mainmenu/btnCampaign"
    funcName = "onCampaign"
    isHidden = function() { return !::has_feature("HistoricalCampaign") }
    isVisualDisabled = function() { return !::ps4_is_chunk_available(PS4_CHUNK_HISTORICAL_CAMPAIGN) }
    isInactiveInQueue = true
  }
  BENCHMARK = {
    id = "benchmark"
    text = "#mainmenu/btnBenchmark"
    funcName = "onBenchmark"
    isHidden = function() {
      return (::is_platform_ps4 ? !::has_feature("BenchmarkPS4") : !::has_feature("Benchmark")) && !::is_dev_version
    }
    isInactiveInQueue = true
  }
  USER_MISSION = {
    id = "UserMission"
    text = "#mainmenu/btnUserMission"
    funcName = "onUserMission"
    isHidden = function() { return !::has_feature("UserMissions") }
    isInactiveInQueue = true
  }
  OPTIONS = {
    id = "gameplay" //!!! Game Options...DAFUQ?
    text = "#mainmenu/btnGameplay"
    funcName = "onGameplay"
  }
  CONTROLS = {
    id = "controls"
    text = "#mainmenu/btnControls"
    funcName = "onControls"
  }
  LEADERBOARDS = {
    id = "leaderboards"
    text = "#mainmenu/btnLeaderboards"
    funcName = "onLeaderboards"
  }
  CLANS = {
    id = "clans"
    text = "#mainmenu/btnClans"
    funcName = "onClans"
    isHidden = function() { return !::has_feature("Clans") }
  }
  REPLAY = {
    id = "replays"
    text = "#mainmenu/btnReplays"
    funcName = "onReplays"
    isHidden = function() { return !::has_feature("Replays") }
  }
  VIRAL_AQUISITION = {
    id = "getLink"
    text = "#mainmenu/btnGetLink"
    funcName = "onGetLink"
    isHidden = function() { return !::has_feature("Invites") }
  }
  EXIT = {
    id = "exit"
    text = "#mainmenu/btnExit"
    funcName = "onExit"
    isHidden = function() { return ::is_platform_ps4}
  }
  DEBUG_UNLOCK = {
    id = "debugUnlock"
    text = "#mainmenu/btnDebugUnlock"
    funcName = "onDebugUnlock"
    isHidden = function() { return !::is_dev_version}
  }
  ENCYCLOPEDIA = {
    id = "encyclopedia"
    text = "#mainmenu/btnEncyclopedia"
    funcName = "onEncyclopedia"
    isHidden = function() { return !::has_feature("Encyclopedia") }
  }
  CREDITS = {
    id = "credits"
    text = "#mainmenu/btnCredits"
    funcName = "onCredits"
    isHidden = function() { return !::has_feature("Credits") }
  }
  TSS = {
    id = "tssLink"
    text = "#topmenu/tss"
    funcName = "onLink"
    link = "#url/tss"
    isLink = true
  }
  STREAMS_AND_REPLAYS = {
    id = "streamsAndReplaysLink"
    text = "#topmenu/streamsAndReplays"
    funcName = "onLink"
    link = "#url/streamsAndReplays"
    isLink = true
  }
  EMPTY = {
    isEmptyButton = true
  }
  LINE_SEPARATOR = {
    isLineSeparator = true
  }
}, null, "name")
