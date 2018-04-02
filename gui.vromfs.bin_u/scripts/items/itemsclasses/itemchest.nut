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

  function canConsume()
  {
    return true
  }

  function getMainActionName(colored = true, short = false)
  {
    return amount ? ::loc("item/open") : ""
  }

  function skipRoulette()
  {
    return false
  }

  function isAllowSkipOpeningAnim()
  {
    return ::is_dev_version
  }

  function getContent()
  {
    local generator = getGenerator()
    return generator ? generator.getContent() : []
  }

  function getDescription()
  {
    local params = { receivedPrizes = false }

    local content = getContent()
    local hasContent = content.len() != 0

    return ::g_string.implode([
      getMarketablePropDesc(),
      getCurExpireTimeText(),
      ExchangeRecipes.getRequirementsText(getRelatedRecipes(), this, params),
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

    return ::PrizesView.getPrizesListView([], { header = getMarketablePropDesc() })
      + (hasTimer() ? ::PrizesView.getPrizesListView([], { header = getCurExpireTimeText() }) : "")
      + ExchangeRecipes.getRequirementsMarkup(getRelatedRecipes(), this, params)
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
    if (!uids || !uids.len())
      return false

    return ExchangeRecipes.tryUse(getRelatedRecipes(), this)
  }
}