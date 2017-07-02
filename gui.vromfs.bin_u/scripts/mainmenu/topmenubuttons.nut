::g_top_menu_buttons <- {
  types = []

  template = {
    id = "unknown"
    text = ""
    image = null
    link = null
    isLink = false
    isFeatured = false
    needDiscountIcon = false
    newIconWidget = null
    funcName = null
    isHidden = function(handler = null) { return false }
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
    isHidden = function(handler = null) { return !::is_custom_battles_enabled() }
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
    isHidden = function(handler = null) { return !::has_feature("HistoricalCampaign") }
    isVisualDisabled = function() { return !::ps4_is_chunk_available(PS4_CHUNK_HISTORICAL_CAMPAIGN) }
    isInactiveInQueue = true
  }
  BENCHMARK = {
    id = "benchmark"
    text = "#mainmenu/btnBenchmark"
    funcName = "onBenchmark"
    isHidden = function(handler = null) {
      return (::is_platform_ps4 ? !::has_feature("BenchmarkPS4") : !::has_feature("Benchmark")) && !::is_dev_version
    }
    isInactiveInQueue = true
  }
  USER_MISSION = {
    id = "UserMission"
    text = "#mainmenu/btnUserMission"
    funcName = "onUserMission"
    isHidden = function(handler = null) { return !::has_feature("UserMissions") }
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
    isHidden = function(handler = null) { return !::has_feature("Clans") }
  }
  REPLAY = {
    id = "replays"
    text = "#mainmenu/btnReplays"
    funcName = "onReplays"
    isHidden = function(handler = null) { return !::has_feature("Replays") }
  }
  VIRAL_AQUISITION = {
    id = "getLink"
    text = "#mainmenu/btnGetLink"
    funcName = "onGetLink"
    isHidden = function(handler = null) { return !::has_feature("Invites") }
  }
  EXIT = {
    id = "exit"
    text = "#mainmenu/btnExit"
    funcName = "onExit"
    isHidden = function(handler = null) { return ::is_platform_ps4}
  }
  DEBUG_UNLOCK = {
    id = "debugUnlock"
    text = "#mainmenu/btnDebugUnlock"
    funcName = "onDebugUnlock"
    isHidden = function(handler = null) { return !::is_dev_version}
  }
  ENCYCLOPEDIA = {
    id = "encyclopedia"
    text = "#mainmenu/btnEncyclopedia"
    funcName = "onEncyclopedia"
    isHidden = function(handler = null) { return !::has_feature("Encyclopedia") }
  }
  CREDITS = {
    id = "credits"
    text = "#mainmenu/btnCredits"
    funcName = "onCredits"
    isHidden = function(handler = null) {
      return !::has_feature("Credits")
             || !(handler && handler instanceof ::gui_handlers.TopMenu)
    }
  }
  TSS = {
    id = "tssLink"
    text = "#topmenu/tss"
    funcName = "onLink"
    link = "#url/tss"
    isLink = true
    isHidden = function(handler = null) { return ::is_vendor_tencent() }
  }
  STREAMS_AND_REPLAYS = {
    id = "streamsAndReplaysLink"
    text = "#topmenu/streamsAndReplays"
    funcName = "onLink"
    link = "#url/streamsAndReplays"
    isLink = true
    isHidden = function(handler = null) { return ::is_vendor_tencent() }
  }
  EAGLES = {
    id = "eagles"
    text = "#shop/recharge"
    funcName = "onOnlineShopEagles"
    image = "#ui/gameuiskin#shop_warpoints_premium"
    needDiscountIcon = true
    isHidden = function(handler = null) { return !::has_feature("SpendGold") || !::isInMenu() }
  }
  PREMIUM = {
    id = "premium"
    text = "#charServer/chapter/premium"
    funcName = "onOnlineShopPremium"
    image = "#ui/gameuiskin#sub_premiumaccount"
    needDiscountIcon = true
    isHidden = function(handler = null) { return !::has_feature("EnablePremiumPurchase") || !::isInMenu() }
  }
  WARPOINTS = {
    id = "warpoints"
    text = "#charServer/chapter/warpoints"
    funcName = "onOnlineShopLions"
    image = "#ui/gameuiskin#shop_warpoints"
    needDiscountIcon = true
    isHidden = function(handler = null) { return !::has_feature("SpendGold") || !::isInMenu() }
  }
  INVENTORY = {
    id = "inventory"
    text = "#items/inventory"
    funcName = "onInventory"
    image = "#ui/gameuiskin#inventory_icon"
    isHidden = function(handler = null) { return !::ItemsManager.isEnabled() || !::isInMenu() }
    newIconWidget = function() { return ::NewIconWidget.createLayout() }
  }
  ITEMS_SHOP = {
    id = "items_shop"
    text = "#items/shop"
    funcName = "onItemsShop"
    image = "#ui/gameuiskin#store_icon"
    isHidden = function(handler = null) { return !::ItemsManager.isEnabled() || !::isInMenu() }
    newIconWidget = function() { return ::NewIconWidget.createLayout() }
  }
  ONLINE_SHOP = {
    id = "shop"
    text = "#msgbox/btn_onlineShop"
    funcName = "onOnlineShop"
    link = ""
    isLink = true
    isFeatured = true
    image = "#ui/gameuiskin#store_icon"
    needDiscountIcon = true
    isHidden = function(handler = null) { return !::has_feature("SpendGold") || !::isInMenu() }
  }
  WINDOW_HELP = {
    id = "window_help"
    text = "#flightmenu/btnControlsHelp"
    funcName = "onWndHelp"
    isHidden = function(handler = null) { return !("getWndHelpConfig" in handler) }
  }
  FAQ = {
    id = "faq"
    text = "#mainmenu/faq"
    funcName = "onLink"
    link = "#url/faq"
    isLink = true
    isFeatured = true
    isHidden = function(handler = null) { return ::is_vendor_tencent() || !::isInMenu() }
  }
  FORUM = {
    id = "forum"
    text = "#mainmenu/forum"
    funcName = "onLink"
    link = "#url/forum"
    isLink = true
    isFeatured = true
    isHidden = function(handler = null) { return ::is_vendor_tencent() || !::isInMenu() }
  }
  SUPPORT = {
    id = "support"
    text = "#mainmenu/support"
    funcName = "onLink"
    link = "#url/support"
    isLink = true
    isFeatured = true
    isHidden = function(handler = null) { return ::is_vendor_tencent() || !::isInMenu() }
  }
  WIKI = {
    id = "wiki"
    text = "#mainmenu/wiki"
    funcName = "onLink"
    link = "#url/wiki"
    isLink = true
    isFeatured = true
    isHidden = function(handler = null) { return ::is_vendor_tencent() || !::isInMenu() }
  }
  EMPTY = {
    isEmptyButton = true
  }
  LINE_SEPARATOR = {
    isLineSeparator = true
  }
  WW_OPERATIONS = {
    id = "ww_operations"
    text = "#worldWar/menu/selectOperation"
    funcName = "onWWBackToOperations"
    isVisualDisabled = function() { return !::is_worldwar_enabled() }
  }
  HANGAR = {
    id = "hangar"
    text = "#worldWar/menu/quitToHangar"
    funcName = "onWWBackToHangar"
    isVisualDisabled = function() { return !::is_worldwar_enabled() }
  }
}, null, "name")
