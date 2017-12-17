local ItemExternal = require("scripts/items/itemsClasses/itemExternal.nut")

class ::items_classes.Decal extends ItemExternal {
  static iType = itemType.DECAL
  static typeIcon = "#ui/gameuiskin#item_type_decal"

  function canConsume()
  {
    if (!metaBlk || !metaBlk.resource || !metaBlk.resourceType)
      return false
    local decoratorType = ::g_decorator_type.getTypeByResourceType(metaBlk.resourceType)
    return ! decoratorType.isPlayerHaveDecorator(metaBlk.resource)
  }
}