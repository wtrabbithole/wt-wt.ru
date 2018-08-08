local modsTree = ::require("scripts/weaponry/modsTree.nut")
local tutorialModule = ::require("scripts/user/newbieTutorialDisplay.nut")

::header_len_per_cell <- 17
::tooltip_display_delay <- 2
::max_spare_amount <- 100

function enable_modification(unitName, modificationName, enable)
{
  if (modificationName == "")
    return;

  local db = ::DataBlock()
  db[unitName] <- ::DataBlock()
  db[unitName][modificationName] <- enable
  return ::shop_enable_modifications(db)
}

function enable_current_modifications(unitName)
{
  local db = ::DataBlock()
  db[unitName] <- ::DataBlock()

  local air = getAircraftByName(unitName)
  foreach(mod in air.modifications)
    db[unitName][mod.name] <- ::shop_is_modification_enabled(unitName, mod.name)

  return ::shop_enable_modifications(db)
}

function gui_modal_weapons(params = {})
{
  ::gui_start_modal_wnd(::gui_handlers.WeaponsModalHandler, params)
}

function open_weapons_for_unit(unit, curEdiff = -1)
{
  if (!("name" in unit))
    return
  ::aircraft_for_weapons = unit.name
  ::gui_modal_weapons({curEdiff = curEdiff})
}

class ::gui_handlers.WeaponsModalHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  items = null

  wndWidth = 6
  mainModsObj = null
  modsBgObj = null
  curBundleTblObj = null

  air = null
  airName = ""
  lastWeapon = ""
  lastBullets = null

  researchMode = false
  researchBlock = null
  availableFlushExp = 0
  lastResearchMod = null
  setResearchManually = false

  airActions = ["research", "buy"]
  isOwn = true
  is_tank = false
  guiScene = null
  scene = null
  wndType = handlerType.MODAL
  sceneBlkName = "gui/weaponry/weapons.blk"
  tierIdPrefix = "tierLine_"

  tooltipOpenTime = -1

  shownTiers = []

  needCheckTutorial = false
  curEdiff = -1

  function initScreen()
  {
    setResearchManually = !researchMode
    airName = ::aircraft_for_weapons
    air = getAircraftByName(airName)
    if (!air)
    {
      goBack()
      return
    }
    isOwn = air.isUsable()
    is_tank = ::isTank(air)
    mainModsObj = scene.findObject("main_modifications")
    modsBgObj = mainModsObj.findObject("bg_elems")

    showSceneBtn("weaponry_close_btn", !researchMode)

    local imageBlock = scene.findObject("researchMode_image_block")
    if (::checkObj(imageBlock))
      imageBlock.show(researchMode)

    ::setDoubleTextToButton(scene, "btn_spendExcessExp",
        ::getRpPriceText(::loc("mainmenu/spendExcessExp") + " ", false),
        ::getRpPriceText(::loc("mainmenu/spendExcessExp") + " ", true))

    items = []
    fillPage()

    if (::isUnitInSlotbar(air) && !::check_aircraft_tags(air.tags, ["bomberview"]))
      if (!canBomb(true) && canBomb(false))
        needCheckTutorial = true

    shownTiers = []

    initFocusArray()
    selectResearchModule()

    checkOnResearchCurMod()
    showNewbieResearchHelp()
    updateWindowTitle()
  }

  function checkOnResearchCurMod()
  {
    if (researchMode && !isAnyModuleInResearch())
    {
      local modForResearch = ::find_any_not_researched_mod(air)
      if (modForResearch)
      {
        setModificatonOnResearch(modForResearch,
          (@(modForResearch) function() {
            updateAllItems()
            local guiPosIdx = ::getTblValue("guiPosIdx", modForResearch, -1)
            ::dagor.assertf(guiPosIdx >= 0, "missing guiPosIdx, mod - " + ::getTblValue("name", modForResearch, "none") + "; unit - " + air.name)
            selectResearchModule(guiPosIdx >= 0? guiPosIdx : 0)
          })(modForResearch))
      }
    }
  }

  function selectResearchModule(customPosIdx = -1)
  {
    if (!researchMode)
      return

    local modIdx = customPosIdx
    if (modIdx < 0)
    {
      local finishedResearch = ::getTblValue(::researchedModForCheck, researchBlock, "")
      foreach(item in items)
        if (::weaponVisual.isModInResearch(air, item))
        {
          modIdx = item.guiPosIdx
          break
        }
        else if (item.name == finishedResearch)
          modIdx = item.guiPosIdx
    }

    if (::checkObj(mainModsObj) && modIdx >= 0)
      mainModsObj.setValue(modIdx+1)
  }

  function updateWindowTitle()
  {
    local titleObj = scene.findObject("wnd_title")
    if (!::checkObj(titleObj))
      return

    local titleText = ::loc("mainmenu/btnWeapons") + ::loc("ui/parentheses/space", { text = ::getUnitName(air) })
    if (researchMode)
      titleText = ::loc("modifications/finishResearch",
          {modName = ::getModificationName(air, ::getTblValue(::researchedModForCheck, researchBlock, "CdMin_Fuse"))})
    titleObj.setValue(titleText)
  }

  function showNewbieResearchHelp()
  {
    if (!researchMode || !tutorialModule.needShowTutorial("researchMod", 1))
      return

    tutorialModule.saveShowedTutorial("researchMod")

    local finMod = ::getTblValue(::researchedModForCheck, researchBlock, "")
    local newMod = ::shop_get_researchable_module_name(airName)

    local finIdx = getItemIdxByName(finMod)
    local newIdx = getItemIdxByName(newMod)

    if (finIdx < 0 || newIdx < 0)
      return

    local newModName = ::getModificationName(air, items[newIdx].name, true)
    local steps = [
      {
        obj = ["item_" + newIdx]
        text = ::loc("help/newModification", {modName = newModName})
        bottomTextLocIdArray = ["help/OBJ_CLICK"]
        actionType = tutorAction.OBJ_CLICK
        accessKey = "J:A"
        cb = (@(newIdx) function() {setModificatonOnResearch(items[newIdx], function(){updateAllItems()})})(newIdx)
      },
      {
        obj = ["available_free_exp_text"]
        text = ::loc("help/FreeExp")
        bottomTextLocIdArray = ["help/NEXT_ACTION"]
        actionType = tutorAction.ANY_CLICK
        accessKey = "J:A"
      }
    ]

    local finItem = items[finIdx]
    local balance = ::Cost()
    balance.setFromTbl(::get_balance())
    if (::weaponVisual.getItemAmount(air, finItem) < 1 && ::weaponVisual.getItemCost(air, finItem) <= balance)
    {
      local finModName = ::getModificationName(air, items[finIdx].name, true)
      steps.insert(0,
        {
          obj = ["item_" + finIdx]
          text = ::loc("help/finishedModification", {modName = finModName})
          bottomTextLocIdArray = ["help/OBJ_CLICK"]
          actionType = tutorAction.OBJ_CLICK
          accessKey = "J:A"
          cb =  (@(finItem) function () { checkAndBuyWeaponry(finItem) })(finItem)
        })
    }

    ::gui_modal_tutor(steps, this)
  }

  function getMainFocusObj()
  {
    return mainModsObj
  }

  function getMainFocusObj2()
  {
    return curBundleTblObj
  }

  function fillPage()
  {
    createItem(air, weaponsItem.curUnit, mainModsObj, 0.0, 0.0)
    fillModsTree(3.0)

    if (researchMode)
      fillPremiumMods(0.0, 1.6)
    else
    {
      fillPremiumMods(1.0, 0.0)
      fillWeaponsAndBullets(0, 1.5)
    }

    updateAllItems()
  }

  function fillAvailableRPText()
  {
    if (!researchMode)
      return

    availableFlushExp = ::shop_get_unit_excess_exp(airName)
    local freeRPObj = scene.findObject("available_free_exp_text")
    if (::checkObj(freeRPObj))
      freeRPObj.setValue(::get_flush_exp_text(availableFlushExp))
  }

  function automaticallySpendAllExcessiveExp() //!!!TEMP function, true func must be from code
  {
    showTaskProgressBox()
    availableFlushExp = ::shop_get_unit_excess_exp(airName)
    local curResModuleName = ::shop_get_researchable_module_name(airName)

    if(availableFlushExp <= 0 || curResModuleName == "")
    {
      local afterDoneFunc = function() {
        destroyProgressBox()
        updateAllItems()
        goBack()
      }

      setModificatonOnResearch(::getModificationByName(air, curResModuleName), afterDoneFunc)
      return
    }

    flushItemExp(curResModuleName, automaticallySpendAllExcessiveExp)
  }

  function onEventUnitResearch(params)
  {
    updateAllItems()
  }

  function onEventUnitBought(params)
  {
    isOwn = air.isUsable()
    updateAllItems()
  }

  function onEventUnitRented(params)
  {
    onEventUnitBought(params)
  }

  function onEventExpConvert(params)
  {
    updateAllItems()
  }

  function onEventUnitRepaired(params)
  {
    foreach(idx, item in items)
      if (isItemTypeUnit(item.type))
        return updateItem(idx)
  }

  function onEventModificationPurchased(params) { updateAllItems() }
  function onEventWeaponPurchased(params) { updateAllItems() }
  function onEventSparePurchased(params) { updateAllItems() }

  function onEventUnitWeaponChanged(params)
  {
    updateAllItems()
  }

  function isItemTypeUnit(type)
  {
    return type == weaponsItem.curUnit
  }

  function addItemToList(item, type)
  {
    local idx = items.len()
    if (::u.isUnit(item)) //!!FIX ME: it a bad idea to unit be a direct item in weaponry list
    {
      item.type = type
      item.guiPosIdx = idx
    }
    else
    {
      item.type <- type
      item.guiPosIdx <- idx
    }
    items.append(item)
    return "item_" + idx
  }

  function createItem(item, type, holderObj, posX, posY)
  {
    local id = addItemToList(item, type)

    if (isItemTypeUnit(type))
      return createUnitItemObj(id, item, holderObj, posX, posY)

    return ::weaponVisual.createItem(id, item, type, holderObj, this, { posX = posX, posY = posY })
  }

  function createUnitItemObj(id, item, holderObj, posX, posY)
  {
    local blockObj = guiScene.createElementByObject(holderObj, "gui/weaponry/nextUnitItem.blk", "weapon_item_unit", this)
    local titleObj = blockObj.findObject("nextResearch_title")
    titleObj.setValue(researchMode? ::loc("mainmenu/nextResearch/title") : "")

    local position = (posX + 0.5).tostring() + "@modCellWidth-0.5w, " + (posY + 0.5).tostring() + "@modCellHeight-0.5h"
    if (researchMode)
      position = (posX + 0.5).tostring() + "@modCellWidth-0.5w, " + (posY + 1).tostring() + "@modCellHeight-0.5h"

    blockObj.pos = position
    local unitObj = blockObj.findObject("next_unit")
    unitObj.id = id
    return unitObj
  }

  function createItemForBundle(id, item, type, holderObj, handler, params = {})
  {
    id = addItemToList(item, type)
    return ::weaponVisual.createItem(id, item, type, holderObj, handler, params)
  }

  function createBundle(itemsList, itemsType, subType, holderObj, posX, posY)
  {
    ::weaponVisual.createBundle("bundle_" + items.len(), itemsList, itemsType, holderObj, this,
      { posX = posX, posY = posY, subType = subType,
        maxItemsInColumn = 5, createItemFunc = createItemForBundle
        cellSizeObj = scene.findObject("cell_size")
      })
  }

  function getItemObj(idx)
  {
    return scene.findObject("item_" + idx)
  }

  function updateItem(idx)
  {
    local itemObj = getItemObj(idx)
    if (!::checkObj(itemObj) || !(idx in items))
      return

    local item = items[idx]
    if (isItemTypeUnit(item.type))
      return updateUnitItem(item, itemObj)

    local isVisualDisabled = false
    local visualItem = item
    if (item.type == weaponsItem.bundle)
      visualItem = ::weaponVisual.getBundleCurItem(air, item) || visualItem
    if (::weaponVisual.isBullets(visualItem))
      isVisualDisabled = !::is_bullets_group_active_by_mod(air, visualItem)

    ::weaponVisual.updateItem(air, item, itemObj, true, this, {canShowResearch = availableFlushExp == 0 && setResearchManually,
                                                               flushExp = availableFlushExp,
                                                               researchMode = researchMode
                                                               visualDisabled = isVisualDisabled
                                                              })
  }

  function updateBuyAllButton()
  {
    local btnId = "btn_buyAll"
    local cost = ::get_all_modifications_cost(air, true)
    local show = !cost.isZero() && ::isUnitUsable(air) && ::has_feature("BuyAllModifications")
    local buttonObj = showSceneBtn(btnId, show)
    if (show)
      ::placePriceTextToButton(scene, btnId, ::loc("mainmenu/btnBuyAll"), cost)
  }

  function updateAllItems()
  {
    if (!isValid())
      return

    fillAvailableRPText()
    for(local i = 0; i < items.len(); i++)
      updateItem(i)
    local treeSize = modsTree.getModsTreeSize(air)
    updateTiersStatus(treeSize)
    updateButtons()
    updateBuyAllButton()
  }

  function updateButtons()
  {
    local isAnyModInResearch = isAnyModuleInResearch()
    showSceneBtn("btn_exit", researchMode && (!isAnyModInResearch || availableFlushExp <= 0 || setResearchManually))
    showSceneBtn("btn_spendExcessExp", researchMode && isAnyModInResearch && availableFlushExp > 0)

    local checkboxObj = scene.findObject("auto_purchase_mods")
    if (::checkObj(checkboxObj))
    {
      checkboxObj.show(isOwn)
      if (isOwn)
        checkboxObj.setValue(::get_auto_buy_modifications())
    }

    updateDependingButtons()
  }

  function updateDependingButtons()
  {
    if (!items
        || items.len() == 0
        || !::checkObj(mainModsObj))
      return

    local index = (mainModsObj.getValue() || 0) - 1
    if (index < 0)
      return

    local btnObj = scene.findObject("btn_nav_research")
    if (!::checkObj(btnObj))
      return

    local item = items[index]
    local showResearchButton = researchMode
                       && ::getAmmoCost(air, item.name, AMMO.MODIFICATION).gold == 0
                       && !::isModClassPremium(item)
                       && ::weaponVisual.canBeResearched(air, item, false)
                       && availableFlushExp > 0

    showSceneBtn("btn_nav_research", showResearchButton)
    if (showResearchButton)
    {
      local flushExp = item.reqExp < availableFlushExp ? item.reqExp : availableFlushExp
      ::set_double_text_to_button(scene, "btn_nav_research",
        ::format(::loc("weaponry/research") + " (%s)", ::Cost().setRp(flushExp).tostring()))
    }

    local showPurchaseButton = researchMode
                               && ::getAmmoCost(air, item.name, AMMO.MODIFICATION).gold == 0
                               && !::isModClassPremium(item)
                               && ::canBuyMod(air, item)

    showSceneBtn("btn_buy_mod", showPurchaseButton)
    if (showPurchaseButton)
      ::placePriceTextToButton(scene, "btn_buy_mod", ::loc("mainmenu/btnBuy"), ::weaponVisual.getItemCost(air, item).wp)

    local textObj = scene.findObject("no_action_text")
    if (::checkObj(textObj))
      textObj.show(researchMode
                   && availableFlushExp > 0
                   && !showResearchButton
                   && !showPurchaseButton)
  }

  function updateUnitItem(unit, itemObj)
  {
    local params = {
      slotbarActions = airActions
      getEdiffFunc  = getCurrentEdiff.bindenv(this)
    }
    local unitBlk = ::build_aircraft_item("unit_item", unit, params)
    guiScene.replaceContentFromText(itemObj, unitBlk, unitBlk.len(), this)
    ::fill_unit_item_timers(itemObj.findObject("unit_item"), unit, params)
  }

  function isAnyModuleInResearch()
  {
    local module = ::shop_get_researchable_module_name(airName)
    if (module == "")
      return false

    local moduleData = ::getModificationByName(air, module)
    if (!moduleData || ::isModResearched(air, moduleData))
      return false

    return !::isModClassPremium(moduleData)
  }

  function updateItemBundle(item)
  {
    local bundle = getItemBundle(item)
    if (!bundle)
      updateItem(item.guiPosIdx)
    else
    {
      updateItem(bundle.guiPosIdx)
      foreach(bitem in bundle.itemsList)
        updateItem(bitem.guiPosIdx)
    }
  }

  function createTreeItems(obj, branch, treeOffsetY = 0)
  {
    local branchItems = collectBranchItems(branch, [])
    branchItems.sort(@(a,b) a.tier <=> b.tier || a?.guiPosX <=> b?.guiPosX)
    foreach(item in branchItems)
      createItem(item, weaponsItem.modification, obj, item.guiPosX, item.tier +treeOffsetY -1)
  }

  function collectBranchItems(branch, resItems)
  {
    foreach(idx, item in branch)
      if (typeof(item)=="table") //modification
        resItems.append(item)
      else if (typeof(item)=="array") //branch
        collectBranchItems(item, resItems)
    return resItems
  }

  function createTreeBlocks(obj, columnsList, height, treeOffsetX, treeOffsetY, blockType = "", blockIdPrefix = "")
  {
    local fullWidth = wndWidth - treeOffsetX
    local view = {
      width = fullWidth
      height = height
      offsetX = treeOffsetX
      offsetY = treeOffsetY
      columnsList = columnsList
      rows = []
      rowType = blockType
    }

    if (columnsList.len())
    {
      local headerWidth = 0
      foreach(idx, column in columnsList)
      {
        column.needDivLine <- idx > 0
        headerWidth += column.width
        if (column.name && ::utf8_strlen(column.name) > ::header_len_per_cell * column.width)
          column.isSmallFont <- true
      }

      //increase last column width to full window width
      local widthDiff = fullWidth - headerWidth
      if (widthDiff > 0)
        columnsList[columnsList.len() - 1].width += widthDiff
    }

    local needTierArrows = blockIdPrefix != ""
    for(local i = 1; i <= height; i++)
    {
      local row = {
        width = fullWidth
        top = i - 1
      }

      if(needTierArrows)
      {
        row.id <- blockIdPrefix + i
        row.needTierArrow <- i > 1
        row.tierText <- ::get_roman_numeral(i)
      }

      view.rows.append(row)
    }

    local data = ::handyman.renderCached("gui/weaponry/weaponryBg", view)
    if (data!="")
      guiScene.appendWithBlk(obj, data, this)
  }

  function createTreeArrows(obj, arrowsList, treeOffsetY)
  {
    local data = ""
    foreach(idx, a in arrowsList)
    {
      local id = "arrow_" + idx

      if (a.from[0]!=a.to[0]) //hor arrow
        data += format("modArrow { id:t='%s'; type:t='right'; " +
                         "pos:t='%.1f@modCellWidth-0.5@modArrowLen, %.1f@modCellHeight-0.5h'; " +
                         "width:t='@modArrowLen + %.1f@modCellWidth' " +
                       "}",
                       id, a.from[0] + 1, a.from[1] - 0.5 + treeOffsetY, a.to[0]-a.from[0]-1
                      )
      else if (a.from[1]!=a.to[1]) //vert arrow
        data += format("modArrow { id:t='%s'; type:t='down'; " +
                         "pos:t='%.1f@modCellWidth-0.5w, %.1f@modCellHeight-0.5@modArrowLen'; " +
                         "height:t='@modArrowLen + %.1f@modCellHeight' " +
                       "}",
                       id, a.from[0] + 0.5, a.from[1] + treeOffsetY, a.to[1]-a.from[1]-1
                      )
    }
    if (data!="")
      guiScene.appendWithBlk(obj, data, this)
  }

  function fillModsTree(treeOffsetY)
  {
    local tree = modsTree.generateModsTree(air)
    if (!tree)
      return

    local treeSize = modsTree.getModsTreeSize(air)
    mainModsObj.size = format("%.1f@modCellWidth, %.1f@modCellHeight", treeSize.guiPosX, treeSize.tier + treeOffsetY)
    if (!(treeSize.tier > 0))
      return

    local bgElems = modsTree.generateModsBgElems(air)
    createTreeBlocks(modsBgObj, bgElems.blocks, treeSize.tier, 0, treeOffsetY, "unlocked", tierIdPrefix)
    createTreeArrows(modsBgObj, bgElems.arrows, treeOffsetY)
    createTreeItems(mainModsObj, tree, treeOffsetY)
    if (treeSize.guiPosX > wndWidth)
      scene.findObject("overflow-div")["overflow-x"] = "auto"
  }

  function updateTiersStatus(size)
  {
    local tiersArray = getResearchedModsArray(size.tier)
    for(local i = 1; i <= size.tier; i++)
    {
      if (tiersArray[i-1] == null)
      {
        ::dagor.assertf(false, ::format("No modification data for unit '%s' in tier %s.", air.name, i.tostring()))
        break
      }
      local unlocked = ::weaponVisual.isTierAvailable(air, i)
      local owned = (tiersArray[i-1].notResearched == 0)
      scene.findObject(tierIdPrefix + i).type = owned? "owned" : unlocked ? "unlocked" : "locked"

      local jObj = scene.findObject(tierIdPrefix + (i+1).tostring())
      if(::checkObj(jObj))
      {
        local modsCountObj = jObj.findObject(tierIdPrefix + (i+1).tostring() + "_txt")
        local countMods = tiersArray[i-1].researched
        local reqMods = air.needBuyToOpenNextInTier[i-1]
        if(countMods >= reqMods)
          if(!unlocked)
          {
            modsCountObj.setValue(countMods.tostring() + ::loc("weapons_types/short/separator") + reqMods.tostring())
            local tooltipText = "<color=@badTextColor>" + ::loc("weaponry/unlockTier/reqPrevTiers") + "</color>"
            modsCountObj.tooltip = ::loc("weaponry/unlockTier/countsBlock/startText") + "\n" +  tooltipText
            jObj.tooltip = tooltipText
          }
          else
          {
            modsCountObj.setValue("")
            modsCountObj.tooltip = ""
            jObj.tooltip = ""
          }
        else
        {
          modsCountObj.setValue(countMods.tostring() + ::loc("weapons_types/short/separator") + reqMods.tostring())
          local req = reqMods - countMods

          local tooltipText = ::loc("weaponry/unlockTier/tooltip",
                                    { amount = req.tostring(), tier = ::get_roman_numeral(i+1) })
          jObj.tooltip = tooltipText
          modsCountObj.tooltip = ::loc("weaponry/unlockTier/countsBlock/startText") + "\n" + tooltipText
        }
      }
    }
  }

  function getResearchedModsArray(tiersCount)
  {
    local tiersArray = []
    if("modifications" in air && tiersCount > 0)
    {
      tiersArray = array(tiersCount, null)
      foreach(mod in air.modifications)
        if (!::wp_get_modification_cost_gold(airName, mod.name) &&
            ::getModificationBulletsGroup(mod.name) == ""
           )
          {
            local idx = mod.tier-1
            tiersArray[idx] = tiersArray[idx] || { researched=0, notResearched=0 }

            if(::isModResearched(air, mod))
              tiersArray[idx].researched++
            else
              tiersArray[idx].notResearched++
          }
    }
    return tiersArray
  }

  function fillPremiumMods(offsetX, offsetY)
  {
    if (!::has_feature("SpendGold"))
      return

    local nextX = offsetX
    if (air.spare && !researchMode)
      createItem(air.spare, weaponsItem.spare, mainModsObj, nextX++, offsetY)
    foreach(mod in air.modifications)
      if ((!researchMode || ::canResearchMod(air, mod))
          && (::isModClassPremium(mod)
              || (mod.modClass == "" && ::getModificationBulletsGroup(mod.name) == "")
          ))
        createItem(mod, weaponsItem.modification, mainModsObj, nextX++, offsetY)

    if (researchMode)
      return

    local columnsList = [getWeaponsColumnData()]
    createTreeBlocks(modsBgObj, columnsList, 1, offsetX, offsetY)
  }

  function getWeaponsColumnData(name = null, width = 1, tooltip = "")
  {
    return { name = name
        width = width
        tooltip = tooltip
      }
  }

  function fillWeaponsAndBullets(offsetX, offsetY)
  {
    local columnsList = []
    //add primary weapons bundle
    local primaryWeaponsNames = ::getPrimaryWeaponsList(air)
    local primaryWeaponsList = []
    local curPrimWeapon = ::get_last_primary_weapon(air)
    foreach(i, modName in primaryWeaponsNames)
    {
      local mod = (modName=="")? null : ::getModificationByName(air, modName)
      local item = { name = modName, weaponMod = mod }

      if (mod)
      {
        mod.isPrimaryWeapon <- true
        item.reqModification <- [modName]
      }
      else
      {
        item.image <- air.commonWeaponImage
        if("weaponUpgrades" in air)
          item.weaponUpgrades <- air.weaponUpgrades
      }
      primaryWeaponsList.append(item)
    }
    createBundle(primaryWeaponsList, weaponsItem.primaryWeapon, 0, mainModsObj, offsetX, offsetY)
    columnsList.append(getWeaponsColumnData(::loc("options/primary_weapons")))
    offsetX++

    lastWeapon = ::get_last_weapon(airName) //real weapon or ..._default
    dagor.debug("initial set lastWeapon " + lastWeapon )
    if (::isAirHaveSecondaryWeapons(air))
    {
      //add secondary weapons bundle
      local weaponsList = []
      for (local j = 0; j < air.weapons.len(); j++)
      {
        if (::isWeaponAux(air.weapons[j]))
          continue

        weaponsList.append(air.weapons[j])
        if (lastWeapon=="" && ::shop_is_weapon_purchased(airName, air.weapons[j].name))
          ::set_last_weapon(airName, air.weapons[j].name)
      }
      createBundle(weaponsList, weaponsItem.weapon, 0, mainModsObj, offsetX, offsetY)
      columnsList.append(getWeaponsColumnData(::g_weaponry_types.WEAPON.getHeader(air)))
      offsetX++
    }

    //add bullets bundle
    lastBullets = []

    for (local groupIndex = 0; groupIndex < ::get_last_fake_bullets_index(air); groupIndex++)
    {
      local bulletsList = ::get_bullets_list(air.name, groupIndex, false, false, false)
      local curBulletsName = ::get_last_bullets(air.name, groupIndex)
      if (groupIndex < ::BULLETS_SETS_QUANTITY)
        lastBullets.append(curBulletsName)
      if (!bulletsList.values.len() || bulletsList.duplicate)
        continue
      local itemsList = []
      local isCurBulletsValid = false
      foreach(i, value in bulletsList.values)
      {
        local bItem = ::getModificationByName(air, value)
        isCurBulletsValid = isCurBulletsValid || value == curBulletsName || (!bItem && curBulletsName == "")
        if (!bItem) //default
          bItem = { name = value, isDefaultForGroup = groupIndex }
        itemsList.append(bItem)
      }
      if (!isCurBulletsValid)
        ::set_unit_last_bullets(air, groupIndex, itemsList[0].name)
      createBundle(itemsList, weaponsItem.bullets, groupIndex, mainModsObj, offsetX, offsetY)

      local name = ::get_bullets_list_header(air, bulletsList)
      columnsList.append(getWeaponsColumnData(name))
      offsetX++
    }

    //add expendables
    local expendablesArray = ::get_expendable_modifications_array(air)
    if (expendablesArray.len())
    {
      columnsList.append(getWeaponsColumnData(::loc("modification/category/expendables")))
      foreach (mod in expendablesArray)
      {
        createItem(mod, mod.type, mainModsObj, offsetX, offsetY)
        offsetX++
      }
    }

    createTreeBlocks(modsBgObj, columnsList, 1, 0, offsetY)
  }

  function canBomb(checkPurchase)
  {
    return ::isAirHaveAnyWeaponsTags(air, ["bomb", "rocket"], checkPurchase)
  }

  function getItemBundle(searchItem)
  {
    foreach(bundle in items)
      if (bundle.type == weaponsItem.bundle)
        foreach(item in bundle.itemsList)
          if (item.name == searchItem.name && item.type==searchItem.type)
            return bundle
    return null
  }

  function onModificationTooltipOpen(obj)
  {
    local id = ::getObjIdByPrefix(obj, "tooltip_item_")
    if (!id) return
    local idx = id.tointeger()
    if (!(idx in items))
      return

    local item = items[idx]
    local curTier = "tier" in item? item.tier : 1
    local canDisplayInfo = curTier <= 1 || ::isInArray(curTier, shownTiers)
    tooltipOpenTime = canDisplayInfo? -1 : ::tooltip_display_delay
    ::weaponVisual.updateWeaponTooltip(obj, air, item, this, { canDisplayInfo = canDisplayInfo })

    obj.findObject("weapons_timer").setUserData(this)
  }

  function onUpdateWeaponTooltip(obj, dt)
  {
    if(tooltipOpenTime <= 0)
      return
    tooltipOpenTime -= dt
    if(tooltipOpenTime <= 0)
    {
      local tooltipObj = obj.getParent()
      local id = ::getObjIdByPrefix(tooltipObj, "tooltip_item_")
      if (!id)
        return
      local idx = id.tointeger()
      if (!(idx in items))
        return
      local item = items[idx]
      if ("tier" in item && !::isInArray(item.tier, shownTiers))
        shownTiers.append(item.tier)
      ::weaponVisual.updateWeaponTooltip(tooltipObj, air, item, this)
    }
  }

  function getItemIdxByObj(obj)
  {
    if (!obj) return -1
    local id = obj.holderId
    if (!id || id=="")
      id = obj.id
    if (id.len() <= 5 || id.slice(0,5) != "item_")
      return -1
    local idx = id.slice(5).tointeger()
    return (idx in items)? idx : -1
  }

  function getItemIdxByName(name)
  {
    foreach(idx, item in items)
      if (item.name == name)
        return idx

    return -1
  }

  function doCurrentItemAction()
  {
    if (!::checkObj(mainModsObj))
      return

    local val = mainModsObj.getValue() - 1
    local itemObj = mainModsObj.findObject("item_" + val)
    if (::checkObj(itemObj))
      onModAction(itemObj, false)
  }

  function onModItemClick(obj)
  {
    if (researchMode)
    {
      local idx = getItemIdxByObj(obj)
      if (idx >= 0)
        mainModsObj.setValue(items[idx].guiPosIdx+1)
      return
    }

    onModAction(obj, false)
  }

  function onModItemDblClick(obj)
  {
    onModAction(obj)
  }

  function onModActionBtn(obj)
  {
    onModAction(obj, true, true)
  }

  function onModCheckboxClick(obj)
  {
    onModAction(obj)
  }

  function getSelectedUnit()
  {
    if (!::checkObj(mainModsObj))
      return null
    local item = getSelItemFromNavObj(mainModsObj)
    return (item && isItemTypeUnit(item.type))? item : null
  }

  function getSelItemFromNavObj(obj)
  {
    local value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return null
    local idx = getItemIdxByObj(obj.getChild(value))
    if (idx < 0)
      return null
    return items[idx]
  }

  function canPerformAction(item, amount)
  {
    local reason = null
    if(!isOwn)
      reason = ::format(::loc("weaponry/action_not_allowed"), ::loc("weaponry/unit_not_bought"))
    else if (!amount && !::canBuyMod(air, item))
    {
      local reqTierMods = 0
      local reqMods = ""
      if("tier" in item)
        reqTierMods = ::getNextTierModsCount(air, item.tier - 1)
      if ("reqModification" in item)
        reqMods = ::weaponVisual.getReqModsText(air, item)

      if(reqTierMods > 0)
        reason = ::format(::loc("weaponry/action_not_allowed"),
                          ::loc("weaponry/unlockModTierReq",
                                { tier = ::roman_numerals[item.tier], amount = (reqTierMods).tostring() }))
      else if(reqMods.len() > 0)
        reason = ::format(::loc("weaponry/action_not_allowed"), ::loc("weaponry/unlockModsReq") + "\n" + reqMods)
    }

    if(reason != null)
    {
      msgBox("not_available", reason, [["ok", function() {} ]], "ok")
      return false
    }
    return true
  }

  function onStickDropDown(obj, show)
  {
    if (!::checkObj(obj))
      return

    local id = obj.id
    if (!id || id.len() <= 5 || id.slice(0,5) != "item_")
      return base.onStickDropDown(obj, show)

    if (!show)
    {
      curBundleTblObj = null
      restoreFocus()
      return
    }

    curBundleTblObj = obj.findObject("items_field")
    guiScene.performDelayed(this, function() {
      local focusObj = getMainFocusObj2()
      if (!::checkObj(focusObj))
        return

      ::play_gui_sound("menu_appear")
      focusObj.select()
    })
    return
  }

  function unstickCurBundle()
  {
    if (::checkObj(curBundleTblObj))
      onDropDown(curBundleTblObj.getParent().getParent()) //need a hoverSize here or bundleItem.

    if (::check_obj(mainModsObj))
    {
      checkCurrentFocusItem(mainModsObj)
      mainModsObj.select()
    }
  }

  function onModAction(obj, fullAction = true, stickBundle = false)
  {
    local idx = getItemIdxByObj(obj)
    if (idx < 0)
      return

    if (items[idx].type == weaponsItem.bundle)
    {
      if (stickBundle)
        onDropDown(obj)
      return
    }
    doItemAction(items[idx], fullAction)
  }

  function doItemAction(item, fullAction = true)
  {
    local amount = ::weaponVisual.getItemAmount(air, item)
    local onlyBuy = !fullAction && !getItemBundle(item)

    if (checkResearchOperation(item))
      return
    if(!canPerformAction(item, amount))
      return

    if (item.type == weaponsItem.weapon && !onlyBuy)
    {
      if(::get_last_weapon(airName) == item.name || !amount)
      {
        if (item.cost <= 0)
          return

        return onBuy(item.guiPosIdx)
      }

      ::play_gui_sound("check")
      ::set_last_weapon(airName, item.name)
      updateItemBundle(item)
      ::check_secondary_weapon_mods_recount(air)
      return
    }
    else if (item.type == weaponsItem.primaryWeapon)
    {
      if (!onlyBuy)
      {
        setLastPrimary(item)
        return
      }
    }
    else if (item.type == weaponsItem.modification)
    {
      local groupDef = ("isDefaultForGroup" in item)? item.isDefaultForGroup : -1
      if (groupDef >= 0)
      {
        setLastBullets(item, groupDef)
        return
      }
      else if (!onlyBuy)
      {
        if (::getModificationBulletsGroup(item.name) != "")
        {
          local id = ::get_bullet_group_index(airName, item.name)
          local isChanged = false
          if (id >= 0)
            isChanged = setLastBullets(item, id)
          if (isChanged)
            return
        }
        else if(amount)
        {
          switchMod(item)
          return
        }
      }
    }
    else if (item.type == weaponsItem.expendables)
    {
      if (!onlyBuy && amount)
      {
        switchMod(item)
        return
      }
    }// else
    //if (item.type==weaponsItem.spare)

    onBuy(item.guiPosIdx)
  }

  function checkResearchOperation(item)
  {
    if (::weaponVisual.canResearchItem(air, item, availableFlushExp <= 0 && setResearchManually))
    {
      local afterFuncDone = (@(item) function() {
        setModificatonOnResearch(item, function()
        {
          updateAllItems()
          if (researchMode)
            selectResearchModule()
        })
      })(item)

      flushItemExp(item.name, afterFuncDone)
      return true
    }
    return false
  }

  function setModificatonOnResearch(item, afterDoneFunc = null)
  {
    local executeAfterDoneFunc = (@(afterDoneFunc) function() {
        if (afterDoneFunc)
          afterDoneFunc()
      })(afterDoneFunc)

    if (!item || ::isModResearched(air, item))
    {
      executeAfterDoneFunc()
      return
    }

    taskId = ::shop_set_researchable_unit_module(airName, item.name)
    if (taskId >= 0)
    {
      setResearchManually = true
      lastResearchMod = item
      ::set_char_cb(this, slotOpCb)
      showTaskProgressBox()
      afterSlotOp = afterDoneFunc
      afterSlotOpError = (@(executeAfterDoneFunc) function(res) {
          msgBox("unit_modul_research_fail", ::loc("weaponry/module_set_research_failed"),
            [["ok", (@(executeAfterDoneFunc) function() { executeAfterDoneFunc() })(executeAfterDoneFunc)]], "ok")
        })(executeAfterDoneFunc)
    }
    else
      executeAfterDoneFunc()
  }

  function flushItemExp(modName, afterDoneFunc = null)
  {
    checkSaveBulletsAndDo((@(modName, afterDoneFunc) function() {
      _flushItemExp(modName, afterDoneFunc)
    })(modName, afterDoneFunc))
  }

  function _flushItemExp(modName, afterDoneFunc = null)
  {
    local executeAfterDoneFunc = (@(afterDoneFunc) function() {
        setResearchManually = true
        if (afterDoneFunc)
          afterDoneFunc()
      })(afterDoneFunc)

    if (availableFlushExp <= 0)
    {
      executeAfterDoneFunc()
      return
    }

    taskId = ::flushExcessExpToModule(airName, modName)
    if (taskId >= 0)
    {
      ::set_char_cb(this, slotOpCb)
      showTaskProgressBox()
      afterSlotOp = afterDoneFunc
      afterSlotOpError = (@(executeAfterDoneFunc) function(res) {
          executeAfterDoneFunc()
        })(executeAfterDoneFunc)
    }
    else
      executeAfterDoneFunc()
  }

  function onAltModAction(obj) //only buy atm before no research.
  {
    local idx = getItemIdxByObj(obj)
    if (idx < 0)
      return

    local item = items[idx]
    if (item.type==weaponsItem.spare)
    {
      ::gui_handlers.UniversalSpareApplyWnd.open(air, getItemObj(idx))
      return
    }
    else if (item.type == weaponsItem.modification)
    {
      if (::weaponVisual.getItemAmount(air, item) && ::is_mod_upgradeable(item.name))
      {
        ::gui_handlers.ModUpgradeApplyWnd.open(air, item, getItemObj(idx))
        return
      }
    }

    onBuy(idx)
  }

  function onBuy(idx, buyAmount = 0) //buy for wp or gold
  {
    if (!isOwn)
      return

    local item = items[idx]
    local open = false

    if (item.type==weaponsItem.bundle)
      return ::weaponVisual.getByCurBundle(air, item, (@(idx, buyAmount) function(air, item) { return onBuy(item.guiPosIdx, buyAmount) })(idx, buyAmount))

    if (item.type==weaponsItem.weapon)
    {
      if (!::shop_is_weapon_available(airName, item.name, false, true))
        return
    }
    else if (item.type==weaponsItem.primaryWeapon)
    {
      if ("guiPosIdx" in item.weaponMod)
        item = items[item.weaponMod.guiPosIdx]
    }
    else if (item.type==weaponsItem.modification || item.type==weaponsItem.expendables)
    {
      local groupDef = ("isDefaultForGroup" in item)? item.isDefaultForGroup : -1
      if (groupDef>=0)
        return

      open = ::canResearchMod(air, item)
    }

    checkAndBuyWeaponry(item, open)
  }

  function onBuyAllButton()
  {
    onBuyAll()
  }

  function onBuyAll(forceOpen = true, silent = false)
  {
    checkSaveBulletsAndDo(::Callback((@(air, forceOpen, silent) function() {
      ::WeaponsPurchase(air, {open = forceOpen, silent = silent})
    })(air, forceOpen, silent), this))
  }

  function setLastBullets(item, groupIdx)
  {
    if (!(groupIdx in lastBullets))
      return false

    local curBullets = ::get_last_bullets(airName, groupIdx)
    local isChanged = curBullets != item.name && !("isDefaultForGroup" in item && curBullets == "")
    ::set_unit_last_bullets(air, groupIdx, item.name)
    if (isChanged)
    {
      ::play_gui_sound("check")
      ::broadcastEvent("UnitBulletsChanged", { unit = air, groupIdx = groupIdx, bullet = item })
    }
    updateItemBundle(item)
    return isChanged
  }

  function checkAndBuyWeaponry(modItem, open = false)
  {
    checkSaveBulletsAndDo(::Callback((@(air, modItem, open) function() {
      ::WeaponsPurchase(air, {modItem = modItem, open = open})
    })(air, modItem, open), this))
  }

  function setLastPrimary(item)
  {
    local lastPrimary = ::get_last_primary_weapon(air)
    if (lastPrimary==item.name)
      return
    local mod = ::getModificationByName(air, (item.name=="")? lastPrimary : item.name)
    if (mod)
      switchMod(mod, false)
  }

  function switchMod(item, checkCanDisable = true)
  {
    local equipped = ::shop_is_modification_enabled(airName, item.name)
    if (checkCanDisable && equipped && !::weaponVisual.isCanBeDisabled(item))
      return

    !equipped? ::play_gui_sound("check") : ::play_gui_sound("uncheck")

    checkSaveBulletsAndDo((@(item, equipped) function() { doSwitchMod(item, equipped) })(item, equipped))
  }

  function doSwitchMod(item, equipped)
  {
    local wndUpdateItems = ::Callback(function() {
      updateAllItems()
      unstickCurBundle()
    }, this)

    local taskSuccessCallback = (@(air, item) function() {
      ::updateAirAfterSwitchMod(air, item.name)
      wndUpdateItems()
    }) (air, item)

    local taskId = enable_modification(airName, item.name, !equipped)
    ::g_tasker.addTask(taskId, { showProgressBox = true }, taskSuccessCallback)
  }

  function checkSaveBulletsAndDo(func)
  {
    local needSave = false;
    for (local groupIndex = 0; groupIndex < ::BULLETS_SETS_QUANTITY; groupIndex++)
    {
        if (lastBullets && groupIndex in lastBullets &&
            lastBullets[groupIndex] != ::get_last_bullets(airName, groupIndex))
        {
          dagor.debug("force cln_update due lastBullets '" + lastBullets[groupIndex] + "' != '" +
                      ::get_last_bullets(airName, groupIndex) + "'")
          needSave = true;
          lastBullets[groupIndex] = ::get_last_bullets(airName, groupIndex)
        }
    }
    if (isAirHaveSecondaryWeapons(air) && lastWeapon!="" && lastWeapon!=::get_last_weapon(airName))
    {
      dagor.debug("force cln_update due lastWeapon '" + lastWeapon + "' != " + ::get_last_weapon(airName))
      needSave = true;
      lastWeapon = ::get_last_weapon(airName)
    }

    if (needSave)
    {
      taskId = save_online_single_job(321)
      if (taskId >= 0 && func)
      {
        local cb = ::u.isFunction(func) ? ::Callback(func, this) : func
        ::g_tasker.addTask(taskId, {showProgressBox = true}, cb)
      }
    }
    else if (func)
      func()
    return true
  }

  function getAutoPurchaseValue()
  {
    return isOwn && ::get_auto_buy_modifications()
  }

  function onChangeAutoPurchaseModsValue(obj)
  {
    local value = obj.getValue()
    local savedValue = getAutoPurchaseValue()
    if (value == savedValue)
      return

    ::set_auto_buy_modifications(value)
    ::save_online_single_job(SAVE_ONLINE_JOB_DIGIT)
  }

  function goBack()
  {
    checkSaveBulletsAndDo(null)

    if (researchMode)
    {
      local curResName = ::shop_get_researchable_module_name(airName)
      if (::getTblValue("name", lastResearchMod, "") != curResName)
        setModificatonOnResearch(::getModificationByName(air, curResName))
    }

    if (getAutoPurchaseValue())
      onBuyAll(false, true)
    else if (researchMode)
      ::prepareUnitsForPurchaseMods.addUnit(air)

    base.goBack()
  }

  function afterModalDestroy()
  {
    if (!::checkNonApprovedResearches(true, false) && ::prepareUnitsForPurchaseMods.haveUnits())
      ::prepareUnitsForPurchaseMods.checkUnboughtMods()
  }

  function onDestroy()
  {
    if (researchMode && ::find_any_not_researched_mod(air))
      ::handlersManager.requestHandlerRestore(this, ::gui_handlers.MainMenu)
  }

  function getHandlerRestoreData()
  {
    if (!researchMode || (setResearchManually && !availableFlushExp))
      return null
    return {
      openData = {
        researchMode = researchMode
        researchBlock = researchBlock
      }
    }
  }

  function onEventUniversalSpareActivated(p)
  {
    foreach(idx, item in items)
      if (item.type == weaponsItem.spare)
        updateItem(idx)
  }

  function onEventModUpgraded(p)
  {
    if (p.unit != air)
      return
    local modName = p.mod.name
    local itemidx = ::u.searchIndex(items, @(item) item.name == modName)
    if (itemidx != -1)
      updateItem(itemidx)
  }

  function getCurrentEdiff()
  {
    return curEdiff == -1 ? ::get_current_ediff() : curEdiff
  }
}

function isWeaponAux(weapon)
{
  local aux = false
  foreach (tag in weapon.tags)
    if (tag == "aux")
    {
      aux = true
      break
    }
  return aux
}


class ::gui_handlers.MultiplePurchase extends ::gui_handlers.BaseGuiHandlerWT
{
  curValue = 0
  minValue = 0
  maxValue = 1
  minUserValue = null
  maxUserValue = null
  item = null
  unit = null

  itemCost = null

  buyFunc = null
  onExitFunc = null
  showDiscountFunc = null

  someAction = true
  scene = null
  wndType = handlerType.MODAL
  sceneBlkName = "gui/multiplePurchase.blk"

  function initScreen()
  {
    if (minValue >= maxValue)
    {
      goBack()
      return
    }

    itemCost = ::weaponVisual.getItemCost(unit, item)
    local statusTbl = ::weaponVisual.getItemStatusTbl(unit, item)
    minValue = statusTbl.amount
    maxValue = statusTbl.maxAmount
    minUserValue = statusTbl.amount + 1
    maxUserValue = statusTbl.maxAmount

    scene.findObject("item_name_header").setValue(::weaponVisual.getItemName(unit, item))

    updateSlider()
    local modItemObj = ::weaponVisual.createItem("mod_" + item.name, item, item.type, scene.findObject("icon"), this)

    ::weaponVisual.updateItem(unit, item, scene.findObject("icon"), false, this)

    local discountType = item.type == weaponsItem.spare? "spare" : (item.type == weaponsItem.weapon)? "weapons" : "mods"
    ::showAirDiscount(scene.findObject("multPurch_discount"), unit.name, discountType, item.name, true)

    sceneUpdate()
  }

  function updateSlider()
  {
    minUserValue = (minUserValue == null)? minValue : clamp(minUserValue, minValue, maxValue)
    maxUserValue = (maxUserValue == null)? maxValue : clamp(maxUserValue, minValue, maxValue)

    if (curValue <= minValue)
    {
      local balance = ::get_balance()
      local maxBuy = maxValue - minValue
      if (maxBuy * itemCost.gold > balance.gold && balance.gold >= 0)
        maxBuy = (balance.gold / itemCost.gold).tointeger()
      if (maxBuy * itemCost.wp > balance.wp && balance.wp >= 0)
        maxBuy = (balance.wp / itemCost.wp).tointeger()
      curValue = itemCost.gold > 0 ? minUserValue: minValue + max(maxBuy, 1)
    }

    local sObj = scene.findObject("skillSlider")
    sObj.max = maxValue
    sObj.select()

    local oldObj = scene.findObject("oldSkillProgress")
    oldObj.max = maxValue

    local newObj = scene.findObject("newSkillProgress")
    newObj.min = minValue
    newObj.max = maxValue
  }

  function onModificationTooltipOpen(obj)
  {
    ::weaponVisual.updateWeaponTooltip(obj, unit, item, this)
  }

  function onButtonDec()
  {
    curValue -= 1
    sceneUpdate()
  }

  function onButtonInc()
  {
    curValue += 1
    sceneUpdate()
  }

  function onButtonMax()
  {
    curValue = maxUserValue
    sceneUpdate()
  }

  function onProgressChanged(obj)
  {
    if(!obj || !someAction)
      return

    local newValue = obj.getValue()
    if (newValue == curValue)
      return

    if (newValue < minUserValue)
      newValue = minUserValue

    local value = clamp(newValue, minUserValue, maxUserValue)

    curValue = value
    sceneUpdate()
  }

  function sceneUpdate()
  {
    scene.findObject("skillSlider").setValue(curValue)
    scene.findObject("oldSkillProgress").setValue(minValue)
    scene.findObject("newSkillProgress").setValue(curValue)
    local buyValue = curValue - minValue
    local buyValueText = buyValue==0? "": ("+" + buyValue.tostring())
    scene.findObject("text_buyingValue").setValue(buyValueText)
    scene.findObject("buttonInc").enable(curValue < maxUserValue)
    scene.findObject("buttonMax").enable(curValue != maxUserValue)
    scene.findObject("buttonDec").enable(curValue > minUserValue)

    local wpCost = buyValue * itemCost.wp
    local eaCost = buyValue * itemCost.gold
    ::placePriceTextToButton(scene, "item_price", ::loc("mainmenu/btnBuy"), wpCost, eaCost)
  }

  function onBuy(obj)
  {
    if (buyFunc)
      buyFunc(curValue - minValue)
  }

  function goBack()
  {
    if (onExitFunc)
      onExitFunc()
    base.goBack()
  }

  function onEventModificationPurchased(params) { goBack() }
  function onEventWeaponPurchased(params) { goBack() }
  function onEventSparePurchased(params) { goBack() }
}
