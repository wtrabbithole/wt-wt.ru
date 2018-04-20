local time = require("scripts/time.nut")


function gui_start_open_trophy(configsTable = {})
{
  if (configsTable.len() == 0)
    return

  local tKey = ""
  foreach(idx, configsArray in configsTable)
  {
    tKey = idx
    break
  }

  local configsArray = configsTable.rawdelete(tKey)
  configsArray.sort(::trophyReward.rewardsSortComparator)
  local afterFunc = (@(configsTable) function() { ::gui_start_open_trophy(configsTable) })(configsTable)
  ::gui_start_modal_wnd(::gui_handlers.trophyRewardWnd, {configsArray = configsArray, afterFunc = afterFunc})
}

class ::gui_handlers.trophyRewardWnd extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/items/trophyReward.blk"

  configsArray = null
  afterFunc = null

  shrinkedConfigsArray = null
  trophyItem = null
  isBoxOpening = true
  isDisassemble = false

  haveItems = false
  opened = false
  animFinished = false

  useSingleAnimation = true

  unit = null
  rentTimeHours = 0

  slotbarActions = [ "take", "weapons", "info" ]

  function initScreen()
  {
    trophyItem = ::ItemsManager.findItemById(configsArray?[0]?.id)
    if (configsArray?[0]?.itemDefId)
      trophyItem = ::ItemsManager.findItemById(configsArray[0]?.itemDefId)

    if (!trophyItem)
      return base.goBack()

    isDisassemble = trophyItem.iType == itemType.RECIPES_BUNDLE && trophyItem.isDisassemble()
    isBoxOpening = !isDisassemble && (trophyItem.iType == itemType.TROPHY || trophyItem.iType == itemType.CHEST)

    local title = (!isDisassemble && configsArray[0]?.item == trophyItem.id) ? trophyItem.getCreationCaption()
      : trophyItem.getOpeningCaption()
    scene.findObject("reward_title").setValue(title)

    shrinkedConfigsArray = ::trophyReward.processUserlogData(configsArray)
    checkConfigsArray()
    updateWnd()
    startOpening()
  }

  function startOpening()
  {
    if (::ItemsRoulette.init(trophyItem.id,
                             configsArray,
                             scene,
                             this,
                             function() {
                               openChest.call(this)
                               onOpenAnimFinish.call(this)
                             }
                          ))
      useSingleAnimation = false

    local animId = useSingleAnimation? "open_chest_animation" : "reward_roullete"
    local animObj = scene.findObject(animId)
    if (::checkObj(animObj))
    {
      animObj.animation = "show"
      if (useSingleAnimation)
      {
        ::play_gui_sound("chest_open")
        local delay = ::to_integer_safe(animObj.chestReplaceDelay, 0)
        ::Timer(animObj, 0.001 * delay, openChest, this)
        ::Timer(animObj, 1.0, onOpenAnimFinish, this) //!!FIX ME: Some times animation finish not apply css, and we miss onOpenAnimFinish
      }
    }
    else
      openChest()
  }

  function openChest()
  {
    if (opened)
      return false
    local obj = scene.findObject("rewards_list")
    ItemsRoulette.skipAnimation(obj)
    opened = true
    updateWnd()
    return true
  }

  function updateWnd()
  {
    updateImage()
    updateRewardText()
    updateButtons()
  }

  function updateImage()
  {
    local imageObj = scene.findObject("reward_image")
    if (!::checkObj(imageObj))
      return

    local itemToShow = trophyItem
    if (isDisassemble && configsArray[0]?.item)
      itemToShow = ::ItemsManager.findItemById(configsArray[0].item)

    local layersData = ""
    if (isBoxOpening && (opened || useSingleAnimation))
    {
      layersData = itemToShow.getOpenedBigIcon()
      if (opened && useSingleAnimation)
        layersData += getRewardImage(itemToShow.iconStyle)
    } else
      layersData = itemToShow.getBigIcon()

    guiScene.replaceContentFromText(imageObj, layersData, layersData.len(), this)
  }

  function updateRewardText()
  {
    if (!opened)
      return

    local obj = scene.findObject("prize_desc_div")
    if (!::checkObj(obj))
      return

    local data = ::trophyReward.getRewardsListViewData(shrinkedConfigsArray,
                   { multiAwardHeader = true
                     widthByParentParent = true
                   })

    if (unit && unit.isRented())
    {
      local totalRentTime = unit.getRentTimeleft()
      local rentText = "mainmenu/rent/rent_unit"
      if (totalRentTime > time.hoursToSeconds(rentTimeHours))
        rentText = "mainmenu/rent/rent_unit_extended"

      rentText = ::loc(rentText) + "\n"
      local timeText = ::colorize("userlogColoredText", time.hoursToString(time.secondsToHours(totalRentTime)))
      rentText += ::loc("mainmenu/rent/rentTimeSec", {time = timeText})

      scene.findObject("prize_desc_text").setValue(::colorize("activeTextColor", rentText))
    }

    guiScene.replaceContentFromText(obj, data, data.len(), this)
  }

  function onTakeNavBar()
  {
    if (!unit)
      return

    onTake(unit)
  }

  function checkConfigsArray()
  {
    foreach(reward in configsArray)
    {
      local rewardType = ::trophyReward.getType(reward)
      haveItems = haveItems || ::trophyReward.isRewardItem(rewardType)

      if (rewardType == "unit" || rewardType == "rentedUnit")
      {
        unit = ::getAircraftByName(reward[rewardType]) || unit
        //Datablock adapter used only to avoid bug with duplicate timeHours in userlog.
        rentTimeHours = ::DataBlockAdapter(reward).timeHours || rentTimeHours
      }
    }
  }

  function getRewardImage(trophyStyle = "")
  {
    local layersData = ""
    for (local i = 0; i < ::trophyReward.maxRewardsShow; i++)
    {
      local config = shrinkedConfigsArray?[i]
      if (config)
        layersData += ::trophyReward.getImageByConfig(config, false)
    }

    if (layersData == "")
      return ""

    local layerId = "item_place_container"
    local layerCfg = ::LayersIcon.findLayerCfg(trophyStyle + "_" + layerId)
    if (!layerCfg)
      layerCfg = ::LayersIcon.findLayerCfg(layerId)

    return ::LayersIcon.genDataFromLayer(layerCfg, layersData)
  }

  function onTake(curUnit)
  {
    if (!curUnit.isUsable())
      return

    ::gui_start_selecting_crew({unit = curUnit, unitObj = scene.findObject(curUnit.name), cellClass = "slotbarClone"})
  }

  function onEventCrewTakeUnit(params)
  {
    goBack()
  }

  function onUnitHover(obj)
  {
    openUnitActionsList(obj, true, true)
  }

  function updateButtons()
  {
    if (!::checkObj(scene))
      return

    ::show_facebook_screenshot_button(scene, opened)
    showSceneBtn("btn_rewards_list", opened && (configsArray.len() > 1 || haveItems))
    showSceneBtn("open_chest_animation", !animFinished) //hack tooltip bug
    showSceneBtn("btn_ok", animFinished)
    showSceneBtn("btn_back", animFinished || trophyItem.isAllowSkipOpeningAnim())

    showSceneBtn("btn_take_air", animFinished && unit != null && unit.isUsable() && !::isUnitInSlotbar(unit))
  }

  function onViewRewards()
  {
    if (!checkSkipAnim())
      return

    if (opened && (configsArray.len() > 1 || haveItems))
      ::gui_start_open_trophy_rewards_list(shrinkedConfigsArray)
  }

  function goBack()
  {
    if (trophyItem && !checkSkipAnim())
      return

    base.goBack()
  }

  function afterModalDestroy()
  {
    if (afterFunc)
      afterFunc()
  }

  function checkSkipAnim()
  {
    if (animFinished)
      return true

    if (!trophyItem.isAllowSkipOpeningAnim())
      return false

    local animObj = scene.findObject("open_chest_animation")
    if (::checkObj(animObj))
      animObj.animation = "hide"
    animFinished = true

    openChest()
    return false
  }

  function onOpenAnimFinish()
  {
    animFinished = true
    if (!openChest())
      updateButtons()
  }
}
