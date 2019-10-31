::dagui_propid.add_name_id("itemId")

local branchIdPrefix = "branch_"
local getBranchId = @(idx) "".concat(branchIdPrefix, idx)
local posFormatString = "{0}, {1}"

local sizeAndPosViewConfig = {
  verticalArrow = ::kwarg(
    function verticalArrow(itemSizes, arrowSizeX, arrowSizeY, arrowPosX, arrowPosY) {
      local w = itemSizes.arrowWidth
      local h = itemSizes.itemBlockInterval + (arrowSizeY - 1)*itemSizes.itemHeight
        - 2*itemSizes.blockInterval
      return {
        arrowType = "vertical"
      arrowSize = posFormatString.subst(w, h)
      arrowPos = posFormatString.subst(
        (arrowPosX - 0.5)*itemSizes.itemHeight + arrowPosX*itemSizes.itemInterval
          + itemSizes.columnOffests[arrowPosX - 1] - 0.5*w,
        (arrowPosY - 1)*(itemSizes.itemHeight + itemSizes.itemBlockInterval)
          + itemSizes.itemHeight + itemSizes.headerBlockInterval + itemSizes.blockInterval)
      }
  })
  horizontalArrow = ::kwarg(
    function horizontalArrow(itemSizes, arrowSizeX, arrowSizeY, arrowPosX, arrowPosY) {
      local w = itemSizes.itemInterval + (arrowSizeX - 1)*itemSizes.itemHeight
        - 2*itemSizes.blockInterval
      local h = itemSizes.arrowWidth
      return {
        arrowType = "horizontal"
        arrowSize = posFormatString.subst(w, h)
        arrowPos = posFormatString.subst(
          (arrowPosX)*itemSizes.itemHeight + arrowPosX*itemSizes.itemInterval
            + itemSizes.columnOffests[arrowPosX - 1] + itemSizes.blockInterval,
          (arrowPosY - 1)*(itemSizes.itemHeight + itemSizes.itemBlockInterval)
            + 0.5*itemSizes.itemHeight  + itemSizes.headerBlockInterval - 0.5*h)
        }
  })
  conectionInRow = ::kwarg(function conectionInRow(itemSizes, itemPosX, itemPosY) {
    local w = itemSizes.itemInterval
    return {
      conectionWidth = w
      conectionPos = posFormatString.subst(
        itemPosX*itemSizes.itemHeight + itemPosX*itemSizes.itemInterval
          + itemSizes.columnOffests[itemPosX],
        "{0} - 0.5h".subst(itemPosY*(itemSizes.itemHeight + itemSizes.itemBlockInterval)
          + 0.5*itemSizes.itemHeight  + itemSizes.headerBlockInterval))
    }
  })
  itemPos = ::kwarg(function itemPos(itemSizes, itemPosX, itemPosY) {
    return posFormatString.subst(
      itemPosX*itemSizes.itemHeight + itemPosX*itemSizes.itemInterval
        + itemSizes.itemInterval + itemSizes.columnOffests[itemPosX],
      itemPosY*(itemSizes.itemHeight + itemSizes.itemBlockInterval) + itemSizes.headerBlockInterval)
  })
}

local sucessItemCraftIconParam = {
  amountIcon = "#ui/gameuiskin#check.svg"
  amountIconColor = "@goodTextColor"
}

local function needReqItemsForCraft(itemBlock, itemsList)
{
  local reqItems = itemBlock?.reqItem != null ? [itemBlock.reqItem] : itemBlock?.reqItems
  if (!reqItems)
    return false

  foreach(reqItemId in reqItems)
    if (reqItemId != null && (itemsList?[reqItemId].getAmount() ?? 0) == 0)
      return true

  return false
}

local function getConfigByItemBlock(itemBlock, itemsList)
{
  local item = itemsList?[itemBlock?.id]
  local hasComponent = itemBlock?.showResources
  local itemId = item?.id ?? "-1"
  local needReqItem = needReqItemsForCraft(itemBlock, itemsList)
  return {
    item = item
    hasComponent = hasComponent
    itemId = itemId
    needReqItem = needReqItem
    isDisabled = item != null && item.getAmount() == 0
      && (!item.hasUsableRecipeOrNotRecipes() || needReqItem)
    iconInsteadAmount = item?.hasReachedMaxAmount() ? sucessItemCraftIconParam : null
  }
}

local getArrowView = ::kwarg(function getArrowView(arrow, itemSizes) {
  local arrowType = arrow.sizeX == 0 ? "verticalArrow" : "horizontalArrow"
  local arrowParam = {
    itemSizes = itemSizes
    arrowSizeX = arrow.sizeX
    arrowSizeY = arrow.sizeY
    arrowPosX = arrow.posX
    arrowPosY = arrow.posY
  }
  return sizeAndPosViewConfig[arrowType](arrowParam)
})

local function getConnectingElementsView(rows, itemSizes, itemsList)
{
  local shopArrows = []
  local conectionsInRow = []
  foreach (row in rows)
  {
    local hasPrevItemInRow = false
    local prevBranchIdx = 0
    foreach (idx, itemBlock in row)
    {
      local itemConfig = getConfigByItemBlock(itemBlock, itemsList)
      local arrow = itemBlock?.arrow
      if (arrow != null)
        shopArrows.append({ isDisabled = itemConfig.isDisabled }.__update(
          getArrowView({
            arrow = arrow
            itemSizes = itemSizes
          })))


      local hasCurItem = itemConfig.item != null
      if (hasPrevItemInRow && hasCurItem)
      {
        local itemPosX = itemBlock.posXY.x - 1
        local curBranchIdx = itemSizes.columnBranchIdx[itemPosX]
        if (prevBranchIdx == curBranchIdx)
          conectionsInRow.append(sizeAndPosViewConfig.conectionInRow({
            itemSizes = itemSizes
            itemPosX = itemPosX
            itemPosY = itemBlock.posXY.y - 1
          }))
        prevBranchIdx = curBranchIdx
      }
      hasPrevItemInRow = hasCurItem
    }
  }
  return {
    shopArrows = shopArrows
    conectionsInRow = conectionsInRow
  }
}


local viewItemsParams = {
  showAction = false,
  showButtonInactiveIfNeed = true,
  showPrice = false,
  contentIcon = false
  shouldHideAdditionalAmmount = true
  count = -1
}

local getItemBlockView = ::kwarg(
  function getItemBlockView(itemBlock, itemsList, itemSizes, allowableResources) {
    local itemConfig = getConfigByItemBlock(itemBlock, itemsList)
    local item = itemConfig.item
    if (item == null)
      return null

    local overridePos = itemBlock?.overridePos
    return {
      isDisabled = itemConfig.isDisabled
      itemId = itemConfig.itemId
      items = [item.getViewData(viewItemsParams.__merge({
        itemIndex = itemConfig.itemId,
        showAction = !itemConfig.needReqItem
        iconInsteadAmount = itemConfig.iconInsteadAmount
        count = item.getAdditionalTextInAmmount(true, true)
      }))]
      blockPos = overridePos ?? sizeAndPosViewConfig.itemPos({
        itemSizes = itemSizes
        itemPosX = itemBlock.posXY.x - 1
        itemPosY = itemBlock.posXY.y - 1
      })
      hasComponent = itemConfig.hasComponent
      isFullSize = itemBlock?.isFullSize ?? false
      component = itemConfig.hasComponent
        ? item.getDescRecipesMarkup({
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

local function getHeaderView (headerItems, localItemsList, baseEff)
{
  local getItemEff = function(item)
  {
    return item?.getAmount() ? item.getBoostEfficiency() ?? 0 : 0
  }
  local items = []
  local totalEff = baseEff
  local itemsEff = [baseEff]
  foreach(id in headerItems)
  {
    local item = localItemsList?[id]
    if(!item)
      continue
    local eff = getItemEff(item)
    items.append(item.getViewData(viewItemsParams.__merge({
      hasBoostEfficiency = true
      iconInsteadAmount = item.hasReachedMaxAmount() ? sucessItemCraftIconParam : null
    })))
    totalEff += eff
    itemsEff.append(eff)
  }

  return {
    items = items
    totalEfficiency = ::colorize(totalEff == 100
      ? "activeTextColor" : totalEff < 100
      ? "badTextColor" : "goodTextColor",  totalEff + ::loc("measureUnits/percent"))
    itemsEfficiency = ::loc("ui/parentheses/space", { text = ::g_string.implode (itemsEff, "+")})
  }
}

local function getBranchSeparator(branch, itemSizes, branchHeight) {
  local posX = branch.minPosX -1
  if (posX == 0)
    return null

  return {
    separatorPos = posFormatString.subst(posX*(itemSizes.itemHeight + itemSizes.itemInterval)
        + itemSizes.columnOffests[posX],
      "3@dp")
    separatorSize = posFormatString.subst("1@dp", "{0} - 6@dp".subst(branchHeight))
  }
}

local handlerClass = class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType          = handlerType.MODAL
  sceneTplName     = "gui/items/craftTreeWnd"
  focusArray       = ["craft_body"]
  currentFocusItem = 0
  branches         = null
  workshopSet      = null
  craftTree        = null
  itemsList        = null
  itemSizes        = null
  itemsListObj     = null

  function getSceneTplView()
  {
    craftTree = workshopSet.getCraftTree()
    if (craftTree == null)
      return null

    branches = craftTree.branches
    itemsList = workshopSet.getItemsListForCraftTree(craftTree)
    itemSizes = getItemSizes()
    return {
      frameHeaderText = ::loc(craftTree.headerlocId)
      itemsSize = itemSizes.name
      headersView = getHeadersView()
    }.__update(getBodyView())
  }

  function initScreen()
  {
    scene.findObject("update_timer").setUserData(this)
    itemsListObj = scene.findObject("craft_body")
    restoreFocus()
    setFocusItem()
  }

  function getItemSizes()
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
    local resourceWidth = ::to_pixels("1@craftTreeResourceWidth")
    local craftTreeWidthString = ("{itemsCount}(1@{itemPrefix}temHeight + 1@{intervalPrefix}raftTreeItemInterval) + "
      + "{branchesCount}@{intervalPrefix}raftTreeItemInterval + {allColumnResourceWidth}").subst({
        itemsCount = itemsCountX
        branchesCount = branchesCount
        allColumnResourceWidth = columnWithResourcesCount * resourceWidth
      })

    local sizes = ::u.search(sizePrefixNames,
        @(prefix) ::to_pixels(craftTreeWidthString.subst({
            itemPrefix = prefix.itemPrefix
            intervalPrefix = prefix.intervalPrefix
          })) <= maxAllowedCrafTreeWidth)
      ?? sizePrefixNames.small
    local itemInterval = ::to_pixels("1@{0}raftTreeItemInterval)".subst(sizes.intervalPrefix))
    local columnOffests = []
    local columnBranchIdx =[]
    foreach(paramsColumn in craftTree.paramsForPosByColumns)
    {
      columnOffests.append(paramsColumn.branchIdx * itemInterval
        + paramsColumn.prevResourcesCount * resourceWidth)
      columnBranchIdx.append(paramsColumn.branchIdx)
    }
    return sizes.__update({
      itemHeight = ::to_pixels("1@{0}temHeight".subst(sizes.itemPrefix))
      itemHeightFull = ::to_pixels("1@itemHeight")
      itemInterval = itemInterval
      itemBlockInterval = ::to_pixels("1@{0}raftTreeBlockInterval".subst(sizes.intervalPrefix))
      resourceWidth = resourceWidth
      scrollBarSize = ::to_pixels("1@scrollBarSize")
      arrowWidth = ::to_pixels("1@modArrowWidth")
      headerBlockInterval = ::to_pixels("1@headerAndCraftTreeBlockInterval")
      blockInterval = ::to_pixels("1@blockInterval")
      columnOffests = columnOffests
      columnBranchIdx = columnBranchIdx
    })
  }

  getBranchWidth = @(branch, hasScrollBar) branch.itemsCountX * (itemSizes.itemHeight + itemSizes.itemInterval)
      + itemSizes.itemInterval + branch.columnWithResourcesCount * itemSizes.resourceWidth
      + (hasScrollBar ? itemSizes.scrollBarSize : 0)

  function getHeadersView()
  {
    local lastBranchIdx = branches.len() - 1
    local baseEff = craftTree.baseEfficiency
    local headerItemsTitle = craftTree?.headerItemsTitle ? ::loc(craftTree.headerItemsTitle) : null
    local bodyItemsTitle = craftTree?.bodyItemsTitle ? ::loc(craftTree.bodyItemsTitle) : null
    local headersView = branches.map((@(branch, idx) {
      branchHeader = ::loc(branch.locId)
      headerItemsTitle = idx == lastBranchIdx ? headerItemsTitle : ""
      bodyItemsTitle = idx == lastBranchIdx ? bodyItemsTitle : ""
      positionsTitleX = 0
      branchId = getBranchId(idx)
      branchHeaderItems = getHeaderView(branch.headerItems, itemsList, baseEff)
      branchWidth = getBranchWidth(branch, idx == lastBranchIdx)
      separators = idx != 0
    }).bindenv(this))

    local totalWidth = headersView.map(@(branch) branch.branchWidth).reduce(@(res, value) res + value)
    local positionsTitleXLastBranch = "{widthLastBranch} - 0.5*{totalWidth} - 0.5w".subst({
      totalWidth = totalWidth
      widthLastBranch = headersView[lastBranchIdx].branchWidth
    })
    headersView[lastBranchIdx].positionsTitleX = positionsTitleXLastBranch
    return headersView
  }

  function getBodyView()
  {
    local rows = craftTree.treeRows
    local allowableResources = craftTree.allowableResources
    local itemBlocksArr = []
    foreach (row in rows)
      foreach (itemBlock in row)
      {
        local itemBlockView = getItemBlockView({
          itemBlock = itemBlock,
          itemsList = itemsList,
          itemSizes = itemSizes,
          allowableResources = allowableResources
        })
        if (itemBlockView != null)
          itemBlocksArr.append(itemBlockView)
      }

    local bodyHeightWithoutResult = rows.len()*(itemSizes.itemHeight + itemSizes.itemBlockInterval)
      + itemSizes.headerBlockInterval
    local bodyWidth = 0
    local separators = []
    local lastBranchIdx = branches.len() - 1
    foreach (idx, branch in branches)
    {
      bodyWidth += getBranchWidth(branch, idx == lastBranchIdx)
      separators.append(getBranchSeparator(branch, itemSizes, bodyHeightWithoutResult))
    }

    local craftResult = craftTree?.craftResult
    local hasCraftResult = craftResult != null
    if (hasCraftResult)
    {
      itemBlocksArr.append(getItemBlockView({
        itemBlock = craftResult.__merge({
          showResources = true
          isFullSize = true
          overridePos = posFormatString.subst(0.5*bodyWidth - 0.5*(itemSizes.itemHeightFull + itemSizes.resourceWidth),
            bodyHeightWithoutResult + itemSizes.headerBlockInterval)
        }),
        itemsList = itemsList,
        itemSizes = itemSizes,
        allowableResources = craftTree.allowableResources
      }))

      separators.append({
        separatorPos = posFormatString.subst("0.5pw - 0.5w", bodyHeightWithoutResult)
        separatorSize = posFormatString.subst(bodyWidth, "1@dp")
      })
    }
    return {
      connectingElements = getConnectingElementsView(rows, itemSizes, itemsList)
      bodyHeight = bodyHeightWithoutResult
        + (hasCraftResult
          ? (itemSizes.headerBlockInterval + itemSizes.itemHeightFull + itemSizes.itemBlockInterval)
          : 0)
      bodyWidth = bodyWidth
      separators = separators
      itemBlock = itemBlocksArr
    }
  }

  function findItemObj(itemId)
  {
    return scene.findObject("shop_item_" + itemId)
  }

  function onItemAction(buttonObj)
  {
    local id = buttonObj?.holderId ?? "-1"
    local item = itemsList?[id.tointeger()]
    local itemObj = findItemObj(id)
    setFocusItem(item)
    doMainAction(item, itemObj)
  }

  function onMainAction()
  {
    local curItemParam = getCurItemParam()
    local item = curItemParam.item
    local itemObj = curItemParam.obj
    if (item == null)
      return

    local itemBlock = craftTree?.craftResult.id == item.id
      ? craftTree.craftResult
      : null
    if (itemBlock == null)
      foreach(branche in branches)
      {
        itemBlock = branche.branchItems?[item.id]
        if (itemBlock != null)
          break
      }

    if (needReqItemsForCraft(itemBlock, itemsList))
      return

    doMainAction(item, itemObj)
  }

  function doMainAction(item, obj)
  {
    if (item == null)
      return

    item.doMainAction(null, this, { obj = obj, isHidePrizeActionBtn = true })
  }

  function getCurItemParam()
  {
    local value = ::get_obj_valid_index(itemsListObj)
    if (value < 0)
      return {
        obj = null
        item = null
      }

    local itemObj = itemsListObj.getChild(value)
    return {
      obj = itemObj
      item = itemsList?[(itemObj?.itemId ?? "-1").tointeger()]
    }
  }

  function onTimer(obj, dt)
  {
    foreach(item in itemsList)
    {
      if (!item.hasTimer())
        continue

      local itemObj = findItemObj(item.id)
      if (!::check_obj(itemObj))
        continue
      local timeTxtObj = itemObj.findObject("expire_time")
      if (::check_obj(timeTxtObj))
        timeTxtObj.setValue(item.getTimeLeftText())
      timeTxtObj = itemObj.findObject("craft_time")
      if (::check_obj(timeTxtObj))
        timeTxtObj.setValue(item.getCraftTimeTextShort())
    }
  }

  function updateCraftTree()
  {
    local curItemParam = getCurItemParam()

    craftTree = workshopSet.getCraftTree() ?? craftTree
    branches = craftTree.branches
    itemsList = workshopSet.getItemsListForCraftTree(craftTree)
    getItemSizes()
    scene.findObject("wnd_title").setValue(::loc(craftTree.headerlocId))

    local view = {
      itemsSize = itemSizes.name
      headersView = getHeadersView()
    }
    local data = ::handyman.renderCached("gui/items/craftTreeHeader", view)
    guiScene.replaceContentFromText(scene.findObject("craft_header"), data, data.len(), this)

    view = getBodyView()
    data = ::handyman.renderCached("gui/items/craftTreeBody", view)
    guiScene.replaceContentFromText(itemsListObj, data, data.len(), this)
    setFocusItem(curItemParam.item)
  }

  function setFocusItem(curItem = null)
  {
    local curItemId = curItem?.id.tostring() ?? ""
    local enabledValue = null
    for(local i = 0; i < itemsListObj.childrenCount(); i++)
    {
      local childObj = itemsListObj.getChild(i)
      if (enabledValue == null && childObj.isEnabled())
        enabledValue = i
      if (childObj?.itemId != curItemId)
        continue

      itemsListObj.setValue(i)
      return
    }
    if (enabledValue != null)
      itemsListObj.setValue(enabledValue)
  }

  function onEventInventoryUpdate(p)
  {
    doWhenActiveOnce("updateCraftTree")
  }

  function onEventProfileUpdated(p)
  {
    doWhenActiveOnce("updateCraftTree")
  }
}

::gui_handlers.vehiclesModal <- handlerClass

return {
  open = @(craftTreeParams) ::handlersManager.loadHandler(handlerClass, craftTreeParams)
}