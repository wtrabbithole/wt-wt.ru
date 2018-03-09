::g_features <- {
  DEFAULTS = {  //def value when feature not found in game_settings.blk
               // not in this list are false
    SpendGold = true
    CrewSkills = true
    CrewBuyAllSkills = false
    UserLog = true
    Voice = true
    Friends = true
    Squad = true
    SquadWidget = true
    SquadTransferLeadership = false
    SquadSizeChange = false
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
    EmbeddedBrowser = false
    EmbeddedBrowserOnlineShop = false

    Chat = true
    ChatThreadsView = false
    ChatThreadLang = false
    ChatThreadCategories = false
    ChatThreadCreate = true

    Ships = ::disable_network()
    ShipsVisibleInShop = ::disable_network()
    ShipsFirstChoice = false
    Tanks = true
    TanksPs4 = true
    TanksInCustomBattles = false
    TanksInRandomBattles = false
    SpendGoldForTanks = false
    BritainTanksInFirstCountryChoice = false
    JapanTanksInFirstCountryChoice = false

    FranceAircraftsInFirstCountryChoice = false
    FranceTanksInFirstCountryChoice = false

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

    WorldWar = false
    worldWarMaster = false
    worldWarShowTestMaps = false
    WorldWarClansQueue = false
    WorldWarReplay = false
    WorldWarSquadInfo = false
    WorldWarSquadInvite = false
    WorldWarGlobalBattles = false

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
    BenchmarkPS4 = false
    DamageModelViewer = ::disable_network()
    DamageModelViewerAircraft = ::disable_network()
    ShowNextUnlockInfo = false
    extendedReplayInfo = ::disable_network()
    LiveBroadcast = false
    showAllUnitsRanks = false
    EarlyExitCrewUnlock = false
    UnitTooltipImage = true

    ActivityFeedPs4 = false

    UnlockAllCountries = false

    AllModesInRandomBattles = true
    SimulatorDifficulty = true
    SimulatorDifficultyInRandomBattles = true

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

    BulletParamsForAirs = ::disable_network()

    TankDetailedDamageIndicator = ::disable_network()
    ShipDetailedDamageIndicator = ::disable_network()

    ActiveScouting = false

    ShowAllPromoBlocks = ::disable_network()
    ShowAllBattleTasks = false

    ExtendedCrewSkillsDescription = ::disable_network()
    WikiUnitInfo = true
    ExpertToAce = false

    HiddenLeaderboardRows = false
    LiveStats = false
    streakVoiceovers = ::disable_network()
    SpectatorUnitDmgIndicator = ::disable_network()

    ProfileMedals = true
    SlotbarShowCountryName = false
    SlotbarShowBattleRating = true
    GlobalShowBattleRating = false
    GamercardDrawerSwitchBR = false
    VideoPreview = ::disable_network()

    ClanRegions = false
    ClanAnnouncements = false
    ClanLog = false
    ClanActivity = false
    ClanSeasonRewardsLog = false
    ClanSeasons_3_0 = false
    ClanChangedInfoData = false
    ClanSquads = false

    Warbonds = false
    WarbondsShop = false

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
    GamepadCursorControl = false

    SeparateTopMenuButtons = false

    HitCameraTargetStateIconsTank = false

    AllowExternalLink = true
    TankAltCrosshair = false

    DebriefingBattleTasks = false
  }

  cache = {}
}

function g_features::hasFeatureBasic(name)
{
  if (name in cache)
    return cache[name]

  local res = ::getTblValue(name, DEFAULTS, false)
  if (!::disable_network())
    res = ::local_player_has_feature(name, res)

  cache[name] <- res
  return res
}

function g_features::getFeaturePack(name)
{
  local sBlk = ::get_game_settings_blk()
  local featureBlk = sBlk && sBlk.features && sBlk.features[name]
  if (!::u.isDataBlock(featureBlk))
    return null
  return featureBlk.reqPack
}

function g_features::onEventProfileUpdated(p)
{
  cache.clear()
}

function has_feature(name)
{
  local confirmingResult = true
  if (name.len() > 1 && name.slice(0,1) == "!")
  {
    confirmingResult = false
    name = name.slice(1, name.len())
  }
  return ::g_features.hasFeatureBasic(name) == confirmingResult
}

function has_feature_array(arr)
{
  if (arr == null || arr.len() <= 0)
    return true

  foreach (name in arr)
    if (name && !::has_feature(name))
      return false

  return true
}

/**
 * Returns array of entitlements that
 * unlock feature with provided name.
 */
function get_entitlements_by_feature(name)
{
  local entitlements = []
  if (name == null)
    return entitlements
  local sBlk = ::get_game_settings_blk()
  local blk = sBlk && sBlk.features
  local feature = blk && blk[name]
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
