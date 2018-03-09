class ::gui_handlers.ModUpgradeApplyWnd extends ::gui_handlers.ItemsListWndBase
{
  sceneTplName = "gui/items/modUpgradeApplyWnd"

  unit = null
  mod = null

  focusArray = [
    @() itemsList.len() > 1 ? "items_list" : null
  ]

  static function open(unitToActivate, modToActivate, wndAlignObj = null, wndAlign = AL_ORIENT.BOTTOM)
  {
    local list = ::ItemsManager.getInventoryList(itemType.MOD_UPGRADE)
    list = ::u.filter(list, @(item) item.canActivateOnMod(unitToActivate, modToActivate))
    if (!list.len())
    {
      ::showInfoMsgBox(::loc("msg/noUpgradeItemsForMod"))
      return
    }
    ::handlersManager.loadHandler(::gui_handlers.ModUpgradeApplyWnd,
    {
      unit = unitToActivate
      mod = modToActivate
      itemsList = list
      alignObj = wndAlignObj
      align = wndAlign
    })
  }

  function onActivate()
  {
    curItem.activateOnMod(unit, mod, ::Callback(goBack, this))
  }
}