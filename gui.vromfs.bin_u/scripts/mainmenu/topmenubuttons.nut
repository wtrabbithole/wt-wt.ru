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
    text = ""
    image = null
    link = null
    isLink = false
    isFeatured = false
    needDiscountIcon = false
    newIconWidget = null
    funcName = null
    onChangeValueFunc = @(value) null
    onChangeValue = "onChangeCheckboxValue"
    useImage = null
    isHidden = @(handler = null) false
    isVisualDisabled = @() false
    isInactiveInQueue = false
    elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
    isButton = @() elementType == TOP_MENU_ELEMENT_TYPE.BUTTON
    checkbox = @() elementType == TOP_MENU_ELEMENT_TYPE.CHECKBOX //param name only because of checkbox.tpl
    isLineSeparator = @() elementType == TOP_MENU_ELEMENT_TYPE.LINE_SEPARATOR
    isEmptyButton = @() elementType == TOP_MENU_ELEMENT_TYPE.EMPTY_BUTTON
  }
}

::g_enum_utils.addTypesByGlobalName("g_top_menu_buttons", {
  UNKNOWN = {}
  SKIRMISH = {
    text = "#mainmenu/btnSkirmish"
    funcName = "onSkirmish"
    isHidden = @(...) !::is_custom_battles_enabled()
    isVisualDisabled = function() { return !::is_custom_battles_enabled() }
    isInactiveInQueue = true
  }
  WORLDWAR = {
    text = "#mainmenu/btnWorldwar"
    funcName = "onWorldwar"
    isVisualDisabled = function() { return !::is_worldwar_enabled() }
  }
  TUTORIAL = {
    text = "#mainmenu/btnTutorial"
    funcName = "onTutorial"
    isInactiveInQueue = true
  }
  SINGLE_MISSION = {
    text = "#mainmenu/btnSingleMission"
    funcName = "onSingleMission"
    isVisualDisabled = function() {return !::has_feature("ModeSingleMissions") }
    isInactiveInQueue = true
  }
  DYNAMIC = {
    text = "#mainmenu/btnDynamic"
    funcName = "onDynamic"
    isVisualDisabled = function() {return !::has_feature("ModeDynamic") }
    isInactiveInQueue = true
  }
  CAMPAIGN = {
    text = "#mainmenu/btnCampaign"
    funcName = "onCampaign"
    isHidden = @(...) !::has_feature("HistoricalCampaign")
    isVisualDisabled = function() { return !::ps4_is_chunk_available(PS4_CHUNK_HISTORICAL_CAMPAIGN) }
    isInactiveInQueue = true
  }
  BENCHMARK = {
    text = "#mainmenu/btnBenchmark"
    funcName = "onBenchmark"
    isHidden = @(...) (::is_platform_ps4 ? !::has_feature("BenchmarkPS4") : !::has_feature("Benchmark")) && !::is_dev_version
    isInactiveInQueue = true
  }
  USER_MISSION = {
    text = "#mainmenu/btnUserMission"
    funcName = "onUserMission"
    isHidden = @(...) !::has_feature("UserMissions")
    isInactiveInQueue = true
  }
  OPTIONS = {
    text = "#mainmenu/btnGameplay"
    funcName = "onGameplay"
  }
  CONTROLS = {
    text = "#mainmenu/btnControls"
    funcName = "onControls"
  }
  LEADERBOARDS = {
    text = "#mainmenu/btnLeaderboards"
    funcName = "onLeaderboards"
  }
  CLANS = {
    text = "#mainmenu/btnClans"
    funcName = "onClans"
    isHidden = @(...) !::has_feature("Clans")
  }
  REPLAY = {
    text = "#mainmenu/btnReplays"
    funcName = "onReplays"
    isHidden = @(...) !::has_feature("Replays")
  }
  VIRAL_AQUISITION = {
    text = "#mainmenu/btnGetLink"
    funcName = "onGetLink"
    isHidden = @(...) !::has_feature("Invites")
  }
  EXIT = {
    text = "#mainmenu/btnExit"
    funcName = "onExit"
    isHidden = @(...) ::is_platform_ps4
  }
  DEBUG_UNLOCK = {
    text = "#mainmenu/btnDebugUnlock"
    funcName = "onDebugUnlock"
    isHidden = @(...) !::is_dev_version
  }
  ENCYCLOPEDIA = {
    text = "#mainmenu/btnEncyclopedia"
    funcName = "onEncyclopedia"
    isHidden = @(...) !::has_feature("Encyclopedia")
  }
  CREDITS = {
    text = "#mainmenu/btnCredits"
    funcName = "onCredits"
    isHidden = @(handler = null) !::has_feature("Credits") || !(handler && handler instanceof ::gui_handlers.TopMenu)
  }
  TSS = {
    text = "#topmenu/tss"
    funcName = "onLink"
    link = "#url/tss"
    isLink = true
    isHidden = @(...) ::is_vendor_tencent()
  }
  STREAMS_AND_REPLAYS = {
    text = "#topmenu/streamsAndReplays"
    funcName = "onLink"
    link = "#url/streamsAndReplays"
    isLink = true
    isHidden = @(...) ::is_vendor_tencent()
  }
  EAGLES = {
    text = "#shop/recharge"
    funcName = "onOnlineShopEagles"
    image = "#ui/gameuiskin#shop_warpoints_premium"
    needDiscountIcon = true
    isHidden = @(...) !::has_feature("SpendGold") || !::isInMenu()
  }
  PREMIUM = {
    text = "#charServer/chapter/premium"
    funcName = "onOnlineShopPremium"
    image = "#ui/gameuiskin#sub_premiumaccount"
    needDiscountIcon = true
    isHidden = @(...) !::has_feature("EnablePremiumPurchase") || !::isInMenu()
  }
  WARPOINTS = {
    text = "#charServer/chapter/warpoints"
    funcName = "onOnlineShopLions"
    image = "#ui/gameuiskin#shop_warpoints"
    needDiscountIcon = true
    isHidden = @(...) !::has_feature("SpendGold") || !::isInMenu()
  }
  INVENTORY = {
    text = "#items/inventory"
    funcName = "onInventory"
    image = "#ui/gameuiskin#inventory_icon"
    isHidden = @(...) !::ItemsManager.isEnabled() || !::isInMenu()
    newIconWidget = @() ::NewIconWidget.createLayout()
  }
  ITEMS_SHOP = {
    text = "#items/shop"
    funcName = "onItemsShop"
    image = "#ui/gameuiskin#store_icon"
    isHidden = @(...) !::ItemsManager.isEnabled() || !::isInMenu()
    newIconWidget = @() ::NewIconWidget.createLayout()
  }
  ONLINE_SHOP = {
    text = "#msgbox/btn_onlineShop"
    funcName = "onOnlineShop"
    link = ""
    isLink = true
    isFeatured = true
    image = "#ui/gameuiskin#store_icon"
    needDiscountIcon = true
    isHidden = @(...) !::has_feature("SpendGold") || !::isInMenu()
  }
  WINDOW_HELP = {
    text = "#flightmenu/btnControlsHelp"
    funcName = "onWndHelp"
    isHidden = @(handler = null) !("getWndHelpConfig" in handler)
  }
  FAQ = {
    text = "#mainmenu/faq"
    funcName = "onLink"
    link = "#url/faq"
    isLink = true
    isFeatured = true
    isHidden = @(...) ::is_vendor_tencent() || !::isInMenu()
  }
  FORUM = {
    text = "#mainmenu/forum"
    funcName = "onLink"
    link = "#url/forum"
    isLink = true
    isFeatured = true
    isHidden = @(...) ::is_vendor_tencent() || !::isInMenu()
  }
  SUPPORT = {
    text = "#mainmenu/support"
    funcName = "onLink"
    link = "#url/support"
    isLink = true
    isFeatured = true
    isHidden = @(...) ::is_vendor_tencent() || !::isInMenu()
  }
  WIKI = {
    text = "#mainmenu/wiki"
    funcName = "onLink"
    link = "#url/wiki"
    isLink = true
    isFeatured = true
    isHidden = @(...) ::is_vendor_tencent() || !::isInMenu()
  }
  EMPTY = {
    elementType = TOP_MENU_ELEMENT_TYPE.EMPTY_BUTTON
  }
  LINE_SEPARATOR = {
    elementType = TOP_MENU_ELEMENT_TYPE.LINE_SEPARATOR
  }
  WW_OPERATIONS = {
    text = "#worldWar/menu/selectOperation"
    funcName = "onWWBackToOperations"
    isVisualDisabled = function() { return !::is_worldwar_enabled() }
  }
  HANGAR = {
    text = "#worldWar/menu/quitToHangar"
    funcName = "onWWBackToHangar"
    isVisualDisabled = function() { return !::is_worldwar_enabled() }
  }
}, null, "id")

function g_top_menu_buttons::getTypeById(id)
{
  return ::g_enum_utils.getCachedType("id", id, ::g_top_menu_buttons.cache.byId,
    ::g_top_menu_buttons, ::g_top_menu_buttons.UNKNOWN)
}