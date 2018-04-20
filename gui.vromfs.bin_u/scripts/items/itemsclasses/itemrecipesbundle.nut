local ItemGenerators = require("scripts/items/itemsClasses/itemGenerators.nut")
local ExchangeRecipes = require("scripts/items/exchangeRecipes.nut")

class ::items_classes.RecipesBundle extends ::items_classes.Chest {
  static iType = itemType.RECIPES_BUNDLE
  static defaultLocId = "recipes_bundle"
  static typeIcon = "#ui/gameuiskin#items_blueprint"
  static openingCaptionLocId = "mainmenu/itemCreated/title"

  isDisassemble         = @() itemDef?.tags?.isDisassemble == true
  updateNameLoc         = @(locName) isDisassemble() ? ::loc("item/disassemble_header", { name = locName })
    : base.updateNameLoc(locName)

  canConsume            = @() false
  shouldShowAmount      = @(count) false
  getMaxRecipesToShow   = @() 1
  getMarketablePropDesc = @() ""

  getGenerator          = @() ItemGenerators.get(id) //recipes bundle created by generator, so has same id
  getDescRecipesText    = @(params) ExchangeRecipes.getRequirementsText(getMyRecipes(), this, params)
  getDescRecipesMarkup  = @(params) ExchangeRecipes.getRequirementsMarkup(getMyRecipes(), this, params)

  function _getDescHeader(fixedAmount = 1)
  {
    local locId = (fixedAmount > 1) ? "trophy/recipe_result/many" : "trophy/recipe_result"
    local headerText = ::loc(locId, { amount = ::colorize("commonTextColor", fixedAmount) })
    return ::colorize("grayOptionColor", headerText)
  }

  function getDescRecipeListHeader(showAmount, totalAmount, isMultipleExtraItems)
  {
    if (!isDisassemble())
      return base.getDescRecipeListHeader(showAmount, totalAmount, isMultipleExtraItems)

    local locId = totalAmount == 1 ? "item/disassemble_recipes/single" : "item/disassemble_recipes"
    return ::loc(locId,
      {
        count = totalAmount
        countColored = ::colorize("activeTextColor", totalAmount)
        exampleCount = showAmount
      })
  }

  getAssembleHeader     = @() isDisassemble() ? getName() : base.getAssembleHeader()
  getAssembleText       = @() isDisassemble() ? ::loc("item/disassemble") : ::loc("item/assemble")
  getCantAssembleLocId  = @() isDisassemble() ? "msgBox/disassembleItem/cant" : "msgBox/assembleItem/cant"
  getAssembleMessageData    = @(recipe) !isDisassemble() ? base.getAssembleMessageData(recipe)
    : getEmptyAssembleMessageData().__update({
        text = ::loc("msgBox/disassembleItem/confirm")
        needRecipeMarkup = true
      })

  getMainActionName     = @(colored = true, short = false) canAssemble() ? getAssembleText() : ""
  doMainAction          = @(cb, handler, params = null) assemble(cb, params)
}