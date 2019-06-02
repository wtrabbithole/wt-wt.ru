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
      local discountData = ::g_discount.generateDiscountInfo(
        ::g_discount.getUnitDiscountList(obj.countryId))
      local maxDiscount = discountData?.maxDiscount ?? 0
      local isVisible = ::top_menu_shop_active && maxDiscount > 0
      obj.show(isVisible)
      if (!isVisible)
        return
      obj.text = "-" + maxDiscount + "%"
      obj.tooltip = discountData?.discountTooltip ?? ""
    }
  }
})

return {}
