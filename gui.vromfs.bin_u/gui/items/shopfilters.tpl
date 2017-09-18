HorizontalListBox {
  id:t='item_type_filter'
  height:t='1@buttonHeight'
  max-width:t='pw'

  navigatorShortcuts:t='yes'
  on_select:t = 'onItemTypeChange'
  on_wrap_up:t='onWrapUp'
  on_wrap_down:t='onWrapDown'

  coloredTexts:t='yes'

  include "gui/commonParts/shopFilter"
}
