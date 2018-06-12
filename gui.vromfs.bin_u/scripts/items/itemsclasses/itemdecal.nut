local ItemExternal = require("scripts/items/itemsClasses/itemExternal.nut")
local ugcPreview = require("scripts/ugc/ugcPreview.nut")

class ::items_classes.Decal extends ItemExternal {
  static iType = itemType.DECAL
  static defaultLocId = "coupon"
  static combinedNameLocId = "coupon/name"
  static typeIcon = "#ui/gameuiskin#item_type_decal"
  static descHeaderLocId = "coupon/for/decal"

  function getContentIconData()
  {
    return { contentIcon = typeIcon }
  }

  function canConsume()
  {
    if (!isInventoryItem || !metaBlk || !metaBlk.resource || !metaBlk.resourceType)
      return false
    local decoratorType = ::g_decorator_type.getTypeByResourceType(metaBlk.resourceType)
    return ! decoratorType.isPlayerHaveDecorator(metaBlk.resource)
  }

  function canPreview()
  {
    return metaBlk?.resource != null
  }

  function doPreview()
  {
    if (canPreview())
      ugcPreview.showResource(metaBlk.resource, metaBlk.resourceType)
  }
}