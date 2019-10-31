::g_features <- {
  DEFAULTS = {  //def value when feature not found in game_settings.blk
               // not in this list are false
    SpendGold = true
    SpendFreeRP = true
    CrewInfo = true
    CrewSkills = true
    CrewBuyAllSkills = false
    UserLog = true
    Voice = true
    Friends = true
    Squad = true
    SquadWidget = true
    SquadTransferLeadership = false
    SquadSizeChange = false
    SquadInviteIngame = true
    Clans = true
    Battalions = false
    Radio = true
    Facebook = true
    FacebookWallPost = true
    FacebookScreenshots = true
    Events = true
    CreateEventRoom = false
    QueueCustomEventRoom = false
    Invites = true
    Credits = true
    EmbeddedBrowser = is_platform_windows
    EmbeddedBrowserOnlineShop = false

    Chat = true
    ChatThreadsView = false
    ChatThreadLang = false
    ChatThreadCategories = false
    ChatThreadCreate = true

    Ships = ::disable_network()
    ShipsVisibleInShop = ::disable_network()
    ShipsFirstChoice = false
    SpendGoldForShips = false
    Tanks = true
    TanksPs4 = true
    TanksInCustomBattles = false
    TanksInRandomBattles = false
    SpendGoldForTanks = false

    UsaAircraftsInFirstCountryChoice      = true
    UsaTanksInFirstCountryChoice          = true
    UsaShipsInFirstCountryChoice          = true
    GermanyAircraftsInFirstCountryChoice  = true
    GermanyTanksInFirstCountryChoice      = true
    GermanyShipsInFirstCountryChoice      = true
    UssrAircraftsInFirstCountryChoice     = true
    UssrTanksInFirstCountryChoice         = true
    UssrShipsInFirstCountryChoice         = true
    BritainAircraftsInFirstCountryChoice  = true
    BritainTanksInFirstCountryChoice      = true
    BritainShipsInFirstCountryChoice      = true
    JapanAircraftsInFirstCountryChoice    = true
    JapanTanksInFirstCountryChoice        = ::disable_network()
    JapanShipsInFirstCountryChoice        = ::disable_network()
    ChinaAircraftsInFirstCountryChoice    = true
    ChinaTanksInFirstCountryChoice        = true
    ChinaShipsInFirstCountryChoice        = ::disable_network()
    ItalyAircraftsInFirstCountryChoice    = true
    ItalyTanksInFirstCountryChoice        = true
    ItalyShipsInFirstCountryChoice        = ::disable_network()
    FranceAircraftsInFirstCountryChoice   = true
    FranceTanksInFirstCountryChoice       = ::disable_network()
    FranceShipsInFirstCountryChoice       = ::disable_network()

    Helicopters = ::disable_network()

    Tribunal = false

    HideDisabledTopMenuActions = false
    ModeSkirmish = true
    ModeBuilder = true
    ModeDynamic = true
    ModeSingleMissions = true
    QmbCoopPc = false
    QmbCoopPs4 = false
    DynCampaignCoopPc = false
    DynCampaignCoopPs4 = false
    SingleMissionsCoopPc = true
    SingleMissionsCoopPs4 = true
    CustomBattlesPc = true
    CustomBattlesPs4 = true
    HistoricalCampaign = true
    Leaderboards = true
    HangarWndHelp = true
    EulaInMenu = true
    WarpointsInMenu = true

    WorldWar = false
    worldWarMaster = false
    worldWarShowTestMaps = false
    WorldWarClansQueue = false
    WorldWarReplay = false
    WorldWarSquadInfo = false
    WorldWarSquadInvite = false
    WorldWarGlobalBattles = false
    WorldWarLeaderboards = false
    WorldWarCountryLeaderboard = false

    SpecialShip = false

    GraphicsOptions = true
    Spectator = false
    BuyAllModifications = false
    Packages = true
    DecalsUse = true
    AttachablesUse = ::disable_network()
    UserSkins = true
    SkinsPreviewOnUnboughtUnits = ::disable_network()
    SkinAutoSelect = false
    UserMissions = true
    UserMissionsSkirmishLocal = false
    UserMissionsSkirmishByUrl = false
    UserMissionsSkirmishByUrlCreate = false
    Replays = true
    ServerReplay = true
    Encyclopedia = true
    Benchmark = true
    DamageModelViewer = ::disable_network()
    ShowNextUnlockInfo = false
    extendedReplayInfo = ::disable_network()
    LiveBroadcast = false
    showAllUnitsRanks = false
    EarlyExitCrewUnlock = false
    UnitTooltipImage = true

    ActivityFeedPs4 = false

    UnlockAllCountries = false

    GameModeSelector = true
    AllModesInRandomBattles = true
    SimulatorDifficulty = true
    SimulatorDifficultyInRandomBattles = true

    Tutorials = true
    AllowedToSkipBaseTutorials = true
    AllowedToSkipBaseTankTutorials = true
    EnableGoldPurchase = true
    EnablePremiumPurchase = true
    OnlineShopPacks = true
    ManuallyUpdateBalance = true //!!debug only
    PaymentMethods = true

    Items = false
    ItemsShop = true
    Wagers = true
    ItemsRoulette = false
    BattleTasks = false
    BattleTasksHard = true
    PersonalUnlocks = false
    ItemsShopInTopMenu = true
    ItemModUpgrade = false
    ModUpgradeDifference = false

    BulletParamsForAirs = ::disable_network()

    TankDetailedDamageIndicator = ::disable_network()
    ShipDetailedDamageIndicator = ::disable_network()

    ActiveScouting = false

    PromoBlocks = true
    ShowAllPromoBlocks = ::disable_network()
    ShowAllBattleTasks = false

    ExtendedCrewSkillsDescription = ::disable_network()
    UnitInfo = true
    WikiUnitInfo = true
    ExpertToAce = false

    HiddenLeaderboardRows = false
    LiveStats = false
    streakVoiceovers = ::disable_network()
    SpectatorUnitDmgIndicator = ::disable_network()

    Profile = true
    ProfileMedals = true
    UserCards = true
    SlotbarShowBattleRating = true
    GlobalShowBattleRating = false
    VideoPreview = ::disable_network()

    ClanRegions = false
    ClanAnnouncements = false
    ClanLog = false
    ClanActivity = false
    ClanSeasonRewardsLog = false
    ClanSeasons_3_0 = false
    ClanChangedInfoData = false
    ClanSquads = false
    ClanVehicles = false

    Warbonds = false
    WarbondsShop = false
    ItemConvertToWarbond = false
    ItemConvertToWarbondMultiple = false

    CountryChina = false

    DisableSwitchPresetOnTutorialForHotas4 = false

    MissionsChapterHidden = ::disable_network()
    MissionsChapterTest = ::disable_network()

    ChinaForbidden = true //feature not allowed for china only
    ClanBattleSeasonAvailable = true

    CheckTwoStepAuth = false
    CheckEmailVerified = false

    AerobaticTricolorSmoke = ::disable_network()

    XRayDescription = ::disable_network()
    GamepadCursorControl = true
    ControlsHelp = true

    SeparateTopMenuButtons = false

    HitCameraTargetStateIconsTank = false

    AllowExternalLink = true
    TankAltCrosshair = false

    DebriefingBattleTasks = false
    PromoBattleTasksRadioButtons = false

    XboxIngameShop = false
    XboxCrossConsoleInteraction = false
    Ps4XboxOneInteraction = false
    EnableMouse = true

    NewUnitTypeToBattleTutorial = false
    AchievementsUrl = false

    AllowSteamAccountLinking = true
    AllowXboxAccountLinking = false

    ClansXBOXOnPC = false

    MapPreferences = false
    TournamentInvites = true

    PS4CrossNetwork = false
  }

  cache = {}
}

g_features.hasFeatureBasic <- function hasFeatureBasic(name)
{
  if (name in cache)
    return cache[name]

  local res = ::getTblValue(name, DEFAULTS, false)
  if (!::disable_network())
    res = ::local_player_has_feature(name, res)

  cache[name] <- res
  return res
}

g_features.getFeaturePack <- function getFeaturePack(name)
{
  local sBlk = ::get_game_settings_blk()
  local featureBlk = sBlk?.features[name]
  if (!::u.isDataBlock(featureBlk))
    return null
  return featureBlk?.reqPack
}

g_features.onEventProfileUpdated <- function onEventProfileUpdated(p)
{
  cache.clear()
}

::has_feature <- function has_feature(name)
{
  local confirmingResult = true
  if (name.len() > 1 && name.slice(0,1) == "!")
  {
    confirmingResult = false
    name = name.slice(1, name.len())
  }
  return ::g_features.hasFeatureBasic(name) == confirmingResult
}

::has_feature_array <- function has_feature_array(arr)
{
  if (arr == null || arr.len() <= 0)
    return true

  foreach (name in arr)
    if (name && !::has_feature(name))
      return false

  return true
}

::has_feature_array_any <- function has_feature_array_any(arr)
{
  if (arr == null || arr.len() <= 0)
    return true

  foreach (name in arr)
    if (name && ::has_feature(name))
      return true

  return false
}

/**
 * Returns array of entitlements that
 * unlock feature with provided name.
 */
::get_entitlements_by_feature <- function get_entitlements_by_feature(name)
{
  local entitlements = []
  if (name == null)
    return entitlements
  local feature = ::get_game_settings_blk()?.features?[name]
  if (feature == null)
    return entitlements
  foreach(condition in (feature % "condition"))
  {
    if (typeof(condition) == "string" &&
        OnlineShopModel.isEntitlement(condition))
      entitlements.push(condition)
  }
  return entitlements
}

::subscribe_handler(::g_features, ::g_listener_priority.CONFIG_VALIDATION)
