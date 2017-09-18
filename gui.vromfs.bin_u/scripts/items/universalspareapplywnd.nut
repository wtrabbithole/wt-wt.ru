class ::gui_handlers.UniversalSpareApplyWnd extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneTplName = "gui/items/universalSpareApplyWnd"

  unit = null
  itemsList = null
  alignObj = null
  align = AL_ORIENT.BOTTOM

  curItem = null
  sliderObj = null
  amountTextObj = null
  curAmount = -1
  maxAmount = 1
  minAmount = 1

  currentFocusItem = 0
  focusArray = [
    @() itemsList.len() > 1 ? "items_list" : null
    "amount_slider"
  ]

  static function open(unitToActivate, wndAlignObj = null, wndAlign = AL_ORIENT.BOTTOM)
  {
    local list = ::ItemsManager.getInventoryList(itemType.UNIVERSAL_SPARE)
    list = ::u.filter(list, @(item) item.canActivateOnUnit(unitToActivate))
    if (!list.len())
    {
      ::showInfoMsgBox(::loc("msg/noUniversalSpareForUnit"))
      return
    }
    ::handlersManager.loadHandler(::gui_handlers.UniversalSpareApplyWnd,
    {
      unit = unitToActivate
      itemsList = list
      alignObj = wndAlignObj
      align = wndAlign
    })
  }

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
    sliderObj = scene.findObject("amount_slider")
    amountTextObj = scene.findObject("amount_text")

    setCurItem(itemsList[0])
    delayedRestoreFocus()

    if (::check_obj(alignObj))
      align = ::g_dagui_utils.setPopupMenuPosAndAlign(alignObj, align, scene.findObject("frame_obj"))
  }

  function setCurItem(item)
  {
    curItem = item
    scene.findObject("header_text").setValue(curItem.getName())
    updateAmountSlider()
  }

  function updateAmountSlider()
  {
    local itemsAmount = curItem.getAmount()
    local availableAmount = ::g_weaponry_types.SPARE.getMaxAmount(unit, null)  - ::g_weaponry_types.SPARE.getAmount(unit, null)
    maxAmount = ::min(itemsAmount, availableAmount)
    curAmount = maxAmount

    local canChangeAmount = maxAmount > minAmount
    showSceneBtn("slider_block", canChangeAmount)
    if (!canChangeAmount)
      return

    sliderObj.min = minAmount.tostring()
    sliderObj.max = maxAmount.tostring()
    sliderObj.setValue(curAmount)
    updateText()
  }

  function updateText()
  {
    amountTextObj.setValue(curAmount + ::loc("icon/universalSpare"))
  }

  function onAmountInc()
  {
    if (curAmount < maxAmount)
      sliderObj.setValue(curAmount + 1)
  }

  function onAmountDec()
  {
    if (curAmount > minAmount)
      sliderObj.setValue(curAmount - 1)
  }

  function onAmountChange()
  {
    curAmount = sliderObj.getValue()
    updateText()
  }

  function onItemSelect(obj)
  {
    local value = obj.getValue()
    if (value in itemsList)
      setCurItem(itemsList[value])
  }

  function onActivate()
  {
    curItem.activateOnUnit(unit, curAmount, ::Callback(goBack, this))
  }
}