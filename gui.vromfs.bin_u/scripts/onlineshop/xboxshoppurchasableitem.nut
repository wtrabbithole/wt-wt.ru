local u = require("std/u.nut")

local XboxShopPurchasableItem = class
{
  defaultIconStyle = "default_chest_debug"
  imagePath = null

  id = ""
  mediaItemType = -1
  releaseDate = 0
  price = 0.0
  listPrice = 0.0
  priceText = ""
  listPriceText = ""
  currencyCode = ""
  isPurchasable = false
  isBought = false
  name = ""
  description = ""
  isBundle = false
  isPartOfAnyBundle = false
  consumableQuantity = 0
  signedOffer = "" //for direct purchase

  amount = ""
  allowBigPicture = true

  isMultiConsumable = false

  constructor(blk)
  {
    id = blk.getBlockName()
    mediaItemType = blk.MediaItemType
    isMultiConsumable = mediaItemType == xboxMediaItemType.GameConsumable
    if (isMultiConsumable)
      defaultIconStyle = "reward_gold"

    name = blk.Name || ""
    description = blk.Description || ""

    releaseDate = blk.ReleaseDate || 0

    price = blk.Price || 0.0
    priceText = blk.DisplayPrice || ""
    listPrice = blk.ListPrice || 0.0
    listPriceText = blk.listPriceText || ""
    currencyCode = blk.CurrencyCode || ""

    isPurchasable = blk.IsPurchasable || false
    isBundle = blk.IsBundle || false
    isPartOfAnyBundle = blk.IsPartOfAnyBundle || false
    isBought = blk.isBought || false

    consumableQuantity = blk.ConsumableQuantity || 0
    signedOffer = blk.SignedOffer || ""

    if (isPurchasable)
      amount = getPriceText()

    local guiCfg = ::configs.GUI.get()
    local ingameShopImages = guiCfg.xbox_ingame_shop_items_images
    if (ingameShopImages && id in ingameShopImages)
      imagePath = "!" + ingameShopImages.mainPart + id + ingameShopImages.fileExtension
  }

  getPriceText = @() price == 0? ::loc("shop/free") : (price + " " + currencyCode)
  updateIsBoughtStatus = @() isBought = isMultiConsumable? false : ::xbox_is_item_bought(id)

  getViewData = @(params = {}) {
    isAllBought = isBought
    price = getPriceText()
    layered_image = getIcon()
    enableBackground = true
    isInactive = isInactive()
    isItemLocked = !isPurchasable
    itemHighlight = isBought
    needAllBoughtIcon = true
  }.__merge(params)

  isCanBuy = @() isPurchasable && !isBought
  isInactive = @() !isPurchasable || isBought

  getIcon = @(...) ::LayersIcon.getIconData(null, imagePath, 1.0, imagePath? null : defaultIconStyle)
  getSeenId = @() id.tostring()
  canBeUnseen = @() isBought
}

return XboxShopPurchasableItem