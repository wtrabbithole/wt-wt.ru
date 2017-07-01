::g_difficulty <- {
  types = []
}

::g_difficulty.template <- {
  diffCode = -1
  name = ""
  icon = ""
  locId = ""
  egdCode = ::EGD_NONE
  egdLowercaseName = ::get_name_by_gamemode(::EGD_NONE, false) // none
  gameTypeName = ""
  matchingName = ""
  crewSkillName = "" // Used in g_crew_skill_parameters.
  settingsName = "" // Used in _difficulty.blk difficulty_settings.
  clanReqOption = "" //Used in clan membership requirement
  cdPresetValue = ::get_cd_preset_value(::DIFFICULTY_CUSTOM)
  getEgdName = function(capital = true) { return ::get_name_by_gamemode(egdCode, capital) } //"none", "arcade", "historical", "simulation"
  getLocName = function() { return ::loc(locId) }

  abbreviation = ""
  choiceType = []
  arcadeCountry = false
  hasRespawns = false
  isAvailable = function(gm = null) { return true }
  getEdiff = function(battleType = BATTLE_TYPES.AIR)
  {
    return diffCode == -1 ? -1 :
      diffCode + (battleType == BATTLE_TYPES.TANK ? EDIFF_SHIFT : 0)
  }
  getEdiffByUnitMask = function(unitTypesMask = 0)
  {
    local isAvailableTanks = (unitTypesMask & (1 << ::ES_UNIT_TYPE_TANK)) != 0
    return diffCode == -1 ? -1 :
      diffCode + (isAvailableTanks ? EDIFF_SHIFT : 0)
  }
}

::g_enum_utils.addTypesByGlobalName("g_difficulty", {
  UNKNOWN = {
    name = "unknown"
    isAvailable = function(...) { return false }
  }

  ARCADE = {
    diffCode = ::DIFFICULTY_ARCADE
    name = ::get_difficulty_name(::DIFFICULTY_ARCADE) // arcade
    icon = "#ui/gameuiskin#mission_complete_arcade"
    locId = "mainmenu/arcadeInstantAction"
    egdCode = ::EGD_ARCADE
    egdLowercaseName = ::get_name_by_gamemode(::EGD_ARCADE, false) // arcade
    gameTypeName = "arcade"
    matchingName = "arcade"
    crewSkillName = "arcade"
    settingsName = "easy"
    clanReqOption = ::USEROPT_CLAN_REQUIREMENTS_MIN_ARCADE_BATTLES
    cdPresetValue = ::get_cd_preset_value(::DIFFICULTY_ARCADE)
    abbreviation = "clan/shortArcadeBattle"
    choiceType = ["AirAB", "TankAB"]
    arcadeCountry = true
    hasRespawns = true
  }

  REALISTIC = {
    diffCode = ::DIFFICULTY_REALISTIC
    name = ::get_difficulty_name(::DIFFICULTY_REALISTIC) // realistic
    icon = "#ui/gameuiskin#mission_complete_realistic"
    locId = "mainmenu/instantAction"
    egdCode = ::EGD_HISTORICAL
    egdLowercaseName = ::get_name_by_gamemode(::EGD_HISTORICAL, false) // historical
    gameTypeName = "historical"
    matchingName = "realistic"
    crewSkillName = "historical"
    settingsName = "medium"
    clanReqOption = ::USEROPT_CLAN_REQUIREMENTS_MIN_REAL_BATTLES
    cdPresetValue = ::get_cd_preset_value(::DIFFICULTY_REALISTIC)
    abbreviation = "clan/shortHistoricalBattle"
    choiceType = ["AirRB", "TankRB"]
    arcadeCountry = true
    hasRespawns = false
  }

  SIMULATOR = {
    diffCode = ::DIFFICULTY_HARDCORE
    name = ::get_difficulty_name(::DIFFICULTY_HARDCORE) // hardcore
    icon = "#ui/gameuiskin#mission_complete_simulator"
    locId = "mainmenu/fullRealInstantAction"
    egdCode = ::EGD_SIMULATION
    egdLowercaseName = ::get_name_by_gamemode(::EGD_SIMULATION, false) // simulation
    gameTypeName = "realistic"
    matchingName = "simulation"
    crewSkillName = "fullreal"
    settingsName = "hard"
    clanReqOption = ::USEROPT_CLAN_REQUIREMENTS_MIN_SYM_BATTLES
    cdPresetValue = ::get_cd_preset_value(::DIFFICULTY_HARDCORE)
    abbreviation = "clan/shortFullRealBattles"
    choiceType = ["AirSB", "TankSB"]
    arcadeCountry = false
    hasRespawns = false
    isAvailable = function(gm = null) {
      return !::has_feature("SimulatorDifficulty") ? false :
        gm == ::GM_DOMINATION ? ::has_feature("SimulatorDifficultyInRandomBattles") :
        true
    }
  }
})

::g_difficulty.types.sort(function(a,b)
{
  if (a.diffCode != b.diffCode)
    return a.diffCode > b.diffCode ? 1 : -1
  return 0
})

function g_difficulty::getDifficultyByDiffCode(diffCode)
{
  return ::g_enum_utils.getCachedType("diffCode", diffCode, ::g_difficulty_cache.byDiffCode, ::g_difficulty, ::g_difficulty.UNKNOWN)
}

function g_difficulty::getDifficultyByName(name)
{
  return ::g_enum_utils.getCachedType("name", name, ::g_difficulty_cache.byName, ::g_difficulty, ::g_difficulty.UNKNOWN)
}

function g_difficulty::getDifficultyByEgdCode(egdCode)
{
  return ::g_enum_utils.getCachedType("egdCode", egdCode, ::g_difficulty_cache.byEgdCode, ::g_difficulty, ::g_difficulty.UNKNOWN)
}

function g_difficulty::getDifficultyByEgdLowercaseName(name)
{
  return ::g_enum_utils.getCachedType("egdLowercaseName", name, ::g_difficulty_cache.byEgdLowercaseName,
                                        ::g_difficulty, ::g_difficulty.UNKNOWN)
}

function g_difficulty::getDifficultyByMatchingName(name)
{
  return ::g_enum_utils.getCachedType("matchingName", name, ::g_difficulty_cache.byMatchingName,
                                        ::g_difficulty, ::g_difficulty.UNKNOWN)
}

function g_difficulty::getDifficultyByCrewSkillName(name)
{
  return ::g_enum_utils.getCachedType("crewSkillName", name, ::g_difficulty_cache.byCrewSkillName,
                                      ::g_difficulty, ::g_difficulty.UNKNOWN)
}

function g_difficulty::isDiffCodeAvailable(diffCode, gm = null)
{
  return getDifficultyByDiffCode(diffCode).isAvailable(gm)
}

function g_difficulty::getDifficultyByChoiceType(searchChoiceType = "")
{
  foreach(type in types)
    if (::isInArray(searchChoiceType, type.choiceType))
      return type

  return ::g_difficulty.UNKNOWN
}

::g_difficulty_cache <- {
  byDiffCode = {}
  byName = {}
  byEgdCode = {}
  byEgdLowercaseName = {}
  byMatchingName = {}
  byCrewSkillName = {}
}

function get_current_ediff()
{

  if (! ::has_feature("GamercardDrawerSwitchBR"))
  {
    local gameMode = ::game_mode_manager.getCurrentGameMode()
    local battleType = ::get_battle_type_by_ediff(gameMode ? gameMode.ediff : 0)
    return ::get_current_shop_difficulty().getEdiff(battleType)
  }

  local gameMode = ::game_mode_manager.getCurrentGameMode()
  return gameMode && gameMode.ediff != -1 ? gameMode.ediff : EDifficulties.ARCADE
}

function get_battle_type_by_ediff(ediff)
{
  return ediff < EDIFF_SHIFT ? BATTLE_TYPES.AIR : BATTLE_TYPES.TANK
}

function get_difficulty_by_ediff(ediff)
{
  local diffCode = ediff % EDIFF_SHIFT
  foreach(difficulty in ::g_difficulty.types)
    if (difficulty.diffCode == diffCode)
      return difficulty
  return ::g_difficulty.ARCADE
}

function get_current_shop_difficulty()
{
  if (! ::has_feature("GamercardDrawerSwitchBR"))
  {
    foreach(diff in ::g_difficulty.types)
      if (::get_show_mode_info(diff.egdCode))
        return diff
    return ::g_difficulty.ARCADE
  }

  local gameMode = ::game_mode_manager.getCurrentGameMode()
  local diffCode = gameMode ? gameMode.diffCode : ::DIFFICULTY_ARCADE
  return ::g_difficulty.getDifficultyByDiffCode(diffCode)
}
