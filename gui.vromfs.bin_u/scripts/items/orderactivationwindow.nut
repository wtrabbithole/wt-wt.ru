function gui_start_order_activation_window(params = null)
{
  if (params == null)
    params = {}
  params.curTab <- itemsTab.INVENTORY
  params.filter <- { typeMask = itemType.ORDER }
  ::handlersManager.loadHandler(::gui_handlers.OrderActivationWindow, params)
}

class ::gui_handlers.OrderActivationWindow extends ::gui_handlers.ItemsList
{
  /*override*/ function updateButtons()
  {
    local item = getCurItem()
    local actionName = item ? item.getMainActionName() : ""
    showSceneBtn("btn_main_action", actionName.len() > 0)
    ::setDoubleTextToButton(scene, "btn_main_action", actionName)
    setWarningText(::g_orders.getWarningText(item))
  }

  /*override*/ function onTimer(obj, dt)
  {
    base.onTimer(obj, dt)
    updateButtons()
  }

  function onEventActiveOrderChanged(params)
  {
    fillPage()
  }

  /*override*/ function onMainActionComplete(result)
  {
    // This forces "Activate" button for each item to update.
    if (base.onMainActionComplete(result))
      fillPage()
  }

  function onEventOrderUseResultMsgBoxClosed(params)
  {
    goBack()
  }

  /*override*/ function isItemLocked(item)
  {
    return !::g_orders.checkCurrentMission(item)
  }
}
