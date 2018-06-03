local ItemExternal = require("scripts/items/itemsClasses/itemExternal.nut")
local ugcPreview = require("scripts/ugc/ugcPreview.nut")

class ::items_classes.ItemVehicle extends ItemExternal {
  static iType = itemType.VEHICLE
  static defaultLocId = "coupon"
  static combinedNameLocId = "coupon/name"
  static typeIcon = "#ui/gameuiskin#item_type_blueprints"
  static descHeaderLocId = "coupon/for/vehicle"

  function getContentIconData()
  {
    return { contentIcon = ::image_for_air(metaBlk?.unit ?? ""), contentType = "unit" }
  }

  function canConsume()
  {
    return isInventoryItem && metaBlk?.unit && !::shop_is_aircraft_purchased(metaBlk.unit)
  }

  function canPreview()
  {
    return metaBlk?.unit && ::getAircraftByName(metaBlk.unit)?.isInShop ?? false
  }

  function doPreview()
  {
    if (canPreview())
      ugcPreview.showUnitSkin(metaBlk.unit)
  }
}