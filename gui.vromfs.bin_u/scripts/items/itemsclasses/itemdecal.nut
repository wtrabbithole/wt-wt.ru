local ItemExternal = require("scripts/items/itemsClasses/itemExternal.nut")

class ::items_classes.Decal extends ItemExternal {
  static iType = itemType.DECAL
  constructor(itemDesc, invBlk = null, slotData = null)
  {
    base.constructor(itemDesc)
  }
}