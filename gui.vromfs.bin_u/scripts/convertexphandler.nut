enum windowState
{
  research,
  canBuy,
  noUnit
}

function gui_modal_convertExp(unit = null, owner = null)
{
  if(unit && ::isTank(unit) && !::has_feature("SpendGoldForTanks"))
  {
    ::showInfoMsgBox(::loc("msgbox/tanksRestrictFromSpendGold"), "not_available_goldspend")
    return
  }

  ::gui_start_modal_wnd(::gui_handlers.ConvertExpHandler, {unit = unit, owner = owner})
}

class ::gui_handlers.ConvertExpHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType         = handlerType.MODAL
  sceneBlkName    = "gui/convertExp/convertExp.blk"
  owner           = null

  expPerGold      = 1
  maxGoldForAir   = 0
  curGoldValue    = 0
  minGoldValue    = 0
  maxGoldValue    = 0

  availableExp    = 0
  playersGold     = 0

  unit            = null
  unitExpGranted  = 0
  unitReqExp      = 0

  country         = ""
  countries       = null

  unitListDisplay = false
  unitList        = null
  listType        = 0
  currentState    = windowState.noUnit

  isRefreshingAfterConvert = false

  function initScreen()
  {
    if (!scene)
      return goBack()

    initCountriesList()
    updateData()

    if (availableExp < expPerGold)
    {
      goBack()
      showNoRPmsgbox()
      return
    }

    if (!unit)
      unit = getAvailableUnitForConversion()

    listType = ::get_es_unit_type(unit)
    updateWindow()

    initFocusArray()
  }

  function getMainFocusObj()
  {
    return getObj("countries_list")
  }

  function getMainFocusObj2()
  {
    return getObj("convert_slider")
  }

  function updateData()
  {
    updateUserCurrency()
    expPerGold = ::wp_get_exp_convert_exp_for_gold_rate(country) || 1

    if (currentState != windowState.noUnit)
    {
      unitExpGranted = ::getUnitExp(unit)
      unitReqExp = ::getUnitReqExp(unit)
    }
    else
    {
      unitExpGranted = 0
      unitReqExp = 0
    }
  }

  function updateUserCurrency()
  {
    availableExp = ::shop_get_free_exp()
    playersGold = max(::get_balance().gold, 0)
  }

  function getUnitList(unitType)
  {
    unitList = []
    foreach (unitForList in ::all_units)
      if (unitForList.shopCountry == country
          && ::canResearchUnit(unitForList)
          && ::get_es_unit_type(unitForList) == unitType)
        unitList.append(unitForList)
  }

  function getCurExpValue()
  {
    local expToBuy = (curGoldValue - minGoldValue) * expPerGold
    if ((expToBuy + unitExpGranted) > unitReqExp && (unitReqExp - unitExpGranted <= availableExp))
      expToBuy = unitReqExp - unitExpGranted
    return expToBuy
  }

  //----VIEW----//
  function initCountriesList()
  {
    local curValue = 0
    country = ::get_profile_country_sq()

    local view = { items = [] }
    foreach(idx, countryItem in ::shopCountriesList)
    {
      view.items.append({
        id = countryItem
        disabled = !::isCountryAvailable(countryItem)
        image = ::get_country_icon(countryItem)
        tooltip = "#" + countryItem
        discountNotification = true
        type = "box_up"
        params = "padding-left:t='0.01@scrn_tgt'; padding-right:t='0.01@scrn_tgt'"
      })

      if (country == countryItem)
        curValue = idx
    }

    local data = ::handyman.renderCached("gui/commonParts/shopFilter", view)
    local countriesObj = scene.findObject("countries_list")
    guiScene.replaceContentFromText(countriesObj, data, data.len(), this)
    countriesObj.setValue(curValue)

    foreach(c in ::shopCountriesList)
      ::showDiscount(countriesObj.findObject(c + "_discount"), "exp_to_gold_rate", c)
  }

  function fillUnitList()
  {
    if (!unitListDisplay)
      return
    local unitListBlk = ""
    local nestObj = scene.findObject("choose_unit_list")
    foreach(unitForResearch in unitList)
      unitListBlk += ::build_aircraft_item(unitForResearch.name, unitForResearch)
    guiScene.replaceContentFromText(nestObj, unitListBlk, unitListBlk.len(), this)
    foreach(unitForResearch in unitList)
      ::fill_unit_item_timers(nestObj.findObject(unitForResearch.name), unitForResearch)
  }

  function updateWindow()
  {
    if (!unit)
      currentState = windowState.noUnit
    else if (::canBuyUnit(unit) || ::isUnitResearched(unit))
      currentState = windowState.canBuy
    else
      currentState = windowState.research

    updateData()
    fillContent()
    updateButtons()
    fillUnitList()
    updateSwitchButtons()
  }

  function showConversionUnit()
  {
    if (!unit)
      return goBack()

    local unitBlk = ::build_aircraft_item(unit.name, unit)
    local unitNest = scene.findObject("unit_nest")
    guiScene.replaceContentFromText(unitNest, unitBlk, unitBlk.len(), this)
    ::fill_unit_item_timers(unitNest.findObject(unit.name), unit)
  }

  function fillFreeExp()
  {
    scene.findObject("available_exp").setValue(::g_language.decimalFormat(availableExp))
  }

  function updateSwitchButtons()
  {
    local switchTankObj = scene.findObject("switchTank")
    local switchAirObj = scene.findObject("switchAir")

    if (currentState == windowState.noUnit)
    {
      switchTankObj.show(false)
      switchAirObj.show(false)
      return
    }

    local showTank = ::has_feature("SpendGoldForTanks")
        && ::isCountryHaveUnitType(country, ::ES_UNIT_TYPE_TANK)

    local showAir =::has_feature("SpendGoldForTanks")
        && ::isCountryHaveUnitType(country, ::ES_UNIT_TYPE_AIRCRAFT)

    switchTankObj.show(showTank)
    switchAirObj.show(showAir)

    switchTankObj.enable(showTank && getCountryResearchUnit(country, ::ES_UNIT_TYPE_TANK) != null)
    switchAirObj.enable(showAir && getCountryResearchUnit(country, ::ES_UNIT_TYPE_AIRCRAFT) != null)

    switchTankObj.selected = (showTank && listType == ::ES_UNIT_TYPE_TANK) ? "yes" : "no"
    switchAirObj.selected = (showAir && listType == ::ES_UNIT_TYPE_AIRCRAFT) ? "yes" : "no"
  }

  function fillSlider()
  {
    local sliderDivObj = scene.findObject("exp_slider_nest")
    if (!::checkObj(sliderDivObj))
      return

    local is_enough_availExp = availableExp > 0
    local is_need_to_convert = (unitReqExp - unitExpGranted) > 0

    local showExpSlider = is_enough_availExp && is_need_to_convert
    sliderDivObj.show(showExpSlider)

    if (showExpSlider)
    {
      local sliderObj     = sliderDivObj.findObject("convert_slider")
      local oldProgressOb = sliderDivObj.findObject("old_exp_progress")
      local newProgressOb = sliderDivObj.findObject("new_exp_progress")

      local diffExp = unitReqExp - unitExpGranted
      local maxGoldDiff = ceil(diffExp.tofloat() / expPerGold).tointeger()
      minGoldValue  = (unitExpGranted.tofloat() / expPerGold).tointeger()
      maxGoldForAir = minGoldValue + maxGoldDiff

      local goldLimitByExp  = (availableExp >= diffExp) ? maxGoldDiff : (availableExp.tofloat() / expPerGold).tointeger()
      maxGoldValue = minGoldValue + min(goldLimitByExp, playersGold)
      curGoldValue = maxGoldValue

      sliderObj.max     = maxGoldForAir
      oldProgressOb.max = maxGoldForAir
      newProgressOb.max = maxGoldForAir

      oldProgressOb.setValue(minGoldValue)
      updateSlider()
    }
  }

  function fillUnitResearchedContent()
  {
    local noExpObj = scene.findObject("buy_unit_cost")
    if (!::checkObj(noExpObj))
      return

    local unitCost = ::wp_get_cost(unit.name)
    noExpObj.setValue(::getPriceAccordingToPlayersCurrency(unitCost, 0, true))
  }

  function updateSlider()
  {
    local sliderObj = scene.findObject("convert_slider")
    local newProgressOb = scene.findObject("new_exp_progress")
    newProgressOb.setValue(curGoldValue)
    sliderObj.setValue(curGoldValue)

    updateSliderText()
    updateExpTextPosition()
  }

  function fillContent()
  {
    scene.findObject("exp_slider_nest").show(currentState == windowState.research)
    scene.findObject("available_exp_nest").show(currentState == windowState.research)
    scene.findObject("cost_holder").show(currentState == windowState.research)
    scene.findObject("unit_researched_nest").show(currentState == windowState.canBuy)
    scene.findObject("unit_nest").show(currentState != windowState.noUnit)

    local noUnitMsgObj = scene.findObject("no_unit_nest")
    local needNoUnitText = currentState == windowState.noUnit
    noUnitMsgObj.show(needNoUnitText)
    if (needNoUnitText)
      noUnitMsgObj.setValue(::loc(getAvailableUnitForConversion() != null ? ::loc("pr_conversion/no_unit") : ::loc("pr_conversion/all_units_researched")))

    if (currentState == windowState.research)
    {
      if (availableExp > expPerGold)
      {
        fillSlider()
        fillFreeExp()
        fillCostGold()
        showConversionUnit()
      }
      else
      {
        goBack()
        if (!isRefreshingAfterConvert)
          showNoRPmsgbox()
      }
    }
    else if (currentState == windowState.canBuy)
    {
      fillUnitResearchedContent()
      showConversionUnit()
    }
  }

  function showNoRPmsgbox()
  {
    if (!::checkObj(guiScene["no_rp_msgbox"]))
      msgBox("no_rp_msgbox", ::loc("msgbox/no_rp"), [["ok", function () {}]], "ok", { cancel_fn = function() {}})
  }

  function updateSliderText()
  {
    local sliderTextObj = scene.findObject("convert_slider_text")
    local strGrantedExp = ::Cost().setRp(unitExpGranted).tostring()
    local expToBuy = getCurExpValue()
    local strWantToBuyExp = expToBuy > 0
                            ? format("<color=@activeTextColor> +%s</color>", ::Cost().setFrp(expToBuy).tostring())
                            : ""
    local strRequiredExp = ::g_language.decimalFormat(::getUnitReqExp(unit))
    local sliderText = ::format("<color=@commonTextColor>%s%s%s%s</color>", strGrantedExp, strWantToBuyExp, ::loc("ui/slash"), strRequiredExp)
    sliderTextObj.setValue(sliderText)
  }

  function fillCostGold()
  {
    local costGoldObj = scene.findObject("convertion_cost")
    costGoldObj.setValue(::g_language.decimalFormat(curGoldValue-minGoldValue))
  }

  function updateButtons()
  {
    local isMinSet = curGoldValue == minGoldValue
    local isMaxSet = curGoldValue == maxGoldValue

    showSceneBtn("btn_apply", currentState == windowState.research)
    showSceneBtn("btn_buy_unit", currentState == windowState.canBuy)
    scene.findObject("btn_apply").inactiveColor = curGoldValue != minGoldValue ? "no" : "yes"

    scene.findObject("buttonDec").enable(!isMinSet)
    scene.findObject("buttonInc").enable(!isMaxSet)
    scene.findObject("btn_max").enable(!isMaxSet)
  }

  function updateExpTextPosition()
  {
    guiScene.setUpdatesEnabled(true, true)
    local textObj     = scene.findObject("convert_slider_text")
    local boxObj      = scene.findObject("exp_slider_nest")
    local textNestObj = scene.findObject("slider_button")

    local boxPosX      = boxObj.getPos()[0]
    local boxSizeX     = boxObj.getSize()[0]

    local textSizeX     = textObj.getSize()[0]

    local textNestPosX  = textNestObj.getPos()[0]
    local textNestSizeX = textNestObj.getSize()[0]

    local overdraft = (textNestPosX + (textSizeX + textNestSizeX) / 2) - (boxPosX + boxSizeX)

    local leftEdge = textNestPosX - 0.5*textSizeX

    local newLeft = textObj.base_left
    if (leftEdge < boxPosX)
      newLeft = textObj.base_left + " + " + (boxPosX - leftEdge).tostring()
    else if (overdraft > 0)
      newLeft = textObj.base_left + " - " + (overdraft).tostring()

    textObj.left = newLeft
  }

  function updateObjects()
  {
    updateSlider()
    fillCostGold()
    updateButtons()
  }

  function toggleUnitList()
  {
    local unitListObj = scene.findObject("choose_unit_list")
    unitListDisplay = !unitListDisplay
    unitListObj.moveOut = unitListDisplay
                          ? "yes"
                          : "no"
  }
  //----END_VIEW----//

  //----CONTROLLER----//
  function onCountrySelect()
  {
    local c = scene.findObject("countries_list").getValue()
    if (!(c in ::shopCountriesList))
      return

    country = ::shopCountriesList[c]

    unit = getAvailableUnitForConversion()

    listType = ::get_es_unit_type(unit)
    updateWindow()

    //TODO: do this in updateWindow
    if (unitListDisplay)
    {
      getUnitList(::get_es_unit_type(unit))
      fillUnitList()
    }

    ::showDiscount(scene.findObject("convert-discount"), "exp_to_gold_rate", country, null, true)
  }

  function onSwithcSelectTank()
  {
    handleSwitchUnitList(::ES_UNIT_TYPE_TANK)
  }

  function onSwithcSelectAir()
  {
    handleSwitchUnitList(::ES_UNIT_TYPE_AIRCRAFT)
  }

  function handleSwitchUnitList(unitType)
  {
    if (listType == unitType && unitListDisplay)
    {
      toggleUnitList()
      updateWindow()
      return
    }

    if (!unitListDisplay)
      toggleUnitList()

    listType = unitType
    getUnitList(unitType)
    fillUnitList()
    unit = ::getCountryResearchUnit(country, unitType)
    updateWindow()
  }

  function getAvailableUnitForConversion()
  {
    local newUnit = null
    //try to get unit of same type as previous unit is
    if (::isCountryHaveUnitType(country, ::get_es_unit_type(unit)))
      newUnit = ::getCountryResearchUnit(country, ::get_es_unit_type(unit))
    if (!newUnit)
    {
      foreach (unitType in ::unitTypesList)
      {
        if (unitType == ::ES_UNIT_TYPE_TANK && !::has_feature("SpendGoldForTanks"))
          continue
        if (::isCountryHaveUnitType(country, unitType))
        {
          newUnit = ::getCountryResearchUnit(country, unitType)
          if (newUnit)
            break
        }
      }
    }
    return newUnit
  }

  function onConvertChanged(obj)
  {
    local value = obj.getValue()
    if (curGoldValue == value)
      return
    curGoldValue = min(max(minGoldValue, value), maxGoldValue)
    updateObjects()
  }

  function onButtonDec()
  {
    local value = curGoldValue - 1
    curGoldValue = min(max(minGoldValue, value), maxGoldValue)
    updateObjects()
  }

  function onButtonInc()
  {
    local value = curGoldValue + 1
    curGoldValue = min(max(minGoldValue, value), maxGoldValue)
    updateObjects()
  }

  function onMax()
  {
    curGoldValue = maxGoldValue
    updateObjects()
  }

  function onApply()
  {
    local curGold = curGoldValue - minGoldValue
    if (curGold == 0)
      return msgBox("no_exp_msgbox", ::loc("exp/convert/noGold"), [["ok", function () {}]], "ok")
    else if (availableExp < expPerGold)
      return msgBox("no_rp_msgbox", ::loc("msgbox/no_rp"), [["ok", function () {}]], "ok")

    local curExp = getCurExpValue()
    local cost = ::Cost(0, curGold)
    local msgText = ::loc("exp/convert/needMoneyQuestion",
      { exp = ::Cost().setFrp(curExp).tostring(), cost = cost })
    msgBox("need_money", msgText,
      [
        ["yes", (@(cost, curExp) function() {
            if (::check_balance_msgBox(cost))
              buyExp(curExp)
          })(cost, curExp) ],
        ["no", function() {} ]
      ], "yes", { cancel_fn = function() {}})
  }

  function buyExp(amount)
  {
    taskId = ::shop_convert_free_exp_for_unit(unit.name, amount)
    if (taskId >= 0)
    {
      ::set_char_cb(this, slotOpCb)
      showTaskProgressBox()
      afterSlotOp = function()
      {
        ::update_gamercards()
        ::broadcastEvent("ExpConvert", {unit = unit})
      }
    }
  }

  function onBuyUnit()
  {
    ::buyUnit(unit)
  }

  function onEventExpConvert(params)
  {
    isRefreshingAfterConvert = true
    updateWindow()
    isRefreshingAfterConvert = false
  }

  function onEventUnitBought(params)
  {
    local unitName = ::getTblValue("unitName", params)
    if (!unitName || unit.name != unitName)
      return

    local handler = this
    local config = {
      unit = unit
      unitObj = scene.findObject("unit_nest").findObject(unitName)
      cellClass = "slotbarClone"
      afterCloseFunc = (@(handler, unit) function() {
          if (::handlersManager.isHandlerValid(handler))
            handler.handleSwitchUnitList(::get_es_unit_type(handler.getAvailableUnitForConversion() || unit))
        })(handler, unit)
    }

    unitListDisplay = false
    ::gui_start_selecting_crew(config)
  }

  function onEventPurchaseSuccess(params)
  {
    doWhenActiveOnce("fillContent")
  }
  //----END_CONTROLLER----//
}
