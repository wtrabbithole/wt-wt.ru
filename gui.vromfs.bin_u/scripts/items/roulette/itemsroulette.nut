/*
ItemsRoulette API:
  reinitParams() - gather outside params once, eg. gui.blk;
  refreshDebugTable() - rewrite params in which stores debug information in case of wrong behaviour;
  getDebugData() - print debug data into log;

  init - main launch function;
  fillDropChances() - calculate drop chances for items;
  generateItemsArray() - create array of tables of items which can be dropped in single copy,
                                                 recieves a trophyName as a main parameter;

  gatherItemsArray() - create main strip of items by random chances
  getRandomItemsSlot() - revieve items array peer slot in roulette
  getRandomItem() - recieve item, by random drop chance;
  insertCurrentReward() - insert into randomly generated strip
                                                 rewards which player really recieved;
*/

const MIN_ITEMS_OFFSET = 0.1
const MAX_ITEMS_OFFSET = 0.4


local ItemGenerators = require("scripts/items/itemsClasses/itemGenerators.nut")
local rouletteAnim = ::require("scripts/items/roulette/rouletteAnim.nut")

::ItemsRoulette <- {
  debugData = {}
  mainAnimation = null

  rouletteObj = null
  ownerHandler = null

  trophyItem = null
  insertRewardIdx = 0
  isGotTopPrize = false
  topPrizeLayout = null
}

function ItemsRoulette::reinitParams()
{
  local params = ["items_roulette_multiplier_slots",
                  "items_roulette_min_trophy_drop_mult"]

  local loadParams = false
  foreach(param in params)
  {
    if (::getTblValue(param, ::ItemsRoulette, null) == null)
    {
      loadParams = true
      break
    }
  }

  if (!loadParams)
    return

  local blk = ::configs.GUI.get()

  foreach(param in params)
  {
    local val = blk[param] || 1.0
    ::ItemsRoulette[param] <- val
    ::ItemsRoulette.debugData.commonInfo[param] <- val
  }
}

function ItemsRoulette::refreshDebugTable()
{
  ::ItemsRoulette.debugData = {
                                result = []
                                unknown = []
                                commonInfo = {itemsLens = {}, overflowChancesNum = 0}
                                step = []
                                beginChances = []
                              }
}

function ItemsRoulette::getDebugData()
{
  ::dagor.debug("ItemsRoulette: Print debug data of previously finished roulette")
  debugTableData(::ItemsRoulette.debugData)
}

::subscribe_events_from_handler(::ItemsRoulette, ["NewSceneLoaded"])

function ItemsRoulette::init(trophyName, rewardsArray, imageObj, handler, afterDoneFunc = null)
{
  if (!::checkObj(imageObj))
    return false

  local placeObj = imageObj.findObject("reward_roullete")
  if (!::checkObj(placeObj))
    return false

  rouletteObj = placeObj.findObject("rewards_list")
  if (!::checkObj(rouletteObj))
    return false

  ownerHandler = handler

  ::ItemsRoulette.refreshDebugTable()
  ::ItemsRoulette.reinitParams()

  local totalLen = ::to_integer_safe(placeObj.totalLen, 1)
  local insertRewardFromEnd = ::to_integer_safe(placeObj.insertRewardFromEnd, 1)
  insertRewardIdx = totalLen - insertRewardFromEnd - 1
  if (insertRewardIdx < 0 || insertRewardIdx >= totalLen)
  {
    ::dagor.assertf(false, "Insert index is wrong: " + insertRewardIdx + " / " + totalLen)
    return false
  }

  local retTable = ::ItemsRoulette.generateItemsArray(trophyName)
  local itemsArray = ::getTblValue("itemsArray", retTable, [])
  if (!::has_feature("ItemsRoulette") || itemsArray.len() <= 1)
    return false

  trophyItem = ::ItemsManager.findItemById(trophyName)
  if (!trophyItem || trophyItem.skipRoulette())
    return false

  topPrizeLayout = null
  isGotTopPrize = false
  foreach (prize in rewardsArray)
    isGotTopPrize = isGotTopPrize || trophyItem.isHiddenTopPrize(prize)

  local count = ::getTblValue("count", retTable, 1)
  local processedItemsArray = ::ItemsRoulette.gatherItemsArray(itemsArray, totalLen, count)
  ::ItemsRoulette.insertCurrentReward(processedItemsArray, rewardsArray)
  ::ItemsRoulette.insertHiddenTopPrize(processedItemsArray)

  local data = createItemsMarkup(processedItemsArray)
  placeObj.getScene().replaceContentFromText(rouletteObj, data, data.len(), handler)
  placeObj.show(true)

  ::updateTransparencyRecursive(placeObj, 0)
  placeObj.animation = "show"

  local blackoutObj = imageObj.findObject("blackout_background")
  if (::checkObj(blackoutObj))
    blackoutObj.animation = "show"

  local afterDoneCb = function() {
    ::ItemsRoulette.showTopPrize()
    afterDoneFunc()
  }

  local anim = rouletteAnim.get(trophyItem.getOpeningAnimId())
  dagor.debug("ItemsRoulette: open trophy " + trophyItem.id + ", animaton = " + anim.id)
  anim.startAnim(rouletteObj, insertRewardIdx)

  placeObj.getScene().applyPendingChanges(false)
  local delay = rouletteAnim.getTimeLeft(rouletteObj) || 0.1
  mainAnimation = ::Timer(placeObj, delay, afterDoneCb, handler).weakref()
  return true
}

function ItemsRoulette::skipAnimation(obj)
{
  rouletteAnim.DEFAULT.skipAnim(obj)
  if (mainAnimation)
    mainAnimation.destroy()
}

function ItemsRoulette::generateItemsArray(trophyName)
{
  local trophy = ::ItemsManager.findItemById(trophyName) || ItemGenerators.get(trophyName)
  if (!trophy)
  {
    ::dagor.debug("ItemsRoulette: Cannot find trophy by name " + trophyName)
    return {}
  }

  if (trophy?.iType != itemType.TROPHY && trophy?.iType != itemType.CHEST && !trophy?.genType)
  {
    ::dagor.debug("ItemsRoulette: Founded item is not a trophy")
    ::dagor.debug(trophy.tostring())
    return {}
  }

  local itemsArray = []
  local commonParams = {
    dropChance = 1.0
    multDiff = 1.0
  }

  local debug = {trophy = trophyName}
  local content = trophy.getContent()
  //!!FIX ME: do not use _getContentFixedAmount outside of prizes list. it very specific for prizes stacks description
  local countContent = ::PrizesView._getContentFixedAmount(content)
  local shouldOnlyImage = countContent > 1
  foreach(block in content)
  {
    if (block.trophy)
    {
      local trophyData = ::ItemsRoulette.generateItemsArray(block.trophy)
      local table = clone commonParams
      table.trophy <- ::getTblValue("itemsArray", trophyData, [])
      table.trophyId <- block.trophy
      table.count <- ::getTblValue("count", trophyData, 1)
      table.dropChanceSum <- 1.0
      itemsArray.append(table)
    }
    else
    {
      debug[::ItemsRoulette.getUniqueTableKey(block)] <- 0
      local table = clone commonParams
      table.reward <- block
      table.layout <- ::ItemsRoulette.getRewardLayout(block, shouldOnlyImage)
      itemsArray.append(table)
    }
  }

  ::ItemsRoulette.debugData.result.append(debug)
  return {itemsArray = itemsArray, count = countContent }
}

function ItemsRoulette::getUniqueTableKey(rewardBlock)
{
  if (!rewardBlock)
  {
    ::dagor.assertf(false, "Bad block for unique key")
    return ""
  }

  local tKey = ::trophyReward.getType(rewardBlock)
  local tVal = rewardBlock[tKey]
  return tKey + "_" + tVal
}

function ItemsRoulette::gatherItemsArray(itemsArray, mainLength, count)
{
  ::ItemsRoulette.debugData.commonInfo["mainLength"] <- mainLength

  local searchKeyTable = itemsArray[0]
  if ("trophy" in searchKeyTable)
    searchKeyTable = searchKeyTable.trophy[0]

  local shouldSearchTopReward = trophyItem.hasTopRewardAsFirstItem
  local topRewardKey = ::ItemsRoulette.getUniqueTableKey(::getTblValue("reward", searchKeyTable, searchKeyTable))

  local dropChanceSum = ::ItemsRoulette.fillDropChances(itemsArray)
  local topRewardFound = false
  local resultArray = []
  for (local i = 0; i < mainLength; i++)
  {
    local tablesArray = ::ItemsRoulette.getRandomItemsSlot(itemsArray, dropChanceSum, searchKeyTable, count)
    foreach(table in tablesArray)
    {
      if (shouldSearchTopReward)
        topRewardFound = topRewardFound || topRewardKey == ::getTblValue("tKey", table)
      dropChanceSum = ::getTblValue("dropChanceSum", table, dropChanceSum)
    }

    ::ItemsRoulette.debugData.step.append(tablesArray)
    resultArray.append(tablesArray)
  }

  if (shouldSearchTopReward && !topRewardFound)
  {
    local insertIdx = insertRewardIdx + 1 // Interting teaser item next to reward.
    if (insertIdx >= mainLength)
      insertIdx = 0
    ::dagor.debug("ItemsRoulette: Top reward by key " + topRewardKey + " not founded." +
         "Insert manually into " + insertIdx + ".")
    local table = ::ItemsRoulette.getRandomItem([searchKeyTable], 0)
    local slot = resultArray[insertIdx]
    if (slot.len() == 0)
      slot.append(table)
    else
      slot[0] = table
  }

  return resultArray
}

/*  Rules for drop chances
1) Trophies have increased drop chance percent
   on param items_roulette_multiplier_slots readed from gui.blk;
2) Trophy slots fills proportionally to count of items in trophies
3) Trophy drop chance calculates as
    (Trophy Slots Num * Current trophy Items Length / All trophies items length)
4) Check max value, cos minimal value of items from trophy
   is set as Current trophy Items Length * items_roulette_min_trophy_drop_mult (set in gui.blk)
*/
function ItemsRoulette::fillDropChances(itemsArray, dropChanceSum = 0)
{
  local array = itemsArray
  local isTrophy = "trophy" in itemsArray
  if (isTrophy)
    array = itemsArray.trophy

  foreach(block in array)
  {
    if (!::getTblValue("trophy", block))
    {
      local dropChance = 1
      ::ItemsRoulette.debugData.beginChances.append({[::ItemsRoulette.getUniqueTableKey(block.reward)] = dropChance})
      block.dropChance = dropChance
      block.multDiff = 1 - ::ItemsRoulette.getChanceMultiplier(false, block.dropChance)
      if (!isTrophy)
        dropChanceSum += block.dropChance
    }
    else
    {
      local trophiesLen = 0
      local commonItemsLen = 0
      local trophiesItemsLength = 0

      foreach(cell in itemsArray)
      {
        if ("trophy" in cell)
        {
          local itemsLength = cell.trophy.len()
          trophiesItemsLength += itemsLength
          trophiesLen++

          ::ItemsRoulette.debugData.commonInfo.itemsLens["trophy_" + cell.trophyId] <- {
            trophiesLen = 1
            commonItemsLen = itemsLength
          }
        }
        else
          commonItemsLen++
      }

      local trophyDropChanceSum = 0
      foreach(item in block.trophy)
        trophyDropChanceSum += item.dropChance
      block.dropChanceSum = trophyDropChanceSum

      local trophySlots = (commonItemsLen + trophiesLen) * ::ItemsRoulette.items_roulette_multiplier_slots - commonItemsLen
      ::ItemsRoulette.debugData.commonInfo["trophySlots"] <- trophySlots

      local trophyItemsLen = block.trophy.len()
      local dropTrophy = ::max(trophySlots * trophyItemsLen / trophiesItemsLength,
                               trophyItemsLen * ::ItemsRoulette.items_roulette_min_trophy_drop_mult)

      block.dropChance = dropTrophy / ::getTblValue("count", block, 1)
      ::ItemsRoulette.debugData.beginChances.append({["trophy_" + block.trophyId] = block.dropChance})
      dropChanceSum += block.dropChance

      block.multDiff = 1 - ::ItemsRoulette.getChanceMultiplier(true, block.dropChance)

      dropChanceSum = ::ItemsRoulette.fillDropChances(block, dropChanceSum)
    }
  }
  return dropChanceSum
}

function ItemsRoulette::getRandomItemsSlot(itemsArray, dropChanceSum, topItem, count = 1)
{
  local resultArray = []
  for (local i = 0; i < count; i++)
  {
    local table = ::ItemsRoulette.getRandomItem(itemsArray, dropChanceSum)
    if (!::getTblValue("reward", table))
    {
      table = ::ItemsRoulette.getRandomItem([topItem], dropChanceSum)
      ::ItemsRoulette.debugData.commonInfo.overflowChancesNum++
    }

    resultArray.append(table)
    dropChanceSum = ::getTblValue("dropChanceSum", table, dropChanceSum)
  }

  foreach(returnTable in resultArray)
  {
    local tKey = ::ItemsRoulette.getUniqueTableKey(::getTblValue("reward", returnTable.reward))
    foreach(table in ::ItemsRoulette.debugData.result)
    {
      if (tKey in table)
      {
        returnTable.tKey = tKey
        table[tKey]++
        break
      }
    }

    returnTable.dropChanceSum = dropChanceSum
  }

  return resultArray
}

function ItemsRoulette::getRandomItem(array, dropChanceSum, count = 1, trophyTable = null)
{
  local returnTable = {
    reward = null,
    dropChanceSum = 0
    trophyTable = trophyTable
    foundedItem = {}
    tKey = ""
  }

  local rndChance = ::math.frnd() * dropChanceSum

  foreach(val in array)
  {
    rndChance -= val.dropChance
    if (rndChance > 0)
      continue

    local div = val.dropChance * val.multDiff
    val.dropChance -= div
    dropChanceSum -= div

    if ("trophy" in val)
    {
      returnTable.trophyTable = val
      local table = ::ItemsRoulette.getRandomItem(val.trophy, val.dropChanceSum, ::getTblValue("count", val, 1), returnTable.trophyTable)
      if (::getTblValue("reward", table) != null)
      {
        returnTable = table
        break
      }
      else
        continue
    }

    if (returnTable.trophyTable != null)
      returnTable.trophyTable.dropChanceSum -= div

    returnTable.foundedItem = {
      item = val
      multDiff = val.multDiff,
      div = div
      dropChance = val.dropChance
    }

    returnTable.reward = val
    break
  }

  returnTable.dropChanceSum = dropChanceSum

  return returnTable
}

function ItemsRoulette::insertCurrentReward(readyItemsArray, rewardsArray)
{
  local array = []
  local shouldOnlyImage = rewardsArray.len() > 1
  foreach(reward in rewardsArray)
  {
    reward.layout <- ::ItemsRoulette.getRewardLayout(reward, shouldOnlyImage)
    array.append(reward)
  }
  readyItemsArray[insertRewardIdx] = array
}

function ItemsRoulette::getHiddenTopPrizeReward(params)
{
  local showType = params?.show_type ?? "vehicle"
  local layerCfg = clone ::LayersIcon.findLayerCfg("item_place_single")
  layerCfg.img <- "#ui/gameuiskin#item_" + showType
  local image = ::LayersIcon.genDataFromLayer(layerCfg)
  local layout = ::LayersIcon.genDataFromLayer(::LayersIcon.findLayerCfg("roulette_item_place"), image)

  return {
    id = trophyItem.id
    item = null
    layout = layout
  }
}

function ItemsRoulette::insertHiddenTopPrize(readyItemsArray)
{
  local hiddenTopPrizeParams = trophyItem.getHiddenTopPrizeParams()
  if (!hiddenTopPrizeParams)
    return

  local showFreq = (hiddenTopPrizeParams?.showFreq ?? "0").tointeger() / 100.0
  local shouldShowTeaser = ::math.frnd() >= 1.0 - showFreq
  if (!isGotTopPrize && !shouldShowTeaser)
    return

  if (isGotTopPrize)
    topPrizeLayout = ::g_string.implode(::u.map(readyItemsArray[insertRewardIdx], @(p) p.layout))

  local totalLen = readyItemsArray.len()
  local insertIdx = 0
  if (isGotTopPrize)
    insertIdx = insertRewardIdx
  else
  {
    local idxMax = insertRewardIdx
    local idxMin = ::max(insertRewardIdx /5*4, 0)
    insertIdx = idxMin + ((idxMax - idxMin) * ::math.frnd()).tointeger()
    if (insertIdx == insertRewardIdx)
      insertIdx++
  }

  local slot = readyItemsArray[insertIdx]
  if (!slot.len())
    slot.append({})
  slot[0] = { reward = ::ItemsRoulette.getHiddenTopPrizeReward(hiddenTopPrizeParams) }
}

function ItemsRoulette::showTopPrize()
{
  if (!topPrizeLayout)
    return
  local obj = ::check_obj(rouletteObj) && rouletteObj.findObject("roulette_slot_" + insertRewardIdx)
  if (!::check_obj(obj))
    return
  local guiScene = rouletteObj.getScene()
  guiScene.replaceContentFromText(obj, topPrizeLayout, topPrizeLayout.len(), ownerHandler)
}

function ItemsRoulette::createItemsMarkup(completeArray)
{
  local result = ""
  foreach(idx, slot in completeArray)
  {
    local slotRes = []
    local offset = slot.len() <= 1 ? 0 : ::max(MIN_ITEMS_OFFSET, MAX_ITEMS_OFFSET / (slot.len() - 1))

    foreach(idx, item in slot)
      slotRes.insert(0,
        ::LayersIcon.genDataFromLayer(
          { x = (offset * idx) + "@itemWidth", w = "1@itemWidth" },
          item?.reward?.layout ?? item?.layout))

    local layerCfg = ::LayersIcon.findLayerCfg("roulette_slot")
    local width = 1
    if (slot.len() > 1)
      width += offset * (slot.len() - 1)
    layerCfg.w <- width + "@itemWidth"
    layerCfg.id <- "roulette_slot_" + idx

    result += ::LayersIcon.genDataFromLayer(layerCfg, ::g_string.implode(slotRes))
  }

  return result
}

function ItemsRoulette::getRewardLayout(block, shouldOnlyImage = false)
{
  local config = ::getTblValueByPath("reward.reward", block, block)
  local type = ::trophyReward.getType(config)
  if (::trophyReward.isRewardItem(type))
    return ::trophyReward.getImageByConfig(config, shouldOnlyImage, "roulette_item_place")

  local image = ::trophyReward.getImageByConfig(config, shouldOnlyImage, "item_place_single")
  return ::LayersIcon.genDataFromLayer(::LayersIcon.findLayerCfg("roulette_item_place"), image)
}

function ItemsRoulette::getChanceMultiplier(isTrophy, dropChance)
{
  local chanceMult = 0.5
  if (isTrophy)
    chanceMult = ::pow(0.5, 1/dropChance)

  return chanceMult
}
