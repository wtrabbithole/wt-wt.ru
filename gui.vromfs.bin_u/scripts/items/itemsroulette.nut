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
::ItemsRoulette <- {
  debugData = {}
  mainAnimation = null
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

function ItemsRoulette::soundStart()
{
  ::play_gui_sound("roulette_start")
  ::start_gui_sound("roulette_spin")
}

function ItemsRoulette::soundEnd()
{
  ::stop_gui_sound("roulette_spin")
  ::play_gui_sound("roulette_stop")
}

function ItemsRoulette::onEventNewSceneLoaded(p)
{
  ::stop_gui_sound("roulette_spin")
}

::subscribe_events_from_handler(::ItemsRoulette, ["NewSceneLoaded"])

function ItemsRoulette::init(trophyName, rewardsArray, imageObj, handler, afterDoneFunc = null)
{
  if (!::checkObj(imageObj))
    return false

  local placeObj = imageObj.findObject("reward_roullete")
  if (!::checkObj(placeObj))
    return false

  local rouletteObj = placeObj.findObject("rewards_list")
  if (!::checkObj(rouletteObj))
    return false

  ::ItemsRoulette.refreshDebugTable()
  ::ItemsRoulette.reinitParams()

  local totalLen = ::to_integer_safe(placeObj.totalLen, 1)
  local insertRewardFromEnd = ::to_integer_safe(placeObj.insertRewardFromEnd, 1)

  local retTable = ::ItemsRoulette.generateItemsArray(trophyName)
  local itemsArray = ::getTblValue("itemsArray", retTable, [])
  if (!::has_feature("ItemsRoulette") || itemsArray.len() <= 1)
    return false

  local trophy = ::ItemsManager.findItemById(trophyName)
  if (!trophy || trophy.skipRoulette())
    return false

  ::ItemsRoulette.soundStart()

  local count = ::getTblValue("count", retTable, 1)
  local processedItemsArray = ::ItemsRoulette.gatherItemsArray(itemsArray, totalLen, insertRewardFromEnd, count)
  processedItemsArray = ::ItemsRoulette.insertCurrentReward(processedItemsArray, rewardsArray, insertRewardFromEnd)

  local arrayLen = processedItemsArray.len()
  local endPos = arrayLen > insertRewardFromEnd? (arrayLen - insertRewardFromEnd) : arrayLen

  local readyImagesTable = ::ItemsRoulette.createDataLine(processedItemsArray, endPos)
  local guiScene = placeObj.getScene()

  local endPos = guiScene.calcString(readyImagesTable.endString, null)
  local rouletteWidth = guiScene.calcString(readyImagesTable.totalString, null)
  local end = endPos.tofloat()/rouletteWidth * 100
  local basePos = 100 - end

  rouletteObj["left-base"] = (-1 * basePos).tostring()
  rouletteObj["left-end"] = (-1 * (end + getRandomEndDisplacement())).tostring()
  rouletteObj["pos-time"] = (6000 + 250*(1 - 2*::math.frnd())).tostring()

  local data = readyImagesTable.data
  guiScene.replaceContentFromText(rouletteObj, data, data.len(), handler)
  placeObj.show(true)

  ::updateTransparencyRecursive(placeObj, 0)
  placeObj.animation = "show"

  local blackoutObj = imageObj.findObject("blackout_background")
  if (::checkObj(blackoutObj))
    blackoutObj.animation = "show"

  local delay = ::to_integer_safe(rouletteObj["pos-time"], 0)
  mainAnimation = ::Timer(placeObj, 0.001 * delay, (@(placeObj, afterDoneFunc, handler, rouletteObj, end) function () {
    rouletteObj["pos-time"] = -500
    rouletteObj["left-base"] = (-1 * end).tostring()
    ::Timer(placeObj, 0.001 * 500, afterDoneFunc, handler)
    ::ItemsRoulette.soundEnd()
  })(placeObj, afterDoneFunc, handler, rouletteObj, end), handler).weakref()

  return true
}

/**
 * Returns random displacement in segment [-0.5, 0.5]
 * with slightly different chances.
 */
function ItemsRoulette::getRandomEndDisplacement()
{
  local sign = ::math.frnd() > 0.5 ? 1.0 : -1.0
  local mean = ::math.frnd()
  // Chance of further displacement is higher.
  mean = 1 - mean * mean
  return 0.5 * sign * mean
}

function ItemsRoulette::skipAnimation(obj)
{
  local timePID = ::dagui_propid.add_name_id("_pos-timer")
  local posTime = obj["pos-time"]
  if (!posTime)
    return

  obj.setFloatProp(timePID, posTime.tofloat() > 0 ? 1.0 : 0.0)

  if (mainAnimation)
  {
    mainAnimation.performAction()
    mainAnimation.destroy()
  }
}

function ItemsRoulette::generateItemsArray(trophyName)
{
  local trophy = ::ItemsManager.findItemById(trophyName)
  if (!trophy)
  {
    ::dagor.debug("ItemsRoulette: Cannot find trophy by name " + trophyName)
    return {}
  }

  if (trophy.iType != itemType.TROPHY)
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
      table.layout <- ::ItemsRoulette.getRewardLayout(block)
      itemsArray.append(table)
    }
  }

  ::ItemsRoulette.debugData.result.append(debug)
  //!!FIX ME: do not use _getContentFixedAmount outside of prizes list. it very specific for prizes stacks description
  return {itemsArray = itemsArray, count = ::PrizesView._getContentFixedAmount(content) }
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

function ItemsRoulette::gatherItemsArray(itemsArray, mainLength, insertRewardFromEnd, count = 1)
{
  ::ItemsRoulette.debugData.commonInfo["mainLength"] <- mainLength

  local searchKeyTable = itemsArray[0]
  if ("trophy" in searchKeyTable)
    searchKeyTable = searchKeyTable.trophy[0]

  local topRewardKey = ::ItemsRoulette.getUniqueTableKey(::getTblValue("reward", searchKeyTable, searchKeyTable))

  local dropChanceSum = ::ItemsRoulette.fillDropChances(itemsArray)
  local topRewardFounded = false
  local resultArray = []
  for (local i = 0; i < mainLength; i++)
  {
    local tablesArray = ::ItemsRoulette.getRandomItemsSlot(itemsArray, dropChanceSum, searchKeyTable, count)
    foreach(table in tablesArray)
    {
      topRewardFounded = topRewardFounded || topRewardKey == ::getTblValue("tKey", table)
      dropChanceSum = ::getTblValue("dropChanceSum", table, dropChanceSum)
    }

    ::ItemsRoulette.debugData.step.append(tablesArray)
    resultArray.append(tablesArray)
  }

  if (!topRewardFounded)
  {
    local insertIdx = mainLength-insertRewardFromEnd
    ::dagor.debug("ItemsRoulette: Top reward by key " + topRewardKey + " not founded." +
         "Insert manually into " + insertIdx + ".")
    local table = ::ItemsRoulette.getRandomItem([searchKeyTable], 0)
    local slot = resultArray[insertIdx > 0? insertIdx : 0]
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

function ItemsRoulette::insertCurrentReward(readyItemsArray, rewardsArray, insertIdx)
{
  local array = []
  foreach(reward in rewardsArray)
  {
    reward.layout <- ::ItemsRoulette.getRewardLayout(reward)
    array.append(reward)
  }

  local insertNum = readyItemsArray.len() - insertIdx-1
  if (insertNum < 0)
  {
    ::dagor.debug("insertNum = " + insertNum)
    ::dagor.debug("roulette length = " + readyItemsArray.len())
    ::dagor.assertf(false, "Insert index is negative")
    insertNum = 0
  }

  readyItemsArray[insertNum].clear()
  readyItemsArray[insertNum] = array
  return readyItemsArray
}

function ItemsRoulette::createDataLine(completeArray, rewardSlotIdx)
{
  local total = 0
  local endPos = 0
  local result = ""
  foreach(idx, slot in completeArray)
  {
    local slotRes = ""
    foreach(idx, item in slot)
      slotRes += ::getTblValueByPath("reward.layout", item, ::getTblValue("layout", item, ""))

    local layerCfg = ::LayersIcon.findLayerCfg("roulette_slot")
    local width = 1
    if (slot.len() > 1)
      width = 1.5
    layerCfg.w <- width + "@itemWidth"

    total += width
    if (idx <= rewardSlotIdx-1)
      endPos += width * (idx == rewardSlotIdx-1? 0.5 : 1)

    result += ::LayersIcon.genDataFromLayer(layerCfg, slotRes)
  }

  return {data = result, endString = endPos + "@itemWidth", totalString = total + "@itemWidth"}
}

function ItemsRoulette::getRewardLayout(block)
{
  local config = ::getTblValueByPath("reward.reward", block, block)
  local type = ::trophyReward.getType(config)
  if (::trophyReward.isRewardItem(type))
    return ::trophyReward.getImageByConfig(config, false, "roulette_item_place")

  local image = ::trophyReward.getImageByConfig(config, false, "item_place_single")
  return ::LayersIcon.genDataFromLayer(::LayersIcon.findLayerCfg("roulette_item_place"), image)
}

function ItemsRoulette::getChanceMultiplier(isTrophy, dropChance)
{
  local chanceMult = 0.5
  if (isTrophy)
    chanceMult = ::pow(0.5, 1/dropChance)

  return chanceMult
}
