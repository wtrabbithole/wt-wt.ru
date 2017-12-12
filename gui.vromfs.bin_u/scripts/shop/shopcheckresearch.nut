class ::gui_handlers.ShopCheckResearch extends ::gui_handlers.ShopMenuHandler
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/shop/shopCheckResearch.blk"
  sceneNavBlkName = "gui/shop/shopNav.blk"
  shouldBlurSceneBg = true

  researchedUnit = null
  researchBlock = null

  curResearchingUnit = null
  lastResearchUnit = null
  unitCountry = ""
  unitType = ""

  setResearchManually = false
  showRankLockedMsgBoxOnce = false

  shopResearchMode = true
  slotbarActions = [ "research", "buy", "take", "weapons", "info", "repair" ]

  function initScreen()
  {
    local unitName = ::getTblValue(::researchedUnitForCheck, researchBlock)
    curAirName = unitName
    researchedUnit = ::getAircraftByName(unitName)
    unitCountry = researchBlock.country
    unitType = ::get_es_unit_type(researchedUnit)
    updateResearchVariables()

    base.initScreen()
    initFocusArray()

    showSceneBtn("modesRadiobuttons", false)

    createSlotbar(
      {
        showNewSlot = true,
        showEmptySlot = true,
        limitCountryChoice = true,
        customCountry = unitCountry,
        showTopPanel = false
      },
      "slotbar_place")

    selectRequiredUnit()
  }

  function showRankRestrictionMsgBox()
  {
    if (!hasNextResearch() || showRankLockedMsgBoxOnce || !isSceneActiveNoModals())
      return

    showRankLockedMsgBoxOnce = true

    local rank = ::get_max_era_available_by_country(unitCountry, unitType)
    local nextRank = rank + 1

    if (nextRank > ::max_country_rank)
      return

    local unitLockedByFeature = ::getNotResearchedUnitByFeature(unitCountry, unitType)
    if (unitLockedByFeature && !::checkFeatureLock(unitLockedByFeature, CheckFeatureLockAction.RESEARCH))
      return

    local ranksBlk = ::get_ranks_blk()
    local unitsCount = boughtVehiclesCount[rank]
    local unitsNeed = ::getUnitsNeedBuyToOpenNextInEra(unitCountry, unitType, rank, ranksBlk)
    local reqUnits = max(0, unitsNeed - unitsCount)
    if (reqUnits > 0)
    {
      local text = ::loc("shop/unlockTier/locked", {rank = ::get_roman_numeral(nextRank)}) + "\n"
                    + ::loc("shop/unlockTier/reqBoughtUnitsPrevRank", {amount = reqUnits, prevRank = ::get_roman_numeral(rank)})
      msgBox("locked_rank", text, [["ok", function(){}]], "ok", { cancel_fn = function(){}})
    }
  }

  function updateHeaderText()
  {
    local headerObj = scene.findObject("shop_header")
    if (!::checkObj(headerObj))
      return

    local expText = ::get_flush_exp_text(availableFlushExp)
    local headerText = ::loc("mainmenu/nextResearch/title")
    if (expText != "")
      headerText += ::loc("ui/parentheses/space", {text = expText})
    headerObj.setValue(headerText)
  }

  function updateResearchVariables()
  {
    updateCurResearchingUnit()
    updateExcessExp()
  }

  function updateCurResearchingUnit()
  {
    local curUnitName = ::shop_get_researchable_unit_name(unitCountry, unitType)
    if (curUnitName == ::getTblValue("name", curResearchingUnit, ""))
      return

    curResearchingUnit = ::getAircraftByName(curUnitName)
  }

  function updateExcessExp()
  {
    availableFlushExp = ::shop_get_country_excess_exp(unitCountry, unitType)
    updateHeaderText()
  }

  function hasNextResearch()
  {
    return availableFlushExp > 0 &&
      (curResearchingUnit == null || ::isUnitResearched(curResearchingUnit))
  }

  function selectRequiredUnit()
  {
    local unit = null
    if (availableFlushExp > 0)
    {
      if (curResearchingUnit && !::isUnitResearched(curResearchingUnit))
        unit = curResearchingUnit
      else
      {
        unit = ::getMaxRankResearchingUnitByCountry(unitCountry, unitType)
        setUnitOnResearch(unit)
      }
    }
    else if (!curResearchingUnit || ::isUnitResearched(curResearchingUnit))
      unit = ::getMaxRankUnboughtUnitByCountry(unitCountry, unitType)
    else
      unit = curResearchingUnit

    if (!unit)
    {
      guiScene.performDelayed(this, function() {
        if (!isSceneActiveNoModals())
          return
        showRankRestrictionMsgBox()
      })
      return
    }

    destroyGroupChoose(::isGroupPart(unit)? unit.group : "")

    if (::isGroupPart(unit))
      guiScene.performDelayed(this, (@(unit) function() {
        if (!isSceneActiveNoModals())
          return
        checkSelectAirGroup(getItemBlockFromShopTree(unit.group), unit.name)
      })(unit))

    selectCellByUnitName(unit.name)
  }

  function showResearchUnitTutorial()
  {
    local isTutorialShowed = ::loadLocalByAccount("tutor/researchUnit", false)
    if (isTutorialShowed)
      return

    ::saveLocalByAccount("tutor/researchUnit", true)

    local visibleObj = scene.findObject("shop_items_visible_div")
    if (!visibleObj)
      return

    local visibleBox = ::GuiBox().setFromDaguiObj(visibleObj)
    local unitsObj = []
    foreach (newUnit in ::all_units)
      if (unitCountry == ::getUnitCountry(newUnit))
        if (unitType == ::get_es_unit_type(newUnit) && ::canResearchUnit(newUnit))
        {
          local newUnitName = ""
          if (::isGroupPart(newUnit))
            newUnitName = newUnit.group
          else
            newUnitName = newUnit.name

          local unitObj = scene.findObject(newUnitName)
          if (unitObj)
          {
            local unitBox = ::GuiBox().setFromDaguiObj(unitObj)
            if (unitBox.isInside(visibleBox))
              unitsObj.append(unitObj)
          }
        }
    unitsObj.append("btn_spend_exp")

    local steps = [
      {
        obj = unitsObj
        text = ::loc("tutorials/research_next_aircraft")
        bottomTextLocIdArray = ["help/NEXT_ACTION"]
        actionType = tutorAction.ANY_CLICK
        haveArrow = false
        accessKey = "J:A"
      }]
    ::gui_modal_tutor(steps, this)
  }

  function onUnitSelect()
  {
    updateButtons()
  }

  function getDefaultUnitInGroup(unitGroup)
  {
    local unitsList = ::getTblValue("airsGroup", unitGroup)
    if (!unitsList)
      return null

    local res = null
    foreach(unit in unitsList)
      if (::canResearchUnit(unit))
      {
        res = unit
        break
      }
      else if (!res && (::canBuyUnit(unit) || ::canBuyUnitOnline(unit)))
        res = unit

    return res || ::getTblValue(0, unitsList)
  }

  function updateButtons()
  {
    if (!::checkObj(scene))
      return

    updateRepairAllButton()
    showSceneBtn("btn_back", curResearchingUnit == null || ::isUnitResearched(curResearchingUnit))

    local unit = getCurAircraft(true, true)
    if (!unit)
      return

    updateSpendExpBtn(unit)

    local canBuyIngame = ::canBuyUnit(unit)
    local canBuyOnline = ::canBuyUnitOnline(unit)
    local showBuyUnit = canBuyIngame || canBuyOnline
    showNavButton("btn_buy_unit", showBuyUnit)
    if (showBuyUnit)
    {
      local locText = ::loc("shop/btnOrderUnit", { unit = ::getUnitName(unit.name) })
      local unitCost = (canBuyIngame && !canBuyOnline) ? ::getUnitCost(unit) : ::Cost()
      ::placePriceTextToButton(navBarObj,      "btn_buy_unit", locText, unitCost)
      ::placePriceTextToButton(navBarGroupObj, "btn_buy_unit", locText, unitCost)
    }
  }

  function updateSpendExpBtn(unit)
  {
    local showSpendBtn = !::isUnitGroup(unit)
                         && ::canResearchUnit(unit)
    local coloredText = ""
    if (showSpendBtn)
    {
      local reqExp = ::getUnitReqExp(unit) - ::getUnitExp(unit)
      local flushExp = reqExp < availableFlushExp ? reqExp : availableFlushExp
      local textSample = ::loc("shop/researchUnit", { unit = ::getUnitName(unit.name) }) + "%s"
      local textValue = flushExp ? ::loc("ui/parentheses/space",
        {text = ::Cost().setRp(flushExp).tostring()}) : ""
      coloredText = ::format(textSample, textValue)
    }

    foreach(navBar in [navBarObj, navBarGroupObj])
    {
      if (!::checkObj(navBar))
        continue
      local spendExpBtn = navBar.findObject("btn_spend_exp")
      if (!::checkObj(spendExpBtn))
        continue

      spendExpBtn.inactive = showSpendBtn? "no" : "yes"
      spendExpBtn.show(showSpendBtn)
      if (showSpendBtn)
        ::set_double_text_to_button(navBar, "btn_spend_exp", coloredText)
    }
  }

  function updateGroupObjNavBar()
  {
    base.updateGroupObjNavBar()
  }

  function onSpendExcessExp()
  {
    local unit = getCurAircraft(true, true)
    flushItemExp(unit, (@(unit) function() {setUnitOnResearch(unit)})(unit))
  }

  /*
  function automaticallySpendAllExcessiveExp() //!!!TEMP function, true func must be from code
  {
    updateResearchVariables()

    local afterDoneFunc = function() {
      destroyProgressBox()
      updateButtons()
      onCloseShop()
    }

    if (availableFlushExp <= 0)
      setUnitOnResearch(curResearchingUnit)

    if (!curResearchingUnit || availableFlushExp <= 0)
    {
      afterDoneFunc()
      return
    }

    flushItemExp(curResearchingUnit, automaticallySpendAllExcessiveExp)
  }
  */

  function setUnitOnResearch(unit = null, afterDoneFunc = null)
  {
    local executeAfterDoneFunc = (@(afterDoneFunc) function() {
        if (afterDoneFunc)
          afterDoneFunc()
      })(afterDoneFunc)

    if (unit && ::isUnitResearched(unit))
    {
      executeAfterDoneFunc()
      return
    }

    if (unit)
    {
      lastResearchUnit = unit
      ::researchUnit(unit, false)
    }
    else
      ::shop_reset_researchable_unit(unitCountry, unitType)
    updateButtons()
  }

  function flushItemExp(unitOnResearch, afterDoneFunc = null)
  {
    local executeAfterDoneFunc = (@(unitOnResearch, afterDoneFunc) function() {
        if (!isValid())
          return

        setResearchManually = true
        updateResearchVariables()
        fillAircraftsList()
        updateButtons()

        selectRequiredUnit()

        if (afterDoneFunc)
          afterDoneFunc()
      })(unitOnResearch, afterDoneFunc)

    if (availableFlushExp <= 0)
    {
      executeAfterDoneFunc()
      return
    }

    taskId = ::flushExcessExpToUnit(unitOnResearch.name)
    if (taskId >= 0)
    {
      ::set_char_cb(this, slotOpCb)
      afterSlotOp = executeAfterDoneFunc
      afterSlotOpError = (@(executeAfterDoneFunc) function(res) {
          executeAfterDoneFunc()
        })(executeAfterDoneFunc)
    }
  }

  function restoreFocus(checkPrimaryFocus = true)
  {
    if (!checkGroupObj())
      ::gui_handlers.BaseGuiHandlerWT.restoreFocus.call(this, checkPrimaryFocus)
  }

  function onWrapUp(obj)
  {
    ::gui_handlers.BaseGuiHandlerWT.onWrapUp.call(this, obj)
  }

  function onWrapDown(obj)
  {
    ::gui_handlers.BaseGuiHandlerWT.onWrapDown.call(this, obj)
  }

  function onCloseShop()
  {
    destroyGroupChoose()
    local curResName = ::shop_get_researchable_unit_name(unitCountry, unitType)
    if (::getTblValue("name", lastResearchUnit, "") != curResName)
      setUnitOnResearch(::getAircraftByName(curResName))

    ::gui_handlers.BaseGuiHandlerWT.goBack.call(this)
  }

  function onEventModalWndDestroy(params)
  {
    local closedHandler = ::getTblValue("handler", params, null)
    if (!closedHandler)
      return

    if (closedHandler.getclass() == ::gui_handlers.researchUnitNotification)
    {
      showResearchUnitTutorial()
      selectRequiredUnit()
      showRankRestrictionMsgBox()
    }
  }

  function afterModalDestroy()
  {
    ::checkNonApprovedResearches(true, true)
  }
}

function getSteamMarkUp()
{
  local blk = ::DataBlock()
  blk = get_discounts_blk()

  foreach(name, block in blk)
    if(name == "steam_markup")
      return block.all

  return 0
}

function checkShopBlk()
{
  local resText = ""
  local shopBlk = ::get_shop_blk()
  for (local tree = 0; tree < shopBlk.blockCount(); tree++)
  {
    local tblk = shopBlk.getBlock(tree)
    local country = tblk.getBlockName()

    for (local page = 0; page < tblk.blockCount(); page++)
    {
      local pblk = tblk.getBlock(page)
      local groups = []
      for (local range = 0; range < pblk.blockCount(); range++)
      {
        local rblk = pblk.getBlock(range)
        for (local a = 0; a < rblk.blockCount(); a++)
        {
          local airBlk = rblk.getBlock(a)
          local airName = airBlk.getBlockName()
          local air = getAircraftByName(airName)
          if (!air)
          {
            local groupTotal = airBlk.blockCount()
            if (groupTotal == 0)
            {
              resText += ((resText!="")? "\n":"") + "Not found aircraft " + airName + " in " + country
              continue
            }
            groups.append(airName)
            for(local ga=0; ga<groupTotal; ga++)
            {
              local gAirBlk = airBlk.getBlock(ga)
              air = getAircraftByName(gAirBlk.getBlockName())
              if (!air)
                resText += ((resText!="")? "\n":"") + "Not found aircraft " + gAirBlk.getBlockName() + " in " + country
            }
          } else
            if (airBlk.reqAir!=null && airBlk.reqAir!="")
            {
              local reqAir = getAircraftByName(airBlk.reqAir)
              if (!reqAir && !isInArray(airBlk.reqAir, groups))
                resText += ((resText!="")? "\n":"") + "Not found reqAir " + airBlk.reqAir + " for " + airName + " in " + country
            }
        }
      }
    }
  }
  if (resText=="")
    dagor.debug("Shop.blk checked.")
  else
    dagor.fatal("Incorrect shop.blk!\n" + resText)
}
