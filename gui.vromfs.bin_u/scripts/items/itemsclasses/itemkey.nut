local ItemExternal = require("scripts/items/itemsClasses/itemExternal.nut")

class ::items_classes.Key extends ItemExternal {
  static iType = itemType.KEY
  static defaultLocId = "key"
  static typeIcon = "#ui/gameuiskin#item_type_key"
  static hasRecentItemConfirmMessageBox = true

  function canConsume()
  {
    false
  }
}