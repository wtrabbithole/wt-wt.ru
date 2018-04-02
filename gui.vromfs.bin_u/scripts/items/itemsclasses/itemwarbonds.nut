local ItemExternal = require("scripts/items/itemsClasses/itemExternal.nut")

class ::items_classes.Warbonds extends ItemExternal {
  static iType = itemType.WARBONDS
  static defaultLocId = "coupon"
  static isUseTypePrefixInName = true
  static typeIcon = "#ui/gameuiskin#item_type_warbonds"
  static descHeaderLocId = "coupon/for"

  function getContentIconData()
  {
    return { contentIcon = typeIcon }
  }

  function getResourceDesc()
  {
    return ""
  }

  function canConsume()
  {
    if (!metaBlk || !metaBlk.warbonds  || metaBlk.warbonds == "" || !metaBlk.count)
      return false
    local wb = ::g_warbonds.findWarbond(metaBlk.warbonds)
    return wb != null
  }
}