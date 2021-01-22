local time = require("scripts/time.nut")
local sheets = require("scripts/items/itemsShopSheets.nut")
local daguiFonts = require("scripts/viewUtils/daguiFonts.nut")
local { canStartPreviewScene, getDecoratorDataToUse, useDecorator } = require("scripts/customization/contentPreview.nut")
local ExchangeRecipes = require("scripts/items/exchangeRecipes.nut")
local { findGenByReceptUid } = require("scripts/items/itemsClasses/itemGenerators.nut")

::gui_start_open_trophy <- function gui_start_open_trophy(configsTable = {})
{
  if (configsTable.len() == 0)
    return

  local params = {}
  foreach (paramName in [ "rewardTitle", "rewardListLocId", "isDisassemble",
    "isHidePrizeActionBtn", "singleAnimationGuiSound", "rewardImage", "rewardImageRatio",
    "rewardImageShowTimeSec", "reUseRecipeUid" ])
  {
    if (!(paramName in configsTable))
      continue

    params[paramName] <- configsTable[paramName]
    configsTable.rawdelete(paramName)
  }

  local tKey = ""
  foreach(idx, configsArray in configsTable)
  {
    tKey = idx
    break
  }

  local configsArray = configsTable.rawdelete(tKey)
  configsArray.sort(::trophyReward.rewardsSortComparator)

  local itemId = configsArray?[0]?.itemDefId
    ?? configsArray?[0]?.trophyItemDefId
    ?? configsArray?[0]?.id
    ?? ""

  local trophyItem = ::ItemsManager.findItemById(itemId)
  if (!trophyItem)
  {
    local configsArrayString = ::toString(configsArray, 2) // warning disable: -declared-never-used
    local isLoggedIn = ::g_login.isLoggedIn()              // warning disable: -declared-never-used
    local { dbgTrophiesListInternal, dbgLoadedTrophiesCount, itemsListInternal, // warning disable: -declared-never-used
      dbgLoadedItemsInternalCount, dbgUpdateInternalItemsCount // warning disable: -declared-never-used
    } = ::ItemsManager.getInternalItemsDebugInfo()  // warning disable: -declared-never-used
    local trophiesBlk = ::get_price_blk()?.trophy
    local currentItemsInternalCount = itemsListInternal.len() // warning disable: -declared-never-used
    local currentTrophiesInternalCount = dbgTrophiesListInternal.len() // warning disable: -declared-never-used
    local trophiesListInternalString = ::toString(dbgTrophiesListInternal)  // warning disable: -declared-never-used
    local trophiesBlkString = ::toString(trophiesBlk)  // warning disable: -declared-never-used
    local trophyBlkString = ::toString(trophiesBlk?[itemId]) // warning disable: -declared-never-used

    ::script_net_assert_once("not found trophyItem", "Trophy Reward: Not found item. Don't show reward.")
    return
  }

  params.trophyItem <- trophyItem
  params.configsArray <- configsArray
  params.afterFunc <- @() ::gui_start_open_trophy(configsTable)

  ::gui_start_modal_wnd(::gui_handlers.trophyRewardWnd, params)
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
  shouldShowRewardItem = false
  isDisassemble = false

  haveItems = false
  rewardItem = null //reward item to show button "go to item"
  isRewardItemActual = false //reward item cn be received, but not visible.
  opened = false
  animFinished = false

  useSingleAnimation = true

  unit = null
  rentTimeHours = 0

  slotbarActions = [ "take", "sec_weapons", "weapons", "info" ]

  decorator = null
  decoratorUnit = null
  decoratorSlot = -1
  rewardTitle = null
  rewardListLocId = null
  isHidePrizeActionBtn = false
  singleAnimationGuiSound = null
  rewardImage = null
  rewardImageRatio = 1
  rewardImageShowTimeSec = -1
  reUseRecipeUid = null
  reUseRecipe = null

  function initScreen()
  {
    configsArray = configsArray ?? []
    rewardTitle = configsArray?[0].rewardTitle ?? rewardTitle
    rewardListLocId = configsArray?[0].rewardListLocId ?? rewardListLocId

    prepareParams()

    setTitle()
    checkConfigsArray()
    updateRewardItem()
    updateWnd()
    startOpening()

    scene.findObject("update_timer").setUserData(this)
  }

  function prepareParams()
  {
    shouldShowRewardItem = trophyItem.iType == itemType.RECIPES_BUNDLE
    isBoxOpening = !shouldShowRewardItem
      && (trophyItem.iType == itemType.TROPHY
         || trophyItem.iType == itemType.CHEST
         || trophyItem.iType == itemType.CRAFT_PROCESS
         || trophyItem.iType == itemType.CRAFT_PART)

    shrinkedConfigsArray = ::trophyReward.processUserlogData(configsArray)
    if (reUseRecipeUid != null)
      reUseRecipe = findGenByReceptUid(reUseRecipeUid)?.getRecipeByUid?(reUseRecipeUid)
  }

  function setTitle()
  {
    local title = getTitle()

    local titleObj = scene.findObject("reward_title")
    titleObj.setValue(title)
    if (daguiFonts.getStringWidthPx(title, "fontMedium", guiScene) >
      ::to_pixels("1@trophyWndWidth - 1@buttonCloseHeight"))
      titleObj.caption = "no"
  }

  getTitle = @() rewardTitle && rewardTitle != "" ? rewardTitle
    : isDisassemble && !shouldShowRewardItem ? ::loc("mainmenu/itemDisassembled/title")
    : isCreation() ? trophyItem.getCreationCaption()
    : trophyItem.getOpeningCaption()

  isRouletteStarted = @() ::ItemsRoulette.init(
    trophyItem.id,
    configsArray,
    scene,
    this,
    function() {
      openChest.call(this)
      onOpenAnimFinish.call(this)
    }
  )

  function startOpening()
  {
    if (isRouletteStarted())
      useSingleAnimation = false

    ::showBtn(useSingleAnimation? "reward_roullete" : "open_chest_animation", false, scene) //hide not used animation
    local animId = useSingleAnimation? "open_chest_animation" : "reward_roullete"
    local animObj = scene.findObject(animId)
    if (::checkObj(animObj))
    {
      animObj.animation = "show"
      if (useSingleAnimation)
      {
        guiScene.playSound(singleAnimationGuiSound ?? "chest_open")
        local delay = ::to_integer_safe(animObj?.chestReplaceDelay, 0)
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
    notifyTrophyVisible()
    return true
  }

  notifyTrophyVisible = @() ::broadcastEvent("TrophyContentVisible", { trophyItem = trophyItem })

  function updateWnd()
  {
    updateImage()
    updateRewardText()
    updateRewardPostscript()
    updateButtons()
  }

  function getIconData() {
    local itemToShow = trophyItem
    if (shouldShowRewardItem && configsArray[0]?.item)
      itemToShow = ::ItemsManager.findItemById(configsArray[0].item)

    local layersData = ""
    if (isBoxOpening && (opened || useSingleAnimation)) {
      layersData = itemToShow.getOpenedBigIcon()
      if (opened && useSingleAnimation)
        layersData += getRewardImage(itemToShow.iconStyle)
    } else
      layersData = itemToShow.getBigIcon()

    return layersData
  }

  function updateTrophyImage() {
    local imageObjPlace = scene.findObject("reward_image_place")
    if (!::check_obj(imageObjPlace))
      return

    local layersData = getIconData()
    guiScene.replaceContentFromText(imageObjPlace, layersData, layersData.len(), this)
  }

  function updateImage()
  {
    if (rewardImage == null) {
      updateTrophyImage()
      return
    }

    local imageObj = showSceneBtn("reward_image", true)
    imageObj["background-image"] = rewardImage
    imageObj.width = $"{rewardImageRatio}@chestRewardHeight"
    if (rewardImageShowTimeSec > 0)
      ::Timer(scene, rewardImageShowTimeSec, function() {
          if (!isValid())
            return

          showSceneBtn("reward_image", false)
          updateTrophyImage()
        }, this)
  }

  function updateRewardPostscript()
  {
    if (!opened || !useSingleAnimation)
      return

    local countNotVisibleItems = shrinkedConfigsArray.len() - ::trophyReward.maxRewardsShow

    if (countNotVisibleItems < 1)
      return

    local obj = scene.findObject("reward_postscript")
    if (!::check_obj(obj))
      return

    obj.setValue(::loc("trophy/moreRewards", {num = countNotVisibleItems}))
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
                     header = ::loc("mainmenu/you_received")
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
        rentTimeHours = ::DataBlockAdapter(reward)?.timeHours || rentTimeHours
      }

      if (rewardType == "resource" || rewardType == "resourceType")
      {
        local decorData = getDecoratorDataToUse(reward?.resource, reward?.resourceType)
        if (decorData.decorator != null)
        {
          decorator = decorData.decorator
          decoratorUnit = decorData.decoratorUnit
          decoratorSlot = decorData.decoratorSlot
          local obj = scene.findObject("btn_use_decorator")
          if (::check_obj(obj))
            obj.setValue(::loc($"decorator/use/{decorator.decoratorType.resourceType}"))
        }
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

  function onTake(unitToTake)
  {
    base.onTake(unitToTake, {
      cellClass = "slotbarClone"
      isNewUnit = true
      afterSuccessFunc = ::Callback(@() goBack(), this)
    })
  }

  function updateButtons()
  {
    if (!::checkObj(scene))
      return

    ::show_facebook_screenshot_button(scene, opened)
    local isShowRewardListBtn = opened && (configsArray.len() > 1 || haveItems)
    local btnObj = showSceneBtn("btn_rewards_list", isShowRewardListBtn)
    if (isShowRewardListBtn)
      btnObj.setValue(::loc(getRewardsListLocId()))
    showSceneBtn("open_chest_animation", !animFinished) //hack tooltip bug
    showSceneBtn("btn_ok", animFinished)
    showSceneBtn("btn_back", animFinished || (trophyItem?.isAllowSkipOpeningAnim() ?? false))

    local prizeActionBtnId = isHidePrizeActionBtn || !animFinished ? ""
      : unit && unit.isUsable() && !::isUnitInSlotbar(unit) ? "btn_take_air"
      : rewardItem ? "btn_go_to_item"
      : decorator && canStartPreviewScene(false) ? "btn_use_decorator"
      : ""
    foreach (id in [ "btn_take_air", "btn_go_to_item", "btn_use_decorator" ])
      showSceneBtn(id, id == prizeActionBtnId)

    local canReUseItem = animFinished && reUseRecipe != null
    btnObj = showSceneBtn("btn_re_use_item", canReUseItem)
    if (canReUseItem) {
      btnObj.inactiveColor = reUseRecipe.isUsable ? "no" : "yes"
      btnObj.setValue(::loc(trophyItem.getLocIdsList().reUseItemLocId))
    }
  }

  function onViewRewards()
  {
    if (!checkSkipAnim() || !(opened && (configsArray.len() > 1 || haveItems)))
      return

    ::gui_start_open_trophy_rewards_list({ rewardsArray = shrinkedConfigsArray,
      tittleLocId = getRewardsListLocId()})
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

    if (!trophyItem?.isAllowSkipOpeningAnim() ?? false)
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

  function updateRewardItem() //ext item will come later, so need to wait until it received to show button
  {
    if (!haveItems || isRewardItemActual)
      return false

    foreach(reward in configsArray)
      if (reward?.item)
      {
        rewardItem = ItemsManager.getInventoryItemById(reward.item)
        if (!rewardItem)
          continue

        isRewardItemActual = true
        if (!sheets.getSheetDataByItem(rewardItem))
          rewardItem = null
        return true
      }
    return false
  }

  onTimer = @(obj, dt) updateRewardItem() && updateButtons()

  function onGoToItem()
  {
    goBack()
    if (rewardItem)
      ::gui_start_items_list(-1, { curItem = rewardItem })
  }

  onUseDecorator = @() useDecorator(decorator, decoratorUnit, decoratorSlot)

  function onReUseItem() {
    if (reUseRecipe == null)
      return
    goBack()
    guiScene.performDelayed(this, @() ExchangeRecipes.tryUse([reUseRecipe], trophyItem, {
      shouldSkipMsgBox = reUseRecipe.isUsable
      isHidePrizeActionBtn  = isHidePrizeActionBtn
    }))
  }

  isCreation = @() (!shouldShowRewardItem && configsArray[0]?.item == trophyItem.id)
  getRewardsListLocId = @() rewardListLocId && rewardListLocId != "" ? rewardListLocId
    : isCreation() ? trophyItem.getItemsListLocId()
    : trophyItem.getRewardListLocId()
}
