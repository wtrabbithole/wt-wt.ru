local xboxShop = ::require("scripts/onlineShop/xboxShop.nut")
local platform = ::require("scripts/clientState/platform.nut")
local callbackWhenAppWillActive = require("scripts/clientState/callbackWhenAppWillActive.nut")
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
  callbackReturnFunc = null
}

/*API methods*/
OnlineShopModel.showGoods <- function showGoods(searchRequest)
{
  if (!::has_feature("OnlineShopPacks"))
    return ::showInfoMsgBox(::loc("msgbox/notAvailbleYet"))

  if (searchRequest?.unitName)
  {
    local customUrl = ::loc("url/custom_purchase/unit", searchRequest, "")
    if (customUrl.len())
      return openShopUrl(customUrl)
  }

  __assyncActionWrap(function ()
    {
      local searchResult = searchEntitlement(searchRequest)
      foreach (goodsName in searchResult)
      {
        if (::is_platform_xboxone)
        {
          local xboxId = getXboxIdForGoods(goodsName)
          if (xboxId != "")
            return ::xbox_show_details(xboxId)
        }
        else if (::is_platform_ps4)
        {
          local psnId = getPsnIdForGoods(goodsName)
          if (psnId != "")
          {
            local res = ::ps4_open_store(psnId, true)
            ::g_tasker.addTask(::update_entitlements_limited(true),
              {
                showProgressBox = true
                progressBoxText = ::loc("charServer/checking")
              })
            return res
          }
        }
        else if (getGuidForGoods(goodsName) != "")
          return doBrowserPurchase(goodsName)
      }

      if (::is_platform_xboxone)
        return launchXboxMarketplace()
      else if (::is_platform_ps4)
        return launchPS4Store()

      return ::gui_modal_onlineShop()
    }.bindenv(OnlineShopModel))
}
/*end API methods*/

OnlineShopModel.invalidatePriceBlk <- function invalidatePriceBlk()
{
  priceBlk = null
  purchaseDataCache.clear()
}

OnlineShopModel.validatePriceBlk <- function validatePriceBlk()
{
  if (priceBlk)
    return
  priceBlk = ::DataBlock()
  ::get_shop_prices(priceBlk)
}

OnlineShopModel.getPriceBlk <- function getPriceBlk()
{
  validatePriceBlk()
  return priceBlk
}

//Check is price.blk is fresh and perform an action.
//If prise.blk is rotten, upfate price.blk and then perform action.
OnlineShopModel.__assyncActionWrap <- function __assyncActionWrap(action)
{
  local isActual = ::configs.ENTITLEMENTS_PRICE.checkUpdate(
    action ? (@() action()).bindenv(this) : null,
    null,
    true,
    false
  )

  if (isActual)
    action()
}

OnlineShopModel.onEventEntitlementsPriceUpdated <- function onEventEntitlementsPriceUpdated(p)
{
  invalidatePriceBlk()
}

OnlineShopModel.onEventSignOut <- function onEventSignOut(p)
{
  invalidatePriceBlk()
}

OnlineShopModel.getGoodsByName <- function getGoodsByName(goodsName)
{
  return ::getTblValue(goodsName, getPriceBlk())
}

OnlineShopModel.isEntitlement <- function isEntitlement(name)
{
  if (typeof name == "string")
    return name in getPriceBlk()
  return false
}

OnlineShopModel.searchEntitlement <- function searchEntitlement(searchRequest)
{
  local result = []
  if (!searchRequest || typeof searchRequest != "table")
    return result

  foreach (name, ib in getPriceBlk())
  {
    if (ib?.hideWhenUnbought && !::has_entitlement(name))
      continue
    if ("unitName" in searchRequest)
      foreach (unitName in ib % "aircraftGift")
        if (unitName == searchRequest.unitName)
          result.append(name)
  }
  return result
}

OnlineShopModel.getGuidForGoods <- function getGuidForGoods(goodsName)
{
  return ::loc("guid/" + goodsName, "")
}

OnlineShopModel.getXboxIdForGoods <- function getXboxIdForGoods(goodsName)
{
  return ::loc("xboxId/" + goodsName, "")
}

OnlineShopModel.getPsnIdForGoods <- function getPsnIdForGoods(goodsName)
{
  local key = "npmtId/" + platform.ps4RegionName() + "/" + goodsName
  local id = ::loc(key, "")
  ::dagor.debug("PSN STORE: " + goodsName + " (" + key + ") -> " + id)
  return id
}

OnlineShopModel.getCustomPurchaseLink <- function getCustomPurchaseLink(goodsName)
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
OnlineShopModel.getPurchaseData <- function getPurchaseData(goodsName)
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

OnlineShopModel.createPurchaseData <- function createPurchaseData(goodsName = "", guid = null, customPurchaseLink = null)
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
OnlineShopModel.getFeaturePurchaseData <- function getFeaturePurchaseData(feature)
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
OnlineShopModel.getAllFeaturePurchases <- function getAllFeaturePurchases(feature)
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

OnlineShopModel.openBrowserForFirstFoundEntitlement <- function openBrowserForFirstFoundEntitlement(entitlementsList)
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

OnlineShopModel.openBrowserByPurchaseData <- function openBrowserByPurchaseData(purchaseData)
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

OnlineShopModel.doBrowserPurchase <- function doBrowserPurchase(goodsName)
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

OnlineShopModel.doBrowserPurchaseByGuid <- function doBrowserPurchaseByGuid(guid, dbgGoodsName = "")
{
  if (::steam_is_running() && (::g_user_utils.haveTag("steam") || ::has_feature("AllowSteamAccountLinking"))) //temporary use old code pass for steam
  {
    local response = ::shell_purchase_in_steam(guid);
    if (response > 0)
    {
      local errorText = ::get_yu2_error_text(response)
      ::showInfoMsgBox(errorText, "errorMessageBox")
      dagor.debug("shell_purchase_in_steam have returned " + response + " with guid/" + dbgGoodsName)
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

OnlineShopModel.getGoodsChapter <- function getGoodsChapter(goodsName)
{
  local goods = getGoodsByName(goodsName)
  return "chapter" in goods ? goods.chapter : ""
}

//Get custom URL for purchase goods from regional stores
//if returns "" uses default store.
//custom URLs are defined for particular languages and almost always are ""
//Consoles are exception. They always uses It's store.
OnlineShopModel.getCustomPurchaseUrl <- function getCustomPurchaseUrl(chapter)
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

OnlineShopModel.openShopUrl <- function openShopUrl(baseUrl, isAlreadyAuthenticated = false)
{
  ::open_url(baseUrl, false, isAlreadyAuthenticated, "shop_window")
  startEntitlementsUpdater()
}

//return true when custom Url found
OnlineShopModel.checkAndOpenCustomPurchaseUrl <- function checkAndOpenCustomPurchaseUrl(chapter, needMsgBox = false)
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

OnlineShopModel.openUpdateBalanceMenu <- function openUpdateBalanceMenu(customUrl)
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

OnlineShopModel.startEntitlementsUpdater <- function startEntitlementsUpdater()
{
  callbackWhenAppWillActive(function()
    {
      if (::is_online_available())
        ::g_tasker.addTask(::update_entitlements_limited(),
          {
            showProgressBox = true
            progressBoxText = ::loc("charServer/checking")
          })
    }
  )
}

OnlineShopModel.launchOnlineShop <- function launchOnlineShop(owner=null, chapter=null, afterCloseFunc=null)
{
  if (!::isInMenu())
    return afterCloseFunc && afterCloseFunc()

  if (launchPS4Store(chapter, afterCloseFunc))
    return

  if (launchXboxMarketplace(chapter, afterCloseFunc))
    return

  ::gui_modal_onlineShop(owner, chapter, afterCloseFunc)
}

OnlineShopModel.launchPS4Store <- function launchPS4Store(chapter = null, afterCloseFunc = null)
{
  if (::is_platform_ps4 && ::isInArray(chapter, [null, "", "eagles"]))
  {
    ::queues.checkAndStart(@() ::launch_ps4_store_by_chapter(chapter, afterCloseFunc),
      null, "isCanUseOnlineShop")
    return true
  }
  return false
}

OnlineShopModel.launchXboxMarketplace <- function launchXboxMarketplace(chapter = null, afterCloseFunc = null)
{
  if (::is_platform_xboxone && ::isInArray(chapter, [null, "", "eagles"]))
  {
    if (xboxShop.canUseIngameShop())
      xboxShop.openWnd(chapter, afterCloseFunc)
    else
      ::queues.checkAndStart(::Callback(@() launchXboxOneStoreByChapter(chapter, afterCloseFunc),this),
        null, "isCanUseOnlineShop")

    return true
  }
  return false
}

OnlineShopModel.launchXboxOneStoreByChapter <- function launchXboxOneStoreByChapter(chapter, afterCloseFunc = null)
{
  callbackReturnFunc = afterCloseFunc
  ::get_gui_scene().performDelayed(::getroottable(),
    function(){ ::xbox_show_marketplace(chapter == "eagles") })
}

OnlineShopModel.onPurchasesUpdated <- function onPurchasesUpdated()
{
  if (callbackReturnFunc)
  {
    callbackReturnFunc()
    callbackReturnFunc = null
  }
}

//                                                                            //
////////////////////////////////////////////////////////////////////////////////
//                                                                            //

::get_entitlement_config <- function get_entitlement_config(name)
{
  local res = { name = name }

  local pblk = ::DataBlock()
  ::get_shop_prices(pblk)
  if (pblk?[name] != null)
  {
    foreach(param in ["ttl", "httl", "onlinePurchase", "wpIncome", "goldIncome", "goldIncomeFirstBuy",
                      "group", "useGroupAmount", "image", "chapterImage",
                      "aircraftGift", "alias", "chapter", "goldDiscount", "goldCost"])
      if (pblk[name]?[param] != null && !(param in res))
        res[param] <- pblk[name][param]
  }
  return res
}

::get_entitlement_locId <- function get_entitlement_locId(item)
{
  return ("alias" in item) ? item.alias : ("group" in item) ? item.group : item.name
}

::get_entitlement_name <- function get_entitlement_name(item)
{
  local name = ""
  if (("useGroupAmount" in item) && item.useGroupAmount && ("group" in item))
  {
    name = ::loc("charServer/entitlement/" + item.group)
    local amountStr = ::g_language.decimalFormat(::get_entitlement_amount(item))
    if(name.indexof("%d") != null)
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

::get_entitlement_amount <- function get_entitlement_amount(item)
{
  if ("httl" in item)
    return item.httl.tofloat() / 24.0

  foreach(n in ["ttl", "wpIncome", "goldIncome"])
    if ((n in item) && item[n] > 0)
      return item[n]

  return 1
}

::get_first_purchase_additional_amount <- function get_first_purchase_additional_amount(item)
{
  if (!::has_entitlement(item.name))
    return ::getTblValue("goldIncomeFirstBuy", item, 0)

  return 0
}

::get_entitlement_timeText <- function get_entitlement_timeText(item)
{
  if ("ttl" in item)
    return item.ttl + ::loc("measureUnits/days")
  if ("httl" in item)
    return item.httl + ::loc("measureUnits/hours")
  return ""
}

::get_entitlement_price <- function get_entitlement_price(item)
{
  if (("onlinePurchase" in item) && item.onlinePurchase)
  {
    local priceText = ""
    if (::steam_is_running())
      priceText = ::loc("price/steam/" + item.name, "")
    if (priceText == "")
      priceText = ::loc("price/" + item.name, "")

    if (priceText != "")
    {
      local markup = ::steam_is_running() ? 1.0 + getSteamMarkUp()/100.0 : 1.0
      local totalPrice = priceText.tofloat() * markup
      local discount = ::g_discount.getEntitlementDiscount(item.name)
      if (discount)
        totalPrice -= totalPrice * discount * 0.01

      return format(::loc("price/common"),
        item?.chapter == "eagles" ? totalPrice.tostring() : ::g_language.decimalFormat(totalPrice))
    }
  }
  else if ("goldCost" in item)
    return ::Cost(0, ::get_entitlement_cost_gold(item.name)).tostring()
  return ""
}

::update_purchases_return_mainmenu <- function update_purchases_return_mainmenu(afterCloseFunc = null, openStoreResult = -1)
{
  //TODO: separate afterCloseFunc on Success and Error.
  if (openStoreResult < 0)
  {
    //openStoreResult = -1 doesn't mean that we must not perform afterCloseFunc
    if (afterCloseFunc)
      afterCloseFunc()
    return
  }

  local taskId = ::update_entitlements_limited(true)
  //taskId = -1 doesn't mean that we must not perform afterCloseFunc
  if (taskId >= 0)
  {
    local progressBox = ::scene_msg_box("char_connecting", null, ::loc("charServer/checking"), null, null)
    ::add_bg_task_cb(taskId, function() {
      ::destroyMsgBox(progressBox)
      ::gui_start_mainmenu_reload()
      if (afterCloseFunc)
        afterCloseFunc()
    })
  }
  else if (afterCloseFunc)
    afterCloseFunc()
}

::gui_modal_onlineShop <- function gui_modal_onlineShop(owner=null, chapter=null, afterCloseFunc=null)
{
  if (::OnlineShopModel.checkAndOpenCustomPurchaseUrl(chapter, true))
    return

  if (::isInArray(chapter, [null, ""]))
  {
    local webStoreUrl = ::loc("url/webstore", "")
    if (::steam_is_running() && (::g_user_utils.haveTag("steam") || ::has_feature("AllowSteamAccountLinking")))
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

::launch_ps4_store_by_chapter <- function launch_ps4_store_by_chapter(chapter,afterCloseFunc = null)
{
  ::get_gui_scene().performDelayed(::getroottable(),
    function() {
      if (chapter == null || chapter == "")
      {
        //TODO: items shop
        local res = ::ps4_open_store("WARTHUNDERAPACKS", false)
        ::update_purchases_return_mainmenu(afterCloseFunc, res)
      }
      else if (chapter == "eagles")
      {
        local res = ::ps4_open_store("WARTHUNDEREAGLES", false)
        ::update_purchases_return_mainmenu(afterCloseFunc, res)
      }
    }
  )
}

::subscribe_handler(::OnlineShopModel, ::g_listener_priority.CONFIG_VALIDATION)

::xbox_on_purchases_updated <- function xbox_on_purchases_updated()
{
  if (!::is_online_available())
    return

  ::g_tasker.addTask(::update_entitlements_limited(),
                      {
                        showProgressBox = true
                        progressBoxText = ::loc("charServer/checking")
                      },
                      @() ::OnlineShopModel.onPurchasesUpdated()
                    )
}
