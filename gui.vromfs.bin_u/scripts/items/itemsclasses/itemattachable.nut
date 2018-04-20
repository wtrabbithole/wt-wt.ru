local ItemExternal = require("scripts/items/itemsClasses/itemExternal.nut")

class ::items_classes.Attachable extends ItemExternal {
  static iType = itemType.ATTACHABLE
  static defaultLocId = "coupon"
  static combinedNameLocId = "coupon/name"
  static typeIcon = "#ui/gameuiskin#item_type_attachable"
  static descHeaderLocId = "coupon/for/attachable"

  function getContentIconData()
  {
    return { contentIcon = typeIcon }
  }

  function canConsume()
  {
    if (!metaBlk || !metaBlk.resource || !metaBlk.resourceType)
      return false
    local decoratorType = ::g_decorator_type.getTypeByResourceType(metaBlk.resourceType)
    return ! decoratorType.isPlayerHaveDecorator(metaBlk.resource)
  }
}