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
        showTopPanel = false
      },
      "slotbar_place")
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
}