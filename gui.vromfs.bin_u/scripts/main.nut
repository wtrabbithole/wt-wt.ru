local __string = require("string")
foreach (name, func in require("dagor.localize"))
  ::dagor[name] <- func
::loc <- require("dagor.localize").loc

::regexp<-__string.regexp
::split <-__string.split
::format <-__string.format
::strip<-__string.strip
local __math = require("math")
::fabs<-__math.fabs

::script_protocol_version <- null
::dagor.runScript("scripts/version.nut")
::dagor.runScript("sqStdLibs/scriptReloader/scriptReloader.nut")
::g_script_reloader.loadOnce("sqStdLibs/helpers/backCompatibility.nut")
::g_script_reloader.loadOnce("scripts/compatibility.nut")
::g_script_reloader.loadOnce("scripts/clientState/errorHandling.nut")

::nda_version <- -1
::nda_version_tanks <-5
::eula_version <- 6

::TEXT_EULA <- 0
::TEXT_NDA <- 1

::target_platform <- ::get_platform()
::is_platform_pc <- ["win32", "win64", "macosx", "linux64"].find(::target_platform) >= 0
::is_platform_windows <- ["win32", "win64"].find(::target_platform) >= 0
::is_platform_ps4 <- ::target_platform == "ps4"
::is_platform_android <- ::target_platform == "android"
::is_platform_xboxone <- ::target_platform == "xboxOne"

::is_ps4_or_xbox <- ::is_platform_ps4 || ::is_platform_xboxone

::is_dev_version <- false // WARNING : this is unsecure

::INVALID_USER_ID <- ::make_invalid_user_id()
::RESPAWNS_UNLIMITED <- -1

::quick_match_flag <- false;
::test_flight <- false
::is_debug_mode_enabled <- false
::first_generation <- true

::skip_steam_confirmations <- false
::show_console_buttons <- false
::ps4_vsync_enabled <- true

::cross_call_api <- {}

if (::is_platform_ps4) ::exit_game <- function() {::gui_start_logout()}

::FORCE_UPDATE <- true
const LOST_DELAYED_ACTION_MSEC = 500

::g_script_reloader.registerPersistentData("MainGlobals", ::getroottable(),
  [
    "nda_version", "nda_version_tanks", "eula_version",
    "test_flight", "is_debug_mode_enabled", "first_generation",
    "skip_steam_confirmations", "show_console_buttons",
    "is_dev_version"
  ])

//------- vvv enums vvv ----------

enum EVENT_TYPE { //bit values for easy multi-type search
  UNKNOWN         = 0
  SINGLE          = 1,
  CLAN            = 2,
  TOURNAMENT      = 4,
  NEWBIE_BATTLES  = 8,

  //basic filters
  ANY             = 15,
  ANY_BASE_EVENTS = 5,
}

enum GAME_EVENT_TYPE
{
  /** Used for events that are neither race nor tournament. */
  TM_NONE = "TM_NONE"

  /** Race events. */
  TM_NONE_RACE = "TM_NONE_RACE"

  // Different tournament events.
  TM_ELO_PERSONAL = "TM_ELO_PERSONAL"
  TM_ELO_GROUP = "TM_ELO_GROUP"
  TM_ELO_GROUP_DETAIL = "TM_ELO_GROUP_DETAIL"
  TM_DOUBLE_ELIMINATION = "TM_DOUBLE_ELIMINATION"
}

enum weaponsItem
{
  primaryWeapon
  weapon  //secondary, weapon presets
  modification
  bullets          //bullets are modifications too, uses only in filling tab panel
  expendables
  spare
  bundle
  nextUnit
  curUnit
  unknown
}

enum BATTLE_TYPES
{
  AIR      = 0,
  TANK     = 1,
  UNKNOWN
}

enum ps4_activity_feed {
  MISSION_SUCCESS,
  PURCHASE_UNIT,
  CLAN_DUEL_REWARD,
  RESEARCHED_UNIT,
  MISSION_SUCCESS_AFTER_UPDATE,
  MAJOR_UPDATE
}

enum bit_activity {
  NONE              = 0,
  PS4_ACTIVITY_FEED = 1,
  FACEBOOK          = 2,
  ALL               = 3
}

enum itemsTab {
  INVENTORY
  SHOP
  WORKSHOP

  TOTAL
}

enum itemType { //bit values for easy multitype search
  UNKNOWN      = 0

  TROPHY          = 0x00000001  //chest
  BOOSTER         = 0x00000002
  TICKET          = 0x00000004  //tournament ticket
  WAGER           = 0x00000008
  DISCOUNT        = 0x00000010
  ORDER           = 0x00000020
  FAKE_BOOSTER    = 0x00000040
  UNIVERSAL_SPARE = 0x00000080
  MOD_OVERDRIVE   = 0x00000100
  MOD_UPGRADE     = 0x00000200

  //external inventory
  VEHICLE         = 0x00010000
  SKIN            = 0x00020000
  DECAL           = 0x00040000
  ATTACHABLE      = 0x00080000
  KEY             = 0x00100000
  CHEST           = 0x00200000
  WARBONDS        = 0x00400000
  INTERNAL_ITEM   = 0x00800000 //external inventory coupon which gives internal item
  ENTITLEMENT     = 0x01000000

  //workshop
  CRAFT_PART      = 0x10000000
  RECIPES_BUNDLE  = 0x20000000
  CRAFT_PROCESS   = 0x40000000

  //masks
  ALL             = 0xFFFFFFFF
  INVENTORY_ALL   = 0x0FBFFFFF //~CRAFT_PART ~CRAFT_PROCESS ~WARBONDS
}

enum PREVIEW_MODE
{
  NONE      = 0x0000
  UNIT      = 0x0001
  SKIN      = 0x0002
  DECORATOR = 0x0004
}

enum prizesStack {
  NOT_STACKED
  DETAILED
  BY_TYPE
}

enum HELP_CONTENT_SET
{
  MISSION
  LOADING
  CONTROLS
}

enum HUD_TYPE {
  CUTSCENE,
  SPECTATOR,
  BENCHMARK,
  AIR,
  TANK,
  SHIP,
  HELICOPTER,

  NONE
}

enum INFO_DETAIL //text detalization level. for weapons and modifications names and descriptions
{
  LIMITED_11 //must to fit in 11 symbols
  SHORT      //short info, like name. mostly in a single string.
  FULL       //full description
  EXTENDED   //full description + addtitional info for more detailed tooltip
}

enum voiceChatStats
{
  online
  offline
  talking
  muted
}

enum squadMemberState
{
  NOT_IN_SQUAD
  SQUAD_LEADER //leader cant be offline or not ready.
  SQUAD_MEMBER
  SQUAD_MEMBER_READY
  SQUAD_MEMBER_OFFLINE
}

::ES_UNIT_TYPE_TOTAL_RELEASED <- 2

const SAVE_ONLINE_JOB_DIGIT = 123 //super secure digit for job tag :)

enum COLOR_TAG {
  ACTIVE = "av"
  USERLOG = "ul"
  TEAM_BLUE = "tb"
  TEAM_RED = "tr"
}
local colorTagToColors = {
  [COLOR_TAG.ACTIVE] = "activeTextColor",
  [COLOR_TAG.USERLOG] = "userlogColoredText",
  [COLOR_TAG.TEAM_BLUE] = "teamBlueColor",
  [COLOR_TAG.TEAM_RED] = "teamRedColor",
}

enum SEEN {
  TITLES = "titles"
  AVATARS = "avatars"
  EVENTS = "events"
  WW_MAPS_AVAILABLE = "wwMapsAvailable"
  WW_MAPS_OBJECTIVE = "wwMapsObjective"
  INVENTORY = "inventory"
  ITEMS_SHOP = "items_shop"
  WORKSHOP = "workshop"
  WARBONDS_SHOP = "warbondsShop"
  EXT_XBOX_SHOP = "ext_xbox_shop"

  //sublists
  S_EVENTS_WINDOW = "##events_window##"
}

enum xboxMediaItemType { //values by microsoft IDE, others not used
  GameContent = 4
  GameConsumable = 5
}

function randomize()
{
  local tm = ::get_local_time()
  ::math.init_rnd(tm.sec + tm.min + tm.hour)
}
randomize()

//------- vvv files before login vvv ----------

::g_string <- ::require("std/string.nut") //put g_string to root_table
::u <- ::require("std/u.nut") //put u to roottable
::Callback <- ::require("sqStdLibs/helpers/callback.nut").Callback

local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")
::g_listener_priority <- {
  DEFAULT = 0
  DEFAULT_HANDLER = 1
  UNIT_CREW_CACHE_UPDATE = 2
  USER_PRESENCE_UPDATE = 2
  CONFIG_VALIDATION = 2
  LOGIN_PROCESS = 3
}
subscriptions.setDefaultPriority(::g_listener_priority.DEFAULT)
::broadcastEvent <- subscriptions.broadcast
::add_event_listener <- subscriptions.addEventListener
::subscribe_handler <- subscriptions.subscribeHandler

foreach (fn in [
  "scripts/sharedEnums.nut"

  "std/math.nut"

  "sqDagui/guiBhv/allBhv.nut"
  "scripts/bhvCreditsScroll.nut"
  "scripts/cubicBezierSolver.nut"
  "scripts/onlineShop/urlType.nut"
  "scripts/onlineShop/url.nut"

  "sqStdLibs/helpers/handyman.nut"
  "scripts/debugTools/dbgToString.nut"

  "sqDagui/framework/framework.nut"

  "scripts/utils/configs.nut"
  "sqDagui/daguiUtil.nut"
  "scripts/viewUtils/layeredIcon.nut"
  "scripts/viewUtils/projectAwards.nut"

  "scripts/sqModuleHelpers.nut"
  "scripts/util.nut"
  "sqDagui/timer/timer.nut"

  "scripts/clientState/localProfile.nut"
  "scripts/options/optionsExtNames.nut"
  "scripts/options/fonts.nut"
  "scripts/options/consoleMode.nut"
  "scripts/options/optionsManager.nut"
  "scripts/options/optionsBeforeLogin.nut"

  "scripts/baseGuiHandlerManagerWT.nut"

  "scripts/langUtils/localization.nut"
  "scripts/langUtils/language.nut"

  "scripts/user/features.nut"
  "scripts/clientState/keyboardState.nut"
  "scripts/clientState/contentPacks.nut"
  "scripts/utils/errorMsgBox.nut"
  "scripts/tasker.nut"
  "scripts/utils/delayedActions.nut"

  "scripts/clientState/fpsDrawer.nut"
  "scripts/loading/animBg.nut"
  "scripts/loading/loading.nut"
  "scripts/login/loginMain.nut"
  "scripts/pseudoThread.nut"
  "scripts/loginWT.nut"

  "scripts/options/gamepadCursorControls.nut"
  "scripts/unit/unitType.nut"
  "scripts/loading/loadingTips.nut"
  "scripts/options/countryFlagsPreset.nut"

  "scripts/hangarLights.nut"
  "scripts/hangarModelLoadManager.nut"

  "scripts/webRPC.nut"
  "scripts/matching/api.nut"
  "scripts/matching/client.nut"
  "scripts/matching/matchingConnect.nut"

  "scripts/wndLib/editBoxHandler.nut"
  "scripts/wndLib/rightClickMenu.nut"
  "scripts/actionsList.nut"

  "scripts/debugTools/dbgEnum.nut"
  "scripts/debugTools/debugWnd.nut"
  "scripts/debugTools/dbgTimer.nut"
  "scripts/debugTools/dbgDump.nut"
  "scripts/debugTools/dbgUtils.nut"
  "scripts/debugTools/dbgImage.nut"
  "scripts/debugTools/dbgFonts.nut"
  "scripts/debugTools/dbgAvatarsList.nut"
  "scripts/debugTools/dbgMarketplace.nut"

  //probably used before login on ps4
  "scripts/controls/controlsConsts.nut"
  "scripts/controls/rawShortcuts.nut"
  "scripts/controls/controlsManager.nut"

  //used before xbox login
  "scripts/social/xboxSquadManager.nut"

  //used for SSO login
  "scripts/onlineshop/browserWnd.nut"
])
{
  ::g_script_reloader.loadOnce(fn)
}

if (::g_script_reloader.isInReloading)
  foreach(bhvName, bhvClass in ::gui_bhv)
    ::replace_script_gui_behaviour(bhvName, bhvClass)

foreach(bhvName, bhvClass in ::gui_bhv_deprecated)
  ::add_script_gui_behaviour(bhvName, bhvClass)

::u.registerClass(
  "DaGuiObject",
  ::DaGuiObject,
  @(obj1, obj2) obj1.isValid() && obj2.isValid() && obj1.isEqual(obj2),
  @(obj) !obj.isValid()
)

  // Independed Modules (before login)
::require("sqDagui/elemUpdater/bhvUpdater.nut").setAssertFunction(::script_net_assert_once)
::require("scripts/clientState/elems/dlDataStatElem.nut")
::require("sqDagui/framework/progressMsg.nut").setTextLocIdDefault("charServer/purchase0")
  // end of Independed Modules

::cross_call_api.platform <- ::require("scripts/clientState/platform.nut")
//------- ^^^ files before login ^^^ ----------


//------- vvv files after login vvv ----------

local isFullScriptsLoaded = false
function load_scripts_after_login_once()
{
  if (isFullScriptsLoaded)
    return
  isFullScriptsLoaded = true

  foreach (fn in [
    "ranks.nut"
    "difficulty.nut"
    "unitClassType.nut"
    "teams.nut"
    "airInfo.nut"
    "options/optionsExt.nut"
    "options/initOptions.nut"

    "gamercard.nut"
    "popups/popups.nut"
    "popups/popup.nut"
    "baseGuiHandlerWT.nut"
    "weaponsInfo.nut"

    "wheelmenu/wheelmenu.nut"
    "guiLines.nut"
    "guiTutorial.nut"
    "wndLib/multiSelectMenu.nut"
    "showImage.nut"
    "chooseImage.nut"
    "newIconWidget.nut"
    "wndLib/commentModal.nut"
    "wndLib/infoWnd.nut"
    "wndLib/skipableMsgBox.nut"
    "wndWidgets/navigationPanel.nut"

    "viewUtils/hintTags.nut"
    "viewUtils/hints.nut"
    "viewUtils/bhvHint.nut"
    "timeBar.nut"

    "money.nut"
    "dataBlockAdapter.nut"

    "postFxSettings.nut"
    "artilleryMap.nut"
    "clusterSelect.nut"
    "encyclopedia.nut"

    "utils/genericTooltip.nut"
    "utils/genericTooltipTypes.nut"

    "eulaWnd.nut"
    "countryChoiceWnd.nut"

    "measureType.nut"
    "options/optionsWnd.nut"
    "systemOptions.nut"
    "genericOptions.nut"
    "options/framedOptionsWnd.nut"
    "options/optionsCustomDifficulty.nut"
    "options/fontChoiceWnd.nut"

    "leaderboardDataType.nut"
    "leaderboardCategoryType.nut"
    "leaderboard.nut"

    "queue/queueManager.nut"

    "events/eventDisplayType.nut"
    "events/eventsChapter.nut"
    "events/eventsManager.nut"
    "events/eventsHandler.nut"
    "events/eventRoomsHandler.nut"
    "events/eventsLeaderboards.nut"
    "events/eventRewards.nut"
    "events/eventRewardsWnd.nut"
    "events/rewardProgressManager.nut"
    "events/eventDescription.nut"
    "events/eventTicketBuyOfferProcess.nut"
    "events/eventDescriptionWindow.nut"
    "vehiclesWindow.nut"
    "events/eventJoinProcess.nut"

    "gameModes/gameModeSelect.nut"
    "gameModes/gameModeManager.nut"
    "changeCountry.nut"
    "instantAction.nut"
    "promo/promoViewUtils.nut"
    "promo/promo.nut"
    "promo/promoHandler.nut"
    "promo/BattleTasksPromoHandler.nut"
    "mainmenu/topMenuButtons.nut"
    "mainmenu/topMenuSections.nut"
    "mainmenu/topMenuSectionsConfigs.nut"
    "mainmenu/topMenuButtonsHandler.nut"
    "mainmenu/topMenuHandler.nut"
    "mainmenu/mainMenu.nut"
    "credits.nut"

    "slotbar/crewsList.nut"
    "slotbar/slotbar.nut"
    "slotbar/slotbarWidget.nut"
    "slotbar/selectCrew.nut"
    "slotbar/selectUnit.nut"
    "slotbar/slotbarPresetsList.nut"

    "onlineInfo/onlineInfo.nut"
    "onlineInfo/clustersManagement.nut"
    "matching/matchingGameModes.nut"

    "user/presenceType.nut"
    "squads/msquadService.nut"
    "squads/squadMember.nut"
    "squads/squadManager.nut"
    "squads/squadUtils.nut"
    "squads/squadInviteListWnd.nut"
    "squads/squadWidgetCustomHandler.nut"
    "squads/psnSquadInvite.nut"

    "social/psnSessions.nut"
    "social/psnPlayTogether.nut"

    "dirtyWordsRussian.nut"
    "dirtyWordsEnglish.nut"
    "dirtyWordsJapanese.nut"
    "dirtyWords.nut"
    "chat/chatRoomType.nut"
    "chat/chat.nut"
    "chat/chatLatestThreads.nut"
    "chat/chatCategories.nut"
    "chat/menuChat.nut"
    "chat/createRoomWnd.nut"
    "chat/chatThreadInfoTags.nut"
    "chat/chatThreadInfo.nut"
    "chat/chatThreadsListView.nut"
    "chat/chatThreadHeader.nut"
    "chat/modifyThreadWnd.nut"
    "chat/mpChatMode.nut"
    "chat/mpChat.nut"

    "invites/invites.nut"
    "invites/inviteBase.nut"
    "invites/inviteChatRoom.nut"
    "invites/inviteSessionRoom.nut"
    "invites/inviteTournamentBattle.nut"
    "invites/inviteSquad.nut"
    "invites/inviteFriend.nut"
    "invites/invitesWnd.nut"

    "voiceMessages.nut"
    "controls/controlsPresets.nut"
    "controls/controlsUtils.nut"
    "controls/controls.nut"
    "controls/controlsConsole.nut"
    "controls/input/inputBase.nut"
    "controls/input/nullInput.nut"
    "controls/input/button.nut"
    "controls/input/combination.nut"
    "controls/input/axis.nut"
    "controls/input/doubleAxis.nut"
    "controls/input/image.nut"
    "controls/shortcutType.nut"
    "controls/controlsPseudoAxes.nut"
    "controls/controlsWizard.nut"
    "controls/controlsType.nut"
    "controls/AxisControls.nut"
    "controls/aircraftHelpers.nut"
    "controls/gamepadCursorControlsSplash.nut"
    "help/helpWnd.nut"
    "help/helpInfoHandlerModal.nut"
    "joystickInterface.nut"

    "loading/loadingHangar.nut"
    "loading/loadingBrief.nut"
    "missions/mapPreview.nut"
    "missions/missionType.nut"
    "missions/missionsUtils.nut"
    "missions/urlMission.nut"
    "missions/loadingUrlMissionModal.nut"
    "missions/missionsManager.nut"
    "missions/urlMissionsList.nut"
    "missions/misListType.nut"
    "missions/missionDescription.nut"
    "tutorials.nut"
    "tutorialsManager.nut"
    "missions/campaignChapter.nut"
    "missions/remoteMissionModalHandler.nut"
    "missions/modifyUrlMissionWnd.nut"
    "missions/chooseMissionsListWnd.nut"
    "dynCampaign/dynamicChapter.nut"
    "dynCampaign/campaignPreview.nut"
    "dynCampaign/campaignResults.nut"
    "briefing.nut"
    "missionBuilder/testFlight.nut"
    "missionBuilder/missionBuilder.nut"
    "missionBuilder/missionBuilderTuner.nut"
    "missionBuilder/changeAircraftForBuilder.nut"

    "events/eventRoomCreationContext.nut"
    "events/createEventRoomWnd.nut"

    "replays/replayScreen.nut"
    "replays/replayPlayer.nut"

    "customization/types.nut"
    "customization/decorator.nut"
    "customization/decoratorsManager.nut"
    "customization/customizationWnd.nut"

    "myStats.nut"
    "user/usersInfoManager.nut"
    "user/partnerUnlocks.nut"
    "user/userUtils.nut"
    "user/userCard.nut"
    "user/profileHandler.nut"
    "user/viralAcquisition.nut"
    "user/chooseTitle.nut"

    "contacts/contacts.nut"
    "userPresence.nut"

    "unlocks/unlocksConditions.nut"
    "unlocks/unlocks.nut"
    "unlocks/unlocksView.nut"
    "unlocks/showUnlock.nut"
    "unlocks/battleTaskDifficulty.nut"
    "unlocks/battleTasks.nut"
    "unlocks/personalUnlocks.nut"
    "unlocks/battleTasksHandler.nut"
    "unlocks/battleTasksSelectNewTask.nut"
    "unlocks/favoriteUnlocksListView.nut"

    "onlineShop/onlineShopModel.nut"
    "onlineShop/onlineShop.nut"
    "onlineShop/reqPurchaseWnd.nut"
    "paymentHandler.nut"

    "shop/shop.nut"
    "shop/shopCheckResearch.nut"
    "shop/shopViewWnd.nut"
    "convertExpHandler.nut"

    "weaponry/dmgModel.nut"
    "weaponry/unitBulletsGroup.nut"
    "weaponry/unitBulletsManager.nut"
    "dmViewer/dmViewer.nut"
    "weaponry/weaponryTypes.nut"
    "weaponsVisual.nut"
    "weaponry/weaponrySelectModal.nut"
    "weaponry/unitWeaponsHandler.nut"
    "weaponry/weapons.nut"
    "weaponry/weaponWarningHandler.nut"
    "weaponry/weaponsPurchase.nut"
    "finishedResearches.nut"
    "modificationsTierResearched.nut"

    "matchingRooms/sessionLobby.nut"
    "matchingRooms/mRoomsList.nut"
    "matchingRooms/mRoomInfo.nut"
    "matchingRooms/mRoomInfoManager.nut"
    "matchingRooms/sessionsListHandler.nut"
    "mplayerParamType.nut"
    "matchingRooms/mRoomPlayersListWidget.nut"
    "matchingRooms/mpLobby.nut"
    "matchingRooms/mRoomMembersWnd.nut"

    "flightMenu.nut"
    "misCustomRules/missionCustomState.nut"
    "mpStatistics.nut"
    "respawn/misLoadingState.nut"
    "respawn/respawn.nut"
    "respawn/teamUnitsLeftView.nut"
    "misObjectives/objectiveStatus.nut"
    "misObjectives/misObjectivesView.nut"
    "tacticalMap.nut"

    "userLog/userlogData.nut"
    "userLog/userlogViewData.nut"
    "userLog/userLog.nut"

    "debriefing/debriefingFull.nut"
    "debriefing/debriefingModal.nut"
    "debriefing/rankUpModal.nut"
    "debriefing/tournamentRewardReceivedModal.nut"
    "mainmenu/benchmarkResultModal.nut"

    "clans/clanType.nut"
    "clans/clanLogType.nut"
    "clans/clans.nut"
    "clans/clanSeasons.nut"
    "clans/clanTagDecorator.nut"
    "clans/modify/modifyClanModalHandler.nut"
    "clans/modify/createClanModalHandler.nut"
    "clans/modify/editClanModalhandler.nut"
    "clans/modify/upgradeClanModalHandler.nut"
    "clans/clanChangeMembershipReqWnd.nut"
    "clans/clanPageModal.nut"
    "clans/clansModalHandler.nut"
    "clans/clanChangeRoleModal.nut"
    "clans/clanBlacklistModal.nut"
    "clans/clanActivityModal.nut"
    "clans/clanRequestsModal.nut"
    "clans/clanLogModal.nut"
    "clans/clanSeasonInfoModal.nut"
    "clans/clanSquadsModal.nut"
    "clans/clanSquadInfoWnd.nut"

    "penitentiary/banhammer.nut"
    "penitentiary/tribunal.nut"

    "social/friends.nut"
    "social/activityFeed.nut"
    "social/facebook.nut"

    "gamercardDrawer.nut"

    "discounts/discounts.nut"
    "discounts/discountUtils.nut"

    "items/itemsManager.nut"
    "items/prizesView.nut"
    "items/recentItems.nut"
    "items/recentItemsHandler.nut"
    "items/ticketBuyWindow.nut"
    "items/itemsShop.nut"
    "items/trophyReward.nut"
    "items/trophyGroupShopWnd.nut"
    "items/trophyRewardWnd.nut"
    "items/trophyRewardList.nut"
    "items/everyDayLoginAward.nut"
    "items/orderAwardMode.nut"
    "items/orderType.nut"
    "items/orderUseResult.nut"
    "items/orders.nut"
    "items/orderActivationWindow.nut"

    "crew/crewShortCache.nut"
    "crew/skillParametersRequestType.nut"
    "crew/skillParametersColumnType.nut"
    "crew/crewModalHandler.nut"
    "crew/skillsPageStatus.nut"
    "crew/crewPoints.nut"
    "crew/crewBuyPointsHandler.nut"
    "crew/crewUnitSpecHandler.nut"
    "crew/crewSkillsPageHandler.nut"
    "crew/crewSpecType.nut"
    "crew/crew.nut"
    "crew/crewSkills.nut"
    "crew/unitCrewCache.nut"
    "crew/crewSkillParameters.nut"
    "crew/skillParametersType.nut"
    "crew/crewTakeUnitProcess.nut"

    "slotbar/slotbarPresets.nut"
    "slotbar/slotbarPresetsWnd.nut"
    "vehicleRequireFeatureWindow.nut"
    "slotbar/slotbarPresetsTutorial.nut"
    "slotInfoPanel.nut"
    "unit/infoBoxWindow.nut"
    "unit/unitInfoType.nut"
    "unit/unitInfoExporter.nut"

    "hud/hudEventManager.nut"
    "hud/hudVisMode.nut"
    "hud/baseUnitHud.nut"
    "hud/hud.nut"
    "hud/hudActionBarType.nut"
    "hud/hudActionBar.nut"
    "replays/spectator.nut"
    "hud/hudTankDebuffs.nut"
    "hud/hudShipDebuffs.nut"
    "hud/hudDisplayTimers.nut"
    "hud/hudCrewState.nut"
    "hud/hudEnemyDebuffsType.nut"
    "hud/hudEnemyDamage.nut"
    "hud/hudRewardMessage.nut"
    "hud/hudMessages.nut"
    "hud/hudMessageStack.nut"
    "hud/hudBattleLog.nut"
    "hud/hudHitCamera.nut"
    "hud/hudLiveStats.nut"
    "hud/hudTutorialElements.nut"
    "hud/hudTutorialObject.nut"
    "streaks.nut"
    "wheelmenu/voicemenu.nut"
    "hud/hudHintTypes.nut"
    "hud/hudHints.nut"
    "hud/hudHintsManager.nut"

    "warbonds/warbondAwardType.nut"
    "warbonds/warbondAward.nut"
    "warbonds/warbond.nut"
    "warbonds/warbondsManager.nut"
    "warbonds/warbondsView.nut"
    "warbonds/warbondShop.nut"

    "statsd/missionStats.nut"
    "debugTools/dbgCheckContent.nut"
    "debugTools/dbgUnlocks.nut"
    "debugTools/dbgClans.nut"
    "debugTools/dbgHud.nut"
    "debugTools/dbgHudObjects.nut"
    "debugTools/dbgHudObjectTypes.nut"
    "debugTools/dbgVoiceChat.nut"

    "utils/popupMessages.nut"
    "utils/soundManager.nut"
    "fileDialog/fileDialog.nut"
    "fileDialog/ps4SaveDataDialog.nut"
    "controls/ps4ControlsBackupManager.nut"

    "matching/serviceNotifications/match.nut"
    "matching/serviceNotifications/mlogin.nut"
    "matching/serviceNotifications/mrpc.nut"
    "matching/serviceNotifications/mpresense.nut"
    "matching/serviceNotifications/msquad.nut"
    "matching/serviceNotifications/worldwar.nut"
    "matching/serviceNotifications/mrooms.nut"

    "webpoll.nut"
  ])
  {
    ::g_script_reloader.loadOnce("scripts/" + fn)
  }

  if (::g_login.isAuthorized() || ::disable_network()) //load scripts from packs only after login
    ::g_script_reloader.loadIfExist("scripts/worldWar/worldWar.nut")

  // Independed Modules (after login)
  ::require("scripts/social/playerInfoUpdater.nut")
  ::require("scripts/seen/bhvUnseen.nut")
  ::require("scripts/items/roulette/bhvRoulette.nut")
  ::require("scripts/squads/elems/voiceChatElem.nut")
  ::require("scripts/slotbar/elems/discountIconElem.nut")
  // end of Independed Modules

  ::require("scripts/utils/systemMsg.nut").registerColors(colorTagToColors)
}

//app does not exist on script load, so we cant to use ::app->shouldDisableMenu
function should_disable_menu()
{
  return (::disable_network() && ::getFromSettingsBlk("debug/disableMenu"))
    || ::getFromSettingsBlk("benchmarkMode")
    || ::getFromSettingsBlk("viewReplay")
}

if (::g_login.isAuthorized() //scripts reload
    || ::should_disable_menu())
{
  ::load_scripts_after_login_once()
  if (!::g_script_reloader.isInReloading)
    ::run_reactive_gui()
}

//------- ^^^ files after login ^^^ ----------
::use_touchscreen <- ::init_use_touchscreen()
