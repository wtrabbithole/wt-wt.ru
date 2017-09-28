/*
  weaponVisual API

    createItem(id, item, type, holderObj, handler, params)  - creates base visual item, but not update it.
               params <- { posX, posY }
    createBundle(itemsList, itemsType, subType, holderObj, handler)  - creates items bundle
                 params <- { posX, posY, createItemFunc, maxItemsInColumn, subType }
*/

::dagui_propid.add_name_id("_iconBulletName")

::weaponVisual <- {
}

function weaponVisual::createItemLayout(id, item, type, params = {})
{
  item.type <- type
  local view = {
    id = id
    itemWidth = ::getTblValue("itemWidth", params, 1)
    posX = ::getTblValue("posX", params, 0)
    posY = ::getTblValue("posY", params, 0)
    isBundle = item.type == weaponsItem.bundle
    hideStatus = ::getTblValue("hideStatus", item, false)
    useGenericTooltip = ::getTblValue("useGenericTooltip", params, false)
    needSliderButtons = ::getTblValue("needSliderButtons", params, false)
    wideItemWithSlider = ::getTblValue("wideItemWithSlider", params, false)
  }
  return ::handyman.renderCached("gui/weaponry/weaponItem", view)
}

function weaponVisual::createItem(id, item, type, holderObj, handler, params = {})
{
  local data = createItemLayout(id, item, type, params)
  holderObj.getScene().appendWithBlk(holderObj, data, handler)
  return holderObj.findObject(id)
}

function weaponVisual::createBundle(id, itemsList, itemsType, holderObj, handler, params = {})
{
  if (itemsList.len()==0)
    return

  local maxItemsInColumn = ::getTblValue("maxItemsInColumn", params, 5)
  local createItemFunc = ::getTblValue("createItemFunc", params, createItem)
  local bundleItem = {
      name = id
      type = weaponsItem.bundle
      hideStatus = true
      itemsType = itemsType
      subType = ::getTblValue("subType", params, 0)
      itemsList = itemsList
    }
  if (itemsType==weaponsItem.bullets)
    itemsType = weaponsItem.modification

  if (itemsList.len()==1)
  {
    itemsList[0].hideStatus <- true
    createItemFunc.call(handler, id, itemsList[0], itemsType, holderObj, handler, params)
    return itemsList[0]
  }

  local bundleObj = createItemFunc.call(handler, id, bundleItem, bundleItem.type, holderObj, handler, params)
  bundleObj["class"] = "dropDown"

  local guiScene = holderObj.getScene()
  local hoverObj = guiScene.createElementByObject(bundleObj, "gui/weaponry/weaponBundleTop.blk", "hoverSize", handler)

  local cols = ((itemsList.len()-1)/maxItemsInColumn + 1).tointeger()
  local rows = ((itemsList.len()-1)/cols + 1).tointeger()
  local itemsObj = hoverObj.findObject("items_field")
  foreach(idx, item in itemsList)
    createItemFunc.call(handler, id + "_" + idx, item, itemsType, itemsObj, handler, { posX = (idx/rows).tointeger(), posY = idx%rows })
  itemsObj.width = cols + "@modCellWidth"
  itemsObj.height = rows + "@modCellHeight"

  hoverObj.width = cols + "@modCellWidth"
  local rootSize = guiScene.getRoot().getSize()
  local rightSide = bundleObj.getPosRC()[0] < 0.7 * rootSize[0] //better to use width const here, but need const calculator from dagui for that
  if (rightSide)
    hoverObj.pos = "0.5pw-0.5@modCellWidth, ph"
  else
    hoverObj.pos = "0.5pw+0.5@modCellWidth-w, ph"

  local cellObj = ::getTblValue("cellSizeObj", params) || bundleObj
  local cellSize = cellObj.getSize()
  hoverObj["height-end"] = (cellSize[1].tofloat() * (rows + 0.4)).tointeger().tostring()
  return bundleItem
}

function weaponVisual::updateItem(air, item, itemObj, showButtons, handler, params = {})
{
  local guiScene = itemObj.getScene()
  local isOwn = ::isUnitUsable(air)
  local visualItem = item
  local isBundle = item.type == weaponsItem.bundle
  if (isBundle)
    visualItem = getBundleCurItem(air, item) || visualItem

  local limitedName = ::getTblValue("limitedName", params, true)
  itemObj.findObject("name").setValue(getItemName(air, visualItem, limitedName))
  if (::getTblValue("useGenericTooltip", params))
    updateGenericTooltipId(itemObj, air, item)

  local bIcoItem = getBulletsIconItem(air, visualItem)
  if (bIcoItem)
  {
    local divObj = itemObj.findObject("bullets")
    if (divObj._iconBulletName != bIcoItem.name)
    {
      divObj._iconBulletName = bIcoItem.name
      local bulletsSet = getBulletsSetData(air, bIcoItem.name)
      dagor.assertf(isTank(air) || bulletsSet!=null, "No bullets in bullets set " + visualItem.name + " for " + air.name)
      local iconData = getBulletsIconData(bulletsSet)
      guiScene.replaceContentFromText(divObj, iconData, iconData.len(), handler)
    }
  }

  local imgObj = itemObj.findObject("image")
  imgObj["background-image"] = bIcoItem? "" : getItemImage(air, visualItem)

  local statusTbl = getItemStatusTbl(air, visualItem)
  local canBeDisabled = isCanBeDisabled(item)
  local isSwitcher = isItemSwitcher(visualItem)
  local discount = ::getDiscountByPath(getDiscountPath(air, visualItem, statusTbl.discountType))
  local priceText = statusTbl.showPrice && ::getTblValue("canShowPrice", params, true) ? getFullItemCostText(air, item) : ""
  local flushExp = ::getTblValue("flushExp", params, 0)
  local canShowResearch = ::getTblValue("canShowResearch", params, true)
  local canResearch = canResearchItem(air, visualItem, false)
  local itemReqExp = ::getTblValue("reqExp", visualItem, 0)
  local isModResearching = canShowResearch &&
                               canResearch &&
                               statusTbl.modExp >= 0 &&
                               statusTbl.modExp < itemReqExp &&
                               !statusTbl.amount

  local isResearchInProgress = isModResearching && isModInResearch(air, visualItem)
  local isResearchPaused = isModResearching && statusTbl.modExp > 0 && !isModInResearch(air, visualItem)

  local showStatus = false
  if (::getTblValue("canShowStatusImage", params, true))
    if (visualItem.type == weaponsItem.weapon || isBullets(visualItem))
      showStatus = true
    else if (visualItem.type == weaponsItem.modification || visualItem.type == weaponsItem.expendables)
      showStatus = canBeDisabled && statusTbl.amount

  local statusObj = itemObj.findObject("status_image")
  if(statusObj)
    statusObj.show(showStatus && (! statusTbl.unlocked || ! isSwitcher))

  local statusRadioObj = itemObj.findObject("status_radio")
  if(statusRadioObj)
    statusRadioObj.show(showStatus && statusTbl.unlocked &&
      isSwitcher && !::is_fake_bullet(visualItem.name))

  local blockObj = itemObj.findObject("modItem_statusBlock")
  if (blockObj)
    blockObj.show(!isResearchInProgress)
  local dObj = itemObj.findObject("discount")
  if(::checkObj(dObj))
    guiScene.destroyElement(dObj)

  local haveDiscount = discount > 0 && (statusTbl.amount == 0 || priceText != "")
  if (haveDiscount)
  {
    local discountObj = itemObj.findObject("modItem_discount")
    if (discountObj)
      ::addBonusToObj(handler, discountObj, discount, statusTbl.discountType, true, "weaponryItem")
    if (priceText != "")
      priceText = "<color=@goodTextColor>" + priceText +"</color>"
  }

  local showProgress = isResearchInProgress || isResearchPaused

  local priceObj = itemObj.findObject("price")
  if (priceObj)
    priceObj.show(!showProgress && (statusTbl.showPrice || canResearch))

  local progressBlock = itemObj.findObject("mod_research_block")
  if (progressBlock)
    progressBlock.show(showProgress)
  if (showProgress && progressBlock)
  {
    local diffExp = ::getTblValue("diffExp", params, 0)
    local progressObj = progressBlock.findObject("mod_research_progress")

    progressObj.setValue((itemReqExp ? statusTbl.modExp.tofloat() / itemReqExp : 1) * 1000)
    progressObj.type = diffExp? "new" : ""
    progressObj.paused = isResearchPaused? "yes" : "no"

    local oldExp = max(0, statusTbl.modExp - diffExp)
    local progressObjOld = progressBlock.findObject("mod_research_progress_old")
    progressObjOld.show(oldExp > 0)
    progressObjOld.setValue((itemReqExp ? oldExp.tofloat() / itemReqExp : 1) * 1000)
    progressObjOld.paused = isResearchPaused? "yes" : "no"
  }
  else
  {
    if (priceObj && statusTbl.showPrice)
      priceObj.setValue(priceText)
    else if (priceObj && canResearch && !isResearchInProgress && !isResearchPaused)
    {
      local showExp = itemReqExp - statusTbl.modExp
      local rpText = getRpPriceText(showExp, true)
      if (flushExp > 0 && flushExp > showExp)
        rpText = "<color=@goodTextColor>" + rpText + "</color>"
      priceObj.setValue(rpText)
    }
  }

  local iconObj = itemObj.findObject("icon")
  local optEquipped = statusTbl.equipped || ::getTblValue("isForceEquipped", params, false) ? "yes" : "no"
  local optStatus = "locked"
  if (::getTblValue("visualDisabled", params, false))
    optStatus = "disabled"
  else if (statusTbl.amount)
    optStatus = "owned"
  else if (statusTbl.unlocked || ::getTblValue("isForceUnlocked", params, false))
    optStatus = "unlocked"
  else if (isModInResearch(air, visualItem) && visualItem.type == weaponsItem.modification)
    optStatus = canShowResearch? "research" : "researchable"
  else if (canResearchItem(air, visualItem))
    optStatus = "researchable"

  itemObj.equipped = optEquipped
  itemObj.status = optStatus
  iconObj.equipped = optEquipped
  iconObj.status = optStatus

  if (!::getTblValue("isForceHideAmount", params, false))
  {
    local amountText = getAmountAndMaxAmountText(statusTbl.amount, statusTbl.maxAmount, statusTbl.showMaxAmount);
    local amountObject = itemObj.findObject("amount");
    amountObject.setValue(amountText)
    amountObject.overlayTextColor = statusTbl.amount < statusTbl.amountWarningValue ? "weaponWarning" : "";
  }

  itemObj.findObject("warning_icon").show(statusTbl.unlocked && statusTbl.showMaxAmount && statusTbl.amount < statusTbl.amountWarningValue)

  updateItemBulletsSliderByItem(itemObj, ::getTblValue("selectBulletsByManager", params), visualItem)

  local showMenuIcon = isBundle || ::getTblValue("hasMenu", params)
  local visualHasMenuObj = itemObj.findObject("modItem_visualHasMenu")
  if (visualHasMenuObj)
    visualHasMenuObj.show(showMenuIcon)

  if (!showButtons)
    return

  //updateButtons
  local btnText = ""
  local showBtnOnlySelected = false
  if (isBundle)
  {
    showBtnOnlySelected = true
    btnText = ::loc("mainmenu/btnAirGroupOpen")
  }
  else if (isOwn && statusTbl.unlocked)
  {
    if (!statusTbl.amount || visualItem.type == weaponsItem.spare)
      btnText = ::loc("mainmenu/btnBuy")
    else if (isSwitcher && !statusTbl.equipped)
      btnText = ::loc("mainmenu/btnSelect")
    else if (visualItem.type == weaponsItem.modification)
      btnText = statusTbl.equipped ? (canBeDisabled ? ::loc("mod/disable") : "") : ::loc("mod/enable")
  }
  else if (canResearchItem(air, visualItem) || (canResearchItem(air, visualItem, false) && (flushExp > 0 || !canShowResearch)))
    btnText = ::loc("mainmenu/btnResearch")

  local actionBtn = itemObj.findObject("actionBtn")
  actionBtn.canShow = btnText == "" ? "no" : !showBtnOnlySelected? "yes"
                      : (isBundle) ? "console" : "selected"
  actionBtn.setValue(btnText)

  //alternative action button
  local altBtn = itemObj.findObject("altActionBtn")
  local altBtnText = ""
  if (statusTbl.goldUnlockable && !(::getTblValue("researchMode", params, false) && flushExp > 0))
    altBtnText = getItemUnlockCost(air, item).tostring()
  if (altBtnText != "")
    altBtnText = ::loc("mainmenu/btnBuy") + ::loc("ui/parentheses/space", {text = altBtnText})
  else if (visualItem.type == weaponsItem.spare)
  {
    if (::ItemsManager.getInventoryList(itemType.UNIVERSAL_SPARE).len())
      altBtnText = ::loc("items/universalSpare/activate", { icon = ::loc("icon/universalSpare") })
  }
  else if (statusTbl.amount && statusTbl.maxAmount > 1
            && statusTbl.amount < statusTbl.maxAmount
            && !isBundle)
    altBtnText = ::loc("mainmenu/btnBuy")

  altBtn.canShow = (altBtnText == "") ? "no" : "yes"
  local textObj = altBtn.findObject("item_buy_text")
  if (::checkObj(textObj))
    textObj.setValue(altBtnText)
}

function weaponVisual::getItemStatusTbl(air, item)
{
  local isOwn = ::isUnitUsable(air)
  local res = {
    amount = getItemAmount(air, item)
    maxAmount = 0
    amountWarningValue = 0
    modExp = 0
    showMaxAmount = false
    canBuyMore = false
    equipped = false
    goldUnlockable = false
    unlocked = false
    showPrice = true
    discountType = ""
  }

  if (item.type == weaponsItem.weapon)
  {
    res.maxAmount = ::getAmmoMaxAmount(air.name, item.name, AMMO.WEAPON)
    res.amount = ::getAmmoAmount(air.name, item.name, AMMO.WEAPON)
    res.showMaxAmount = res.maxAmount > 1
    res.amountWarningValue = ::weaponsWarningMinimumSecondary
    res.canBuyMore = res.amount < res.maxAmount
    res.equipped = res.amount && ::get_last_weapon(air.name) == item.name
    res.unlocked = ::is_weapon_enabled(air, item)
    res.discountType = "weapons"
  }
  else if (item.type == weaponsItem.primaryWeapon)
  {
    res.equipped = ::get_last_primary_weapon(air) == item.name
    if (item.name == "") //default
      res.unlocked = isOwn
    else
    {
      res.maxAmount = ::wp_get_modification_max_count(air.name, item.name)
      res.equipped = res.amount && ::shop_is_modification_enabled(air.name, item.name)
      res.unlocked = res.amount || ::canBuyMod(air, item)
      res.showPrice = false//amount < maxAmount
    }
  }
  else if (item.type == weaponsItem.modification || item.type == weaponsItem.expendables)
  {
    local groupDef = ("isDefaultForGroup" in item)? item.isDefaultForGroup : -1
    if (groupDef >= 0) //default bullets, always bought.
    {
      res.unlocked = isOwn
      local currBullet = ::get_last_bullets(air.name, groupDef);
      res.equipped = !currBullet || currBullet == "" || currBullet == item.name
      res.showPrice = false
    }
    else
    {
      res.unlocked = res.amount || ::canBuyMod(air, item)
      res.maxAmount = ::wp_get_modification_max_count(air.name, item.name)
      res.amountWarningValue = ::weaponsWarningMinimumPrimary
      res.canBuyMore = res.amount < res.maxAmount
      res.modExp = ::shop_get_module_exp(air.name, item.name)
      res.discountType = "mods"
      if (!isBullets(item))
      {
        res.equipped = res.amount && ::shop_is_modification_enabled(air.name, item.name)
        res.goldUnlockable = !res.unlocked && ::has_feature("SpendGold") && canBeResearched(air, item, false)
        if (item.type == weaponsItem.expendables)
          res.showPrice = !res.amount || ::canBuyMod(air, item)
        else
          res.showPrice = !res.amount && ::canBuyMod(air, item)
      }
      else
      {
        res.equipped = false
        res.showMaxAmount = res.maxAmount > 1
        local id = get_bullet_group_index(air.name, item.name)
        if (id >= 0)
        {
          local currBullet = ::get_last_bullets(air.name, id);
          res.equipped = res.amount && (currBullet == item.name)
        }
      }
    }
  }
  else if (item.type == weaponsItem.spare)
  {
    res.equipped = res.amount > 0
    res.maxAmount = ::max_spare_amount
    res.showMaxAmount = false
    res.canBuyMore = true
    res.unlocked = isOwn
    res.discountType = "spare"
  }
  return res
}

function weaponVisual::isItemSwitcher(item)
{
  return (item.type == weaponsItem.weapon) || (item.type == weaponsItem.primaryWeapon) || isBullets(item)
}

function weaponVisual::updateGenericTooltipId(itemObj, unit, item)
{
  local tooltipObj = itemObj.findObject("tooltip_" + itemObj.id)
  if (!tooltipObj)
    return

  local tooltipId = ""
  if (item.type == weaponsItem.modification)
    tooltipId = ::g_tooltip_type.MODIFICATION.getTooltipId(unit.name, item.name)
  else if (item.type == weaponsItem.weapon)
    tooltipId = ::g_tooltip_type.WEAPON.getTooltipId(unit.name, item.name)
  else if (item.type == weaponsItem.spare)
    tooltipId = ::g_tooltip_type.SPARE.getTooltipId(unit.name)
  tooltipObj.tooltipId = tooltipId
}

function weaponVisual::updateItemBulletsSliderByItem(itemObj, bulletsManager, item)
{
  local bulGroup = null
  if (bulletsManager != null && bulletsManager.canChangeBulletsCount())
    bulGroup = bulletsManager.getBulletGroupBySelectedMod(item)
  updateItemBulletsSlider(itemObj, bulletsManager, bulGroup)
}

function weaponVisual::updateItemBulletsSlider(itemObj, bulletsManager, bulGroup)
{
  local show = bulGroup != null && bulletsManager != null && bulletsManager.canChangeBulletsCount()
  local holderObj = ::showBtn("bullets_amount_choice_block", show, itemObj)
  if (!show || !holderObj)
    return

  local guns = bulGroup.guns
  local maxVal = bulGroup.maxBulletsCount
  local curVal = bulGroup.bulletsCount
  local unallocated = bulletsManager.getUnallocatedBulletCount(bulGroup)

  local textObj = holderObj.findObject("bulletsCountText")
  if (::checkObj(textObj))
  {
    local restText = ""
    if (unallocated)
      restText = ::colorize("userlogColoredText", ::loc("ui/parentheses", { text = "+" + unallocated * guns }))
    local valColor = "activeTextColor"
    if (!curVal || maxVal == 0)
      valColor = "badTextColor"
    else if (curVal == maxVal)
      valColor = "goodTextColor"

    local valText = ::colorize(valColor, curVal*guns)
    local text = ::format("%s\\%s %s", valText, (maxVal*guns).tostring(), restText)
    textObj.setValue(text)
  }

  local btnDec = holderObj.findObject("buttonDec")
  if (::checkObj(btnDec))
    btnDec.bulletsLimit = curVal != 0? "no" : "yes"

  local btnIncr = holderObj.findObject("buttonInc")
  if (::checkObj(btnIncr))
    btnIncr.bulletsLimit = (curVal != maxVal && unallocated != 0)? "no" : "yes"

  local slidObj = holderObj.findObject("bulletsSlider")
  if (::checkObj(slidObj))
  {
    slidObj.max = maxVal.tostring()
    slidObj.setValue(curVal)
  }
  local invSlidObj = holderObj.findObject("invisBulletsSlider")
  if (::checkObj(invSlidObj))
  {
    invSlidObj.groupIdx = bulGroup.groupIndex
    invSlidObj.max = maxVal.tostring()
    if (invSlidObj.getValue() != curVal)
      invSlidObj.setValue(curVal)
  }
}

function weaponVisual::getBundleCurItem(air, bundle)
{
  if (!("itemsType" in bundle))
    return null

  if (bundle.itemsType == weaponsItem.weapon)
  {
    local curWeapon = ::get_last_weapon(air.name)
    foreach(item in bundle.itemsList)
      if (curWeapon == item.name)
        return item
    return bundle.itemsList[0]
  }
  else if (bundle.itemsType == weaponsItem.bullets)
  {
    local curName = ::get_last_bullets(air.name, ::getTblValue("subType", bundle, 0))
    local def = null
    foreach(item in bundle.itemsList)
      if (curName == item.name)
        return item
      else if (("isDefaultForGroup" in item)
               || (!def && curName == "" && !::wp_get_modification_cost(air.name, item.name)))
        def = item
    return def
  }
  else if (bundle.itemsType == weaponsItem.primaryWeapon)
  {
    local curPrimaryWeaponName = ::get_last_primary_weapon(air)
    foreach (item in bundle.itemsList)
      if(item.name == curPrimaryWeaponName)
        return item
  }
  return null
}

function weaponVisual::getByCurBundle(air, bundle, func, defValue = "")
{
  local cur = getBundleCurItem(air, bundle)
  return cur? func(air, cur) : defValue
}

function weaponVisual::isBullets(item)
{
  return ("isDefaultForGroup" in item) && (item.isDefaultForGroup >= 0) ||
    (item.type == weaponsItem.modification && ::getModificationBulletsGroup(item.name) != "")
}

function weaponVisual::getBulletsIconItem(air, item)
{
  if (isBullets(item))
    return item

  if (item.type == weaponsItem.modification)
  {
    updateRelationModificationList(air, item.name)
    if ("relationModification" in item && item.relationModification.len() == 1)
      return ::getModificationByName(air, item.relationModification[0])
  }
  return null
}

function weaponVisual::getItemName(air, item, limitedName = true)
{
  return ::g_weaponry_types.getUpgradeTypeByItem(item).getLocName(air, item, limitedName)
}

function weaponVisual::getItemImage(air, item)
{
  if (!isBullets(item))
  {
    if (item.type==weaponsItem.bundle)
      return getByCurBundle(air, item, getItemImage)

    if("image" in item && item.image != "")
      return item.image
    if (item.type==weaponsItem.primaryWeapon && ("weaponMod" in item) && item.weaponMod)
      return getItemImage(air, item.weaponMod)
  }
  return ""
}

function weaponVisual::getBulletsIconData(bulletsSet)
{
  if (!bulletsSet)
    return ""
  local blk = ::handyman.renderCached(("gui/weaponry/bullets"), getBulletsIconView(bulletsSet))
  return blk
}

/**
 * @param tooltipId If not null, tooltip block
 * will be added with specified tooltip id.
 */
function weaponVisual::getBulletsIconView(bulletsSet, tooltipId = null, tooltipDelayed = false)
{
  local view = {}
  if (!bulletsSet || !("bullets" in bulletsSet))
    return view

  view.bullets <- (@(bulletsSet, tooltipId, tooltipDelayed) function () {
      local res = []

      local length = bulletsSet.bullets.len()
      local isBelt = "isBulletBelt" in bulletsSet ? bulletsSet.isBulletBelt : true
      local maxAmountInView = 4
      if (bulletsSet.catridge)
        maxAmountInView = ::min(bulletsSet.catridge, maxAmountInView)
      local count = isBelt ? length * max(1,floor(maxAmountInView / length)) : 1
      local totalWidth = 100.0
      local itemWidth = isBelt ? totalWidth / 5 : totalWidth
      local itemHeight = totalWidth
      local space = totalWidth - itemWidth * count
      local separator = (space > 0) ? (space / (count + 1)) : (count == 1 ? space : (space / (count - 1)))
      local start = (space > 0) ? separator : 0.0

      ::init_bullet_icons()

      for (local i = 0; i < count; i++)
      {
        local imgId = bulletsSet.bullets[i % length]
        if (imgId.find("@") != null)
          imgId = imgId.slice(0, imgId.find("@"))
        local defaultImgId = ("caliber" in bulletsSet && bulletsSet.caliber < 0.015) ? "default_ball" : "default_shell"

        local item = {
          image           = "#ui/gameuiskin#" + bullet_icons[ (imgId in bullet_icons) ? imgId : defaultImgId ]
          posx            = (start + (itemWidth + separator) * i) + "%pw"
          sizex           = itemWidth + "%pw"
          sizey           = itemHeight + "%pw"
          useTooltip      = tooltipId != null
          tooltipId       = tooltipId
          tooltipDelayed  = tooltipId != null && tooltipDelayed
        }
        res.append(item)
      }

      return res
    })(bulletsSet, tooltipId, tooltipDelayed)

  local bIconParam = getTblValue("bIconParam", bulletsSet)
  if (bIconParam)
  {
    local addIco = []
    foreach(item in ::bullets_features_img)
    {
      local idx = ::getTblValue(item.id, bIconParam, -1)
      if (idx in item.values)
        addIco.append({ img = item.values[idx] })
    }
    if (addIco.len())
      view.addIco <- addIco
  }
  return view
}

function weaponVisual::getItemAmount(air, item)
{
  return ::g_weaponry_types.getUpgradeTypeByItem(item).getAmount(air, item)
}

function weaponVisual::getItemCost(air, item)
{
  return ::g_weaponry_types.getUpgradeTypeByItem(item).getCost(air, item)
}

//include spawn score cost
function weaponVisual::getFullItemCostText(unit, item)
{
  local res = ""
  local wType = ::g_weaponry_types.getUpgradeTypeByItem(item)
  local misRules = ::g_mis_custom_state.getCurMissionRules()

  if (!::is_in_flight() || misRules.isWarpointsRespawnEnabled)
    res = wType.getCost(unit, item).tostring()

  if (::is_in_flight() && misRules.isScoreRespawnEnabled)
  {
    local scoreCostText = wType.getScoreCostText(unit, item)
    if (scoreCostText.len())
      res += (res.len() ? ", " : "") + scoreCostText
  }
  return res
}

function weaponVisual::getItemUnlockCost(air, item)
{
  return ::g_weaponry_types.getUpgradeTypeByItem(item).getUnlockCost(air, item)
}

function weaponVisual::isCanBeDisabled(item)
{
  return (item.type == weaponsItem.modification || item.type == weaponsItem.expendables) &&
         (!("deactivationIsAllowed" in item) || item.deactivationIsAllowed) &&
         !isBullets(item)
}

function weaponVisual::isResearchableItem(item)
{
  return item.type == weaponsItem.modification
}

function weaponVisual::canResearchItem(air, item, checkCurrent = true)
{
  return item.type == weaponsItem.modification &&
         canBeResearched(air, item, checkCurrent)
}

function weaponVisual::canBeResearched(air, item, checkCurrent = true)
{
  if (isResearchableItem(item))
    return ::canResearchMod(air, item, checkCurrent)
  return false
}

function weaponVisual::isModInResearch(air, item)
{
  if (item.name == "" || !("type" in item) || item.type != weaponsItem.modification)
    return false

  local status = ::shop_get_module_research_status(air.name, item.name)
  return status == ::ES_ITEM_STATUS_IN_RESEARCH
}

function weaponVisual::getEffectDesc(air, effect)
{
  local desc = "";
  local speeds = [];
  local climbs = [];
  local rolls = [];
  local virages = [];

  local haveSpeeds = false;
  local haveClimbs = false;
  local haveRolls = false;
  local haveVirages = false;

  local masses = [];
  local oswalds = [];
  local cdMinFusel = [];
  local cdMinTail = [];
  local cdMinWing = [];
  local ailThrSpd = [];
  local ruddThrSpd = [];
  local elevThrSpd = [];
  local horsePowers = [];
  local thrust = [];
  local cdParasite = [];
  local turnTurretSpeedK = [];
  local gunPitchSpeedK = [];
  local maxInclination = [];
  local maxDeltaAngleK = [];
  local maxDeltaAngleVerticalK = [];
  local maxBrakeForceK = [];
  local suspensionDampeningForceK = [];
  local timeToBrake = [];
  local distToBrake = [];
  local accelTime = [];
  local partHpMult = [];
  local blackoutG = [];
  local redoutG = [];

  local haveMass = false;
  local haveOswalds = false;
  local haveCdMinFusel = false;
  local haveCdMinTail = false;
  local haveCdMinWing = false;
  local haveAilThrSpd = false;
  local haveRuddThrSpd = false;
  local haveElevThrSpd = false;
  local haveHorsePowers = false;
  local haveThrust = false;
  local haveCdParasite = false;
  local haveTurnTurretSpeedK = false;
  local haveGunPitchSpeedK = false;
  local haveMaxInclination = false;
  local haveMaxDeltaAngleK = false;
  local haveMaxDeltaAngleVerticalK = false;
  local haveMaxBrakeForceK = false;
  local haveSuspensionDampeningForceK = false;
  local haveTimeToBrake = false;
  local haveDistToBrake = false;
  local haveAccelTime = false;
  local havePartHpMult = false;
  local haveBlackoutG = false;
  local haveRedoutG = false;
  foreach(m in ::domination_modes)
  {
    if (m.id in effect && ::get_show_mode_info(m.modeId))
    {
      local validSpeed = "speed" in effect[m.id] && fabs(effect[m.id].speed * 3.6) > 1;
      local validClimb = "climb" in effect[m.id] && fabs(effect[m.id].climb) > 0.1;
      local validRoll = "roll" in effect[m.id] && fabs(effect[m.id].roll) > 1;
      local validVirage = "virage" in effect[m.id] && fabs(effect[m.id].virage) > 0.1 && fabs(effect[m.id].virage) < 20.0;
      haveSpeeds = haveSpeeds || validSpeed;
      haveClimbs = haveClimbs || validClimb;
      haveRolls = haveRolls || validRoll;
      haveVirages = haveVirages || validVirage;

      speeds.append(validSpeed ? effect[m.id].speed : "0");
      climbs.append(validClimb ? effect[m.id].climb : "0");
      rolls.append(validRoll ? effect[m.id].roll : "0");
      virages.append(validVirage ? effect[m.id].virage : "0");

      local validMass = "mass" in effect[m.id] && fabs(effect[m.id].mass) > 0.5;
      local validOswalds = "oswalds" in effect[m.id] && fabs(effect[m.id].oswalds) > 0.01;
      local validCdMinFusel = "cdMinFusel" in effect[m.id] && fabs(effect[m.id].cdMinFusel) > 0.0001;
      local validCdMinTail = "cdMinTail" in effect[m.id] && fabs(effect[m.id].cdMinTail) > 0.0001;
      local validCdMinWing = "cdMinWing" in effect[m.id] && fabs(effect[m.id].cdMinWing) > 0.0001;
      local validAilThrSpd = "ailThrSpd" in effect[m.id] && fabs(effect[m.id].ailThrSpd) * 3.6 > 1.0;
      local validRuddThrSpd = "ruddThrSpd" in effect[m.id] && fabs(effect[m.id].ruddThrSpd) * 3.6 > 1.0;
      local validElevThrSpd = "elevThrSpd" in effect[m.id] && fabs(effect[m.id].elevThrSpd) * 3.6 > 1.0;
      local validHorsePowers = "horsePowers" in effect[m.id] && fabs(effect[m.id].horsePowers) > 1.0;
      local validThrust = "thrust" in effect[m.id] && fabs(effect[m.id].thrust) > 10.0;
      local validCdParasite = "cdParasite" in effect[m.id] && fabs(effect[m.id].cdParasite) > 0.0001;
      local validTurnTurretSpeedK = "turnTurretSpeedK" in effect[m.id] && fabs(effect[m.id].turnTurretSpeedK) > 0.0001;
      local validGunPitchSpeedK = "gunPitchSpeedK" in effect[m.id] && fabs(effect[m.id].gunPitchSpeedK) > 0.0001;
      local validMaxInclination = "maxInclination" in effect[m.id] && fabs(effect[m.id].maxInclination) > 0.001;
      local validMaxDeltaAngleK = "maxDeltaAngleK" in effect[m.id] && fabs(effect[m.id].maxDeltaAngleK) > 0.001;
      local validMaxDeltaAngleVerticalK = "maxDeltaAngleVerticalK" in effect[m.id] && fabs(effect[m.id].maxDeltaAngleVerticalK) > 0.001;
      local validMaxBrakeForceK = "maxBrakeForceK" in effect[m.id] && fabs(effect[m.id].maxBrakeForceK) > 0.001;
      local validSuspensionDampeningForceK = "suspensionDampeningForceK" in effect[m.id] && fabs(effect[m.id].suspensionDampeningForceK) > 0.001;
      local validTimeToBrake = "timeToBrake" in effect[m.id] && fabs(effect[m.id].timeToBrake) > 0.0001;
      local validDistToBrake = "distToBrake" in effect[m.id] && fabs(effect[m.id].distToBrake) > 0.0001;
      local validAccelTime = "accelTime" in effect[m.id] && fabs(effect[m.id].accelTime) > 0.0001;
      local validPartHpMult = "partHpMult" in effect[m.id] && fabs(effect[m.id].partHpMult) > 0.0001;
      local validBlackoutG = "blackoutG" in effect[m.id] && fabs(effect[m.id].blackoutG) > 0.01;
      local validRedoutG = "redoutG" in effect[m.id] && fabs(effect[m.id].redoutG) > 0.01;

      haveMass = haveMass || validMass;
      haveOswalds = haveOswalds || validOswalds;
      haveCdMinFusel = haveCdMinFusel || validCdMinFusel;
      haveCdMinTail = haveCdMinTail || validCdMinTail;
      haveCdMinWing = haveCdMinWing || validCdMinWing;
      haveAilThrSpd = haveAilThrSpd || validAilThrSpd;
      haveRuddThrSpd = haveRuddThrSpd || validRuddThrSpd;
      haveElevThrSpd = haveElevThrSpd || validElevThrSpd;
      haveHorsePowers = (!isTank(air) || ::has_feature("TankModEffect")) ? (haveHorsePowers || validHorsePowers) : false;
      haveThrust = haveThrust || validThrust;
      haveCdParasite = haveCdParasite || validCdParasite;
      haveBlackoutG = haveBlackoutG || validBlackoutG;
      haveRedoutG = haveRedoutG || validRedoutG;
      if (::has_feature("TankModEffect"))
      {
        haveTurnTurretSpeedK = haveTurnTurretSpeedK || validTurnTurretSpeedK;
        haveGunPitchSpeedK = haveGunPitchSpeedK || validGunPitchSpeedK;
        haveMaxInclination = haveMaxInclination || validMaxInclination;
        haveMaxDeltaAngleK = haveMaxDeltaAngleK || validMaxDeltaAngleK;
        haveMaxDeltaAngleVerticalK = haveMaxDeltaAngleVerticalK || validMaxDeltaAngleVerticalK;
        haveMaxBrakeForceK = haveMaxBrakeForceK || validMaxBrakeForceK;
        haveSuspensionDampeningForceK = haveSuspensionDampeningForceK || validSuspensionDampeningForceK;
        haveTimeToBrake = haveTimeToBrake || validTimeToBrake;
        haveDistToBrake = haveDistToBrake || validDistToBrake;
        haveAccelTime = haveAccelTime || validAccelTime;
        havePartHpMult = havePartHpMult || validPartHpMult;
      }

      masses.append(validMass ? effect[m.id].mass : "0");
      oswalds.append(validOswalds ? effect[m.id].oswalds : "0");
      cdMinFusel.append(validCdMinFusel ? effect[m.id].cdMinFusel : "0");
      cdMinTail.append(validCdMinTail ? effect[m.id].cdMinTail : "0");
      cdMinWing.append(validCdMinWing ? effect[m.id].cdMinWing : "0");
      ailThrSpd.append(validAilThrSpd ? effect[m.id].ailThrSpd : "0");
      ruddThrSpd.append(validRuddThrSpd ? effect[m.id].ruddThrSpd : "0");
      elevThrSpd.append(validElevThrSpd ? effect[m.id].elevThrSpd : "0");
      horsePowers.append(validHorsePowers ? effect[m.id].horsePowers : "0");
      thrust.append(validThrust ? effect[m.id].thrust / KGF_TO_NEWTON : "0");
      cdParasite.append(validCdParasite ? effect[m.id].cdParasite : "0");
      turnTurretSpeedK.append(validTurnTurretSpeedK ? effect[m.id].turnTurretSpeedK * 100.0 : "0");
      gunPitchSpeedK.append(validGunPitchSpeedK ? effect[m.id].gunPitchSpeedK * 100.0 : "0");
      maxInclination.append(validMaxInclination ? (effect[m.id].maxInclination*180.0/PI).tointeger() : "0");
      maxDeltaAngleK.append(haveMaxDeltaAngleK ? effect[m.id].maxDeltaAngleK * 100.0 : "0");
      maxDeltaAngleVerticalK.append(haveMaxDeltaAngleVerticalK ? effect[m.id].maxDeltaAngleVerticalK * 100.0 : "0");
      maxBrakeForceK.append(haveMaxBrakeForceK ? effect[m.id].maxBrakeForceK * 100.0 : "0");
      suspensionDampeningForceK.append(haveSuspensionDampeningForceK ? effect[m.id].suspensionDampeningForceK * 100.0 : "0");
      timeToBrake.append(haveTimeToBrake ? effect[m.id].timeToBrake : "0");
      distToBrake.append(haveDistToBrake ? effect[m.id].distToBrake : "0");
      accelTime.append(haveAccelTime ? effect[m.id].accelTime : "0");
      partHpMult.append(havePartHpMult ? effect[m.id].partHpMult * 100.0 : "0");
      blackoutG.append(haveBlackoutG ? effect[m.id].blackoutG : "0");
      redoutG.append(haveRedoutG ? effect[m.id].redoutG : "0");
    }
  }
  local startTab = ::nbsp + ::nbsp + ::nbsp + ::nbsp;
  if (haveMass || haveOswalds || haveCdMinFusel || haveCdMinTail || haveCdMinWing || haveAilThrSpd || haveRuddThrSpd || haveElevThrSpd || haveHorsePowers || haveThrust ||
      "armor" in effect || "cutProbability" in effect || "overheadCooldown" in effect || haveTurnTurretSpeedK || haveGunPitchSpeedK || haveMaxInclination ||
      haveMaxDeltaAngleK || haveMaxDeltaAngleVerticalK || haveMaxBrakeForceK || haveSuspensionDampeningForceK || haveTimeToBrake || haveDistToBrake || haveAccelTime ||
      haveSpeeds || haveClimbs || haveRolls || haveVirages || haveMaxInclination || havePartHpMult || haveBlackoutG || haveRedoutG)
    desc += "\n" + ::loc("modifications/specs_change") + ::loc("ui/colon")
  if ("armor" in effect)
    desc += "\n" + startTab + genModEffectDescr("armor", effect.armor, "@goodTextColor", "@badTextColor", "%", 0);
  if ("cutProbability" in effect)
    desc += "\n" + startTab + genModEffectDescr("cutProbability", effect.cutProbability, "@goodTextColor", "@badTextColor", "%", 0);
  if ("overheadCooldown" in effect)
    desc += "\n" + startTab + genModEffectDescr("overheadCooldown", effect.overheadCooldown, "@badTextColor", "@goodTextColor", "%", 0);
  if (haveMass)
    desc += "\n" + startTab + genModEffectDescr("mass", masses, "@badTextColor", "@goodTextColor", ::loc("measureUnits/kg"), 1);
  if (haveOswalds)
    desc += "\n" + startTab + genModEffectDescr("oswalds", oswalds, "@goodTextColor", "@badTextColor", "", 3);
  if (haveCdMinFusel)
    desc += "\n" + startTab + genModEffectDescr("cdMinFusel", cdMinFusel, "@badTextColor", "@goodTextColor", "", 5);
  if (haveCdMinTail)
    desc += "\n" + startTab + genModEffectDescr("cdMinTail", cdMinTail, "@badTextColor", "@goodTextColor", "", 5);
  if (haveCdMinWing)
    desc += "\n" + startTab + genModEffectDescr("cdMinWing", cdMinWing, "@badTextColor", "@goodTextColor", "", 5);
  if (haveAilThrSpd)
    desc += "\n" + startTab + genModEffectDescr("ailThrSpd", ailThrSpd, "@goodTextColor", "@badTextColor", 0, 0);
  if (haveRuddThrSpd)
    desc += "\n" + startTab + genModEffectDescr("ruddThrSpd", ruddThrSpd, "@goodTextColor", "@badTextColor", 0, 0);
  if (haveElevThrSpd)
    desc += "\n" + startTab + genModEffectDescr("elevThrSpd", elevThrSpd, "@goodTextColor", "@badTextColor", 0, 0);
  if (haveHorsePowers)
  {
    local transmission = "modifName" in effect && effect.modifName == "new_tank_transmission"
    desc += "\n" + startTab + genModEffectDescr(transmission ? "horsePowersTransmission" : "horsePowers",
      horsePowers, "@goodTextColor", "@badTextColor", ::loc("measureUnits/hp"), 1);
  }
  if (haveThrust)
    desc += "\n" + startTab + genModEffectDescr("thrust", thrust, "@goodTextColor", "@badTextColor", ::loc("measureUnits/kgf"), 1);
  if (haveCdParasite)
    desc += "\n" + startTab + genModEffectDescr("cdParasite", cdParasite, "@badTextColor", "@goodTextColor", "", 5);
  if (haveSpeeds)
    desc += "\n" + startTab + genModEffectDescr("speed", speeds, "@goodTextColor", "@badTextColor", 0, 0);
  if (haveClimbs)
    desc += "\n" + startTab + genModEffectDescr("climb", climbs, "@goodTextColor", "@badTextColor", 3, 0);
  if (haveRolls)
    desc += "\n" + startTab + genModEffectDescr("roll", rolls, "@goodTextColor", "@badTextColor", ::loc("measureUnits/deg_per_sec"), 1);
  if (haveVirages)
    desc += "\n" + startTab + genModEffectDescr("virage", virages, "@badTextColor", "@goodTextColor", ::loc("measureUnits/seconds"), 1);
  if (haveTurnTurretSpeedK)
    desc += "\n" + startTab + genModEffectDescr("turnTurretSpeedK", turnTurretSpeedK, "@goodTextColor", "@badTextColor", "%", 0);
  if (haveGunPitchSpeedK)
    desc += "\n" + startTab + genModEffectDescr("gunPitchSpeedK", gunPitchSpeedK, "@goodTextColor", "@badTextColor", "%", 0);
  if (haveMaxInclination)
    desc += "\n" + startTab + genModEffectDescr("maxInclination", maxInclination, "@goodTextColor", "@badTextColor", ::loc("measureUnits/deg"), 0);
  if (haveMaxDeltaAngleK)
    desc += "\n" + startTab + genModEffectDescr("maxDeltaAngleK", maxDeltaAngleK, "@badTextColor", "@goodTextColor", "%", 0);
  if (haveMaxDeltaAngleVerticalK)
    desc += "\n" + startTab + genModEffectDescr("maxDeltaAngleVerticalK", maxDeltaAngleVerticalK, "@badTextColor", "@goodTextColor", "%", 0);
  if (haveMaxBrakeForceK)
    desc += "\n" + startTab + genModEffectDescr("maxBrakeForceK", maxBrakeForceK, "@goodTextColor", "@badTextColor", "%", 0);
  if (haveSuspensionDampeningForceK)
    desc += "\n" + startTab + genModEffectDescr("suspensionDampeningForceK", suspensionDampeningForceK, "@goodTextColor", "@badTextColor", "%", 0);
  if (haveTimeToBrake)
    desc += "\n" + startTab + genModEffectDescr("timeToBrake", timeToBrake, "@badTextColor", "@goodTextColor", ::loc("measureUnits/seconds"), 1);
  if (haveDistToBrake)
    desc += "\n" + startTab + genModEffectDescr("distToBrake", distToBrake, "@badTextColor", "@goodTextColor", 1, 1);
  if (haveAccelTime)
    desc += "\n" + startTab + genModEffectDescr("accelTime", accelTime, "@badTextColor", "@goodTextColor", ::loc("measureUnits/seconds"), 1);
  if (havePartHpMult)
    desc += "\n" + startTab + genModEffectDescr("partHpMult", partHpMult, "@goodTextColor", "@badTextColor", "%", 0);
  if (haveBlackoutG)
    desc += "\n" + startTab + genModEffectDescr("blackoutG", blackoutG, "@goodTextColor", "@badTextColor", "", 2);
  if (haveRedoutG)
    desc += "\n" + startTab + genModEffectDescr("redoutG", redoutG, "@badTextColor", "@goodTextColor", "", 2);

  if ("weaponMods" in effect)
    foreach(w in effect.weaponMods)
    {
      desc += "\n" + ::loc(w.name) + ":";
      if ("spread" in w)
        desc += "\n" + startTab + genModEffectDescr("spread", w.spread, "@badTextColor", "@goodTextColor", 1, 0);
      if ("overheat" in w)
        desc += "\n" + startTab + genModEffectDescr("overheat", -w.overheat * 100.0, "@goodTextColor", "@badTextColor", "%", 0);
    }
  if(desc != "")
    desc += "\n" + "<color=@fadedTextColor>" + ::loc("weaponry/modsEffectsNotification") + "</color>"
  return desc;
}

function weaponVisual::getItemUpgradesList(item)
{
  if ("weaponUpgrades" in item)
    return item.weaponUpgrades
  else if ("weaponMod" in item && item.weaponMod != null && "weaponUpgrades" in item.weaponMod)
    return item.weaponMod.weaponUpgrades
  return false
}

function weaponVisual::countWeaponsUpgrade(air, item)
{
  local upgradesTotal = 0
  local upgraded = 0
  local upgrades = getItemUpgradesList(item)

  if (!upgrades)
    return null

  foreach (i, modsArray in upgrades)
  {
    if (modsArray.len() == 0)
      continue

    upgradesTotal++

    foreach(modName in modsArray)
      if (::shop_is_modification_enabled(air.name, modName))
      {
        upgraded++
        break
      }
  }
  return [upgraded, upgradesTotal]
}

function weaponVisual::getRepairCostCoef(item)
{
  local ret = null

  foreach(m in ::domination_modes)
    if (::get_show_mode_info(m.modeId))
    {
      local modeName = ::get_name_by_gamemode(m.modeId, true)
      if ((("repairCostCoef"+modeName) in item) && item["repairCostCoef"+modeName])
      {
        if (ret == null)
          ret = {}
        ret[modeName] <- item["repairCostCoef"+modeName]
      }
      else if (("repairCostCoef" in item) && item.repairCostCoef)
      {
        if (ret == null)
          ret = {}
        ret[modeName] <- item.repairCostCoef
      }
    }

  return ret
}

function weaponVisual::getReqModsText(air, item)
{
  local reqText = ""
  foreach(rp in ["reqWeapon", "reqModification"])
      if (rp in item)
        foreach (req in item[rp])
          if (rp == "reqWeapon" && !::shop_is_weapon_purchased(air.name, req))
            reqText += ((reqText=="")?"":"\n") + ::loc(rp) + ::loc("ui/colon") + ::getWeaponNameText(air.name, false, req, ", ")
          else
          if (rp == "reqModification" && !::shop_is_modification_purchased(air.name, req))
            reqText += ((reqText=="")?"":"\n") + ::loc(rp) + ::loc("ui/colon") + ::getModificationName(air, req)
  return reqText
}

function weaponVisual::getItemDescTbl(air, item, canDisplayInfo = true, effect = null, updateEffectFunc = null)
{
  local res = { name = "", desc = "", delayed = false }

  if (item.type==weaponsItem.bundle)
    return ::weaponVisual.getByCurBundle(air, item, (@(canDisplayInfo, effect, updateEffectFunc) function(air, item) { return getItemDescTbl(air, item, canDisplayInfo, effect, updateEffectFunc) })(canDisplayInfo, effect, updateEffectFunc), res)

  local name = "<color=@activeTextColor>" + getItemName(air, item, false) + "</color>"
  local desc = ""
  local addDesc = ""
  local reqText = ""
  local curTier = "tier" in item? item.tier : 1
  local statusTbl = getItemStatusTbl(air, item)
  local currentPrice = statusTbl.showPrice? getFullItemCostText(air, item) : ""

  if (!::weaponVisual.isTierAvailable(air, curTier) && curTier > 1)
  {
    local reqMods = ::getNextTierModsCount(air, curTier - 1)
    if(reqMods > 0)
      reqText = ::loc("weaponry/unlockModTierReq",
                      { tier = ::roman_numerals[curTier], amount = reqMods.tostring() })
    else
      reqText = ::loc("weaponry/unlockTier/reqPrevTiers")
    reqText = "<color=@badTextColor>" + reqText + "</color>"
    res.reqText <- reqText
    if(!canDisplayInfo)
    {
      res.delayed = true
      return res
    }
  }

  if (item.type==weaponsItem.weapon)
  {
    name = ""
    desc = ::getWeaponInfoText(air, false, item.name, "\n", INFO_DETAIL.EXTENDED)
    if (effect)
      addDesc = getEffectDesc(air, effect)
    if (!effect && updateEffectFunc)
      ::calculate_mod_or_weapon_effect(air.name, item.name, false, this, updateEffectFunc, null)
  }
  else if (item.type==weaponsItem.primaryWeapon)
  {
    name = ""
    desc = ::getWeaponInfoText(air, true, item.name, "\n", INFO_DETAIL.EXTENDED)
    local upgradesList = getItemUpgradesList(item)
    if(upgradesList)
    {
      local upgradesCount = countWeaponsUpgrade(air, item)
      if (upgradesCount)
        addDesc = "\n" + ::loc("weaponry/weaponsUpgradeInstalled",
                               { current = upgradesCount[0], total = upgradesCount[1] })
      foreach(array in upgradesList)
        foreach(upgrade in array)
        {
          if(upgrade == null)
            continue
          addDesc += "\n" + (::shop_is_modification_enabled(air.name, upgrade) ? "<color=@goodTextColor>" : "<color=@commonTextColor>") + ::getModificationName(air, upgrade) + "</color>"
        }
    }
  }
  else if (item.type==weaponsItem.modification || item.type==weaponsItem.expendables)
  {
    if (effect)
    {
      desc = ::getModificationInfoText(air, item.name);
      addDesc = getEffectDesc(air, effect);
    }
    else
      desc = ::getModificationInfoText(air, item.name, false, false, this, updateEffectFunc)

    addBulletsParamToDesc(res, air, item)
  }
  else if (item.type==weaponsItem.spare)
    desc = ::loc("spare/"+item.name + "/desc")

  if (statusTbl.unlocked && currentPrice != "")
  {
    local amountText = ::getAmountAndMaxAmountText(statusTbl.amount, statusTbl.maxAmount, statusTbl.showMaxAmount)
    if (amountText != "")
    {
      local color = statusTbl.amount < statusTbl.amountWarningValue ? "badTextColor" : ""
      res.amountText <- ::colorize(color, ::loc("options/count") + ::loc("ui/colon") + amountText)

      if (::is_in_flight() && item.type==weaponsItem.weapon)
      {
        local respLeft = ::g_mis_custom_state.getCurMissionRules().getUnitWeaponRespawnsLeft(air, item)
        if (respLeft >= 0)
          res.amountText += ::loc("ui/colon") + ::loc("respawn/leftRespawns", { num = respLeft })
      }
    }
    if (statusTbl.showMaxAmount && statusTbl.amount < statusTbl.amountWarningValue)
      res.warningText <- ::loc("weapons/restock_advice")
  }

  if (statusTbl.discountType != "")
  {
    local discount = getDiscountByPath(getDiscountPath(air, item, statusTbl.discountType))
    if (discount > 0 && statusTbl.showPrice)
    {
      local cost = "cost" in item? item.cost : 0
      local costGold = "costGold" in item? item.costGold : 0
      local priceText = ::getPriceText(cost, costGold, false)
      if (priceText != "")
        res.noDiscountPrice <- "<color=@oldPrice>" + priceText + "</color>"
      if (currentPrice != "")
        currentPrice = "<color=@goodTextColor>" + currentPrice + "</color>"
    }
  }

  local repairCostCoefTbl = getRepairCostCoef(item)
  if (repairCostCoefTbl)
  {
    local wBlk = ::get_warpoints_blk()
    local repairMul = wBlk.avgRepairMul? wBlk.avgRepairMul : 1.0
    local repairText = ""
    foreach(m in ::domination_modes)
      if (::get_show_mode_info(m.modeId))
      {
        local modeName = ::get_name_by_gamemode(m.modeId, true)

        local repairCostCoef = 0.0
        if (modeName in repairCostCoefTbl)
          repairCostCoef = repairCostCoefTbl[modeName] * repairMul

        local rcost = ::wp_get_repair_cost_by_mode(air.name, m.modeId, false)
        local avgCost = (repairCostCoef * rcost).tointeger()
        if (!avgCost)
          continue
        repairText += ((repairText!="")?" / ":"") + (avgCost > 0? "+" : "") + ::getWpPriceText(avgCost)
      }
    if (repairText!="")
      addDesc += "\n" + ::loc("shop/avg_repair_cost") + repairText
  }

  if (!statusTbl.amount)
  {
    local reqMods = getReqModsText(air, item)
    if(reqMods != "")
      reqText += (reqText==""? "" : "\n") + reqMods
  }
  if (isBullets(item) && !::is_bullets_group_active_by_mod(air, item))
    reqText += ((reqText=="")?"":"\n") + ::loc("msg/weaponSelectRequired")
  reqText = reqText!=""? ("<color=@badTextColor>" + reqText + "</color>") : ""
  res.reqText <- reqText

  if (currentPrice != "")
    res.currentPrice <- currentPrice
  res.name = name
  res.desc = desc
  res.addDesc <- addDesc
  return res
}

function weaponVisual::addBulletsParamToDesc(descTbl, unit, item)
{
  if (!unit.unitType.canUseSeveralBulletsForGun && !::has_feature("BulletParamsForAirs"))
    return
  local bIcoItem = getBulletsIconItem(unit, item)
  if (!bIcoItem)
    return

  local modName = bIcoItem.name
  local bulletsSet = getBulletsSetData(unit, modName)
  if (!bulletsSet)
    return

  local bIconParam = getTblValue("bIconParam", bulletsSet)
  if (bIconParam)
  {
    descTbl.bulletActions <- []
    local setClone = clone bulletsSet
    foreach(p in ["armor", "damage"])
    {
      local value = ::getTblValue(p, bIconParam, -1)
      if (value < 0)
        continue

      setClone.bIconParam = { [p] = value }
      descTbl.bulletActions.append({
        text = ::loc("bulletAction/" + p)
        visual = getBulletsIconData(setClone)
      })
    }
  }

  local searchName = ::getBulletsSearchName(unit, modName)
  local useDefaultBullet = searchName!=modName;
  local bullet_parameters = ::calculate_tank_bullet_parameters(unit.name,
    useDefaultBullet && "weaponBlkName" in bulletsSet ? bulletsSet.weaponBlkName : getModificationBulletsEffect(searchName),
    useDefaultBullet);
  local dist = [10, 100, 500, 1000, 1500, 2000];
  local param = { armorPiercing = array(dist.len(), null) }
  local needAddParams = bullet_parameters.len() == 1

  local isSmokeShell   = bulletsSet.bullets.len() == 1 && bulletsSet.bullets[0] == "smoke_tank"
  local isSmokeGrenade = bulletsSet.weaponType == WEAPON_TYPE.SMOKE_SCREEN
  if (isSmokeGrenade || isSmokeShell)
  {
    local whitelistParams = isSmokeGrenade ? [ "bulletType", "armorPiercing", "armorPiercingDist" ]
      : [ "mass", "speed", "bulletType", "armorPiercing", "armorPiercingDist" ]
    local filteredBulletParameters = []
    foreach (_params in bullet_parameters)
    {
      local params = _params ? {} : null
      if (_params)
      {
        foreach (key in whitelistParams)
          if (key in _params)
            params[key] <- _params[key]

        params.armorPiercing = []
        params.armorPiercingDist = []
      }
      filteredBulletParameters.append(params)
    }
    bullet_parameters = filteredBulletParameters
  }

  foreach (bullet_params in bullet_parameters)
  {
    if (!bullet_params)
      continue

    foreach(ind, d in dist)
    {
      for (local i = 0; i < bullet_params.armorPiercingDist.len(); i++)
      {
        local armor = null;
        local idist = bullet_params.armorPiercingDist[i].tointeger()
        if (typeof(bullet_params.armorPiercing[i]) != "table")
          continue

        if (d == idist || (d < idist && !i))
          armor = ::u.map(bullet_params.armorPiercing[i], ::to_integer_safe)
        else if (d < idist && i)
        {
          local prevDist = bullet_params.armorPiercingDist[i-1].tointeger()
          if (d > prevDist)
            armor = ::u.tablesCombine(bullet_params.armorPiercing[i-1], bullet_params.armorPiercing[i],
                       (@(d, prevDist, idist) function(prev, next) {
                         return (prev + (next - prev) * (d - prevDist.tointeger()) / (idist - prevDist)).tointeger()
                       })(d, prevDist, idist), 0)
        }
        if (armor == null)
          continue

        /*!!!HACK, Change headers - angle of attack. Don't cause calculation mistakes in data itself
          Better be in code, but require too much changes, for changing only header.
        */
        local armorClone = {}
        foreach(distance, value in armor)
          armorClone[90 - distance] <- value
        param.armorPiercing[ind] = (!param.armorPiercing[ind]) ? armorClone
                                   : ::u.tablesCombine(param.armorPiercing[ind], armorClone, ::max)
      }
    }

    if (!needAddParams)
      continue

    foreach(p in ["mass", "speed", "fuseDelayDist", "explodeTreshold", "operatedDist", "endSpeed"])
      param[p] <- ::getTblValue(p, bullet_params, 0)

    if ("reloadTimes" in bullet_params)
      param.reloadTimes <- bullet_params["reloadTimes"]

    if ("autoAiming" in bullet_params)
      param.autoAiming <- bullet_params["autoAiming"]

    foreach(p in ["explosiveType", "explosiveMass"])
      if (p in bulletsSet)
        param[p] <- bulletsSet[p]

    foreach(p in ["smokeShellRad", "smokeActivateTime", "smokeTime"])
      if (p in bulletsSet)
        param[p] <- bulletsSet[p]

    param.bulletType <- ::getTblValue("bulletType", bullet_params, "")
  }

  descTbl.bulletParams <- []
  local p = []
  local addProp = function(arr, text, value)
  {
    arr.append({
      text = text
      value = value
    })
  }
  if ("mass" in param)
  {
    if (param.mass > 0)
      addProp(p, ::loc("bullet_properties/mass"),
                ::roundToDigits(param.mass, 2) + " " + ::loc("measureUnits/kg"))
    if (param.speed > 0)
      addProp(p, ::loc("bullet_properties/speed"),
                 ::format("%.0f %s", param.speed, ::loc("measureUnits/metersPerSecond_climbSpeed")))

    local maxSpeed = ::getTblValue("endSpeed", param, 0)
    if (maxSpeed)
      addProp(p, ::loc("rocket/maxSpeed"), ::g_measure_type.SPEED_PER_SEC.getMeasureUnitsText(maxSpeed))

    if ("autoAiming" in param)
    {
      local aimingTypeLocId = "guidanceSystemType/" + (param.autoAiming ? "semiAuto" : "handAim")
      addProp(p, ::loc("guidanceSystemType/header"), ::loc(aimingTypeLocId))
    }

    local operatedDist = ::getTblValue("operatedDist", param, 0)
    if (operatedDist)
      addProp(p, ::loc("firingRange"), ::g_measure_type.DISTANCE.getMeasureUnitsText(operatedDist))

    local explosiveType = ::getTblValue("explosiveType", param)
    if (explosiveType)
      addProp(p, ::loc("bullet_properties/explosiveType"), ::loc("explosiveType/" + explosiveType))
    local explosiveMass = ::getTblValue("explosiveMass", param)
    if (explosiveMass)
      addProp(p, ::loc("bullet_properties/explosiveMass"),
        ::g_dmg_model.getMeasuredExplosionText(explosiveMass))

    if (explosiveType && explosiveType)
    {
      local tntEqText = ::g_dmg_model.getTntEquivalentText(explosiveType, explosiveMass)
      if (tntEqText.len())
        addProp(p, ::loc("bullet_properties/explosiveMassInTNTEquivalent"), tntEqText)
    }

    local fuseDelayDist = ::roundToDigits(param.fuseDelayDist, 2)
    if (fuseDelayDist)
      addProp(p, ::loc("bullet_properties/fuseDelayDist"),
                 fuseDelayDist + " " + ::loc("measureUnits/meters_alt"))
    local explodeTreshold = ::roundToDigits(param.explodeTreshold, 2)
    if (explodeTreshold)
      addProp(p, ::loc("bullet_properties/explodeTreshold"),
                 explodeTreshold + " " + ::loc("measureUnits/mm"))

    local needRicochetData = !isSmokeGrenade && !isSmokeShell
    local ricochetData = needRicochetData && ::g_dmg_model.getRicochetData(param.bulletType)
    if (ricochetData)
      for (local i = ricochetData.angleProbabilityMap.len() - 1; i >= 0; --i)
      {
        local item = ricochetData.angleProbabilityMap[i]
        addProp(p, ::loc("bullet_properties/angleByProbability",
                         { probability = ::roundToDigits(100.0 * item.probability, 2) }),
                   ::roundToDigits(item.angle, 2) + ::loc("measureUnits/deg"))
      }

    if ("reloadTimes" in param)
    {
      local currentDiffficulty = ::game_mode_manager.getCurrentGameMode().diffCode
      local reloadTime = param.reloadTimes[currentDiffficulty]
      if(reloadTime > 0)
        addProp(p, ::colorize("badTextColor", ::loc("bullet_properties/cooldown")),
                   ::colorize("badTextColor", ::format("%.2f %s", reloadTime, ::loc("measureUnits/seconds"))))
    }

    if ("smokeShellRad" in param)
      addProp(p, ::loc("bullet_properties/smokeShellRad"),
                 ::roundToDigits(param.smokeShellRad, 2) + " " + ::loc("measureUnits/meters_alt"))

    if ("smokeActivateTime" in param)
      addProp(p, ::loc("bullet_properties/smokeActivateTime"),
                 ::roundToDigits(param.smokeActivateTime, 2) + " " + ::loc("measureUnits/seconds"))

    if ("smokeTime" in param)
      addProp(p, ::loc("bullet_properties/smokeTime"),
                 ::roundToDigits(param.smokeTime, 2) + " " + ::loc("measureUnits/seconds"))

    local bTypeDesc = ::loc(param.bulletType, "")
    if (bTypeDesc != "")
      descTbl.bulletsDesc <- bTypeDesc
  }
  descTbl.bulletParams.append({ props = p })

  local apData = getArmorPiercingViewData(param.armorPiercing, dist)
  if (apData)
  {
    local header = ::loc("bullet_properties/armorPiercing") + "\n"
                   + ::format("(%s \\ %s)", ::loc("distance"), ::loc("bullet_properties/hitAngle"))
    descTbl.bulletParams.append({ props = apData, header = header })
  }
}

function weaponVisual::getArmorPiercingViewData(armorPiercing, dist)
{
  local res = null
  if (armorPiercing[0] == null)
    return res

  local angles = null
  local p2 = []
  foreach(ind, armorTbl in armorPiercing)
  {
    if (armorTbl == null)
      continue
    if (!angles)
    {
      res = []
      angles = ::u.keys(armorTbl)
      angles.sort(function(a,b) { return a > b ? -1 : (a < b ? 1 : 0)})
      local headRow = {
        text = ""
        values = ::u.map(angles, function(v) { return { value = v + ::loc("measureUnits/deg") } })
      }
      res.append(headRow)
    }

    local row = {
      text = dist[ind] + ::loc("measureUnits/meters_alt")
      values = []
    }
    foreach(angle in angles)
      row.values.append({ value = ::getTblValue(angle, armorTbl, 0) + ::loc("measureUnits/mm") })
    res.append(row)
  }
  return res
}

function weaponVisual::updateModType(unit, mod)
{
  if ("type" in mod)
    return

  local name = mod.name
  local primaryWeaponsNames = ::getPrimaryWeaponsList(unit)
  foreach(modName in primaryWeaponsNames)
    if (modName == name)
    {
      mod.type <- weaponsItem.primaryWeapon
      return
    }

  mod.type <- weaponsItem.modification
  return
}

function weaponVisual::updateSpareType(spare)
{
  if (!("type" in spare))
    spare.type <- weaponsItem.spare
}

function weaponVisual::updateWeaponTooltip(obj, air, item, handler, params={}, effect=null)
{
  local canDisplayInfo = ::getTblValue("canDisplayInfo", params, true)
  local descTbl = getItemDescTbl(air, item, canDisplayInfo, effect, (@(obj, air, item, handler, params) function(effect, ...) {
          if (::checkObj(obj) && obj.isVisible())
            ::weaponVisual.updateWeaponTooltip(obj, air, item, handler, params, effect)
        })(obj, air, item, handler, params))

  local curExp = ::shop_get_module_exp(air.name, item.name)
  local is_researched = !isResearchableItem(item) || ((item.name.len() > 0) && ::isModResearched(air, item))
  local is_researching = isModInResearch(air, item)
  local is_paused = canBeResearched(air, item, true) && curExp > 0

  if (is_researching || is_paused || !is_researched)
  {
    if (("reqExp" in item) && item.reqExp > curExp || is_paused)
    {
      local expText = ""
      if (is_researching || is_paused)
        expText = ::loc("currency/researchPoints/name") + ::loc("ui/colon") + "<color=@activeTextColor>" + curExp + ::loc("ui/slash") + ::getRpPriceText(item.reqExp, true) + "</color>"
      else
        expText = ::loc("shop/required_rp") + " " + "<color=@activeTextColor>" + ::getRpPriceText(item.reqExp, true) + "</color>"

      local diffExp = ::getTblValue("diffExp", params, 0)
      if (diffExp > 0)
        expText += " (+" + diffExp + ")"
      descTbl.expText <- expText
    }
  } else
    descTbl.showPrice <- ("currentPrice" in descTbl) || ("noDiscountPrice" in descTbl)

  local data = ::handyman.renderCached(("gui/weaponry/weaponTooltip"), descTbl)
  obj.getScene().replaceContentFromText(obj, data, data.len(), handler)
}

function weaponVisual::isTierAvailable(air, tierNum)
{
  local isAvailable = ::is_tier_available(air.name, tierNum)

  if (!isAvailable && tierNum > 1) //make force check
  {
    local reqMods = air.needBuyToOpenNextInTier[tierNum-2]
    foreach(mod in air.modifications)
      if(mod.tier == (tierNum-1) &&
         ::isModResearched(air, mod) &&
         ::getModificationBulletsGroup(mod.name) == "" &&
         !::wp_get_modification_cost_gold(air.name, mod.name)
        )
        reqMods--

    isAvailable = reqMods <= 0
  }

  return isAvailable
}

function weaponVisual::getDiscountPath(air, item, discountType)
{
  local discountPath = ["aircrafts", air.name, item.name]
  if (item.type != weaponsItem.spare)
    discountPath.insert(2, discountType)

  return discountPath
}
