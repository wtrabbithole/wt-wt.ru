local elemModelType = ::require("sqDagui/elemUpdater/elemModelType.nut")
local elemViewType = ::require("sqDagui/elemUpdater/elemViewType.nut")


elemModelType.addTypes({
  COUNTRY_DISCOUN_ICON = {
    init = @() ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)

    onEventDiscountsDataUpdated = @(p) notify([])
    onEventShopWndSwitched = @(p) notify([])
  }
})


elemViewType.addTypes({
  COUNTRY_DISCOUN_ICON = {
    model = elemModelType.COUNTRY_DISCOUN_ICON

    updateView = function(obj, params)
    {
      local isVisible = ::top_menu_shop_active &&
        ::g_discount.haveAnyCountryUnitDiscount(obj.countryId)
      obj.show(isVisible)
    }
  }
})

return {}
