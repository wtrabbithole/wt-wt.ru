function gui_modal_crew(countryId, idInCountry, showTutorial = false)
{
  if (::has_feature("CrewSkills"))
  {
    local params = {
      countryId = countryId
      idInCountry = idInCountry
      showTutorial = showTutorial
    }
    ::gui_start_modal_wnd(::gui_handlers.CrewModalHandler, params)
  }
  else
    ::showInfoMsgBox(::loc("msgbox/notAvailbleYet"))
}

class ::gui_handlers.CrewModalHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/crew/crew.blk"

  slotbarActions = ["aircraft", "weapons", "showroom", "repair" ]

  countryId = -1
  idInCountry = -1
  showTutorial = false
  crew = null
  curUnitType = ::ES_UNIT_TYPE_INVALID
  curPage = 0
  curPageId = null
  pageBonuses = 0

  pages = null
  airList = null

  crewCurLevel = 0
  crewLevelInc = 0
  curPoints = 0

  discountInfo = null

  afterApplyAction = null
  updateAfterApplyAction = true

  unitSpecHandler = null
  skillsPageHandler = null

  function initScreen()
  {
    if (!scene)
      return goBack()
    crew = getSlotItem(countryId, idInCountry)
    if (!crew)
      return goBack()

    initMainParams(true, true)
    ::init_slotbar(this, scene.findObject("nav-help"), true, null,
                    { showNewSlot=false,
                      emptyText="#shop/aircraftNotSelected",
                      crewId = crew.id
                    })
    if (slotbarParams)
      delete slotbarParams.crewId //it need only to correct init slotbar, but no need on reinit it.

    initFocusArray()

    if (showTutorial)
      onUpgrCrewSkillsTutorial()
  }

  function getMainFocusObj()
  {
    return getObj("skills_table")
  }

  function getMainFocusObj2()
  {
    return getObj("specs_table")
  }

  function getMainFocusObj3()
  {
    return getObj("rb_unit_type")
  }

  function updateCrewInfo()
  {
    local infoText = ""
    local air = ::g_crew.getCrewUnit(crew)
    if (curUnitType == ::ES_UNIT_TYPE_AIRCRAFT && air && !::isTank(air))
        infoText = ::loc("crew/numGunners") + ::loc("ui/colon") + air.gunnersCount
    scene.findObject("crew-info-text").setValue(infoText)
  }

  function initMainParams(reloadSkills=true, reinitUnitType = false)
  {
    if (!::checkObj(scene))
      return

    local unitType = reinitUnitType? (::get_es_unit_type(::g_crew.getCrewUnit(crew))
                                      || ::ES_UNIT_TYPE_AIRCRAFT)
                                     : curUnitType

    curUnitType = unitType

    ::update_gamercards()
    if (reloadSkills)
      ::load_crew_skills()
    countSkills()

    scene.findObject("crew_name").setValue(::g_crew.getCrewName(crew))

    updateUnitTypeRadioButtons()
  }

  function countSkills()
  {
    curPoints = ("skillPoints" in crew)? crew.skillPoints : 0
    crewCurLevel = ::g_crew.getCrewLevel(crew, curUnitType)
    crewLevelInc = ::g_crew.getCrewLevel(crew, curUnitType, true) - crewCurLevel
    foreach(page in ::crew_skills)
      foreach(item in page.items)
      {
        local value = getSkillValue(page.id, item.name)
        local newValue = ::getTblValue("newValue", item, value)
        if (newValue > value)
          curPoints -= ::g_crew.getSkillCost(item, newValue, value)
      }
    scene.findObject("crew_cur_skills").setValue(::round_by_value(crewCurLevel, 0.01).tostring())
    updatePointsText()
    updateBuyAllButton()
    updateAvailableSkillsIcons()
  }

  function onSkillRowChange(item, newValue)
  {
    local wasValue = ::g_crew.getSkillNewValue(item, crew)
    local changeCost = ::g_crew.getSkillCost(item, newValue, wasValue)
    local crewLevelChange = ::g_crew.getSkillCrewLevel(item, newValue, wasValue)
    item.newValue <- newValue //!!FIX ME: this code must be in g_crew too
    curPoints -= changeCost
    crewLevelInc += crewLevelChange

    updatePointsText()
    updateBuyAllButton()
    updatePointsAdvice()
    updateAvailableSkillsIcons()
    ::broadcastEvent("CrewNewSkillsChanged", { crew = crew })
  }

  function getCurCountryName()
  {
    return ::g_crews_list.get()[countryId].country
  }

  function updateUnitTypeRadioButtons()
  {
    local rbObj = scene.findObject("rb_unit_type")
    if (!::checkObj(rbObj))
      return

    local data = ""
    foreach(unitType in ::g_unit_type.types)
    {
      if (!unitType.isVisibleInShop())
        continue

      local esUnitType = unitType.esUnitType
      if (!::isCountryHaveUnitType(getCurCountryName(), esUnitType))
        continue

      data += ::format("RadioButton { id:t='%s'; text:t='%s'; %s RadioButtonImg{} }",
                     "unit_type_" + esUnitType,
                     unitType.getLocName(),
                     curUnitType == esUnitType ? "selected:t='yes';" : "")
    }
    guiScene.replaceContentFromText(rbObj, data, data.len(), this)
    delayedRestoreFocus()
    updateUnitType()
  }

  function updateUnitType()
  {
    countSkills()
    updateCrewInfo()
    initPages()
  }

  function initPages()
  {
    updateDiscountInfo()

    pages = []
    foreach(page in ::crew_skills)
      if (page.isVisible(curUnitType))
        pages.append(page)
    pages.append({ id = "trained" })

    local maxDiscount = ::g_crew.getMaxDiscountByInfo(discountInfo, false)
    local discountText = maxDiscount > 0? ("-" + maxDiscount + "%") : ""
    local discountTooltip = ::g_string.stripTags(::g_crew.getDiscountsTooltipByInfo(discountInfo, false))

    curPage = 0


    local view = {
      tabs = []
    }
    foreach(index, page in pages)
    {
      if (page.id == curPageId)
        curPage = index

      local tabData = {
        id = page.id
        tabName = "#crew/"+ page.id
        navImagesText = ::get_navigation_images_text(index, pages.len())
      }

      if (isSkillsPage(page))
        tabData.cornerImg <- {
          cornerImg = ""
          cornerImgId = getCornerImgId(page)
        }
      else if (page.id == "trained")
        tabData.discount <- {
          text = discountText
          tooltip = discountTooltip
        }

      view.tabs.push(tabData)
    }
    local data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    local pagesObj = scene.findObject("crew_pages_list")
    guiScene.replaceContentFromText(pagesObj, data, data.len(), this)

    pagesObj.setValue(curPage)
    onCrewPage(pagesObj)
    updateAvailableSkillsIcons()
  }

  function onChangeUnitType(obj)
  {
    curUnitType = obj.getValue()
    updateUnitType()
  }

  function onCrewPage(obj)
  {
    if (!obj)
      return
    local value = obj.getValue()
    if (value in pages)
    {
      curPage = value
      curPageId = obj.getChild(value).id
      fillPage()
    }
  }

  function getCrewSkillTooltipLocId(skillName, pageName)
  {
    return "crew/" + pageName + "/" + skillName + "/tooltip"
  }

  function isSkillsPage(page)
  {
    return "items" in page
  }

  function fillPage()
  {
    local page = pages[curPage]
    guiScene.setUpdatesEnabled(false, false)
    if (isSkillsPage(page))
      skillsPageHandler = ::g_crew.createCrewSkillsPageHandler(scene, this, crew)
    else if (page.id=="trained")
      unitSpecHandler = ::g_crew.createCrewUnitSpecHandler(scene)
    updatePage()
    guiScene.setUpdatesEnabled(true, true)
  }

  function getSkillValue(crewType, skillName)
  {
    return ::g_crew.getSkillValue(crew.id, crewType, skillName)
  }

  function updatePointsText()
  {
    local isMaxLevel = ::g_crew.isCrewMaxLevel(crew, getCurCountryName(), curUnitType)
    local curPointsText = ::nbsp + ::get_crew_sp_text(curPoints)
    scene.findObject("crew_cur_points").setValue(isMaxLevel ? "" : curPointsText)

    local levelIncText = ""
    local levelIncTooltip = ::loc("crew/usedSkills/tooltip")
    if (isMaxLevel)
    {
      levelIncText = ::loc("ui/parentheses/space", { text = ::loc("options/quality_max") })
      levelIncTooltip += "\n" + ::loc("crew/availablePoints") + curPointsText
    }
    else if (crewLevelInc > 0.005)
      levelIncText = "+" + ::round_by_value(crewLevelInc, 0.01)

    scene.findObject("crew_new_skills").setValue(levelIncText)
    scene.findObject("crew_level_block").tooltip = levelIncTooltip
    scene.findObject("btn_apply").enable(crewLevelInc > 0)
    showSceneBtn("crew_cur_points_block", !isMaxLevel)
    showSceneBtn("btn_buy", ::has_feature("SpendGold") && !isMaxLevel)
  }

  function updatePointsAdvice()
  {
    local page = pages[curPage]
    local isSkills = isSkillsPage(page)
    scene.findObject("crew_points_advice_block").show(isSkills)
    if (!isSkills)
      return
    local statusType = ::g_skills_page_status.getPageStatus(crew, page, curUnitType, curPoints)
    scene.findObject("crew_points_advice").show(statusType.show)
    scene.findObject("crew_points_advice_text")["crewStatus"] = statusType.style
  }

  function updateBuyAllButton()
  {
    if (!::has_feature("CrewBuyAllSkills"))
      return

    local totalPointsToMax = ::g_crew.getSkillPointsToMaxAllSkills(crew, curUnitType)
    local btnObj = showSceneBtn("btn_buy_all", totalPointsToMax > 0)
    local text = ::loc("mainmenu/btnBuyAll") + ::loc("ui/parentheses/space", { text = ::get_crew_sp_text(totalPointsToMax) })
    ::set_double_text_to_button(scene, "btn_buy_all", text)
  }

  function onBuyAll()
  {
    ::g_crew.buyAllSkills(crew, curUnitType)
  }

  function getCornerImgId(page)
  {
    return page.id + "_available"
  }

  function updateAvailableSkillsIcons()
  {
    if (!pages)
      return

    guiScene.setUpdatesEnabled(false, false)
    local pagesObj = scene.findObject("crew_pages_list")
    foreach(page in pages)
    {
      if (!isSkillsPage(page))
        continue
      local obj = pagesObj.findObject(getCornerImgId(page))
      if (!::checkObj(obj))
        continue

      local statusType = ::g_skills_page_status.getPageStatus(crew, page, curUnitType, curPoints)
      obj["background-image"] = statusType.icon
      obj["background-color"] = guiScene.getConstantValue(statusType.color) || ""
      obj.wink = statusType.wink ? "yes" : "no"
      obj.show(statusType.show)
    }
    guiScene.setUpdatesEnabled(true, true)
  }

  function updateDiscountInfo()
  {
    discountInfo = ::g_crew.getDiscountInfo(countryId, idInCountry)
    updateAirList()

    local obj = scene.findObject("buyPoints_discount")
    local buyPointsDiscount = ::getTblValue("buyPoints", discountInfo, 0)
    ::showCurBonus(obj, buyPointsDiscount, "buyPoints", true, true)
  }

  function updateAirList()
  {
    airList = []
    if (!("trainedSpec" in crew))
      return

    local sortData = [] // { unit, locname }
    foreach(unit in ::all_units)
      if (unit.name in crew.trainedSpec && ::get_es_unit_type(unit) == curUnitType)
      {
        local isCurrent = ::getTblValue("aircraft", crew, "") == unit.name
        if (isCurrent)
          airList.append(unit)
        else
        {
          sortData.append({
            unit = unit
            locname = ::english_russian_to_lower_case(::getUnitName(unit))
          })
        }
      }

    sortData.sort(function(a,b)
    {
      return a.locname > b.locname ? 1 : (a.locname < b.locname ? -1 : 0)
    })

    foreach(data in sortData)
      airList.append(data.unit)
  }

  function updatePage()
  {
    local page = pages[curPage]
    if (isSkillsPage(page))
    {
      if (unitSpecHandler != null)
        unitSpecHandler.setHandlerVisible(false)
      if (skillsPageHandler != null)
      {
        skillsPageHandler.setHandlerVisible(true)
        skillsPageHandler.updateHandlerData()
      }
    }
    else if (page.id=="trained")
    {
      if (skillsPageHandler != null)
        skillsPageHandler.setHandlerVisible(false)
      if (unitSpecHandler != null)
      {
        unitSpecHandler.setHandlerVisible(true)
        unitSpecHandler.setHandlerData(crew, crewCurLevel, airList, curUnitType)
      }
    }
    updatePointsAdvice()
    updateUnitTypeWarning(isSkillsPage(page))
    restoreFocus()
  }

  function updateUnitTypeWarning(skillsVisible)
  {
    local show = false
    if (skillsVisible)
    {
      local unit = ::g_crew.getCrewUnit(crew)
      show = unit != null && ::get_es_unit_type(unit) != curUnitType
    }
    scene.findObject("skills_unit_type_warning").show(show)
  }

  function onButtonRowApply(obj)
  {
    if (::handlersManager.isHandlerValid(unitSpecHandler) && unitSpecHandler.isHandlerVisible)
      unitSpecHandler.applyRowButton(obj)
  }

  function onBuyPoints()
  {
    if (!::checkObj(scene))
      return

    updateDiscountInfo()
    ::g_crew.createCrewBuyPointsHandler(crew)
  }

  function goBack()
  {
    checkSkillPointsAndDo(base.goBack)
  }

  function onEventSetInQueue(params)
  {
    base.goBack()
  }

  function onApply()
  {
    if (progressBox)
      return

    local blk = ::DataBlock()

    foreach(page in ::crew_skills)
      if (isSkillsPage(page))
      {
        local typeBlk = ::DataBlock()
        foreach(idx, item in page.items)
          if ("newValue" in item)
          {
            local value = getSkillValue(page.id, item.name)
            if (value<item.newValue)
              typeBlk[item.name] = item.newValue-value
          }
        blk[page.id] = typeBlk
      }

    local curHandler = this //to prevent handler destroy even when invalid.
    local isTaskCreated = ::g_tasker.addTask(
      ::shop_upgrade_crew(crew.id, blk),
      { showProgressBox = true },
      function()
      {
        ::broadcastEvent("CrewSkillsChanged", { crew = curHandler.crew })
        if (curHandler.isValid() && curHandler.afterApplyAction)
        {
          curHandler.afterApplyAction()
          curHandler.afterApplyAction = null
        }
        ::g_crews_list.flushSlotbarUpdate()
      },
      @(err) ::g_crews_list.flushSlotbarUpdate()
    )

    if (isTaskCreated)
      ::g_crews_list.suspendSlotbarUpdates()
  }

  function onSelect()
  {
    onApply()
  }

  function checkSkillPointsAndDo(action, cancelAction = function() {}, updateAfterApply = true)
  {
    local crewPoints = ::getTblValue("skillPoints", crew, 0)
    if (curPoints == crewPoints || skipCheckAirSelect)
      return action()

    local msgOptions = [
      ["yes", (@(action, updateAfterApply) function() {
        afterApplyAction = action
        updateAfterApplyAction = updateAfterApply
        onApply()
      })(action, updateAfterApply)],
      ["no", action]
    ]

    msgBox("applySkills", ::loc("crew/applySkills"), msgOptions, "yes", { cancel_fn = cancelAction })
  }

  function baseGoForward(startFunc, needFade)
  {
    base.goForward(startFunc, needFade)
  }

  function goForward(startFunc, needFade=true)
  {
    checkSkillPointsAndDo(::Callback(@() baseGoForward(startFunc, needFade), this))
  }

  function onShop(obj)
  {
    checkSkillPointsAndDo(::gui_start_menuShop)
  }

  function onSlotbarDblClick(obj)
  {
    checkSkillPointsAndDo(base.onSlotbarDblClick)
  }

  function onSlotbarSelectAction(obj)
  {
    if (!obj || ::slotbar_oninit)
      return

    local tblId = obj.id
    if ((tblId.len() <= 11) || (tblId.slice(0, 11) != "airs_table_"))
      return

    curSlotCountryId = tblId.slice(11).tointeger()

    local curCol = obj.cur_col.tointeger()
    local trObj = obj.getChild(0)
    if (curCol < 0 || curCol >= trObj.childrenCount())
      return
    local curTdId = trObj.getChild(curCol).id
    local newSlotId = getSlotIdByObjId(curTdId, curSlotCountryId)
    if (newSlotId < 0)
      return
    curSlotIdInCountry = newSlotId

    local newCrew = getSlotItem(curSlotCountryId, curSlotIdInCountry)
    if (!newCrew || newCrew.id==crew.id)
      return

    ignoreCheckSlotbar = true
    checkSkillPointsAndDo(function() {
      ignoreCheckSlotbar = false
      openSelectedCrew()
    },
    function() {
      ignoreCheckSlotbar = false
      checkSlotbar()
    })
  }

  function beforeSlotbarChange(action, cancelAction)
  {
    checkSkillPointsAndDo(action, cancelAction)
  }

  function openSelectedCrew()
  {
    crew = getSlotItem(curSlotCountryId, curSlotIdInCountry)
    if (crew)
    {
      countryId = curSlotCountryId
      idInCountry = curSlotIdInCountry
    } else
      crew = getSlotItem(countryId, idInCountry)
    initMainParams(true, true)
    if (crew)
      if ("aircraft" in crew)
      {
        showAircraft(crew.aircraft)
        ::select_crew(curSlotCountryId, curSlotIdInCountry)
      } else
        onSlotChangeAircraft(null)
  }

  function reinitSlotbarAction()
  {
    base.reinitSlotbarAction()

    if (countryId != curSlotCountryId || idInCountry != curSlotIdInCountry)
      openSelectedCrew()
  }

  function onUpgrCrewSkillsTutorial()
  {
    local steps = [
      {
        obj = ["crew_cur_points_block"]
        text = ::loc("tutorials/upg_crew/total_skill_points")
        bottomTextLocIdArray = ["help/NEXT_ACTION"]
        actionType = tutorAction.ANY_CLICK
        accessKey = "J:A"
      },
      {
        obj = [["crew_pages_list", "driver_available"]]
        text = ::loc("tutorials/upg_crew/skill_groups")
        bottomTextLocIdArray = ["help/NEXT_ACTION"]
        actionType = tutorAction.ANY_CLICK
        accessKey = "J:A"
      },
      {
        obj = [getObj("skill_row0").findObject("incCost"), "skill_row0"]
        text = ::loc("tutorials/upg_crew/take_skill_points")
        bottomTextLocIdArray = ["help/NEXT_ACTION"]
        actionType = tutorAction.ANY_CLICK
        accessKey = "J:A"
      },
      {
        obj = [getObj("skill_row0").findObject("buttonInc"), "skill_row0"]
        text = ::loc("tutorials/upg_crew/inc_skills")
        actionType = tutorAction.FIRST_OBJ_CLICK
        accessKey = "J:A"
        cb = function()
        {
          onButtonInc(getObj("skill_row0").findObject("buttonInc"))
        }
      },
      {
        obj = [getObj("skill_row1").findObject("buttonInc"), "skill_row1"]
        text = ::loc("tutorials/upg_crew/inc_skills")
        actionType = tutorAction.FIRST_OBJ_CLICK
        accessKey = "J:A"
        cb = function()
        {
          onButtonInc(getObj("skill_row1").findObject("buttonInc"))
        }
      },
      {
        obj = ["btn_apply"]
        text = ::loc("tutorials/upg_crew/apply_upgr_skills")
        actionType = tutorAction.OBJ_CLICK
        accessKey = "J:A"
        cb = function()
        {
          onApply()
          local unit = ::g_crew.getCrewUnit(crew)
          local unitType = ::get_es_unit_type(unit)
          local curSpecType = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, unit)
          local wpSpecCost = curSpecType.getUpgradeCostByCrewAndByUnit(crew, unit)
          local reqLevel = curSpecType.getUpgradeReqCrewLevel(unit)
          local crewLevel = ::g_crew.getCrewLevel(crew, unitType)
          if (::get_cur_warpoints() < wpSpecCost.wp ||
              curSpecType != ::g_crew_spec_type.BASIC ||
              crewLevel >= reqLevel)
            onUpgrCrewTutorFinalStep()
          else
            onUpgrCrewSpec1Tutorial()
        }
      }
    ]
    ::gui_modal_tutor(steps, this)
  }

  function onUpgrCrewSpec1Tutorial()
  {
    local steps = [
      {
        obj = [getObj("skill_row0").findObject("btn_spec1"), "skill_row0"]
        text = ::loc("tutorials/upg_crew/spec1")
        actionType = tutorAction.FIRST_OBJ_CLICK
        accessKey = "J:A"
        cb = onUpgrCrewSpec1ConfirmTutorial
      }
    ]
    ::gui_modal_tutor(steps, this)
  }

  function onUpgrCrewSpec1ConfirmTutorial()
  {
    ::g_crew.upgradeUnitSpec(crew, ::g_crew.getCrewUnit(crew), null, ::g_crew_spec_type.EXPERT)

    if (::scene_msg_boxes_list.len() == 0)
    {
      local curUnit = ::g_crew.getCrewUnit(crew)
      local curSpec = ::g_crew_spec_type.getTypeByCrewAndUnit(crew, curUnit)
      local message = ::format("Error: Empty MessageBox List for userId = %s\ncountry = %s" +
                               "\nidInCountry = %s\nunitname = %s\nspecCode = %s",
                               ::my_user_id_str,
                               crew.country,
                               crew.idInCountry.tostring(),
                               curUnit.name,
                               curSpec.code.tostring())
      ::script_net_assert_once("empty scene_msg_boxes_list", message)
      onUpgrCrewTutorFinalStep()
      return
    }

    local specMsgBox = ::scene_msg_boxes_list.top()
    local steps = [
      {
        obj = [specMsgBox.findObject("yes"), specMsgBox.findObject("msgText")]
        text = ::loc("tutorials/upg_crew/confirm_spec1")
        actionType = tutorAction.FIRST_OBJ_CLICK
        accessKey = "J:A"
        cb = (@(specMsgBox) function() {
          ::destroyMsgBox(specMsgBox)
          ::g_crew._upgradeUnitSpec(crew, ::g_crew.getCrewUnit(crew), 1)
          onUpgrCrewTutorFinalStep()
        })(specMsgBox)
      }
    ]
    ::gui_modal_tutor(steps, this)
  }

  function onUpgrCrewTutorFinalStep()
  {
    local steps = [
      {
        text = ::loc("tutorials/upg_crew/final_massage")
        bottomTextLocIdArray = ["help/NEXT_ACTION"]
        actionType = tutorAction.ANY_CLICK
        accessKey = "J:A"
      }
    ]
    ::gui_modal_tutor(steps, this)
  }

  function onEventCrewSkillsChanged(params)
  {
    base.onEventCrewSkillsChanged(params)
    crew = getSlotItem(countryId, idInCountry)
    initMainParams(!::getTblValue("isOnlyPointsChanged", params, false))
  }

  /** Triggered from CrewUnitSpecHandler. */
  function onEventQualificationIncreased(params)
  {
    base.onEventQualificationIncreased(params)
    crew = getSlotItem(countryId, idInCountry)
    initMainParams()
    updatePage()
  }

  function onEventCrewTakeUnit(p)
  {
    crew = getSlotItem(countryId, idInCountry)
    initMainParams(false, true)
    updatePage()
  }

  function onButtonInc(obj)
  {
    if (::handlersManager.isHandlerValid(skillsPageHandler) && skillsPageHandler.isHandlerVisible)
      skillsPageHandler.onButtonInc(obj)
  }

  function onButtonIncRepeat(obj)
  {
    if (::handlersManager.isHandlerValid(skillsPageHandler) && skillsPageHandler.isHandlerVisible)
      skillsPageHandler.onButtonIncRepeat(obj)
  }

  function onButtonDec(obj)
  {
    if (::handlersManager.isHandlerValid(skillsPageHandler) && skillsPageHandler.isHandlerVisible)
      skillsPageHandler.onButtonDec(obj)
  }

  function onButtonDecRepeat(obj)
  {
    if (::handlersManager.isHandlerValid(skillsPageHandler) && skillsPageHandler.isHandlerVisible)
      skillsPageHandler.onButtonDecRepeat(obj)
  }

  function getCurPage()
  {
    return pages[curPage]
  }

  function getCrewLevel()
  {
    return crewCurLevel
  }
}
