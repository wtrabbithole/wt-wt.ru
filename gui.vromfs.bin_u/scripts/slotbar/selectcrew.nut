function gui_start_selecting_crew(config)
{
  if (::CrewTakeUnitProcess.safeInterrupt())
    ::handlersManager.destroyPrevHandlerAndLoadNew(::gui_handlers.SelectCrew, config)
}

class ::gui_handlers.SelectCrew extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/shop/shopTakeAircraft.blk"

  unit = null
  unitObj = null
  cellClass = "slotbarClone"
  getEdiffFunc = null
  afterCloseFunc = null
  afterSuccessFunc = null

  useTutorial = false

  restrictCancel = false

  country = ""
  messageText = ""

  takeCrewIdInCountry = -1

  focusArray = [
    function() { return slotbarWeak && slotbarWeak.getFocusObj() }   // slotbar
  ]

  function initScreen()
  {
    if (!unit || !unit.isUsable() || ::isUnitInSlotbar(unit) || !::checkObj(unitObj))
    {
      goBack()
      return
    }

    country = ::getUnitCountry(unit)
    checkAvailableCrew()

    guiScene.setUpdatesEnabled(false, false)

    local tdObj = unitObj.getParent()
    local tdPos = tdObj.getPosRC()

    ::gui_handlers.ActionsList.removeActionsListFromObject(tdObj)

    local tdClone = tdObj.getClone(scene, this)
    local tdSize = tdObj.getSize()
    tdClone.pos = tdPos[0] + ", " + tdPos[1]
    tdClone["class"] = cellClass
    tdClone.position = "root"
    ::fill_unit_item_timers(tdClone.findObject(unit.name), unit)

    if (!::has_feature("GlobalShowBattleRating") && ::has_feature("SlotbarShowBattleRating"))
    {
      local rankObj = tdClone.findObject("rank_text")
      if (::checkObj(rankObj))
      {
        local unitRankText = ::get_unit_rank_text(unit, null, true, getCurrentEdiff())
        rankObj.setValue(unitRankText)
      }
    }

    local bDiv = tdClone.findObject("air_action_button")
    if (::checkObj(bDiv))
      guiScene.destroyElement(bDiv)

    local crew = ::get_crews_list_by_country(country)?[takeCrewIdInCountry]
    createSlotbar(
      {
        crewId = crew?.id
        shouldSelectCrewRecruit =  takeCrewIdInCountry > 0 && !crew
        singleCountry = country
        hasActions = false
        showNewSlot = true,
        showEmptySlot = true,
        needActionsWithEmptyCrews = false
        unitForSpecType = unit,
        alwaysShowBorder = true

        afterSlotbarSelect = onChangeUnit
        onSlotDblClick = onApplyCrew
      },
      "take-aircraft-slotbar")

    onChangeUnit()

    local legendObj = fillLegendData()

    local airTblObj = slotbarWeak && slotbarWeak.getCurrentAirsTable()
    if (::checkObj(airTblObj))
      airTblObj.select()

    local textObj = scene.findObject("take-aircraft-text")
    textObj.setValue(messageText)

    guiScene.setUpdatesEnabled(true, true)

    updateObjectsPositions(tdClone, legendObj, textObj)
    checkUseTutorial()
    delayedRestoreFocus()
  }

  function updateObjectsPositions(tdClone, legendObj, headerObj)
  {
    local rootSize = guiScene.getRoot().getSize()
    local sh = rootSize[1]
    local bh = ::g_dagui_utils.toPixels(guiScene, "@bh")
    local interval = ::g_dagui_utils.toPixels(guiScene, "@itemsIntervalBig")

    //count position by visual card obj. real td is higher and wider than a card.
    local visTdObj = tdClone.childrenCount() ? tdClone.getChild(0) : tdClone
    local tdPos = visTdObj.getPosRC()
    local tdSize = visTdObj.getSize()

    //top and bottom of already positioned items
    local top = tdPos[1]
    local bottom = tdPos[1] + tdSize[1]

    //place slotbar
    local sbObj = scene.findObject("slotbar_with_buttons")
    local sbSize = sbObj.getSize()
    local isSlotbarOnTop = bottom + interval + sbSize[1] > sh - bh
    local sbPosY = 0
    if (isSlotbarOnTop)
    {
      sbPosY = top - interval - sbSize[1]
      top = sbPosY
    } else
    {
      sbPosY = bottom + interval
      bottom = sbPosY + sbSize[1]
    }
    sbObj.top = sbPosY

    //place legend
    if (::checkObj(legendObj))
    {
      local legendSize = legendObj.getSize()

      //try to put legend near unit td, but below slotbar when possible
      local isNearTd = false
      local bottomNoTd = bottom
      if (tdPos[1] + tdSize[1] == bottom)
      {
        bottomNoTd = tdPos[1] - interval
        isNearTd = true
      }

      local isLegendBottom = bottomNoTd + interval + legendSize[1] <= sh - bh
      local legendPosY = 0
      if (isLegendBottom)
      {
        legendPosY = bottomNoTd + interval
        bottom = ::max(legendPosY + legendSize[1], bottom)
      } else
      {
        isNearTd = tdPos[1] == top
        local topNoTd = isNearTd ? tdPos[1] + tdSize[1] + interval : top
        legendPosY = topNoTd - interval - legendSize[1]
        top = ::min(legendPosY, top)
      }

      legendObj.top = legendPosY

      if (isNearTd) //else centered.
      {
        local sw = rootSize[0]
        local bw = ::g_dagui_utils.toPixels(guiScene, "@bw")
        local legendPosX = tdPos[0] + tdSize[0] + interval
        if (legendPosX + legendSize[0] > sw - bw)
          legendPosX = tdPos[0] - interval - legendSize[0]
        legendObj.left = legendPosX
      }
    }

    //place headerMessage
    local headerPosY = top - interval - headerObj.getSize()[1]
    headerObj.top = headerPosY
    top = headerPosY
  }

  function checkAvailableCrew()
  {
    if (takeCrewIdInCountry >= 0)
      return

    takeCrewIdInCountry = ::g_crew.getBestTrainedCrewIdxForUnit(unit, true)
    if (takeCrewIdInCountry >= 0)
      return

    takeCrewIdInCountry = ::get_first_empty_crew_slot()
    if (takeCrewIdInCountry >= 0)
      return

    local costTable = ::get_crew_slot_cost(country)
    if (!costTable)
      return

    local cost = ::Cost(costTable.cost, costTable.costGold)
    if (cost.gold > 0)
      return

    takeCrewIdInCountry = cost <= ::get_gui_balance()? ::get_crew_count(country) : takeCrewIdInCountry
  }

  function getCurrentEdiff()
  {
    return ::u.isFunction(getEdiffFunc) ? getEdiffFunc() : ::get_current_ediff()
  }

  function getTakeAirCost()
  {
    return ::CrewTakeUnitProcess.getProcessCost(
             getCurCrew(),
             unit
           )
  }

  function onChangeUnit()
  {
    takeCrewIdInCountry = getCurCrew()?.idInCountry ?? ::get_crew_count(country)
    updateButtons()
  }

  function updateButtons()
  {
    ::placePriceTextToButton(scene, "btn_set_air", ::loc("mainmenu/btnTakeAircraft"), getTakeAirCost())
  }

  function onEventOnlineShopPurchaseSuccessful(p)
  {
    updateButtons()
  }

  function checkUseTutorial()
  {
    if (useTutorial)
      startTutorial()
  }

  function startTutorial()
  {
    local playerBalance = ::Cost()
    local playerInfo = ::get_profile_info()
    playerBalance.wp = playerInfo.balance
    playerBalance.gold = playerInfo.gold

    restrictCancel = getTakeAirCost() < playerBalance
    showSceneBtn("btn_set_cancel", !restrictCancel)

    guiScene.applyPendingChanges(false)
    local steps = [
      {
        obj = getSlotbar() && getSlotbar().getBoxOfUnits()
        text = ::loc("help/takeAircraft", {unitName = ::getUnitName(unit)})
        bottomTextLocIdArray = ["help/NEXT_ACTION"]
        actionType = tutorAction.ANY_CLICK
        haveArrow = false
        accessKey = "J:A"
      },
      {
        obj = "btn_set_air"
        text = ::loc("help/pressOnReady")
        bottomTextLocIdArray = ["help/NEXT_ACTION"]
        actionType = tutorAction.ANY_CLICK
        accessKey = "J:A"
      }
    ]

    ::gui_modal_tutor(steps, this)
  }

  function onApply()
  {
    onApplyCrew(getCurCrew())
  }

  function onApplyCrew(crew)
  {
    ::CrewTakeUnitProcess(crew, unit, ::Callback(onTakeProcessFinish, this))
  }

  function onTakeProcessFinish(isSuccess)
  {
    if (!isSuccess)
      return

    if (afterSuccessFunc)
      afterSuccessFunc()
    goBack()
  }

  function onEventSetInQueue(params)
  {
    local reqMoneyMsg = scene.findObject("need_money")
    if (::checkObj(reqMoneyMsg))
      guiScene.destroyObject(reqMoneyMsg)

    local noMoneyMsg = scene.findObject("no_money")
    if (::checkObj(noMoneyMsg))
      guiScene.destroyObject(noMoneyMsg)

    goBack()
  }

  function onTakeCancel()
  {
    if (restrictCancel)
      return

    goBack()
  }

  function addLegendData(result, specType)
  {
    foreach(data in result)
      if (specType == data.specType)
        return

    result.append({
      id = specType.specName,
      specType = specType,
      imagePath = specType.trainedIcon,
      locId = ::loc("crew/trained") + ::loc("ui/colon") + specType.getName()
    })
  }

  function fillLegendData()
  {
    local legendData = []
    foreach (idx, crew in ::get_crews_list_by_country(country))
    {
      local specType = ::g_crew_spec_type.getTypeByCode(::g_crew_spec_type.getTrainedSpecCode(crew, unit))
      if (specType != ::g_crew_spec_type.UNKNOWN)
        addLegendData(legendData, specType)
    }

    if (::u.isEmpty(legendData))
      return null

    legendData.sort(function(a, b) {
      if (a.specType.code != b.specType.code)
        return a.specType.code > b.specType.code? 1 : -1
      return 0
    })

    local view = {
      header = ::loc("mainmenu/legend") + ::loc("ui/colon") + ::colorize("userlogColoredText", ::getUnitName(unit, false))
      haveLegend = legendData.len() > 0
      legendData = legendData
    }

    local obj = scene.findObject("qualification_legend")
    if (!::checkObj(obj))
      return null

    local blk = ::handyman.renderCached("gui/slotbar/legend_block", view)
    guiScene.replaceContentFromText(obj, blk, blk.len(), this)

    return obj
  }

  function onDestroy()
  {
    if (afterCloseFunc)
      afterCloseFunc()
  }

  function onUnitMainFunc(obj) {}
}
