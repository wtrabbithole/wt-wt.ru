local inventoryClient = require("scripts/inventory/inventoryClient.nut")
local ItemGenerators = require("scripts/items/itemsClasses/itemGenerators.nut")
local ExchangeRecipes = require("scripts/items/exchangeRecipes.nut")
local guidParser = require("scripts/guidParser.nut")
local itemRarity = require("scripts/items/itemRarity.nut")
local time = require("scripts/time.nut")

local emptyBlk = ::DataBlock()

local ItemExternal = class extends ::BaseItem
{
  static defaultLocId = ""
  static isUseTypePrefixInName = false
  static descHeaderLocId = ""
  static openingCaptionLocId = "mainmenu/itemConsumed/title"
  static linkActionLocId = "msgbox/btn_find_on_marketplace"
  static linkActionIcon = "#ui/gameuiskin#gc.svg"
  static userlogOpenLoc = "coupon_exchanged"
  static linkBigQueryKey = "marketplace_item"
  static isPreferMarkupDescInTooltip = true
  static isDescTextBeforeDescDiv = false
  static hasRecentItemConfirmMessageBox = false

  rarity = null
  expireTimestamp = -1

  itemDef = null
  metaBlk = null

  amountByUids = null //{ <uid> = <amount> }, need for recipe materials

  constructor(itemDefDesc, itemDesc = null, slotData = null)
  {
    base.constructor(emptyBlk)

    itemDef = itemDefDesc
    id = itemDef.itemdefid
    blkType  = itemDefDesc?.tags?.type ?? ""

    rarity = itemRarity.get(itemDef?.item_quality, itemDef?.name_color)

    link = inventoryClient.getMarketplaceItemUrl(id, itemDesc?.itemid) || ""
    forceExternalBrowser = true

    if (itemDesc)
    {
      isInventoryItem = true
      amount = itemDesc.quantity
      uids = [ itemDesc.itemid ]
      amountByUids = { [itemDesc.itemid] = amount }
      lastChangeTimestamp = time.getTimestampFromIso8601(itemDesc?.timestamp)
    }

    expireTimestamp = getExpireTimestamp(itemDefDesc, itemDesc)
    if (expireTimestamp != -1)
      expiredTimeSec = (::dagor.getCurTime() * 0.001) + (expireTimestamp - ::get_charserver_time_sec())

    local meta = getTblValue("meta", itemDef)
    if (meta && meta.len()) {
      metaBlk = ::DataBlock()
      if (!metaBlk.loadFromText(meta, meta.len())) {
        metaBlk = null
      }
    }

    addResources()
  }

  function tryAddItem(itemDefDesc, itemDesc)
  {
    if (id != itemDefDesc.itemdefid || expireTimestamp != getExpireTimestamp(itemDefDesc, itemDesc))
      return false
    amount += itemDesc.quantity
    uids.append(itemDesc.itemid)
    amountByUids[itemDesc.itemid] <- itemDesc.quantity
    lastChangeTimestamp = ::max(lastChangeTimestamp, time.getTimestampFromIso8601(itemDesc?.timestamp))
    return true
  }

  function getExpireTimestamp(itemDefDesc, itemDesc)
  {
    local tShop = time.getTimestampFromIso8601(itemDefDesc?.expireAt ?? "")
    local tInv  = time.getTimestampFromIso8601(itemDesc?.expireAt ?? "")
    return (tShop != -1 && (tInv == -1 || tShop < tInv)) ? tShop : tInv
  }

  function getName(colored = true)
  {
    local res = ""
    if (isDisguised)
      res = ::loc("item/disguised")
    else
    {
      res = itemDef?.name ?? ""
      if (isUseTypePrefixInName)
        res = getTypeName() + " " + res
    }
    if (colored)
      res = ::colorize(getRarityColor(), res)
    return res
  }

  function getDescription()
  {
    if (isDisguised)
      return ""

    local desc = [
      getResourceDesc()
    ]

    local tags = getTagsLoc()
    if (tags.len())
    {
      tags = ::u.map(tags, @(txt) ::colorize("activeTextColor", txt))
      desc.append(::loc("ugm/tags") + ::loc("ui/colon") + ::g_string.implode(tags, ::loc("ui/comma")))
    }

    desc.append(itemDef?.description ?? "")

    return ::g_string.implode(desc, "\n\n")
  }

  function getIcon(addItemName = true)
  {
    return isDisguised ? ::LayersIcon.getIconData("disguised_item")
      : ::LayersIcon.getIconData(null, itemDef.icon_url)
  }

  function getBigIcon()
  {
    if (isDisguised)
      return ::LayersIcon.getIconData("disguised_item")

    local url = !::u.isEmpty(itemDef.icon_url_large) ?
      itemDef.icon_url_large : itemDef.icon_url
    return ::LayersIcon.getIconData(null, url)
  }

  function getOpeningCaption()
  {
    return ::loc(openingCaptionLocId)
  }

  function isAllowSkipOpeningAnim()
  {
    return true
  }

  function getLongDescriptionMarkup(params = null)
  {
    params = params || {}
    params.receivedPrizes <- false

    if (isDisguised)
      return ExchangeRecipes.getRequirementsMarkup(getMyRecipes(), this, params)

    local content = []
    local desc = [
      getMarketablePropDesc()
      getCurExpireTimeText()
    ]

    if (metaBlk)
    {
      desc.append(::colorize("grayOptionColor", ::loc(descHeaderLocId)))
      content = [ metaBlk ]
      params.showAsTrophyContent <- true
      params.receivedPrizes <- false
      params.relatedItem <- id
    }

    params.header <- ::u.map(desc, @(par) { header = par })
    return ::PrizesView.getPrizesListView(content, params)
      + ExchangeRecipes.getRequirementsMarkup(getMyRecipes(), this, params)
  }

  function getMarketablePropDesc()
  {
    if (!::has_feature("Marketplace"))
      return ""

    local canSell = itemDef?.marketable
    return ::loc("currency/gc/sign/colored", "") + " " +
      ::colorize(canSell ? "userlogColoredText" : "badTextColor",
      ::loc("item/marketable/" + (canSell ? "yes" : "no"), { name =  ::g_string.utf8ToLower(getTypeName()) } ))
  }

  function getResourceDesc()
  {
    if (!metaBlk || !metaBlk.resource || !metaBlk.resourceType)
      return ""
    local decoratorType = ::g_decorator_type.getTypeByResourceType(metaBlk.resourceType)
    local decorator = ::g_decorator.getDecorator(metaBlk.resource, decoratorType)
    if (!decorator)
      return ""
    return ::g_string.implode([
      decorator.getTypeDesc()
      decorator.getRestrictionsDesc()
    ], "\n")
  }

  isRare              = @() isDisguised ? base.isRare() : rarity.isRare
  getRarity           = @() isDisguised ? base.getRarity() :rarity.value
  getRarityColor      = @() isDisguised ? base.getRarityColor() :rarity.color
  getTagsLoc          = @() rarity.tag && !isDisguised ? [ rarity.tag ] : []

  canConsume          = @() false
  canAssemble         = @() getMyRecipes().len() > 0

  function getMainActionName(colored = true, short = false)
  {
    return amount && canConsume() ? ::loc("item/consume")
      : canAssemble() ? ::loc("item/assemble")
      : ""
  }

  function doMainAction(cb, handler, params = null)
  {
    return consume(cb, params)
      || assemble(cb, params)
  }

  getAltActionName   = @() amount && canConsume() && canAssemble() ? ::loc("item/assemble") : ""
  doAltAction        = @() assemble()

  function consume(cb, params)
  {
    if (!uids || !uids.len() || !metaBlk || !canConsume())
      return false

    local canSell = itemDef?.marketable
    local text = ::loc("recentItems/useItem", { itemName = ::colorize("activeTextColor", getName()) })
      + "\n" + ::loc("msgBox/coupon_exchange")
    local msgboxParams = {
      cancel_fn = @() null
      baseHandler = ::get_cur_base_gui_handler() //FIX ME: handler used only for prizes tooltips
      data_below_text = ::PrizesView.getPrizesListView([ metaBlk ], { showAsTrophyContent = true, widthByParentParent = true })
      data_below_buttons = canSell
        ? ::format("textarea{overlayTextColor:t='warning'; text:t='%s'}", ::g_string.stripTags(::loc("msgBox/coupon_will_be_spent")))
        : null
    }
    local item = this //we need direct link, to not lose action on items list refresh.
    ::scene_msg_box("coupon_exchange", null, text, [
      [ "yes", @() item.consumeImpl(cb, params) ],
      [ "no" ]
    ], "yes", msgboxParams)
    return true
  }

  function consumeImpl(cb = null, params = null)
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

  function assemble(cb = null, params = null)
  {
    if (!canAssemble())
      return false

    ExchangeRecipes.tryUse(getMyRecipes(), this)
    return true
  }

  function hasLink()
  {
    return !isDisguised && base.hasLink() && ::has_feature("Marketplace")
  }

  function addResources() {
    if (!metaBlk || !metaBlk.resource || !metaBlk.resourceType)
      return
    local resource = metaBlk.resource
    if (!guidParser.isGuid(resource))
      return

    ::g_decorator.buildUgcDecoratorFromResource(metaBlk.resource, metaBlk.resourceType, itemDef)
    ::add_rta_localization(metaBlk.resource, itemDef?.name ?? "")
  }

  function getRelatedRecipes()
  {
    local res = []
    foreach (genItemdefId in inventoryClient.getChestGeneratorItemdefIds(id))
    {
      local gen = ItemGenerators.get(genItemdefId)
      if (gen)
        res.extend(gen.getRecipesWithComponent(id))
    }
    return res
  }

  function getMyRecipes()
  {
    local gen = ItemGenerators.get(id)
    return gen ? gen.getRecipes() : []
  }

  function getTimeLeftText()
  {
    return ::colorize("badTextColor", base.getTimeLeftText())
  }

  function getCurExpireTimeText()
  {
    if (expireTimestamp == -1)
      return ""
    return ::colorize("badTextColor", ::loc("items/expireDate", {
      datetime = time.buildDateTimeStr(::get_time_from_t(expireTimestamp))
      timeleft = getTimeLeftText()
    }))
  }
}

return ItemExternal
