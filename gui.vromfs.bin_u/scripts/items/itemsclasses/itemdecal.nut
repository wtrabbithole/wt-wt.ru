local ItemExternal = require("scripts/items/itemsClasses/itemExternal.nut")

class ::items_classes.Decal extends ItemExternal {
  static iType = itemType.DECAL
  static defaultLocId = "coupon"
  static isUseTypePrefixInName = true
  static typeIcon = "#ui/gameuiskin#item_type_decal"
  static descHeaderLocId = "coupon/for/decal"

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