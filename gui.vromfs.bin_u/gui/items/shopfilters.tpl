HorizontalListBox {
  id:t='sheets_list'
  max-width:t='pw'
  smallFont:t='yes'

  navigatorShortcuts:t='yes'
  on_select:t = 'onItemTypeChange'
  on_wrap_up:t='onWrapUp'
  on_wrap_down:t='onWrapDown'

  coloredTexts:t='yes'

  include "gui/commonParts/shopFilter"
}
