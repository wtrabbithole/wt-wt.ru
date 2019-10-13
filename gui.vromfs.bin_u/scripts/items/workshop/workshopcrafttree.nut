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

local function generateRows(branchBlk)
{
  local branchItems = {}
  local notFoundReqForItems = {}
  local rows = []
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
    local posX = itemConfig.posXY.x
    local posY = itemConfig.posXY.y
    minPosX = ::min(minPosX ?? posX, posX)
    maxPosX = ::max(maxPosX ?? posX, posX)
    if (itemConfig?.showResources && resourcesInColumn?[posX] == null)
      resourcesInColumn[posX] <- 1
    local reqItem = itemConfig?.reqItem.tointeger()
    if (reqItem != null)
    {
      if (branchItems?[reqItem] != null)
        itemConfig.arrow <- getArrowConfigByItems(itemConfig, branchItems[reqItem])
      else
        notFoundReqForItems[id] <- itemConfig
    }

    if (rows.len() < posY)
      rows.resize(posY, array(posX, null))

    if (rows[posY-1].len() < posX)
      rows[posY-1].resize(posX, null)

    branchItems[id] <- itemConfig
    rows[posY-1][posX-1] = itemConfig
  }

  local searchReqForItems = clone notFoundReqForItems
  foreach(id, itemConfig in searchReqForItems)
  {
    local reqItem = itemConfig.reqItem.tointeger()
    if (!(reqItem in branchItems))
      continue

    itemConfig.arrow <- getArrowConfigByItems(itemConfig, branchItems[reqItem])
    branchItems[id] = itemConfig
    rows[itemConfig.posXY.y-1][itemConfig.posXY.x-1] = itemConfig
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
    rows = rows.map(@(row) row.slice(minPosX-1, maxPosX))
    minPosX = minPosX
    maxPosX = maxPosX
    itemsCountX = maxPosX - minPosX + 1
    branchItems = branchItems
    columnWithResourcesCount = resourcesInColumn.reduce(@(res, value) res + value, 0)
  }
}

local function createBranch(branchBlk)
{
  local branch = DEFAULT_BRANCH_CONFIG.__merge({
    locId = branchBlk?.locId ?? ""
  })

  branch.headerItems = getHeaderItems(branchBlk)
  return branch.__update(generateRows(branchBlk))
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

local function generateTreeConfig(blk)
{
  local branches = []
  foreach(branch in blk % "treeBlock")
  {
    branches.append(createBranch(branch))
  }

  local craftTreeItemsIdArray = branches.map(@(branch) branch.branchItems.keys().extend(branch.headerItems)
    ).reduce(@(res, value) res.extend(value))
  if (craftTreeItemsIdArray.len() > 0)   //request items by itemDefId for craft tree
    inventoryClient.requestItemdefsByIds(craftTreeItemsIdArray)

  return {
    headerlocId = blk?.main_header ?? ""
    openButtonLocId = blk?.openButtonLocId ?? ""
    allowableResources = getAllowableResources(blk?.allowableResources)
    craftTreeItemsIdArray = craftTreeItemsIdArray
    branches = branches
    reqFeaturesList = ::g_features.getReqFeaturesListFromString(blk?.reqFeature)
  }
}

return generateTreeConfig