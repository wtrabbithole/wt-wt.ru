local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")
local seenList = ::require("scripts/seen/seenList.nut").get(SEEN.EXT_XBOX_SHOP)
local progressMsg = ::require("sqDagui/framework/progressMsg.nut")

local XboxShopPurchasableItem = ::require("scripts/onlineShop/XboxShopPurchasableItem.nut")

const XBOX_RECEIVE_CATALOG_MSG_ID = "XBOX_RECEIVE_CATALOG"

local visibleSeenIds = null
local xboxProceedItems = {}

local onReceiveCatalogCb = null
local reqProgressMsg = false
local invalidateSeenList = false
local haveItemDiscount = null
::xbox_browse_catalog_callback <- function(catalog)
{
  if (!catalog || !catalog.blockCount())
  {
    ::dagor.debug("XBOX SHOP: Empty catalog. Don't open shop.")
    return
  }

  xboxProceedItems.clear()
  for (local i = 0; i < catalog.blockCount(); i++)
  {
    local itemBlock = catalog.getBlock(i)
    if (itemBlock.IsPartOfAnyBundle)
    {
      ::dagor.debug("XBOX SHOP: Skip " + itemBlock.Name)
      continue
    }

    local item = XboxShopPurchasableItem(itemBlock)
    if (!(item.mediaItemType in xboxProceedItems))
      xboxProceedItems[item.mediaItemType] <- []
    xboxProceedItems[item.mediaItemType].append(item)
  }

  if (invalidateSeenList)
  {
    visibleSeenIds = null
    seenList.onListChanged()
  }
  invalidateSeenList = false

  if (reqProgressMsg)
    progressMsg.destroy(XBOX_RECEIVE_CATALOG_MSG_ID)
  reqProgressMsg = false

  if (onReceiveCatalogCb)
    onReceiveCatalogCb()
  onReceiveCatalogCb = null

  ::g_discount.updateXboxShopDiscounts()
}

local requestData = function(isSilent = false, cb = null, invSeenList = false)
{
  if (!::is_platform_xboxone)
    return

  onReceiveCatalogCb = cb
  reqProgressMsg = !isSilent
  invalidateSeenList = invSeenList
  haveItemDiscount = null

  if (reqProgressMsg)
    progressMsg.create(XBOX_RECEIVE_CATALOG_MSG_ID, null)

  ::xbox_browse_catalog_async()

  /* Debug Purpose Only
  {
    local blk = ::DataBlock()
    blk.load("browseCatalog.blk")
    ::xbox_browse_catalog_callback(blk)
  }
  */
}

local canUseIngameShop = @() ::is_platform_xboxone && ::has_feature("XboxIngameShop")

local getVisibleSeenIds = function()
{
  if (!visibleSeenIds)
  {
    visibleSeenIds = []
    foreach (mediaType, itemsList in xboxProceedItems)
      visibleSeenIds.extend(itemsList.filter(@(idx, it) !it.canBeUnseen()).map(@(it) it.getSeenId()))
  }
  return visibleSeenIds
}

seenList.setListGetter(getVisibleSeenIds)

local isItemsInitedOnce = false
local initXboxItemsListAfterLogin = function()
{
  if (canUseIngameShop() && !isItemsInitedOnce)
  {
    isItemsInitedOnce = true
    requestData(true)
  }
}

local haveAnyItemWithDiscount = function()
{
  if (haveItemDiscount != null)
    return haveItemDiscount

  haveItemDiscount = false
  foreach (mediaType, itemsList in xboxProceedItems)
    foreach (item in itemsList)
      if (item.haveDiscount())
      {
        haveItemDiscount = true
        break
      }

  return haveItemDiscount
}

local haveDiscount = function()
{
  if (!canUseIngameShop())
    return false

  if (!isItemsInitedOnce)
  {
    initXboxItemsListAfterLogin()
    return false
  }

  return haveAnyItemWithDiscount()
}

subscriptions.addListenersWithoutEnv({
  ProfileUpdated = @(p) initXboxItemsListAfterLogin()
  SignOut = function(p) {
    isItemsInitedOnce = false
    xboxProceedItems.clear()
    visibleSeenIds = null
    haveItemDiscount = null
  }
}, ::g_listener_priority.CONFIG_VALIDATION)

return {
  canUseIngameShop = canUseIngameShop
  requestData = requestData
  xboxProceedItems = xboxProceedItems
  haveDiscount = haveDiscount
}