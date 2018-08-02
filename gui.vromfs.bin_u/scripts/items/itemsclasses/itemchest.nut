local inventoryClient = require("scripts/inventory/inventoryClient.nut")
local ItemExternal = require("scripts/items/itemsClasses/itemExternal.nut")
local ItemGenerators = require("scripts/items/itemsClasses/itemGenerators.nut")
local ExchangeRecipes = require("scripts/items/exchangeRecipes.nut")

class ::items_classes.Chest extends ItemExternal {
  static iType = itemType.CHEST
  static defaultLocId = "chest"
  static typeIcon = "#ui/gameuiskin#item_type_trophies"
  static openingCaptionLocId = "mainmenu/chestConsumed/title"
  static isPreferMarkupDescInTooltip = false
  static userlogOpenLoc = "open_trophy"
  static hasTopRewardAsFirstItem = false
  static includeInRecentItems = false
  static descReceipesListHeaderPrefix = "chest/requires/"

  _isInitialized = false
  generator = null

  function getGenerator()
  {
    if (!_isInitialized)
    {
      _isInitialized = true
      local genId = inventoryClient.getChestGeneratorItemdefIds(id)?[0]
      generator = genId && ItemGenerators.get(genId)
    }
    return generator
  }

  function getOpenedBigIcon()
  {
    return ""
  }

  canConsume = @() isInventoryItem

  function getMainActionName(colored = true, short = false)
  {
    return isCanBuy() ? getBuyText(colored, short)
      : isInventoryItem && amount ? ::loc("item/open")
      : ""
  }

  skipRoulette              = @() false
  isAllowSkipOpeningAnim    = @() ::is_dev_version
  getOpeningAnimId          = @() itemDef?.tags?.isLongOpenAnim ? "LONG" : "DEFAULT"
  getCantAssembleLocId      = @() "msgBox/chestOpen/cant"
  getAssembleMessageData    = @(recipe) getEmptyAssembleMessageData().__update({
    text = ::loc("msgBox/chestOpen/confirm", { itemName = ::colorize("activeTextColor", getName()) })
      + (recipe.isMultipleItems ? "\n" + ::loc("msgBox/extra_items_will_be_spent") : "")
    needRecipeMarkup = recipe.isMultipleItems
  })

  function getContent()
  {
    local generator = getGenerator()
    return generator ? generator.getContent() : []
  }

  getDescRecipesText    = @(params) ExchangeRecipes.getRequirementsText(getRelatedRecipes(), this, params)
  getDescRecipesMarkup  = @(params) ExchangeRecipes.getRequirementsMarkup(getRelatedRecipes(), this, params)

  function getDescription()
  {
    local params = { receivedPrizes = false }

    local content = getContent()
    local hasContent = content.len() != 0

    return ::g_string.implode([
      getTransferText(),
      getMarketablePropDesc(),
      getCurExpireTimeText(),
      getDescRecipesText(params),
      (hasContent ? ::PrizesView.getPrizesListText(content, _getDescHeader) : ""),
      getHiddenItemsDesc() || "",
    ], "\n")
  }

  function getLongDescription()
  {
    return ""
  }

  function getLongDescriptionMarkup(params = null)
  {
    params = params || {}
    params.receivedPrizes <- false

    local content = getContent()
    local hasContent = content.len() != 0

    return ::PrizesView.getPrizesListView([], { header = getTransferText() })
      + ::PrizesView.getPrizesListView([], { header = getMarketablePropDesc() })
      + (hasTimer() ? ::PrizesView.getPrizesListView([], { header = getCurExpireTimeText(), timerId = "expire_timer" }) : "")
      + getDescRecipesMarkup(params)
      + (hasContent ? ::PrizesView.getPrizesStacksView(content, _getDescHeader, params) : "")
      + (hasContent ? ::PrizesView.getPrizesListView([], { header = getHiddenItemsDesc() }) : "")
  }

  function _getDescHeader(fixedAmount = 1)
  {
    local locId = (fixedAmount > 1) ? "trophy/chest_contents/many" : "trophy/chest_contents"
    local headerText = ::loc(locId, { amount = ::colorize("commonTextColor", fixedAmount) })
    return ::colorize("grayOptionColor", headerText)
  }

  function getHiddenItemsDesc()
  {
    local generator = getGenerator()
    if (!generator || !generator.hasHiddenItems || !getContent().len())
      return null
    return ::colorize("grayOptionColor", ::loc("trophy/chest_contents/other"))
  }

  function getHiddenTopPrizeParams()
  {
    local generator = getGenerator()
    return generator ? generator.hiddenTopPrizeParams : null
  }

  function isHiddenTopPrize(prize)
  {
    local generator = getGenerator()
    return generator != null && generator.isHiddenTopPrize(prize)
  }

  function doMainAction(cb, handler, params = null)
  {
    if (buy(cb, handler, params))
      return true
    if (!uids || !uids.len())
      return false

    return ExchangeRecipes.tryUse(getRelatedRecipes(), this, params)
  }
}