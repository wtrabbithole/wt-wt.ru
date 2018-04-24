div {
  size:t='sw, sh'
  position:t='root'
  pos:t='0, 0'
  behavior:t='button'
  on_click:t='goBack'
  on_r_click:t='goBack'
  input-transparent:t='yes'
  accessKey:t='Esc | J:B'
}

popup_menu {
  id:t='frame_obj'
  width:t='1@sliderWidth + 2@buttonHeight + 4@blockInterval'
  min-width:t='<<columns>>*(@itemWidth + @itemSpacing) + 1@itemSpacing + 2@framePadding'
  position:t='root'
  pos:t='<<position>>'
  menu_align:t='<<align>>'
  total-input-transparent:t='yes'
  flow:t='vertical'

  Button_close { _on_click:t='goBack'; smallIcon:t='yes'}

  textAreaCentered {
    id:t='header_text'
    width:t='pw'
    overlayTextColor:t='active'
    text:t='<<header>>'
  }

  div {
    id:t='items_list'
    width:t='<<columns>>*(@itemWidth + @itemSpacing) + 1@itemSpacing'
    pos:t='50%pw-50%w, 0'
    position:t='relative'
    itemShopList:t='yes'
    mouse-focusable:t='yes'
    clearOnFocusLost:t='no'

    flow:t='h-flow'
    behavior:t='posNavigator'
    navigatorShortcuts:t='yes'
    moveX:t='linear'
    moveY:t='closest'
    value:t='0'

    on_select:t = 'onItemSelect'
    on_wrap_down:t='onWrapDown'

    <<@items>>
  }

  Button_text {
    pos:t='50%pw-50%w, @blockInterval'
    position:t='relative'
    text:t='#mainmenu/btnUpgrade'
    on_click:t='onActivate'
    btnName:t='A'
    ButtonImg{}
  }

  <<#hasPopupMenuArrow>>
  popup_menu_arrow{}
  <</hasPopupMenuArrow>>
}
