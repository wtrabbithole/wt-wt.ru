local kwarg = require("std/functools.nut").kwarg

local getArrowView = function(arrow, itemSizePrefix)
{
  if (arrow == null)
    return {}

  local arrowConfig = {}
  if (arrow.sizeX == 0)
    arrowConfig = {
      arrowType = "vertical"
      arrowSize = "1@modArrowWidth, 1@{intervalPrefix}raftTreeBlockInterval - 2@blockInterval + "
        + (arrow.sizeY-1) + "@{itemPrefix}temHeight"
      arrowPos  = "0.5@{0}temHeight - 0.5w, -h -1@blockInterval".subst(itemSizePrefix.itemPrefix)
    }
  else
    arrowConfig = {
      arrowType = "horizontal"
      arrowSize = "1@{intervalPrefix}raftTreeItemInterval - 2@blockInterval + "
        + (arrow.sizeX-1) + "@{itemPrefix}temHeight, 1@modArrowWidth"
      arrowPos  = "-w -1@blockInterval, 0.5ph - 0.5h"
    }

  arrowConfig.arrowSize = arrowConfig.arrowSize.subst({
    intervalPrefix = itemSizePrefix.intervalPrefix
    itemPrefix = itemSizePrefix.itemPrefix})
  return arrowConfig
}

local viewItemsParams = {
  showAction = false,
  showPrice = false,
  contentIcon = false,
  hasCraftTimer = false
}

local getItemBlockView = kwarg(function(itemBlock, itemsList, itemSizePrefix, allowableResources)
{
  local item = ::u.search(itemsList, @(i) i.id == itemBlock?.id)
  local reqItemId = ::to_integer_safe(itemBlock?.reqItem, null, false)
  local hasComponent = itemBlock?.showResources
  return {
    isDisabled = item != null && item.getAmount() == 0
      && (!item.hasUsableRecipeOrNotRecipes()
        || (reqItemId != null && (::u.search(itemsList, @(i) i.id == reqItemId)?.getAmount() ?? 0) == 0))
    items = [item?.getViewData(viewItemsParams)]
    shopArrow = getArrowView(itemBlock?.arrow, itemSizePrefix)
    hasComponent = hasComponent
    component = hasComponent
      ? item?.getDescRecipesMarkup({
          maxRecipes = 1
          needShowItemName = false
          needShowHeader = false
          isShowItemIconInsteadItemType = true
          visibleResources = allowableResources
        })
      : null
  }
})

local sizePrefixNames = {
  normal = {
    name = ""
    itemPrefix = "i"
    intervalPrefix = "c"
  },
  compact = {
    name = "compact"
    itemPrefix = "compactI"
    intervalPrefix = "compactC"
  },
  small = {
    name = "small"
    itemPrefix = "smallI"
    intervalPrefix = "smallC"
  }
}

local handlerClass = class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType          = handlerType.MODAL
  sceneTplName     = "gui/items/craftTreeWnd"
  branches         = null
  workshopSet      = null
  craftTree        = null

  function getSceneTplView()
  {
    craftTree = workshopSet.getCraftTree()
    if (craftTree == null)
      return null

    branches = craftTree.branches
    local itemSizePrefix = getItemSizePrefix()
    return {
      frameHeaderText = ::loc(craftTree.headerlocId)
      itemsSize = itemSizePrefix.name
      branchesView = getBranchesView(itemSizePrefix, craftTree.allowableResources)
    }
  }

  function getItemSizePrefix()
  {
    local itemsCountX = 0
    local columnWithResourcesCount = 0
    foreach(branch in branches)
    {
      itemsCountX += branch.itemsCountX
      columnWithResourcesCount += branch.columnWithResourcesCount
    }
    local branchesCount = branches.len()

    local maxAllowedCrafTreeWidth = ::to_pixels("1@maxWindowWidth - 2@frameHeaderPad + 1@scrollBarSize")
    local craftTreeWidthString = ("{itemsCount}(1@{itemPrefix}temHeight + 1@{intervalPrefix}raftTreeItemInterval) + "
      + "{branchesCount}@{intervalPrefix}raftTreeItemInterval + {columnWithResourcesCount}@craftTreeResourceWidth").subst({
        itemsCount = itemsCountX
        branchesCount = branchesCount
        columnWithResourcesCount = columnWithResourcesCount
      })

    return ::u.search(sizePrefixNames,
        @(prefix) ::to_pixels(craftTreeWidthString.subst({
            itemPrefix = prefix.itemPrefix
            intervalPrefix = prefix.intervalPrefix
          })) <= maxAllowedCrafTreeWidth)
      ?? sizePrefixNames.small
  }

  function getBranchesView(itemSizePrefix, allowableResources)
  {
    local lastBranchIdx = branches.len() - 1
    local itemsList = workshopSet.getItemsListForCraftTree(craftTree)
    local branchesView = branches.map((@(branch, idx) {
      branchHeader = ::loc(branch.locId)
      branchHeaderItems = {
        items = branch.headerItems.map(
          @(itemId) ::u.search(itemsList, @(item) item.id == itemId)?.getViewData(viewItemsParams)
        )
      }
      branchWidth = ("{itemsCount}(1@{itemPrefix}temHeight + 1@{intervalPrefix}raftTreeItemInterval)"
        + " + 1@{intervalPrefix}raftTreeItemInterval + {columnWithResourcesCount}@craftTreeResourceWidth"
        + (idx == lastBranchIdx ? "+ 1@scrollBarSize" : "")).subst({
          itemsCount = branch.itemsCountX
          columnWithResourcesCount = branch.columnWithResourcesCount
          itemPrefix = itemSizePrefix.itemPrefix,
          intervalPrefix = itemSizePrefix.intervalPrefix
      })
      separators = idx != 0
      rows = branch.rows.map(@(row) {
        itemBlock = row.map(@(itemBlock) getItemBlockView({
          itemBlock = itemBlock,
          itemsList = itemsList,
          itemSizePrefix = itemSizePrefix,
          allowableResources = allowableResources
        })
      )})
    }))
    return branchesView
  }
}

::gui_handlers.vehiclesModal <- handlerClass

return {
  open = @(craftTreeParams) ::handlersManager.loadHandler(handlerClass, craftTreeParams)
}