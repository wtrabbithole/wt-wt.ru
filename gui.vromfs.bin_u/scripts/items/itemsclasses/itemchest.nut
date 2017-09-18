local inventoryClient = require("scripts/inventory/inventoryClient.nut")
local ItemExternal = require("scripts/items/itemsClasses/itemExternal.nut")

class ::items_classes.Chest extends ItemExternal {
  static iType = itemType.CHEST
  constructor(itemDesc, invBlk = null, slotData = null)
  {
    base.constructor(itemDesc)
  }

  function getMainActionName(colored = true, short = false)
  {
    return ::loc("item/open")
  }

  function doMainAction(cb, handler, params = null)
  {
    inventoryClient.openChest(id, function(items) {
      ::ItemsManager.markInventoryUpdate()
      ::gui_start_open_chest_list(items)
    })
  }
}