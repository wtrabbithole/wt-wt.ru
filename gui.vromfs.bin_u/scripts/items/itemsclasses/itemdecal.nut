local ItemCouponBase = require("scripts/items/itemsClasses/itemCouponBase.nut")

class ::items_classes.Decal extends ItemCouponBase {
  static iType = itemType.DECAL
  static typeIcon = "#ui/gameuiskin#item_type_decal"
  static descHeaderLocId = "coupon/for/decal"

  getDecorator = @() ::g_decorator.getDecoratorByResource(metaBlk?.resource, metaBlk?.resourceType)

  canConsume = @() isInventoryItem ? (getDecorator() && !getDecorator().isUnlocked()) : false
  canPreview = @() getDecorator() ? getDecorator().canPreview() : false
  doPreview  = @() getDecorator() && getDecorator().doPreview()
}