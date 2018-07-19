local ItemExternal = require("scripts/items/itemsClasses/itemExternal.nut")
local ugcPreview = require("scripts/ugc/ugcPreview.nut")

class ::items_classes.Attachable extends ItemExternal {
  static iType = itemType.ATTACHABLE
  static defaultLocId = "coupon"
  static combinedNameLocId = "coupon/name"
  static typeIcon = "#ui/gameuiskin#item_type_attachable"
  static descHeaderLocId = "coupon/for/attachable"

  getDecorator = @() ::g_decorator.getDecoratorByResource(metaBlk?.resource, metaBlk?.resourceType)

  getContentIconData = @() { contentIcon = typeIcon }
  canConsume = @() isInventoryItem ? (getDecorator() && !getDecorator().isUnlocked()) : false
  canPreview = @() metaBlk?.resource != null
  doPreview  = @() canPreview() && ugcPreview.showResource(metaBlk.resource, metaBlk.resourceType)
}