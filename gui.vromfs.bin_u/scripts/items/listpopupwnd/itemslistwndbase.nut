class ::gui_handlers.ItemsListWndBase extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneTplName = "gui/items/universalSpareApplyWnd"

  itemsList = null
  alignObj = null
  align = AL_ORIENT.BOTTOM

  curItem = null

  function getSceneTplView()
  {
    return {
      items = ::handyman.renderCached("gui/items/item", { items = ::u.map(itemsList, @(i) i.getViewData()) })
      columns = ::calc_golden_ratio_columns(itemsList.len())

      align = align
      position = "50%pw-50%w, 50%ph-50%h"
      hasPopupMenuArrow = ::check_obj(alignObj)
    }
  }

  function initScreen()
  {
    setCurItem(itemsList[0])
    delayedRestoreFocus()
    updateWndAlign()
  }

  function updateWndAlign()
  {
    if (::check_obj(alignObj))
      align = ::g_dagui_utils.setPopupMenuPosAndAlign(alignObj, align, scene.findObject("frame_obj"))
  }

  function setCurItem(item)
  {
    curItem = item
    scene.findObject("header_text").setValue(curItem.getName())
  }

  function onItemSelect(obj)
  {
    local value = obj.getValue()
    if (value in itemsList)
      setCurItem(itemsList[value])
  }

  function onActivate() {}
}