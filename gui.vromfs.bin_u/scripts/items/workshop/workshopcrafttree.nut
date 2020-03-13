local inventoryClient = require("scripts/inventory/inventoryClient.nut")

local DEFAULT_BRANCH_CONFIG = {
  locId = ""
  minPosX = 1
  maxPosX = 1
  itemsCountX = 1
  columnWithResourcesCount = 0
  headerItems = []
  rows = []
  branchItems = {}
}

local function getHeaderItems(branchBlk)
{
  local headerItems = branchBlk?.headerItems
  return headerItems != null ? (headerItems % "headerItem") : []
}

local function getArrowConfigByItems(item, reqItem)
{
  local reqItemPos = reqItem.posXY
  local itemPos = item.posXY
  return {
    posX = reqItemPos.x
    posY = reqItemPos.y
    sizeX = itemPos.x - reqItemPos.x
    sizeY  = itemPos.y - reqItemPos.y
  }
}

local function generateRows(branchBlk, treeRows)
{
  local branchItems = {}
  local notFoundReqForItems = {}
  local minPosX = null
  local maxPosX = null
  local resourcesInColumn = {}
  for(local i = 0; i < branchBlk.blockCount(); i++)
  {
    local iBlk = branchBlk.getBlock(i)
    local id = iBlk.getBlockName()
    id = ::to_integer_safe(id, id, false)
    if (!::ItemsManager.isItemdefId(id))
      continue

    local itemConfig = ::buildTableFromBlk(iBlk)
    itemConfig.id <- id
    itemConfig.reqItem <- itemConfig?.reqItem.tointeger()
    local posX = itemConfig.posXY.x.tointeger()
    local posY = itemConfig.posXY.y.tointeger()
    minPosX = ::min(minPosX ?? posX, posX)
    maxPosX = ::max(maxPosX ?? posX, posX)
    if (itemConfig?.showResources && resourcesInColumn?[posX] == null)
      resourcesInColumn[posX] <- 1
    local reqItem = itemConfig.reqItem
    if (reqItem != null)
    {
      if (branchItems?[reqItem] != null)
        itemConfig.arrow <- getArrowConfigByItems(itemConfig, branchItems[reqItem])
      else
        notFoundReqForItems[id] <- itemConfig
    }

    if (treeRows.len() < posY)
      treeRows.resize(posY, array(posX, null))

    if (treeRows[posY-1].len() < posX)
      treeRows[posY-1].resize(posX, null)

    branchItems[id] <- itemConfig
    treeRows[posY-1][posX-1] = itemConfig
  }

  local searchReqForItems = clone notFoundReqForItems
  foreach(id, itemConfig in searchReqForItems)
  {
    local reqItem = itemConfig.reqItem
    if (!(reqItem in branchItems))
      continue

    itemConfig.arrow <- getArrowConfigByItems(itemConfig, branchItems[reqItem])
    branchItems[id] = itemConfig
    treeRows[itemConfig.posXY.y-1][itemConfig.posXY.x-1] = itemConfig
    notFoundReqForItems.rawdelete(id)
  }

  if (notFoundReqForItems.len() > 0)
  {
    local craftTreeName = branchBlk?.locId ?? ""  // warning disable: -declared-never-used
    local reqItems = ::g_string.implode(notFoundReqForItems.map(@(item) item.reqItem).values(), "; ") // warning disable: -declared-never-used
    ::script_net_assert_once("Not found reqItems for craftTree", "Error: Not found reqItems")
  }

  minPosX = minPosX ?? 0
  maxPosX = maxPosX ?? 0
  return {
    treeRows = treeRows
    branch = DEFAULT_BRANCH_CONFIG.__merge({
      locId = branchBlk?.locId ?? ""
      headerItems = getHeaderItems(branchBlk)
      minPosX = minPosX
      maxPosX = maxPosX
      itemsCountX = maxPosX - minPosX + 1
      branchItems = branchItems
      resourcesInColumn = resourcesInColumn
      columnWithResourcesCount = resourcesInColumn.reduce(@(res, value) res + value, 0)
    })
  }
}

local function getAllowableResources(resourcesBlk)
{
  if (resourcesBlk == null)
    return null

  local allowableResources = {}
  foreach(res in (resourcesBlk % "allowableResource"))
    allowableResources[::to_integer_safe(res, res, false)] <- true

  return allowableResources
}

local function getCraftResult(treeBlk)
{
  local craftResult = treeBlk?.craftResult
  if (!craftResult || !craftResult?.item)
    return null

  local reqItems = craftResult?.reqItems ?? ""
  return {
    id = craftResult.item
    reqItems = reqItems.split(",").map(@(item) item.tointeger())
  }
}

local function generateTreeConfig(blk)
{
  local branches = []
  local treeRows = []
  foreach(branchBlk in blk % "treeBlock")
  {
    local configByBranch = generateRows(branchBlk, treeRows)
    treeRows = configByBranch.treeRows
    branches.append(DEFAULT_BRANCH_CONFIG.__merge(configByBranch.branch))
  }

  branches.sort(@(a, b) a.minPosX <=> b.minPosX)

  local craftResult = getCraftResult(blk)
  local treeColumnsCount = 0
  local resourcesInColumn = {}
  local branchIdxByColumns = {}
  local craftTreeItemsIdArray = []
  if (craftResult != null)
    craftTreeItemsIdArray.append(craftResult.id)
  foreach (idx, branch in branches)
  {
     branchIdxByColumns[branch.minPosX-1] <- idx
     craftTreeItemsIdArray.extend(branch.branchItems.keys()).extend(branch.headerItems)
     resourcesInColumn.__update(branch.resourcesInColumn)
     treeColumnsCount += branch.itemsCountX
  }
  local paramsForPosByColumns = array(treeColumnsCount, null)
  local resourcesCount = 0
  local curBranchIdx = 0
  foreach(idx, column in paramsForPosByColumns)
  {
    curBranchIdx = branchIdxByColumns?[idx] ?? curBranchIdx
    paramsForPosByColumns[idx] = { branchIdx = curBranchIdx,
      prevResourcesCount = resourcesCount }
    resourcesCount += (resourcesInColumn?[idx+1] ?? 0)
  }

  if (craftTreeItemsIdArray.len() > 0)   //request items by itemDefId for craft tree
    inventoryClient.requestItemdefsByIds(craftTreeItemsIdArray)

  return {
    headerlocId = blk?.main_header ?? ""
    headerItemsTitle = blk?.headerItemsTitle
    bodyItemsTitle = blk?.bodyItemsTitle
    openButtonLocId = blk?.openButtonLocId ?? ""
    allowableResources = getAllowableResources(blk?.allowableResources)
    craftTreeItemsIdArray = craftTreeItemsIdArray
    branches = branches
    treeRows = treeRows
    reqFeaturesArr = blk?.reqFeature != null ? (blk.reqFeature).split(",") : []
    baseEfficiency = blk?.baseEfficiency.tointeger() ?? 0
    craftResult = craftResult
    paramsForPosByColumns = paramsForPosByColumns
  }
}

return generateTreeConfig