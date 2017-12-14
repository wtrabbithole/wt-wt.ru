local inventoryClient = require("scripts/inventory/inventoryClient.nut")
local ItemExternal = require("scripts/items/itemsClasses/itemExternal.nut")

class ::items_classes.Chest extends ItemExternal {
  static iType = itemType.CHEST
  static typeIcon = "#ui/gameuiskin#item_type_trophies"
  static openingCaptionLocId = "mainmenu/chestConsumed/title"

  function getOpenedBigIcon()
  {
    return getBigIcon()
  }

  function getMainActionName(colored = true, short = false)
  {
    return ::loc("item/open")
  }

  function doMainAction(cb, handler, params = null)
  {
    if (!uids || !uids.len())
      return -1

    local uid = uids[0]

    inventoryClient.openChest(uid, function(items) {
      ::ItemsManager.markInventoryUpdate()
      ::gui_start_open_chest_list(items)
    })
  }
}