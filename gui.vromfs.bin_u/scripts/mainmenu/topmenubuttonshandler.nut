class ::gui_handlers.TopMenuButtonsHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  sceneTplName = "gui/mainmenu/topmenu_menuPanel"

  parentHandlerWeak = null
  sectionsStructure = null

  GCDropdownsList = null
  focusArray = null
  isPrimaryFocus = false

  maxSectionsCount = 0
  sectionsOrder = null

  ON_ESC_SECTION_OPEN = "menu"

  static function create(nestObj, parentHandler, sectionsStructure)
  {
    if (!::g_login.isLoggedIn())
      return null

    if (!::check_obj(nestObj))
      return null

    local handler = ::handlersManager.loadHandler(::gui_handlers.TopMenuButtonsHandler, {
                                           scene = nestObj
                                           parentHandlerWeak = parentHandler,
                                           sectionsStructure = sectionsStructure
                                        })
    return handler? handler.weakref() : null
  }

  function getSceneTplView()
  {
    GCDropdownsList = []
    focusArray = ["top_menu_panel_place"]
    return {
      section = getSectionsView()
    }
  }

  function initScreen()
  {
    if (parentHandlerWeak)
      parentHandlerWeak = parentHandlerWeak.weakref()

    scene.show(true)
    updateButtonsStatus()
    updateItemsWidgets()
    initFocusArray()
  }

  function getFocusObj()
  {
    if (curGCDropdown)
      return findObjInFocusArray(false)

    return scene.findObject("top_menu_panel_place")
  }

  function getMaxSectionsCount()
  {
    if (!::check_obj(scene))
      return 1

    if (!::has_feature("SeparateTopMenuButtons"))
      return 1

    local freeWidth = scene.getSize()[0]
    local singleButtonMinWidth = guiScene.calcString("1@topMenuButtonWidth", null)
    return freeWidth / singleButtonMinWidth || 1
  }

  function initSectionsOrder()
  {
    if (sectionsOrder)
      return

    maxSectionsCount = getMaxSectionsCount()
    sectionsOrder = ::g_top_menu_sections.getSectionsOrder(sectionsStructure, maxSectionsCount)
  }

  function getSectionsView()
  {
    if (!::check_obj(scene))
      return {}

    initSectionsOrder()

    local sectionsView = []
    foreach (topMenuButtonIndex, sectionData in sectionsOrder)
    {
      local columnsCount = sectionData.buttons.len()
      local columns = []

      foreach (idx, column in sectionData.buttons)
      {
        columns.append({
          buttons = column
          addNewLine = idx != (columnsCount - 1)
          columnIndex = (idx+1)
        })
      }

      local tmId = sectionData.getTopMenuButtonDivId()
      ::append_once(tmId, GCDropdownsList)

      sectionsView.append({
        tmId = tmId
        haveTmDiscount = sectionData.haveTmDiscount
        tmDiscountId = sectionData.getTopMenuDiscountId()
        tmType = sectionData.type
        tmText = sectionData.getText(maxSectionsCount)
        tmImage = sectionData.getImage(maxSectionsCount)
        tmWinkImage = sectionData.getWinkImage()
        tmHoverMenuPos = sectionData.hoverMenuPos
        tmOnClick = sectionData.onClick
        forceHoverWidth = sectionData.forceHoverWidth
        minimalWidth = sectionData.minimalWidth
        columnsCount = columnsCount
        columns = columns
        btnName = sectionData.btnName
      })
    }
    return sectionsView
  }

  function updateButtonsStatus()
  {
    local needHideVisDisabled = ::has_feature("HideDisabledTopMenuActions")
    local isInQueue = ::checkIsInQueue()

    foreach (idx, section in sectionsOrder)
    {
      local sectionId = section.getTopMenuButtonDivId()
      local sectionObj = scene.findObject(sectionId)
      if (!::check_obj(sectionObj))
        continue

      local isVisibleAnyButton = false
      foreach (column in section.buttons)
      {
        foreach (button in column)
        {
          local btnObj = sectionObj.findObject(button.id)
          if (!::checkObj(btnObj))
            continue

          local isVisualDisable = button.isVisualDisabled()
          local show = !button.isHidden(parentHandlerWeak)
          if (show && isVisualDisable)
            show = !needHideVisDisabled

          btnObj.show(show)
          btnObj.enable(show)
          isVisibleAnyButton = isVisibleAnyButton || show

          if (!show)
            continue

          isVisualDisable = isVisualDisable || button.isInactiveInQueue && isInQueue
          btnObj.inactiveColor = isVisualDisable? "yes" : "no"
        }
      }

      sectionObj.show(isVisibleAnyButton)
      sectionObj.enable(isVisibleAnyButton)
    }

    updateItemsWidgets()
  }

  function hideHoverMenu(name)
  {
    local obj = getObj(name)
    if (!::check_obj(obj))
      return

    obj["_size-timer"] = "0"
    obj.setFloatProp(::dagui_propid.add_name_id("_size-timer"), 0.0)
    obj.height = "0"
  }

  function onClick(obj)
  {
    if (!::handlersManager.isHandlerValid(parentHandlerWeak))
      return

    local btn = ::g_top_menu_buttons.getTypeById(obj.id)
    btn.onClickFunc(obj, parentHandlerWeak)
  }

  function onChangeCheckboxValue(obj)
  {
    local btn = ::g_top_menu_buttons.getTypeById(obj.id)
    btn.onChangeValueFunc(obj.getValue())
  }

  function switchDropDownMenu()
  {
    local section = sectionsStructure.getSectionByName(ON_ESC_SECTION_OPEN)
    if (::u.isEmpty(section))
      return

    local buttonObj = scene.findObject(section.getTopMenuButtonDivId())
    if (::checkObj(buttonObj))
      this[section.onClick](buttonObj)
  }

  function topmenuMenuActivate(obj)
  {
    local curVal = obj.getValue()
    if (curVal < 0)
      return

    local selObj = obj.getChild(curVal)
    if (!::checkObj(selObj))
      return
    local eventName = selObj._on_click || selObj.on_click || selObj.on_change_value
    if (!eventName || !(eventName in this))
      return

    if (selObj.on_change_value)
      selObj.setValue(!selObj.getValue())

    this[eventName](selObj)
  }

  function onWrapLeft(obj)
  {
    if (::handlersManager.isHandlerValid(parentHandlerWeak))
      parentHandlerWeak.onTopGCPanelLeft(obj)
  }

  function onWrapRight(obj)
  {
    if (::handlersManager.isHandlerValid(parentHandlerWeak))
      parentHandlerWeak.onTopGCPanelRight(obj)
  }

  function onEventGameModesAvailability(p)
  {
    doWhenActiveOnce("updateButtonsStatus")
  }

  function onEventQueueChangeState(p)
  {
    doWhenActiveOnce("updateButtonsStatus")
  }

  function onEventUpdateGamercard(p)
  {
    doWhenActiveOnce("updateButtonsStatus")
  }

  function onEventActiveHandlersChanged(p)
  {
    if (!isSceneActiveNoModals())
      unstickLastDropDown()
  }

  function onEventUpdatedSeenItems(p)
  {
    local forInventoryItems = ::getTblValue("forInventoryItems", p)
    updateItemsWidgets(forInventoryItems)
  }

  function updateItemsWidgets(forInventoryItems = null)
  {
    local iconObj = null

    if (forInventoryItems == null || !forInventoryItems)
    {
      iconObj = scene.findObject(::g_top_menu_buttons.ITEMS_SHOP.id + "_new_icon")
      if (::check_obj(iconObj))
        iconObj.show(::ItemsManager.getNumUnseenItems(false) > 0)
    }

    if (forInventoryItems == null || forInventoryItems)
    {
      iconObj = scene.findObject(::g_top_menu_buttons.INVENTORY.id + "_new_icon")
      if (::check_obj(iconObj))
        iconObj.show(::ItemsManager.getNumUnseenItems(true) > 0)
    }
  }
}
