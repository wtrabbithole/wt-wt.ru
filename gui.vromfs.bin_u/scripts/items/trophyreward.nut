::trophyReward <- {
  maxRewardsShow = 5

  //!!FIX ME: need to convert reward type by enum_utils
  rewardTypes = [ "multiAwardsOnWorthGold", "modsForBoughtUnit",
                  "unit", "rentedUnit",
                  "trophy", "item", "unlock", "unlockType", "resource", "resourceType",
                  "entitlement", "gold", "warpoints", "exp", "warbonds"]
  iconsRequired = [ "trophy", "item", "unlock", "entitlement", "resource" ]
  specialPrizeParams = {
    rentedUnit = function(config, prize) {
      prize.timeHours <- ::getTblValue("timeHours", config)
      prize.numSpares <- ::getTblValue("numSpares", config)
    }
    resource = function(config, prize) {
      prize.resourceType <- ::getTblValue("resourceType", config)
    }
  }

  wpIcons = [
    { value = 1000, icon = "battle_trophy1k" },
    { value = 5000, icon = "battle_trophy5k" },
    { value = 10000, icon = "battle_trophy10k" },
    { value = 50000, icon = "battle_trophy50k" },
    { value = 100000, icon = "battle_trophy100k" },
    { value = 1000000, icon = "battle_trophy1kk" },
  ]
}

function trophyReward::processUserlogData(configsArray = [])
{
  if (configsArray.len() == 0)
    return []

  local tempBuffer = {}
  foreach(idx, config in configsArray)
  {
    local type = ::trophyReward.getType(config)
    local typeVal = ::getTblValue(type, config)
    local count = config?.count ?? 1

    local checkBuffer = typeVal
    if (typeof typeVal != "string")
      checkBuffer = type + "_" + typeVal

    if (!::getTblValue(checkBuffer, tempBuffer))
    {
      tempBuffer[checkBuffer] <- {
          count = count
          arrayIdx = idx
        }
    }
    else
      tempBuffer[checkBuffer].count += count

    if (type == "unit")
      ::broadcastEvent("UnitBought", { unitName = typeVal, receivedFromTrophy = true })
    else if (type == "rentedUnit")
      ::broadcastEvent("UnitRented", { unitName = typeVal, receivedFromTrophy = true })
    else if (type == "resourceType" && typeVal == g_decorator_type.DECALS.resourceType)
      ::broadcastEvent("DecalReceived", { id = config?.resource })
    else if (type == "resourceType" && typeVal == g_decorator_type.ATTACHABLES.resourceType)
      ::broadcastEvent("AttachableReceived", { id = config?.resource })
  }

  local res = []
  foreach(block in tempBuffer)
  {
    local result = clone configsArray[block.arrayIdx]
    result.count <- block.count

    res.append(result)
  }

  res.sort(rewardsSortComparator)
  return res
}

function trophyReward::rewardsSortComparator(a, b)
{
  if (!a || !b)
    return b <=> a

  local typeA = ::trophyReward.getType(a)
  local typeB = ::trophyReward.getType(b)
  if (typeA != typeB)
    return typeA <=> typeB

  if (typeA == "item")
  {
    local itemA = ::ItemsManager.findItemById(a.item)
    local itemB = ::ItemsManager.findItemById(b.item)
    if (itemA && itemB)
      return ::ItemsManager.itemsSortComparator(itemA, itemB)
  }

  return a?[typeA] <=> b?[typeB]
}

function trophyReward::getImageByConfig(config = null, onlyImage = true, layerCfgName = "item_place_single", imageAsItem = false)
{
  local image = ""
  local rewardType = ::trophyReward.getType(config)
  if (rewardType == "")
    return ""

  local rewardValue = config[rewardType]
  local style = "reward_" + rewardType

  if (rewardType == "multiAwardsOnWorthGold" || rewardType == "modsForBoughtUnit")
    image = ::TrophyMultiAward(::DataBlockAdapter(config)).getRewardImage()
  else if (::trophyReward.isRewardItem(rewardType))
  {
    local item = ::ItemsManager.findItemById(rewardValue)
    if (!item)
      return ""

    if (onlyImage)
      return item.getIcon()

    image = ::handyman.renderCached(("gui/items/item"), {
      items = item.getViewData({
            enableBackground = false,
            showAction = false,
            showPrice = false,
            needRarity = false,
            contentIcon = false,
            count = ::getTblValue("count", config, 0)
          })
      })
    return image
  }
  else if (rewardType == "unit" || rewardType == "rentedUnit")
    style += "_" + ::getUnitTypeText(::get_es_unit_type(::getAircraftByName(rewardValue))).tolower()
  else if (rewardType == "resource")
  {
    if (config.resourceType)
    {
      style = "reward_" + config.resourceType
      if (!::LayersIcon.findStyleCfg(style))
        style = "reward_unlock"
    }
  }
  else if (rewardType == "unlockType" || rewardType == "resourceType")
  {
    style = "reward_" + rewardValue
    if (!::LayersIcon.findStyleCfg(style))
      style = "reward_unlock"
  }
  else if (rewardType == "warpoints")
    image = getFullWPIcon(rewardValue)
  else if (rewardType == "warbonds")
    image = getFullWarbondsIcon(rewardValue)

  if (image == "")
    image = ::LayersIcon.getIconData(style)

  if (!isRewardMultiAward(config))
    image += getMoneyLayer(config)

  local resultImage = ::LayersIcon.genDataFromLayer(::LayersIcon.findLayerCfg(layerCfgName), image)
  if (!imageAsItem)
    return resultImage

  return ::handyman.renderCached(("gui/items/item"), {items = [{layered_image = resultImage}]})
}

function trophyReward::getMoneyLayer(config)
{
  local currencyCfg = ::PrizesView.getPrizeCurrencyCfg(config)
  if (!currencyCfg)
    return  ""

  local layerCfg = ::LayersIcon.findLayerCfg("roulette_money_text")
  if (!layerCfg)
    return ""

  layerCfg.text <- currencyCfg.printFunc(currencyCfg.val)
  return ::LayersIcon.getTextDataFromLayer(layerCfg)
}

function trophyReward::getWPIcon(wp)
{
  local icon = ""
  foreach (v in wpIcons)
    if (wp >= v.value || icon == "")
      icon = v.icon
  return icon
}

function trophyReward::getFullWPIcon(wp)
{
  local layer = ::LayersIcon.findLayerCfg("item_warpoints")
  local wpLayer = ::LayersIcon.findLayerCfg(getWPIcon(wp))
  if (layer && wpLayer)
    layer.img <- ::getTblValue("img", wpLayer, "")
  return ::LayersIcon.genDataFromLayer(layer)
}

function trophyReward::getFullWarbondsIcon(wbId)
{
  local layer = ::LayersIcon.findLayerCfg("item_warpoints")
  layer.img <- "#ui/gameuiskin#item_warbonds"
  return ::LayersIcon.genDataFromLayer(layer)
}

function trophyReward::getRestRewardsNumLayer(configsArray, maxNum)
{
  local restRewards = configsArray.len() - maxNum
  if (restRewards <= 0)
    return ""

  local layer = ::LayersIcon.findLayerCfg("item_rest_rewards_text")
  if (!layer)
    return ""

  layer.text <- ::loc("trophy/moreRewards", {num = restRewards})
  return ::LayersIcon.getTextDataFromLayer(layer)
}

function trophyReward::getReward(configsArray = [])
{
  if (configsArray.len() == 1)
    return ::trophyReward.getRewardText(configsArray[0])

  return ::trophyReward.getCommonRewardText(configsArray)
}

function trophyReward::isRewardItem(rewardType)
{
  return ::isInArray(rewardType, ["item", "trophy"])
}

function trophyReward::getType(config)
{
  if (isRewardMultiAward(config))
    return "multiAwardsOnWorthGold" in config? "multiAwardsOnWorthGold" : "modsForBoughtUnit"

  if (config)
    foreach(param, value in config)
      if (::isInArray(param, rewardTypes))
        return param

  ::dagor.debug("TROPHYREWARD::GETTYPE recieved bad config")
  debugTableData(config)
  return ""
}

function trophyReward::getName(config)
{
  local rewardType = ::trophyReward.getType(config)
  if (!::trophyReward.isRewardItem(rewardType))
    return ""

  local item = ::ItemsManager.findItemById(config[rewardType])
  if (item)
    return item.getName()

  return ""
}

function trophyReward::getDecription(config, isFull = false)
{
  local rewardType = ::trophyReward.getType(config)
  if (!::trophyReward.isRewardItem(rewardType))
    return ::trophyReward.getRewardText(config, isFull)

  local item = ::ItemsManager.findItemById(config[rewardType])
  if (item)
    return item.getDescription()

  return ""
}

function trophyReward::getRewardText(config, isFull = false)
{
  return ::PrizesView.getPrizeText(::DataBlockAdapter(config), true, false, true, isFull)
}

function trophyReward::getCommonRewardText(configsArray)
{
  local result = {}
  local currencies = {}

  foreach(config in configsArray)
  {
    local currencyCfg = ::PrizesView.getPrizeCurrencyCfg(config)
    if (currencyCfg)
    {
      if (!(currencyCfg.type in currencies))
        currencies[currencyCfg.type] <- currencyCfg
      else
        currencies[currencyCfg.type].val += currencyCfg.val
      continue
    }

    local rewType = ::trophyReward.getType(config)
    local rewData = {
      type = rewType
      subType = null
      num = 0
    }
    if (rewType == "item")
    {
      local item = ::ItemsManager.findItemById(config[rewType])
      if (item)
      {
        rewData.subType <- item.iType
        rewData.item <- item
        rewType = rewType + "_" + item.iType
      }
    }
    else
      rewData.config <- config

    if (!::getTblValue(rewType, result))
      result[rewType] <- rewData

    result[rewType].num++;
  }

  currencies = ::u.values(currencies)
  currencies.sort(@(a, b) a.type <=> b.type)
  currencies = ::u.map(currencies, @(c) c.printFunc(c.val))
  currencies = ::g_string.implode(currencies, ::loc("ui/comma"))

  local returnData = [ currencies ]

  foreach(data in result)
  {
    if (data.type == "item")
    {
      local item = ::getTblValue("item", data)
      if (item)
        returnData.append(item.getTypeName() + ::loc("ui/colon") + data.num)
    }
    else
    {
      local text = ::trophyReward.getRewardText(data.config)
      if (data.num > 1)
        text += ::loc("ui/colon") + data.num
      returnData.append(text)
    }
  }
  returnData = ::g_string.implode(returnData, ", ")
  return ::colorize("activeTextColor", returnData)
}

function trophyReward::isRewardMultiAward(config)
{
  return ::getTblValue("multiAwardsOnWorthGold", config) != null
         || ::getTblValue("modsForBoughtUnit", config) != null
}

function trophyReward::showInResults(rewardType)
{
  return rewardType != "unlockType" && rewardType != "resourceType"
}

function trophyReward::getRewardList(config)
{
  if (isRewardMultiAward(config))
    return ::TrophyMultiAward(::DataBlockAdapter(config)).getResultPrizesList()

  local prizes = []
  foreach (rewardType in rewardTypes)
    if (rewardType in config && showInResults(rewardType))
    {
      local prize = {
        [rewardType] = config[rewardType]
        count = ::getTblValue("count", config)
      }
      if (!::isInArray(rewardType, iconsRequired))
        prize.noIcon <- true
      if (rewardType in specialPrizeParams)
        specialPrizeParams[rewardType](config, prize)

      prizes.append(::DataBlockAdapter(prize))
    }
  return prizes
}

function trophyReward::getRewardsListViewData(config, params = {})
{
  local rewardsList = []
  local singleReward = config
  if (typeof(config) != "array")
    rewardsList = getRewardList(config)
  else
  {
    singleReward = (config.len() == 1) ? config[0] : null
    foreach(cfg in config)
      rewardsList.extend(getRewardList(cfg))
  }

  if (singleReward != null && ::getTblValue("multiAwardHeader", params)
      && isRewardMultiAward(singleReward))
    params.header <- ::TrophyMultiAward(::DataBlockAdapter(singleReward)).getName()

  params.receivedPrizes <- true

  return ::PrizesView.getPrizesListView(rewardsList, params)
}

function trophyReward::getRewardType(prize)
{
  foreach (rewardType in rewardTypes)
    if (rewardType in prize)
      return rewardType
  return ""
}
