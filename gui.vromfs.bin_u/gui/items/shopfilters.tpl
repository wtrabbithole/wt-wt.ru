HorizontalListBox {
  id:t='item_type_filter'
  height:t='0.03@scrn_tgt_font'
  max-width:t='pw'

  navigatorShortcuts:t='yes'
  on_select:t = 'onItemTypeChange'
  on_wrap_up:t='onWrapUp'
  on_wrap_down:t='onWrapDown'

  coloredTexts:t='yes'

  <<#itemTypesList>>
  shopFilter {
    id:t='shop_filter_<<key>>'
    <<#selected>>
    selected:t='yes'
    <</selected>>

    <<#newIconWidget>>
    tdiv {
      id:t='filter_new_icon_widget'
      <<@newIconWidget>>
    }
    <</newIconWidget>>

    shopFilterText {
      text:t='<<text>>'
    }
  }
  <</itemTypesList>>
}
