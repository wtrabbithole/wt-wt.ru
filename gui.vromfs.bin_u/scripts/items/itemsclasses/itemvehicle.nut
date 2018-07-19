local ItemExternal = require("scripts/items/itemsClasses/itemExternal.nut")
local ugcPreview = require("scripts/ugc/ugcPreview.nut")

class ::items_classes.ItemVehicle extends ItemExternal {
  static iType = itemType.VEHICLE
  static defaultLocId = "coupon"
  static combinedNameLocId = "coupon/name"
  static typeIcon = "#ui/gameuiskin#item_type_blueprints"
  static descHeaderLocId = "coupon/for/vehicle"

  unit = null

  function addResources() {
    base.addResources()
    unit = ::getAircraftByName(metaBlk?.unit)
  }

  getContentIconData = @() { contentIcon = ::image_for_air(unit?.name ?? ""), contentType = "unit" }
  canConsume = @() isInventoryItem ? (unit && !::shop_is_aircraft_purchased(unit.name)) : false
  canPreview = @() unit?.isInShop ?? false
  doPreview  = @() canPreview() && ugcPreview.showUnitSkin(unit?.name ?? "")
}