local ItemExternal = require("scripts/items/itemsClasses/itemExternal.nut")

class ::items_classes.ItemVehicle extends ItemExternal {
  static iType = itemType.VEHICLE
  constructor(itemDesc, invBlk = null, slotData = null)
  {
    base.constructor(itemDesc)
  }
}