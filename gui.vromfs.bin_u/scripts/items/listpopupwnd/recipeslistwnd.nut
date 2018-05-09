local ExchangeRecipes = ::require("scripts/items/exchangeRecipes.nut")
local u = ::require("std/u.nut")

local MIN_ITEMS_IN_ROW = 7

class ::gui_handlers.RecipesListWnd extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneTplName = "gui/items/recipesListWnd"

  recipesList = null
  curRecipe = null

  headerText = ""
  buttonText = "#item/assemble"
  onAcceptCb = null //if return true, recipes list will not close.
  alignObj = null
  align = "bottom"

  function getSceneTplView()
  {
    recipesList = clone recipesList
    recipesList.sort(@(a, b) b.isUsable <=> a.isUsable || a.uid <=> b.uid)
    curRecipe = recipesList[0]

    local maxRecipeLen = 1
    foreach(r in recipesList)
      maxRecipeLen = ::max(maxRecipeLen, r.components.len())

    local recipeWidthPx = maxRecipeLen * ::to_pixels("0.5@itemWidth")
    local recipeHeightPx = ::to_pixels("0.5@itemHeight")
    local minColumns = ::ceil(MIN_ITEMS_IN_ROW.tofloat() / maxRecipeLen).tointeger()
    local columns = ::max(minColumns,
      ::calc_golden_ratio_columns(recipesList.len(), recipeWidthPx / (recipeHeightPx || 1)))
    local rows = ::ceil(recipesList.len().tofloat() / columns).tointeger()

    local itemsInRow = 0 //some columns are thinner than max
    local columnWidth = 0
    foreach(i, recipe in recipesList)
    {
      columnWidth = ::max(columnWidth, recipe.components.len())
      if ((i + 1) % (rows + 1))
        continue
      itemsInRow += columnWidth
      columnWidth = 0
      recipesList.insert(i, { isSeparator = true })
    }
    itemsInRow += columnWidth

    local res = {
      maxRecipeLen = maxRecipeLen
      recipesList = recipesList
      columns = columns
      rows = rows
      itemsInRow = ::max(itemsInRow, MIN_ITEMS_IN_ROW)
    }

    foreach(key in ["headerText", "buttonText"])
      res[key] <- this[key]
    return res
  }

  function initScreen()
  {
    align = ::g_dagui_utils.setPopupMenuPosAndAlign(alignObj, align, scene.findObject("main_frame"))

    scene.findObject("recipes_list").select()
    updateCurRecipeInfo()
  }

  function updateCurRecipeInfo()
  {
    local infoObj = scene.findObject("selected_recipe_info")
    local markup = curRecipe ? curRecipe.getTextMarkup() : ""
    guiScene.replaceContentFromText(infoObj, markup, markup.len(), this)

    scene.findObject("btn_apply").inactiveColor = curRecipe?.isUsable ? "no" : "yes"
  }

  function onRecipeSelect(obj)
  {
    local newRecipe = recipesList?[obj.getValue()]
    if (!u.isRecipe(newRecipe) || newRecipe == curRecipe)
      return
    curRecipe = newRecipe
    updateCurRecipeInfo()
  }

  function onRecipeApply()
  {
    local needLeaveWndOpen = false
    if (curRecipe && onAcceptCb)
      needLeaveWndOpen = onAcceptCb(curRecipe)
    if (!needLeaveWndOpen)
      goBack()
  }
}

return {
  open = function(params) {
    local recipesList = params?.recipesList
    if (!recipesList || !recipesList.len())
      return
    ::handlersManager.loadHandler(::gui_handlers.RecipesListWnd, params)
  }
}