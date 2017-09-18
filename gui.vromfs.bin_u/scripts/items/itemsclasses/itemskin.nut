local ItemExternal = require("scripts/items/itemsClasses/itemExternal.nut")

class ::items_classes.Skin extends ItemExternal {
  static iType = itemType.SKIN
  constructor(itemDesc, invBlk = null, slotData = null)
  {
    base.constructor(itemDesc)
  }
}