local ItemExternal = require("scripts/items/itemsClasses/itemExternal.nut")
local ugcPreview = require("scripts/ugc/ugcPreview.nut")

class ::items_classes.Skin extends ItemExternal {
  static iType = itemType.SKIN
  static defaultLocId = "coupon"
  static isUseTypePrefixInName = true
  static typeIcon = "#ui/gameuiskin#item_type_skin"
  static descHeaderLocId = "coupon/for/skin"

  function getContentIconData()
  {
    return { contentIcon = typeIcon }
  }

  function getTagsLoc()
  {
    if (!metaBlk || !metaBlk.resource || !metaBlk.resourceType)
      return false
    local decoratorType = ::g_decorator_type.getTypeByResourceType(metaBlk.resourceType)
    local decorator = ::g_decorator.getDecorator(metaBlk.resource, decoratorType)
    return decorator ? decorator.getTagsLoc() : []
  }

  function canConsume()
  {
    if (!metaBlk || !metaBlk.resource || !metaBlk.resourceType)
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