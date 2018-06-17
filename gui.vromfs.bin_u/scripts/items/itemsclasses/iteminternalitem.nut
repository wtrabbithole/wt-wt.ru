local ItemExternal = require("scripts/items/itemsClasses/itemExternal.nut")

class ::items_classes.InternalItem extends ItemExternal
{
  static iType = itemType.INTERNAL_ITEM
  static defaultLocId = "coupon"
  static combinedNameLocId = "coupon/name"
  static typeIcon = "#ui/gameuiskin#item_type_trophies"
  static descHeaderLocId = "coupon/for"

  getContentItem   = @() metaBlk?.item && ::ItemsManager.findItemById(metaBlk?.item)
  canConsume       = @() isInventoryItem && getContentItem() != null

  function updateShopFilterMask()
  {
    shopFilterMask = iType
    local contentItem = getContentItem()
    if (contentItem)
      shopFilterMask = shopFilterMask | contentItem.iType
  }

  getContentIconData   = function()
  {
    local contentItem = getContentItem()
    return contentItem && { contentIcon = contentItem.typeIcon }
  }
}