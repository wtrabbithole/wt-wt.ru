local inventoryClient = require("scripts/inventory/inventoryClient.nut")
local guidParser = require("scripts/guidParser.nut")

local emptyBlk = ::DataBlock()

local ItemExternal = class extends ::BaseItem
{
  static openingCaptionLocId = "mainmenu/itemConsumed/title"
  static isDescTextBeforeDescDiv = false

  itemDef = null
  metaBlk = null

  constructor(itemDefDesc, itemDesc = null, slotData = null)
  {
    base.constructor(emptyBlk)

    itemDef = itemDefDesc
    id = itemDef.itemdefid

    if (itemDesc)
    {
      isInventoryItem = true
      uids = [ itemDesc.itemid ]
      amount = itemDesc.quantity
    }

    local meta = getTblValue("meta", itemDef)
    if (meta && meta.len()) {
      metaBlk = ::DataBlock()
      if (!metaBlk.loadFromText(meta, meta.len())) {
        metaBlk = null
      }
    }

    addLocalization()
  }

  function tryAddItem(itemDefDesc, itemDesc)
  {
    if (id != itemDefDesc.itemdefid)
      return false
    uids.append(itemDesc.itemid)
    amount += itemDesc.quantity
    return true
  }

  function getName(colored = true)
  {
    local text = itemDef?.name ?? ""
    if (colored && itemDef.name_color && itemDef.name_color.len() > 0)
    {
      return ::colorize("#" + itemDef.name_color, text)
    }

    return text;
  }

  function getDescription()
  {
    return itemDef?.description ?? ""
  }

  function getIcon(addItemName = true)
  {
    return ::LayersIcon.getIconData(null, itemDef.icon_url)
  }

  function getBigIcon()
  {
    local url = !::u.isEmpty(itemDef.icon_url_large) ?
      itemDef.icon_url_large : itemDef.icon_url
    return ::LayersIcon.getIconData(null, url)
  }

  function getOpeningCaption()
  {
    return ::loc(openingCaptionLocId)
  }

  function getLongDescriptionMarkup(params = null)
  {
    if (!metaBlk)
      return ""

    params = params || {}
    params.showAsTrophyContent <- true
    params.receivedPrizes <- false

    local view = ::PrizesView.getPrizesViewData(metaBlk, true, params)
    return ::handyman.renderCached("gui/items/trophyDesc", { list = [ view ] })
  }

  function canConsume()
  {
    return false
  }

  function getMainActionName(colored = true, short = false)
  {
    return canConsume() ? ::loc("item/consume") : ""
  }

  function doMainAction(cb, handler, params = null)
  {
    if (!uids || !uids.len())
      return -1

    local uid = uids[0]

    if (metaBlk) {
      local blk = ::DataBlock()
      blk.setInt("itemId", uid.tointeger())

      local taskCallback = function() {
        inventoryClient.removeItem(uid)
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
}

return ItemExternal
