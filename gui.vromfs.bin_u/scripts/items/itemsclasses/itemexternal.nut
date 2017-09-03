local inventoryClient = require("scripts/inventory/inventoryClient.nut")
local guidParser = require("scripts/guidParser.nut")

local ItemExternal = class extends ::BaseItem
{
  metaBlk = null

  constructor(itemDesc)
  {
    base.constructor(::DataBlock())

    uids = []
    id = itemDesc.itemid
    amount = itemDesc.quantity
    itemDef = itemDesc.itemdef

    local meta = getTblValue("meta", itemDef)
    if (meta) {
      metaBlk = ::DataBlock()
      if (!metaBlk.loadFromText(meta, meta.len())) {
        metaBlk = null
      }
    }
  }

  function getName(colored = true)
  {
    local text = g_language.getLocTextFromSteamDesc(itemDef, "name")
    if (colored && itemDef.name_color && itemDef.name_color.len() > 0)
    {
      return ::colorize("#" + itemDef.name_color, text)
    }

    return text;
  }

  function getDescription()
  {
    return g_language.getLocTextFromSteamDesc(itemDef, "description")
  }

  function getIcon(addItemName = true)
  {
    return ::LayersIcon.getIconData(null, itemDef.icon_url)
  }

  function canConsume()
  {
    if (!metaBlk)
      return false

    if (metaBlk.unit && ::shop_is_aircraft_purchased(metaBlk.unit))
      return false

    if (metaBlk.resource) {
      local type = ::g_decorator_type.getTypeByResourceType(metaBlk.resourceType)
      if (type.isPlayerHaveDecorator(metaBlk.resource))
       return false
    }

    return true
  }

  function getMainActionName(colored = true, short = false)
  {
    return canConsume() ? ::loc("item/consume") : ""
  }

  function doMainAction(cb, handler, params = null)
  {
    if (metaBlk) {
      addLocalization()

      local blk = ::DataBlock()
      blk.setInt("itemId", id.tointeger())

      local idToRemove = id
      local taskCallback = function() {
        inventoryClient.removeItem(idToRemove)
        cb({ success = true })
      }

      local taskId = ::char_send_blk("cln_consume_inventory_item", blk)

      ::g_tasker.addTask(taskId, { showProgressBox = true }, taskCallback)
      return
    }

    base.doMainAction(cb, handler, params)
  }

  function addLocalization() {
    if (!metaBlk)
      return

    local resource = metaBlk.resource
    if (!resource)
      return

    if (!guidParser.isGuid(resource))
      return

    add_rta_localization(resource, getName(false))
  }

  itemDef = null
}

return ItemExternal
