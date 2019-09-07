local enums = ::require("sqStdlibs/helpers/enums.nut")
local bhvUnseen = ::require("scripts/seen/bhvUnseen.nut")
local xboxShopData = ::require("scripts/onlineShop/xboxShopData.nut")

enum TOP_MENU_ELEMENT_TYPE {
  BUTTON,
  EMPTY_BUTTON,
  CHECKBOX,
  LINE_SEPARATOR
}

::g_top_menu_buttons <- {
  types = []
  cache = {
    byId = {}
  }

  template = {
    id = ""
    text = ""
    image = null
    link = null
    isLink = @() false
    isFeatured = @() false
    needDiscountIcon = false
    unseenIcon = null
    onClickFunc = @(obj, handler = null) null
    onChangeValueFunc = @(value) null
    useImage = null
    isHidden = @(handler = null) false
    isVisualDisabled = @() false
    isInactiveInQueue = false
    elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
    isButton = @() elementType == TOP_MENU_ELEMENT_TYPE.BUTTON
    isDelayed = true
    checkbox = @() elementType == TOP_MENU_ELEMENT_TYPE.CHECKBOX //param name only because of checkbox.tpl
    isLineSeparator = @() elementType == TOP_MENU_ELEMENT_TYPE.LINE_SEPARATOR
    isEmptyButton = @() elementType == TOP_MENU_ELEMENT_TYPE.EMPTY_BUTTON
    funcName = @() isButton()? "onClick" : checkbox()? "onChangeCheckboxValue" : null
  }
}

enums.addTypesByGlobalName("g_top_menu_buttons", {
  UNKNOWN = {}
  SKIRMISH = {
    text = "#mainmenu/btnSkirmish"
    onClickFunc = function(obj, handler)
    {
      if (!::is_custom_battles_enabled())
        return ::show_not_available_msg_box()
      if (!::check_gamemode_pkg(::GM_SKIRMISH))
        return
      ::queues.checkAndStart(
        ::Callback(@() goForwardIfOnline(::gui_start_skirmish, false), handler),
        null,
        "isCanNewflight"
      )
    }

    isHidden = @(...) !::is_custom_battles_enabled()
    isInactiveInQueue = true
  }
  WORLDWAR = {
    text = "#mainmenu/btnWorldwar"
    onClickFunc = @(obj, handler) ::g_world_war.openOperationsOrQueues()
    tooltip = @() ::g_world_war.getCantPlayWorldwarReasonText()
    isVisualDisabled = @() !::is_worldwar_enabled() || !::g_world_war.canPlayWorldwar()
    unseenIcon = @() ::is_worldwar_enabled() && ::g_world_war.canPlayWorldwar() && SEEN.WW_MAPS_AVAILABLE
  }
  TUTORIAL = {
    text = "#mainmenu/btnTutorial"
    onClickFunc = @(obj, handler) handler.checkedNewFlight(::gui_start_tutorial)
    isInactiveInQueue = true
  }
  SINGLE_MISSION = {
    text = "#mainmenu/btnSingleMission"
    onClickFunc = @(obj, handler) ::checkAndCreateGamemodeWnd(handler, ::GM_SINGLE_MISSION)
    isVisualDisabled = function() {return !::has_feature("ModeSingleMissions") }
    isInactiveInQueue = true
  }
  DYNAMIC = {
    text = "#mainmenu/btnDynamic"
    onClickFunc = @(obj, handler) ::checkAndCreateGamemodeWnd(handler, ::GM_DYNAMIC)
    isVisualDisabled = function() {return !::has_feature("ModeDynamic") }
    isInactiveInQueue = true
  }
  CAMPAIGN = {
    text = "#mainmenu/btnCampaign"
    onClickFunc = function(obj, handler) {
      if (!::ps4_is_chunk_available(PS4_CHUNK_HISTORICAL_CAMPAIGN))
        return ::showInfoMsgBox(::loc("mainmenu/campaignDownloading"), "question_wait_download")

      if (::is_any_campaign_available())
        return handler.checkedNewFlight(@() ::gui_start_campaign())

      if (!::has_feature("OnlineShopPacks"))
        return ::show_not_available_msg_box()

      ::scene_msg_box("question_buy_campaign", null, ::loc("mainmenu/questionBuyHistorical"),
        [
          ["yes", ::purchase_any_campaign],
          ["no", function() {}]
        ], "yes", { cancel_fn = function() {}})
    }
    isHidden = @(...) !::has_feature("HistoricalCampaign")
    isVisualDisabled = function() { return !::ps4_is_chunk_available(PS4_CHUNK_HISTORICAL_CAMPAIGN) }
    isInactiveInQueue = true
  }
  BENCHMARK = {
    text = "#mainmenu/btnBenchmark"
    onClickFunc = @(obj, handler) handler.checkedNewFlight(::gui_start_benchmark)
    isHidden = @(...) !::has_feature("Benchmark") && !::is_dev_version
    isInactiveInQueue = true
  }
  USER_MISSION = {
    text = "#mainmenu/btnUserMission"
    onClickFunc = @(obj, handler) ::checkAndCreateGamemodeWnd(handler, ::GM_USER_MISSION)
    isHidden = @(...) !::has_feature("UserMissions")
    isInactiveInQueue = true
  }
  OPTIONS = {
    text = "#mainmenu/btnGameplay"
    onClickFunc = @(obj, handler) ::gui_start_options(handler)
  }
  CONTROLS = {
    text = "#mainmenu/btnControls"
    onClickFunc = @(...) ::gui_start_controls()
  }
  LEADERBOARDS = {
    text = "#mainmenu/btnLeaderboards"
    onClickFunc = @(obj, handler) handler.goForwardIfOnline(::gui_modal_leaderboards, false, true)
  }
  CLANS = {
    text = "#mainmenu/btnClans"
    onClickFunc = @(...) ::has_feature("Clans")? ::gui_modal_clans() : ::show_not_available_msg_box()
    isHidden = @(...) !::has_feature("Clans")
  }
  REPLAY = {
    text = "#mainmenu/btnReplays"
    onClickFunc = @(obj, handler) ::is_platform_ps4? ::show_not_available_msg_box() : handler.checkedNewFlight(::gui_start_replays)
    isHidden = @(...) !::has_feature("Replays")
  }
  VIRAL_AQUISITION = {
    text = "#mainmenu/btnGetLink"
    onClickFunc = @(...) ::show_viral_acquisition_wnd()
    isHidden = @(...) !::has_feature("Invites")
  }
  EXIT = {
    text = "#mainmenu/btnExit"
    onClickFunc = function(...) {
      ::add_msg_box("topmenu_question_quit_game", ::loc("mainmenu/questionQuitGame"),
        [
          ["yes", ::exit_game],
          ["no", @() null ]
        ], "no", { cancel_fn = @() null })
    }
    isHidden = @(...) !::is_platform_pc
  }
  DEBUG_UNLOCK = {
    text = "#mainmenu/btnDebugUnlock"
    onClickFunc = @(obj, handler) ::add_msg_box("debug unlock", "Debug unlock enabled", [["ok", ::gui_do_debug_unlock]], "ok")
    isHidden = @(...) !::is_dev_version
  }
  ENCYCLOPEDIA = {
    text = "#mainmenu/btnEncyclopedia"
    onClickFunc = @(...) ::gui_start_encyclopedia()
    isHidden = @(...) !::has_feature("Encyclopedia")
  }
  CREDITS = {
    text = "#mainmenu/btnCredits"
    onClickFunc = @(obj, handler) handler.checkedForward(::gui_start_credits)
    isHidden = @(handler = null) !::has_feature("Credits") || !(handler && handler instanceof ::gui_handlers.TopMenu)
  }
  TSS = {
    text = "#topmenu/tss"
    onClickFunc = @(obj, handler) ::g_url.openByObj(obj, true)
    isDelayed = false
    link = "#url/tss"
    isLink = @() true
    isHidden = @(...) !::has_feature("AllowExternalLink") || ::is_vendor_tencent()
  }
  STREAMS_AND_REPLAYS = {
    text = "#topmenu/streamsAndReplays"
    onClickFunc = @(obj, handler) ::g_url.openByObj(obj, true)
    isDelayed = false
    link = "#url/streamsAndReplays"
    isLink = @() true
    isHidden = @(...) !::has_feature("AllowExternalLink") || ::is_vendor_tencent()
  }
  EAGLES = {
    text = "#charServer/chapter/eagles"
    onClickFunc = @(obj, handler) ::has_feature("EnableGoldPurchase")
      ? handler.startOnlineShop("eagles")
      : ::showInfoMsgBox(::loc("msgbox/notAvailbleGoldPurchase"))
    image = "#ui/gameuiskin#shop_warpoints_premium"
    needDiscountIcon = true
    isHidden = @(...) !::has_feature("SpendGold") || !::isInMenu()
  }
  PREMIUM = {
    text = "#charServer/chapter/premium"
    onClickFunc = @(obj, handler) handler.startOnlineShop("premium")
    image = "#ui/gameuiskin#sub_premiumaccount"
    needDiscountIcon = true
    isHidden = @(...) !::has_feature("EnablePremiumPurchase") || !::isInMenu()
  }
  WARPOINTS = {
    text = "#charServer/chapter/warpoints"
    onClickFunc = @(obj, handler) handler.startOnlineShop("warpoints")
    image = "#ui/gameuiskin#shop_warpoints"
    needDiscountIcon = true
    isHidden = @(...) !::has_feature("SpendGold") || !::isInMenu()
  }
  INVENTORY = {
    text = "#items/inventory"
    onClickFunc = @(...) ::gui_start_inventory()
    image = "#ui/gameuiskin#inventory_icon"
    isHidden = @(...) !::ItemsManager.isEnabled() || !::isInMenu()
    unseenIcon = @() SEEN.INVENTORY
  }
  ITEMS_SHOP = {
    text = "#items/shop"
    onClickFunc = @(...) ::gui_start_itemsShop()
    image = "#ui/gameuiskin#store_icon.svg"
    isHidden = @(...) !::ItemsManager.isEnabled() || !::isInMenu() || !::has_feature("ItemsShopInTopMenu")
    unseenIcon = @() SEEN.ITEMS_SHOP
  }
  WARBONDS_SHOP = {
    text = "#mainmenu/btnWarbondsShop"
    onClickFunc = @(...) ::g_warbonds.openShop()
    image = "#ui/gameuiskin#wb.svg"
    isHidden = @(...) !::g_battle_tasks.isAvailableForUser()
      || !::g_warbonds.isShopAvailable()
      || !::isInMenu()
    unseenIcon = @() SEEN.WARBONDS_SHOP
  }
  ONLINE_SHOP = {
    text = @() xboxShopData.canUseIngameShop()? "#topmenu/xboxIngameShop" : "#msgbox/btn_onlineShop"
    onClickFunc = @(obj, handler) handler.startOnlineShop()
    link = ""
    isLink = @() !xboxShopData.canUseIngameShop()
    isFeatured = @() !xboxShopData.canUseIngameShop()
    image = @() xboxShopData.canUseIngameShop()? "#ui/gameuiskin#xbox_store_icon.svg" : "#ui/gameuiskin#store_icon.svg"
    needDiscountIcon = true
    isHidden = @(...) !::has_feature("SpendGold") || !::isInMenu()
    unseenIcon = @() SEEN.EXT_XBOX_SHOP
  }
  MARKETPLACE = {
    text = "#mainmenu/marketplace"
    onClickFunc = @(obj, handler) ::ItemsManager.goToMarketplace()
    link = ""
    isLink = @() true
    isFeatured = @() true
    image = "#ui/gameuiskin#gc.svg"
    isHidden = @(...) !::ItemsManager.isMarketplaceEnabled() || !::isInMenu()
  }
  WINDOW_HELP = {
    text = "#flightmenu/btnControlsHelp"
    onClickFunc = function(obj, handler) {
      if (!("getWndHelpConfig" in handler))
        return

      ::gui_handlers.HelpInfoHandlerModal.open(handler.getWndHelpConfig(), handler.scene)
    }
    isHidden = @(handler = null) !("getWndHelpConfig" in handler)
  }
  FAQ = {
    text = "#mainmenu/faq"
    onClickFunc = @(obj, handler) ::g_url.openByObj(obj)
    isDelayed = false
    link = "#url/faq"
    isLink = @() true
    isFeatured = @() true
    isHidden = @(...) !::has_feature("AllowExternalLink") || ::is_vendor_tencent() || !::isInMenu()
  }
  FORUM = {
    text = "#mainmenu/forum"
    onClickFunc = @(obj, handler) ::g_url.openByObj(obj)
    isDelayed = false
    link = "#url/forum"
    isLink = @() true
    isFeatured = @() true
    isHidden = @(...) !::has_feature("AllowExternalLink") || ::is_vendor_tencent() || !::isInMenu()
  }
  SUPPORT = {
    text = "#mainmenu/support"
    onClickFunc = @(obj, handler) ::g_url.openByObj(obj)
    isDelayed = false
    link = "#url/support"
    isLink = @() true
    isFeatured = @() true
    isHidden = @(...) !::has_feature("AllowExternalLink") || ::is_vendor_tencent() || !::isInMenu()
  }
  WIKI = {
    text = "#mainmenu/wiki"
    onClickFunc = @(obj, handler) ::g_url.openByObj(obj)
    isDelayed = false
    link = "#url/wiki"
    isLink = @() true
    isFeatured = @() true
    isHidden = @(...) !::has_feature("AllowExternalLink") || ::is_vendor_tencent() || !::isInMenu()
  }
  EULA = {
    text = "#mainmenu/licenseAgreement"
    onClickFunc = @(obj, handler) ::gui_start_eula(::TEXT_EULA, true)
    isDelayed = false
    isHidden = @(...) !::isInMenu()
  }
  EMPTY = {
    elementType = TOP_MENU_ELEMENT_TYPE.EMPTY_BUTTON
  }
  LINE_SEPARATOR = {
    elementType = TOP_MENU_ELEMENT_TYPE.LINE_SEPARATOR
  }
},
function() {
  id = typeName.tolower()
},
"typeName")

function g_top_menu_buttons::getTypeById(id)
{
  return enums.getCachedType("id", id, ::g_top_menu_buttons.cache.byId,
    ::g_top_menu_buttons, ::g_top_menu_buttons.UNKNOWN)
}