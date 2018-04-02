local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
/*
 * Search in price.blk:
 * Search parapm is a table of request fields
 * Return an array of entitlements names
 * The result of search will satisfy each condition
 * in request (using && statement)
 * Supported conditions:
 *  - unitName
 *
 * API:
 *
 *  showGoods(searchRequest)
 *    Find goods and open it in store
 *    ---
 *    This function should be moved to onlineShop handler,
 *    but this required refactioring in this handler
 *    ---
 * */

OnlineShopModel <- {
  priceBlk = null
  purchaseDataCache = {}
  entitlemetsUpdaterWeak = null
}

/*API methods*/
function OnlineShopModel::showGoods(searchRequest)
{
  if (!::has_feature("OnlineShopPacks"))
    return ::showInfoMsgBox(::loc("msgbox/notAvailbleYet"))

  if (searchRequest?.unitName)
  {
    local customUrl = ::loc("url/custom_purchase/unit", searchRequest, "")
    if (customUrl.len())
      return openShopUrl(customUrl)
  }

  if (::is_ps4_or_xbox)
    return launchPS4Store() || launchXboxMarketplace()

  __assyncActionWrap(function ()
    {
      local searchResult = __searchEntitlement(searchRequest)
      foreach (goodsName in searchResult)
        if (getGuidForGoods(goodsName) != "")
          return doBrowserPurchase(goodsName)

      return ::gui_modal_onlineShop()
    }.bindenv(OnlineShopModel))
}
/*end API methods*/

function OnlineShopModel::invalidatePriceBlk()
{
  priceBlk = null
  purchaseDataCache.clear()
}

function OnlineShopModel::validatePriceBlk()
{
  if (priceBlk)
    return
  priceBlk = ::DataBlock()
  ::get_shop_prices(priceBlk)
}

function OnlineShopModel::getPriceBlk()
{
  validatePriceBlk()
  return priceBlk
}

//Check is price.blk is fresh and perform an action.
//If prise.blk is rotten, upfate price.blk and then perform action.
function OnlineShopModel::__assyncActionWrap(action)
{
  local isActual = ::configs.ENTITLEMENTS_PRICE.checkUpdate(
    ::Callback((@(action) function () {
      action && action()
    })(action), this)
    null,
    true,
    false
  )

  if (isActual)
    action()
}

function OnlineShopModel::onEventEntitlementsPriceUpdated(p)
{
  invalidatePriceBlk()
}

function OnlineShopModel::onEventSignOut(p)
{
  invalidatePriceBlk()
}

function OnlineShopModel::getGoodsByName(goodsName)
{
  return ::getTblValue(goodsName, getPriceBlk())
}

function OnlineShopModel::isEntitlement(name)
{
  if (typeof name == "string")
    return name in getPriceBlk()
  return false
}

function OnlineShopModel::__searchEntitlement(searchRequest)
{
  local result = []
  if (!searchRequest || typeof searchRequest != "table")
    return result

  foreach (name, ib in getPriceBlk())
  {
    if (ib.hideWhenUnbought && !::has_entitlement(name))
      continue
    if ("unitName" in searchRequest)
      foreach (unitName in ib % "aircraftGift")
        if (unitName == searchRequest.unitName)
          result.append(name)
  }
  return result
}

function OnlineShopModel::getGuidForGoods(goodsName)
{
  return ::loc("guid/" + goodsName, "")
}

function OnlineShopModel::getCustomPurchaseLink(goodsName)
{
  return ::loc("customPurchaseLink/" + goodsName, "")
}

/*
  search first available entitlemnt to purchase to get current entitlement.by name
  _res - internal parametr - do not use from outside

  return {
    canBePurchased = (bool)
    guid = (string) or null
    customPurchaseLink = (string) or null
    sourceEntitlement =  (string)   - entitlement which need to buy to get requested entitlement
  }
*/
OnlineShopModel._purchaseDataRecursion <- 0
function OnlineShopModel::getPurchaseData(goodsName)
{
  if (goodsName in purchaseDataCache)
    return purchaseDataCache[goodsName]

  if (_purchaseDataRecursion > 10)
  {
    local msg = "OnlineShopModel: getPurchaseData: found recursion for " + goodsName
    ::script_net_assert_once("getPurchaseData recursion", msg)
    return createPurchaseData(goodsName)
  }

  local customPurchaseLink = getCustomPurchaseLink(goodsName)
  if (!::u.isEmpty(customPurchaseLink))
    return createPurchaseData(goodsName, null, customPurchaseLink)

  local guid = getGuidForGoods(goodsName)
  if (!::u.isEmpty(guid))
    return createPurchaseData(goodsName, guid)

  _purchaseDataRecursion++
  //search in gifts or fingerPrints
  local res = null
  foreach(entitlement, blk in getPriceBlk())
  {
    if (!::isInArray(goodsName, blk % "entitlementGift")
        && !::isInArray(goodsName, blk % "fingerprintController"))
      continue

    local purchData = getPurchaseData(entitlement)
    if (!purchData.canBePurchased)
      continue

    res = purchData
    purchaseDataCache[goodsName] <- res
    break
  }

  _purchaseDataRecursion--
  return res || createPurchaseData(goodsName)
}

function OnlineShopModel::createPurchaseData(goodsName = "", guid = null, customPurchaseLink = null)
{
  local res = {
    canBePurchased = !!(guid || customPurchaseLink)
    guid = guid
    customPurchaseLink = customPurchaseLink
    sourceEntitlement = goodsName
    openBrowser = function () { return ::OnlineShopModel.openBrowserByPurchaseData(this) }
  }
  if (goodsName != "")
      purchaseDataCache[goodsName] <- res
  return res
}

//return purchaseData (look getPurchaseData) of first found entitlement which can be purchased.
// or empty purchase data
function OnlineShopModel::getFeaturePurchaseData(feature)
{
  local res = null
  foreach(entitlement in ::get_entitlements_by_feature(feature))
  {
    res = getPurchaseData(entitlement)
    if (res.canBePurchased)
      return res
  }
  return res || createPurchaseData()
}

//return purchaseDatas (look getPurchaseData) of all entitlements which can be purchased.
// or empty array
function OnlineShopModel::getAllFeaturePurchases(feature)
{
  local res = []
  foreach(entitlement in ::get_entitlements_by_feature(feature))
  {
    local purchase = getPurchaseData(entitlement)
    if (purchase.canBePurchased)
      res.push(purchase)
  }
  return res
}

function OnlineShopModel::openBrowserForFirstFoundEntitlement(entitlementsList)
{
  foreach(entitlement in entitlementsList)
  {
    local purchase = getPurchaseData(entitlement)
    if (purchase.canBePurchased)
    {
      openBrowserByPurchaseData(purchase)
      break
    }
  }
}

function OnlineShopModel::openBrowserByPurchaseData(purchaseData)
{
  if (!purchaseData.canBePurchased)
    return false

  if (::is_ps4_or_xbox)
    return launchPS4Store() || launchXboxMarketplace()

  if (purchaseData.customPurchaseLink)
  {
    openShopUrl(purchaseData.customPurchaseLink)
    return true
  }
  local customPurchaseUrl = getCustomPurchaseUrl(getGoodsChapter(purchaseData.sourceEntitlement))
  if ( ! ::u.isEmpty(customPurchaseUrl))
  {
    openShopUrl(customPurchaseUrl)
    return true
  }
  if (purchaseData.guid)
  {
    doBrowserPurchaseByGuid(purchaseData.guid, purchaseData.sourceEntitlement)
    return true
  }
  return false
}

function OnlineShopModel::doBrowserPurchase(goodsName)
{
  if (::is_ps4_or_xbox)
    return launchPS4Store() || launchXboxMarketplace()
  //just to avoid bugs, when users, who should to purchase goods in regional
  //web shops, accidentally uses ingame online shop
  local customUrl = getCustomPurchaseUrl(getGoodsChapter(goodsName))
  if (customUrl != "")
  {
    openShopUrl(customUrl)
    return
  }
  doBrowserPurchaseByGuid(getGuidForGoods(goodsName))
}

function OnlineShopModel::doBrowserPurchaseByGuid(guid, dbgGoodsName = "")
{
  if (::steam_is_running()) //temporary use old code pass for steam
  {
    local response = ::shell_purchase_in_browser(guid);
    if (response > 0)
    {
      local errorText = ::get_yu2_error_text(response)
      ::showInfoMsgBox(errorText, "errorMessageBox")
      dagor.debug("shell_purchase_in_browser have returned " + response + " with guid/" + dbgGoodsName)
    }
    return
  }

  local url = ::get_authenticated_url_for_purchase(guid)

  if (url == "")
  {
    ::showInfoMsgBox(::loc("browser/purchase_url_not_found"), "errorMessageBox")
    dagor.debug("get_authenticated_url_for_purchase have returned empty url for guid/" + dbgGoodsName)
    return
  }

  openShopUrl(url, true)
}

function OnlineShopModel::getGoodsChapter(goodsName)
{
  local goods = getGoodsByName(goodsName)
  return "chapter" in goods ? goods.chapter : ""
}

//Get custom URL for purchase goods from regional stores
//if returns "" uses default store.
//custom URLs are defined for particular languages and almost always are ""
//Consoles are exception. They always uses It's store.
function OnlineShopModel::getCustomPurchaseUrl(chapter)
{
  if (::is_ps4_or_xbox)
    return ""

  local circuit = ::get_cur_circuit_name()
  local locParams = {
    userId = ::my_user_id_str
    circuit = circuit
    circuitTencentId = ::getTblValue("circuitTencentId", ::get_network_block()[circuit], circuit)
  }
  local locIdPrefix = ::is_platform_shield_tv()
    ? "url/custom_purchase_shield_tv"
    : "url/custom_purchase"
  if (chapter == "eagles")
    return ::loc(locIdPrefix + "/eagles", locParams)
  if (!::isInArray(chapter, ["hidden", "premium", "eagles", "warpoints"]))
    return ::loc(locIdPrefix, locParams)
  return ""
}

function OnlineShopModel::openShopUrl(baseUrl, isAlreadyAuthenticated = false)
{
  ::open_url(baseUrl, false, isAlreadyAuthenticated, "shop_window")
  startEntitlementsUpdater()
}

//return true when custom Url found
function OnlineShopModel::checkAndOpenCustomPurchaseUrl(chapter, needMsgBox = false)
{
  local customUrl = getCustomPurchaseUrl(chapter)
  if (customUrl == "")
    return false

  if (::has_feature("ManuallyUpdateBalance"))
  {
    openUpdateBalanceMenu(customUrl)
    return true
  }

  if (!needMsgBox)
    openShopUrl(customUrl)
  else
    ::scene_msg_box("onlineShop_buy_" + chapter, null,
      ::loc("charServer/web_recharge"),
      [["ok", (@(customUrl) function() { ::OnlineShopModel.openShopUrl(customUrl) })(customUrl) ],
       ["cancel", function() {} ]
      ],
      "ok",
      { cancel_fn = function() {}}
    )

  return true
}

function OnlineShopModel::openUpdateBalanceMenu(customUrl)
{
  local menu = [
    {
      text = ::loc("charServer/btn/web_recharge")
      action = (@(customUrl) function() { openShopUrl(customUrl) })(customUrl)
    }
    {
      text = ""
      action = ::update_entitlements_limited
      onUpdateButton = function(p)
      {
        local refreshText = ::loc("charServer/btn/refresh_balance")
        local updateTimeout = ::get_update_entitlements_timeout_msec()
        local enable = updateTimeout <= 0
        if (!enable)
          refreshText += ::loc("ui/parentheses/space", { text = ::ceil(0.001 * updateTimeout) })
        return {
          text = refreshText
          enable = enable
          stopUpdate = enable
        }
      }
    }
  ]
  ::gui_right_click_menu(menu, this)
}

function OnlineShopModel::startEntitlementsUpdater()
{
  if (entitlemetsUpdaterWeak)
    return

  local handler = ::handlersManager.getActiveBaseHandler()
  if (!handler)
    return

  entitlemetsUpdaterWeak = SecondsUpdater(
    handler.scene,
    function(obj, params)
    {
      local wasActive = ::getTblValue("active", params, true)
      local isActive = ::is_app_active() && !::steam_is_overlay_active() && !::is_builtin_browser_active()
      if (wasActive == isActive)
        return false

      if (!isActive)
      {
        params.active <- false
        return false
      }
      if (::is_online_available())
        ::g_tasker.addTask(::update_entitlements_limited(),
                           {
                             showProgressBox = true
                             progressBoxText = ::loc("charServer/checking")
                           })
      return true
    }
    false
  ).weakref()
}

function OnlineShopModel::launchOnlineShop(owner=null, chapter=null, afterCloseFunc=null)
{
  if (!::isInMenu())
    return

  if (launchPS4Store(chapter))
    return

  if (launchXboxMarketplace(chapter))
    return

  ::gui_modal_onlineShop(owner, chapter, afterCloseFunc)
}

function OnlineShopModel::launchPS4Store(chapter = null)
{
  if (::is_platform_ps4 && ::isInArray(chapter, [null, "", "eagles"]))
  {
    ::queues.checkAndStart(@() ::launch_ps4_store_by_chapter(chapter),
      null, "isCanUseOnlineShop")
    return true
  }
  return false
}

function OnlineShopModel::launchXboxMarketplace(chapter = null)
{
  if (::is_platform_xboxone && ::isInArray(chapter, [null, "", "eagles"]))
  {
    ::queues.checkAndStart(@() ::launch_xbox_one_store_by_chapter(chapter),
      null, "isCanUseOnlineShop")
    return true
  }
  return false
}

//                                                                            //
////////////////////////////////////////////////////////////////////////////////
//                                                                            //

function get_entitlement_config(name)
{
  local res = { name = name }

  local pblk = ::DataBlock()
  ::get_shop_prices(pblk)
  if (pblk[name] != null)
  {
    foreach(param in ["ttl", "httl", "onlinePurchase", "wpIncome", "goldIncome", "goldIncomeFirstBuy",
                      "group", "useGroupAmount", "image", "chapterImage",
                      "aircraftGift", "alias", "chapter", "goldDiscount", "goldCost"])
      if (pblk[name][param]!=null && !(param in res))
        res[param] <- pblk[name][param]
  }
  return res
}

function get_entitlement_locId(item)
{
  return ("alias" in item) ? item.alias : ("group" in item) ? item.group : item.name
}

function get_entitlement_name(item)
{
  local name = ""
  if (("useGroupAmount" in item) && item.useGroupAmount && ("group" in item))
  {
    name = ::loc("charServer/entitlement/" + item.group)
    local amountStr = ::g_language.decimalFormat(::get_entitlement_amount(item))
    if(name.find("%d") != null)
      name = ::stringReplace(name, "%d", amountStr)
    else
      name = ::loc("charServer/entitlement/" + item.group, {amount = amountStr})
  }
  else
    name = ::loc("charServer/entitlement/" + ::get_entitlement_locId(item))

  local timeText = ::get_entitlement_timeText(item)
  if (timeText!="")
    name += " " + timeText
  return name
}

function get_entitlement_amount(item)
{
  if ("httl" in item)
    return item.httl.tofloat() / 24.0

  foreach(n in ["ttl", "wpIncome", "goldIncome"])
    if ((n in item) && item[n] > 0)
      return item[n]

  return 1
}

function get_first_purchase_additional_amount(item)
{
  if (!::has_entitlement(item.name))
    return ::getTblValue("goldIncomeFirstBuy", item, 0)

  return 0
}

function get_entitlement_timeText(item)
{
  if ("ttl" in item)
    return item.ttl + ::loc("measureUnits/days")
  if ("httl" in item)
    return item.httl + ::loc("measureUnits/hours")
  return ""
}

function get_entitlement_price(item)
{
  if (("onlinePurchase" in item) && item.onlinePurchase)
  {
    local priceText = ::loc("price/"+item.name, "")

    if (priceText != "")
    {
      local markup = ::steam_is_running() ? 1.0 + getSteamMarkUp()/100.0 : 1.0
      local totalPrice = priceText.tofloat() * markup
      local discount = ::getTblValue(item.name, ::visibleDiscountNotifications.entitlements, 0)
      if (discount)
        totalPrice -= totalPrice * discount * 0.01

      return format(::loc("price/common"), ::g_language.decimalFormat(totalPrice))
    }
  }
  else if ("goldCost" in item)
    return ::Cost(0, ::get_entitlement_cost_gold(item.name)).tostring()
  return ""
}

function update_purchases_return_mainmenu()
{
  local taskId = ::update_entitlements()
  if (taskId >= 0)
  {
    local progressBox = ::scene_msg_box("char_connecting", null, ::loc("charServer/checking"), null, null)
    ::add_bg_task_cb(taskId, (@(progressBox) function() {
      ::destroyMsgBox(progressBox)
      ::gui_start_mainmenu_reload()
    })(progressBox))
  }
}

function gui_modal_onlineShop(owner=null, chapter=null, afterCloseFunc=null)
{
  if (::OnlineShopModel.checkAndOpenCustomPurchaseUrl(chapter, true))
    return

  if (::isInArray(chapter, [null, ""]))
  {
    local webStoreUrl = ::loc("url/webstore", "")
    if (::steam_is_running())
      webStoreUrl = ::format(::loc("url/webstore/steam"), ::steam_get_my_id())

    if (webStoreUrl != "")
      return ::OnlineShopModel.openShopUrl(webStoreUrl)
  }

  local useRowVisual = chapter != null && ::isInArray(chapter, ["premium", "eagles", "warpoints"])
  local hClass = useRowVisual? ::gui_handlers.OnlineShopRowHandler : ::gui_handlers.OnlineShopHandler
  local prevShopHandler = ::handlersManager.findHandlerClassInScene(hClass)
  if (prevShopHandler)
  {
    if (!afterCloseFunc)
    {
      afterCloseFunc = prevShopHandler.afterCloseFunc
      prevShopHandler.afterCloseFunc = null
    }
    if (prevShopHandler.scene.getModalCounter() != 0)
      ::handlersManager.destroyModal(prevShopHandler)
  }

  ::gui_start_modal_wnd(hClass, { owner = owner, afterCloseFunc = afterCloseFunc, chapter = chapter })
}

function launch_ps4_store_by_chapter(chapter)
{
  if (chapter == null || chapter == "")
  {
    //TODO: items shop
    if (::ps4_open_store("WARTHUNDERAPACKS", false) >= 0)
      ::update_purchases_return_mainmenu()
  }
  else if (chapter == "eagles")
  {
    if (::ps4_open_store("WARTHUNDEREAGLES", false) >= 0)
      ::update_purchases_return_mainmenu()
  }
}

function launch_xbox_one_store_by_chapter(chapter)
{
  ::xbox_show_marketplace(chapter == "eagles");
}

::subscribe_handler(::OnlineShopModel, ::g_listener_priority.CONFIG_VALIDATION)

function xbox_on_purchases_updated()
{
  if (::is_online_available())
    ::g_tasker.addTask(::update_entitlements_limited(),
                        {
                          showProgressBox = true
                          progressBoxText = ::loc("charServer/checking")
                        })
}
