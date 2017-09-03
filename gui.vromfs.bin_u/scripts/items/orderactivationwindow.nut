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
  _types = [
    {
      key = "orders"
      typeMask = itemType.ORDER
    }
    {
      key = "devItems"
      typeMask = itemType.ALL
      devItemsTab = true
      tabEnable = @() ::has_feature("devItemShop") ? [itemsTab.SHOP] : []
    }
  ]

  /*override*/ function updateButtons()
  {
    local item = getCurItem()
    local actionName = item ? item.getMainActionName() : ""
    local showMainAction = actionName != ""
    local buttonObj = showSceneBtn("btn_main_action", showMainAction)
    if (showMainAction)
    {
      buttonObj.visualStyle = curTab == itemsTab.INVENTORY? "secondary" : "purchase"
      ::setDoubleTextToButton(scene, "btn_main_action", item.getMainActionName(false), actionName)
    }

    local text = ""
    if (curTab == itemsTab.INVENTORY)
      text =::g_orders.getWarningText(item)
    setWarningText(text)
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
