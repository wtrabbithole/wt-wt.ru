class ::gui_handlers.navigationPanel extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneTplName = "gui/wndWidgets/navigationPanel"
  sceneBlkName = null

  // ==== Handler params ====

  onSelectCb = null
  onClickCb  = null
  onCollapseCb = null

  // ==== Handler template params ====

  panelWidth        = null  // Panel width
  headerHeight      = null  // Panel header height
  headerOffsetX     = "0.015@sf"  // Panel header left and right offset
  headerOffsetY     = "0.015@sf"  // Panel header top and bottom offset

  collapseShortcut  = null
  needShowCollapseButton = null
  expandShortcut    = null  // default: collapseShortcut
  focusShortcut     = "LB"

  // ==== Privates ====

  itemList = null

  shouldCallCallback = true
  isPanelVisible = true

  static panelObjId = "panel"
  static panelHeaderObjId = "panel_header"
  static collapseButtonObjId = "collapse_button"
  static expandButtonObjId = "expand_button"
  static navListObjId = "nav_list"


  // ==== Functions ====

  function getSceneTplView()
  {
    return {
      panelWidth        = panelWidth
      headerHeight      = headerHeight
      headerOffsetX     = headerOffsetX
      headerOffsetY     = headerOffsetY
      collapseShortcut  = collapseShortcut
      needShowCollapseButton = needShowCollapseButton || ::is_low_width_screen()
      expandShortcut    = expandShortcut ?? collapseShortcut
      focusShortcut     = focusShortcut
    }
  }

  function initScreen()
  {
    setNavItems(itemList || [])
  }

  function showPanel(isVisible)
  {
    isPanelVisible = isVisible
    updateVisibility()
  }

  function setNavItems(navItems)
  {
    local navListObj = scene.findObject(navListObjId)
    if (!::checkObj(navListObj))
      return

    itemList = navItems
    local view = {items = itemList.map(@(navItem, idx)
      navItem.__merge({
        id = $"nav_{idx.tostring()}"
        isSelected = idx == 0
        itemText = navItem?.text ?? navItem?.id ?? ""
        isCollapsable = navItem?.isCollapsable ?? false
      })
    )}

    local data = ::handyman.renderCached("gui/missions/missionBoxItemsList", view)
    guiScene.replaceContentFromText(navListObj, data, data.len(), this)

    updateVisibility()
  }

  function getNavItems()
  {
    return itemList
  }

  function setCurrentItem(item)
  {
    local itemIdx = itemList.indexof(item)
    if (itemIdx != null)
      setCurrentItemIdx(itemIdx)
  }

  function setCurrentItemIdx(itemIdx)
  {
    shouldCallCallback = false
    doNavigate(itemIdx)
    shouldCallCallback = true
  }

  function doNavigate(itemIdx, isRelative = false)
  {
    local navListObj = scene.findObject(navListObjId)
    if (!::checkObj(navListObj))
      return false

    local itemsCount = itemList.len()
    if (itemsCount < 1)
      return

    if (isRelative)
      itemIdx += navListObj.getValue()
    itemIdx = ::clamp(itemIdx, 0, itemsCount - 1)

    if (itemIdx == navListObj.getValue())
      return

    navListObj.setValue(itemIdx)
    notifyNavChanged(itemIdx)
  }

  function notifyNavChanged(itemIdx)
  {
    if (shouldCallCallback && onSelectCb && itemIdx in itemList)
      onSelectCb(itemList[itemIdx])
  }

  function updateVisibility()
  {
    local isNavRequired = itemList.len() > 1
    showSceneBtn(panelObjId, isNavRequired && isPanelVisible)
    showSceneBtn(expandButtonObjId, isNavRequired && !isPanelVisible)
    guiScene.performDelayed(this, function() {
      if (isValid())
        updateMoveToPanelButton()
    })
  }

  function onNavClick(obj = null)
  {
    local navListObj = scene.findObject(navListObjId)
    if (!::checkObj(navListObj))
      return false

    local itemIdx = navListObj.getValue()
    if (shouldCallCallback && onClickCb && itemIdx in itemList)
      onClickCb(itemList[itemIdx])
  }

  function onNavSelect(obj = null)
  {
    local navListObj = scene.findObject(navListObjId)
    if (!::checkObj(navListObj))
      return false

    notifyNavChanged(navListObj.getValue())
  }

  function onExpand(obj = null)
  {
    showPanel(true)
    if (shouldCallCallback && onCollapseCb)
      onCollapseCb(false)
  }

  function onNavCollapse(obj = null)
  {
    showPanel(false)
    if (shouldCallCallback && onCollapseCb)
      onCollapseCb(true)
  }

  function onCollapse(obj)
  {
    local itemObj = obj?.collapse_header ? obj : obj.getParent()
    local listObj = ::check_obj(itemObj) ? itemObj.getParent() : null
    if (!::check_obj(listObj) || !itemObj?.collapse_header)
      return

    itemObj.collapsing = "yes"
    local isShow = itemObj?.collapsed == "yes"
    local listLen = listObj.childrenCount()
    local selIdx = listObj.getValue()
    local headerIdx = -1
    local needReselect = false

    local found = false
    for (local i = 0; i < listLen; i++)
    {
      local child = listObj.getChild(i)
      if (!found)
      {
        if (child?.collapsing == "yes")
        {
          child.collapsing = "no"
          child.collapsed  = isShow ? "no" : "yes"
          headerIdx = i
          found = true
        }
      }
      else
      {
        if (child?.collapse_header)
          break
        child.show(isShow)
        child.enable(isShow)
        if (!isShow && i == selIdx)
          needReselect = true
      }
    }

    if (needReselect)
    {
      local indexes = []
      for (local i = selIdx + 1; i < listLen; i++)
        indexes.append(i)
      for (local i = selIdx - 1; i >= 0; i--)
        indexes.append(i)

      local newIdx = -1
      foreach (idx in indexes)
      {
        local child = listObj.getChild(idx)
        if (!child?.collapse_header && child.isEnabled())
        {
          newIdx = idx
          break
        }
      }
      selIdx = newIdx != -1 ? newIdx : headerIdx
      listObj.setValue(selIdx)
    }
  }

  onFocusNavigationList = @() ::move_mouse_on_child_by_value(scene.findObject(navListObjId))
  function updateMoveToPanelButton() {
    if (isValid())
      showSceneBtn("moveToLeftPanel", ::show_console_buttons && !scene.findObject(navListObjId).isHovered())
  }

  function getCurrentItem() {
    local currentIdx = ::get_object_value(scene, navListObjId)
    if (currentIdx == null)
      return null

    return itemList?[currentIdx]
  }
}
