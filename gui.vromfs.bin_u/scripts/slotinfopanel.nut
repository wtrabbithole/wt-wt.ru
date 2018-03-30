const SLOT_INFO_CFG_SAVE_PATH = "show_slot_info_panel_tab"

function create_slot_info_panel(parent_scene, show_tabs, configSaveId)
{
  if (!::checkObj(parent_scene))
    return null
  local containerObj = parent_scene.findObject("slot_info")
  if (!::checkObj(containerObj))
    return null
  local params = {
    scene = containerObj
    showTabs = show_tabs
    configSavePath = SLOT_INFO_CFG_SAVE_PATH + "/" + configSaveId
  }
  return ::handlersManager.loadHandler(::gui_handlers.SlotInfoPanel, params)
}

class ::gui_handlers.SlotInfoPanel extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "gui/slotInfoPanel.blk"
  showTabs = false
  configSavePath = ""
  isSceneForceHidden = false
  listboxObj = null

  tabsInfo = [
      {
        tooltip = "#slotInfoPanel/unitInfo/tooltip",
        imgId = "slot_info_vehicle_icon",
        imgBg = "#ui/gameuiskin#slot_testdrive.svg",
        discountId = "unit_lb_discount",
        contentId = "air_info_content",
        fillerFunction = function() { updateAirInfo(true) }
      },
      {
        tooltip = "#slotInfoPanel/crewInfo/tooltip",
        imgId = "",
        imgBg = "#ui/gameuiskin#slot_crew.svg",
        discountId = "crew_lb_discount",
        contentId = "crew_info_content",
        fillerFunction = function() { updateCrewInfo(true) }
      },
      {
        tooltip = "#mainmenu/btnFavoritesUnlockAchievement",
        imgId = "",
        imgBg = "#ui/gameuiskin#sh_unlockachievement.svg",
        discountId = "",
        contentId = "unlockachievement_content",
        fillerFunction = function() { showUnlockAchievementInfo() }
      }
    ]

  favUnlocksHandlerWeak = null

  function initScreen()
  {
    scene.show(true)
    ::dmViewer.init(this)

    local showTabsCount = showTabs ? tabsInfo.len() : 1

    listboxObj = scene.findObject("slot_info_listbox")
    if (::checkObj(listboxObj))
    {
      local view = { items = [] }
      for(local i = 0; i < showTabsCount; i++)
      {
        view.items.push({
          tooltip = tabsInfo[i].tooltip,
          imgId = tabsInfo[i].imgId,
          imgBg = tabsInfo[i].imgBg
          discountId = tabsInfo[i].discountId
        })
      }
      local data = ::handyman.renderCached("gui/SlotInfoTabItem", view)
      guiScene.replaceContentFromText(listboxObj, data, data.len(), this)

      updateUnitIcon()
      listboxObj.setValue(::min(::load_local_account_settings(configSavePath, 0), showTabsCount))
      updateContentVisibility()

      listboxObj.show(view.items.len() > 1)
    }

    local unitInfoObj = scene.findObject("air_info_content_info")
    if (::checkObj(unitInfoObj))
    {
      local handler = ::handlersManager.getActiveBaseHandler()
      local hasSlotbar = handler && handler.getSlotbar()
      unitInfoObj["max-height"] = unitInfoObj[hasSlotbar ? "maxHeightWithSlotbar" : "maxHeightWithoutSlotbar"]
    }

    // Fixes DM selector being locked after battle.
    ::dmViewer.update()
  }

  function getCurShowUnitName()
  {
    return ::hangar_get_current_unit_name()
  }

  function getCurShowUnit()
  {
    return ::getAircraftByName(getCurShowUnitName())
  }

  function onAirInfoWeapons()
  {
    local airName = getCurShowUnitName()
    if (airName == "")
      return

    ::aircraft_for_weapons = airName
    ::gui_modal_weapons()
  }

  function onCollapseButton()
  {
    if(listboxObj)
      listboxObj.setValue(listboxObj.getValue() < 0 ? 0 : -1)
  }

  function onAirInfoToggleDMViewer(obj)
  {
    ::dmViewer.toggle(obj.getValue())
  }

  function onDMViewerHintTimer(obj, dt)
  {
    ::dmViewer.placeHint(obj)
  }

  function updateContentVisibility(obj = null)
  {
    local currentIndex = listboxObj.getValue()
    local isPanelHidden = currentIndex == -1
    local collapseBtnContainer = scene.findObject("slot_collapse")
    if(::checkObj(collapseBtnContainer))
      collapseBtnContainer.collapsed = isPanelHidden ? "yes" : "no"
    showSceneBtn("slot_info_content", ! isPanelHidden)
    updateVisibleTabContent(true)
    ::save_local_account_settings(configSavePath, currentIndex)
  }

  function updateVisibleTabContent(isTabSwitch = false)
  {
    if (isSceneForceHidden)
      return
    local currentIndex = listboxObj.getValue()
    local isPanelHidden = currentIndex == -1
    foreach(index, tabInfo in tabsInfo)
    {
      local discountObj = listboxObj.findObject(tabInfo.discountId)
      if (::check_obj(discountObj))
        discountObj.type = isPanelHidden ? "box_left" : "box_up"
      if(isPanelHidden)
        continue

      local isActive = index == currentIndex
      if (isTabSwitch)
        showSceneBtn(tabInfo.contentId, isActive)
      if(isActive)
        tabInfo.fillerFunction.call(this)
    }
  }

  function updateHeader(text)
  {
    local header = scene.findObject("content_header")
    if(::checkObj(header))
      header.setValue(text)
  }

  function updateAirInfo(force = false)
  {
    local unit = updateUnitIcon()

    local contentObj = scene.findObject("air_info_content")
    if ( !::checkObj(contentObj) || ( ! contentObj.isVisible() && ! force))
      return

    updateWeaponryDiscounts(unit)
    ::showAirInfo(unit, true)
    ::showBtn("aircraft-name", false, scene)
    updateHeader(::getUnitName(unit))
  }

  function checkUpdateAirInfo()
  {
    local unit = getCurShowUnit()
    if (!unit)
      return

    local isAirInfoValid = ::check_unit_mods_update(unit)
                           && ::check_secondary_weapon_mods_recount(unit)
    if (!isAirInfoValid)
      doWhenActiveOnce("updateAirInfo")
  }

  function onSceneActivate(show)
  {
    if (show && isSceneForceHidden)
      return

    if (show)
    {
      ::dmViewer.init(this)
      doWhenActiveOnce("updateVisibleTabContent")
    }
    base.onSceneActivate(show)
    scene.show(show)
  }

  function onEventShopWndVisible(p)
  {
    isSceneForceHidden = ::getTblValue("isShopShow", p, false)
    onSceneActivate(!isSceneForceHidden)
  }

  function onEventModalWndDestroy(p)
  {
    if (isSceneActiveNoModals())
      checkUpdateAirInfo()
    base.onEventModalWndDestroy(p)
  }

  function onEventHangarModelLoaded(params)
  {
    doWhenActiveOnce("updateAirInfo")
    doWhenActiveOnce("updateCrewInfo")
  }

  function onEventCurrentGameModeIdChanged(params)
  {
    doWhenActiveOnce("updateAirInfo")
  }

  function onEventUnitModsRecount(params)
  {
    local unit = ::getTblValue("unit", params)
    if (unit && unit.name == getCurShowUnitName())
      doWhenActiveOnce("updateAirInfo")
  }

  function onEventSecondWeaponModsUpdated(params)
  {
    local unit = ::getTblValue("unit", params)
    if (unit && unit.name == getCurShowUnitName())
      doWhenActiveOnce("updateAirInfo")
  }

  function onEventMeasureUnitsChanged(params)
  {
    doWhenActiveOnce("updateAirInfo")
  }

  function onEventCrewSkillsChanged(params)
  {
    doWhenActiveOnce("updateCrewInfo")
  }

  function onEventQualificationIncreased(params)
  {
    doWhenActiveOnce("updateCrewInfo")
  }

  function updateCrewInfo(force = false)
  {
    local contentObj = scene.findObject("crew_info_content")
    if ( !::checkObj(contentObj) || ( ! contentObj.isVisible() && ! force))
      return

    local crewCountryId = ::find_in_array(::shopCountriesList, ::get_profile_country_sq(), -1)
    local crewIdInCountry = ::getTblValue(crewCountryId, ::selected_crews, -1)
    local crewData = ::getSlotItem(crewCountryId, crewIdInCountry)
    if (crewData == null)
      return

    local unitName = ::getTblValue("aircraft", crewData, null)
    local unit = ::getAircraftByName(unitName)
    if (unit == null)
      return

    local discountInfo = ::g_crew.getDiscountInfo(crewCountryId, crewIdInCountry)
    local maxDiscount = ::g_crew.getMaxDiscountByInfo(discountInfo)
    local discountText = maxDiscount > 0? ("-" + maxDiscount + "%") : ""
    local discountTooltip = ::g_crew.getDiscountsTooltipByInfo(discountInfo)

    if (::checkObj(listboxObj))
    {
      local obj = listboxObj.findObject("crew_lb_discount")
      if (::checkObj(obj))
      {
        obj.setValue(discountText)
        obj.tooltip = discountTooltip
      }
    }

    local unitType = ::get_es_unit_type(unit)
    local country  = ::getUnitCountry(unit)
    local specType = ::g_crew_spec_type.getTypeByCrewAndUnit(crewData, unit)
    local isMaxLevel = ::g_crew.isCrewMaxLevel(crewData, country, unitType)
    local crewLevelText = ::g_crew.getCrewLevel(crewData, unitType)
    if (isMaxLevel)
      crewLevelText += ::colorize("@commonTextColor",
                                  ::loc("ui/parentheses/space", { text = ::loc("options/quality_max") }))
    local needCurPoints = !isMaxLevel

    local view = {
      crewName   = ::g_crew.getCrewName(crewData)
      crewLevelText  = crewLevelText
      needCurPoints = needCurPoints
      crewPoints = needCurPoints && ::get_crew_sp_text(::g_crew_skills.getCrewPoints(crewData))
      crewStatus = ::get_crew_status(crewData)
      crewSpecializationLabel = ::loc("crew/trained") + ::loc("ui/colon")
      crewSpecializationIcon = specType.trainedIcon
      crewSpecialization = specType.getName()
      categoryRows = ::g_crew_skills.getSkillCategoryView(crewData, unit)
      discountText = discountText
      discountTooltip = discountTooltip
    }
    local blk = ::handyman.renderCached("gui/crew/crewInfo", view)
    guiScene.replaceContentFromText(contentObj, blk, blk.len(), this)
    showSceneBtn("crew_name", false)
    updateHeader(::g_crew.getCrewName(crewData))
  }

  function showUnlockAchievementInfo()
  {
    if( ! favUnlocksHandlerWeak)
    {
      local contentObj = scene.findObject("favorite_unlocks_placeholder")
      if(! ::checkObj(contentObj))
        return
      favUnlocksHandlerWeak = ::handlersManager.loadHandler(
        ::gui_handlers.FavoriteUnlocksListView, { scene = contentObj}).weakref()
      registerSubHandler(favUnlocksHandlerWeak)
    }
    else
      favUnlocksHandlerWeak.onSceneActivate(true)

    updateHeader(::loc("mainmenu/btnFavoritesUnlockAchievement"))
  }

  function onAchievementsButtonClicked(obj)
  {
    ::gui_start_profile({ initialSheet = "UnlockAchievement" })
  }

  function onEventCrewChanged(params)
  {
    doWhenActiveOnce("updateAirInfo")
    doWhenActiveOnce("updateCrewInfo")
  }

  function updateUnitIcon()
  {
    local unit = getCurShowUnit()
    if (!unit)
      return null

    local iconObj = scene.findObject("slot_info_vehicle_icon")
    if (::checkObj(iconObj))
      iconObj["background-image"] = unit.unitType.testFlightIcon

    return unit
  }

  function updateWeaponryDiscounts(unit)
  {
    local discount = unit ? ::get_max_weaponry_discount_by_unitName(unit.name) : 0
    ::showCurBonus(scene.findObject("btnAirInfoWeaponry_discount"), discount, "mods", true, true)

    if (::checkObj(listboxObj))
    {
      local obj = listboxObj.findObject("unit_lb_discount")
      if (::checkObj(obj))
      {
        obj.setValue(discount > 0? ("-" + discount + "%") : "")
        obj.tooltip = ::format(::loc("discount/mods/tooltip"), discount.tostring())
      }
    }
  }

  function onCrewButtonClicked(obj)
  {
    local crewCountryId = ::find_in_array(::shopCountriesList, ::get_profile_country_sq(), -1)
    local crewIdInCountry = ::getTblValue(crewCountryId, ::selected_crews, -1)
    if (crewCountryId != -1 && crewIdInCountry != -1)
      ::gui_modal_crew(crewCountryId, crewIdInCountry)
  }
}
