local ItemExternal = ::require("scripts/items/itemsClasses/itemExternal.nut")

class ::items_classes.CraftPart extends ItemExternal {
  static iType = itemType.CRAFT_PART
  static defaultLocId = "craft_part"
  static typeIcon = "#ui/gameuiskin#item_type_key"

  function canConsume()
  {
    return false
  }
}