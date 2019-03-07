class ::gui_handlers.ShopViewWnd extends ::gui_handlers.ShopMenuHandler
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/shop/shopCheckResearch.blk"
  sceneNavBlkName = "gui/shop/shopNav.blk"

  static function open(params)
  {
    ::handlersManager.loadHandler(::gui_handlers.ShopViewWnd, params)
  }

  function initScreen()
  {
    base.initScreen()
    initFocusArray()

    createSlotbar(
      {
        showNewSlot = true,
        showEmptySlot = true,
        showTopPanel = isSquadronResearchMode
        enableCountryList = isSquadronResearchMode
          ? ::u.filter(shopData, @(c) c?.hasSquadronUnits).map(@(c) c.name)
          : null
      },
      "slotbar_place")

    updateResearchVariables()
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
    ::gui_handlers.BaseGuiHandlerWT.goBack.call(this)
  }

  isDisabledCountry = @(countryData) isSquadronResearchMode && !countryData?.hasSquadronUnits
  isDisabledUnitTypePage = @(countryData, unitTypePage) isSquadronResearchMode
    && (!countryData?.hasSquadronUnits || !unitTypePage?.hasSquadronUnits)

  function updateButtons()
  {
    if (!isValid())
      return

    updateRepairAllButton()
    showSceneBtn("btn_back", !isSquadronResearchMode || ::clan_get_exp() == 0
      || !hasSquadronVehicleToResearche())

    local unit = getCurAircraft(true, true)
    if (!unit)
      return

    updateSpendExpBtn(unit)

    local isFakeUnit = unit?.isFakeUnit ?? false
    local canBuyIngame = !isFakeUnit && ::canBuyUnit(unit)
    local canBuyOnline = !isFakeUnit && ::canBuyUnitOnline(unit)
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
    local flushExp = min(::clan_get_exp(), ::getUnitReqExp(unit) - ::getUnitExp(unit))
    local showSpendBtn = !::isUnitGroup(unit) && isSquadronResearchMode
      && unit?.isSquadronVehicle?() && ::canResearchUnit(unit)
    local coloredText = ""

    if (showSpendBtn)
    {
      local textSample = ::loc("shop/researchUnit", { unit = ::getUnitName(unit.name) }) + "%s"
      local textValue = flushExp ? ::loc("ui/parentheses/space",
        {text = ::Cost().setSap(flushExp).tostring()}) : ""
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
      spendExpBtn.enable(showSpendBtn)
      if (showSpendBtn)
        ::set_double_text_to_button(navBar, "btn_spend_exp", coloredText)
    }
  }

  function onSpendExcessExp()
  {
    foreach(navBar in [navBarObj, navBarGroupObj])
    {
      if (!::checkObj(navBar))
        continue

      local spendExpBtn = navBar.findObject("btn_spend_exp")
      if (::checkObj(spendExpBtn))
        spendExpBtn.enable(false)
    }

    local unit = getCurAircraft(true, true)
    if (!unit?.isSquadronVehicle?() || !::canResearchUnit(unit))
      return

    local flushExp = min(::clan_get_exp(), ::getUnitReqExp(unit) - ::getUnitExp(unit))
    local canFlushExp = flushExp > 0
    local afterDoneFunc = function() {
      if (unit.isSquadronVehicle()
        && !::load_local_account_settings("has_chosen_research_of_squadron", false))
        ::save_local_account_settings("has_chosen_research_of_squadron", true)
      if(canFlushExp)
        return flushSquadronExp()
      else
        onCloseShop()
    }
    if (::isUnitInResearch(unit))
      afterDoneFunc()

    ::researchUnit(unit, true, function() {
      sendChoosedNewResearchUnitStatistic(unit)
      afterDoneFunc()
    }.bindenv(this) )
  }

 function updateResearchVariables()
  {
    if(!isSquadronResearchMode)
      return

    updateExcessExpText()
  }

  function updateExcessExpText()
  {
    local headerObj = scene.findObject("excess_exp_text")
    if (!::checkObj(headerObj))
      return

    if (!hasSquadronVehicleToResearche())
    {
      headerObj.setValue("")
      return
    }

    local flushExp = ::clan_get_exp()
    if (flushExp <= 0)
    {
      headerObj.setValue(::loc("mainmenu/nextResearchSquadronVehicle"))
      return
    }

    local expText = flushExp ? ::loc("ui/parentheses/space",
        {text = ::Balance(0, 0, 0, 0, flushExp).getTextAccordingToBalance()}) : ""
    expText = ::loc("shop/distributeSquadronExp") + expText

    headerObj.setValue(expText)
  }
}