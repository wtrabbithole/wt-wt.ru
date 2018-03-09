local inventoryClient = require("scripts/inventory/inventoryClient.nut")
local guidParser = require("scripts/guidParser.nut")

local emptyBlk = ::DataBlock()

local ItemExternal = class extends ::BaseItem
{
  static defaultLocId = ""
  static isUseTypePrefixInName = false
  static descHeaderLocId = ""
  static openingCaptionLocId = "mainmenu/itemConsumed/title"
  static isPreferMarkupDescInTooltip = true
  static isDescTextBeforeDescDiv = false
  static hasRecentItemConfirmMessageBox = false

  itemDef = null
  metaBlk = null

  constructor(itemDefDesc, itemDesc = null, slotData = null)
  {
    base.constructor(emptyBlk)

    itemDef = itemDefDesc
    id = itemDef.itemdefid

    link = inventoryClient.getMarketplaceItemUrl(id, itemDesc?.itemid) || ""
    forceExternalBrowser = true

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
      text = ::colorize("#" + itemDef.name_color, text)
    if (isUseTypePrefixInName)
      text = getTypeName() + " " + text
    return text
  }

  function getDescription()
  {
    local desc = []
    desc.append(itemDef?.description ?? "")

    local tags = getTagsLoc()
    if (tags.len())
    {
      tags = ::u.map(tags, @(txt) ::colorize("activeTextColor", txt))
      desc.append(::loc("ugm/tags") + ::loc("ui/colon") + ::g_string.implode(tags, ::loc("ui/comma")))
    }

    local canSell = itemDef?.marketable
    desc.append(::colorize(canSell ? "goodTextColor" : "badTextColor",
      ::loc("item/marketable/" + (canSell ? "yes" : "no"), { name =  getTypeName() } )))
    return ::g_string.implode(desc, "\n\n")
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
    params.header <- ::colorize("grayOptionColor", ::loc(descHeaderLocId))
    params.showAsTrophyContent <- true
    params.receivedPrizes <- false
    if (metaBlk.resourceType && metaBlk.resource && guidParser.isGuid(metaBlk.resource))
      params.tags <- itemDef?.tags

    return ::PrizesView.getPrizesListView([ metaBlk ], params)
  }

  function getTagsLoc()
  {
    return []
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
      return false
    if (!metaBlk)
      return false

    local text = ::loc("recentItems/useItem", { itemName = ::colorize("activeTextColor", getName()) })
    if (itemDef?.marketable)
      text += "\n" + ::loc("msgBox/coupon_will_be_spent")
    ::scene_msg_box("coupon_exchange", null, text, [
      [ "yes", ::Callback(@() doConsumeItem(cb, params), this) ],
      [ "no" ]
    ], "yes", { cancel_fn = function() {} })
    return true
  }

  function doConsumeItem(cb = null, params = null)
  {
    local uid = uids?[0]
    if (!uid)
      return

    local blk = ::DataBlock()
    blk.setInt("itemId", uid.tointeger())

    local taskCallback = function() {
      inventoryClient.removeItem(uid)
      if (cb)
        cb({ success = true })
    }

    local taskId = ::char_send_blk("cln_consume_inventory_item", blk)
    ::g_tasker.addTask(taskId, { showProgressBox = true }, taskCallback)
  }

  function addLocalization() {
    if (!metaBlk)
      return
    local resource = metaBlk.resource
    if (!resource)
      return
    if (!guidParser.isGuid(resource))
      return

    ::add_rta_localization(resource, itemDef?.name ?? "")
  }
}

return ItemExternal
