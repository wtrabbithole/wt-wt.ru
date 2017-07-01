tdiv {
  id:t='top_menu_panel_place'
  behaviour:t='wrapNavigator'
  navigatorShortcuts:t='yes'
  childsActivate:t='yes'
  on_wrap_up:t='onWrapUp'
  on_wrap_down:t='onWrapDown'
  on_wrap_left:t='onWrapLeft'
  on_wrap_right:t='onWrapRight'

  <<#section>>
  emptyButton {
    id:t = '<<tmId>>'
    class:t='dropDown'
    hoverMenuButtons:t='yes'
    css-hier-invalidate:t='yes'
    input-transparent:t='yes'
    on_click:t = 'onGCDropdown'

    hoverSize {
      id:t='<<tmId>>_list_hover'
      width:t='<<columnsCount>> * 0.28@scrn_tgt_font'
      height:t='0'
      pos:t='-1@topMenuHoverMenuIndent, ph-1'; position:t='absolute'
      overflow:t='hidden'
      tooltip:t='' // Overrides underlying widgets tooltips.

      height-base:t='0'; height-end:t='60'
      size-scale:t='sh'
      _size-timer:t='0'

      topMenuButtons {
        id:t='<<tmId>>_focus'
        pos:t='1@topMenuHoverMenuIndent, ph-60%sh-3';
        position:t='absolute';
        flow:t='vertical'

        behavior:t='posNavigator'
        navigatorShortcuts:t='full'
        moveX:t='closest';
        moveY:t='linear';
        showSelect:t='yes'
        disableFocusParent:t='yes'
        on_wrap_up:t='unstickLastDropDown'

        on_activate:t='topmenuMenuActivate'
        on_cancel_edit:t='unstickGCDropdownMenu'

        <<#columns>>
          <<#buttons>>
            <<#isLineSeparator>>
              topMenuLinePlace {
                inactive:t='yes'
                topMenuLine {}
              }
            <</isLineSeparator>>
            <<^isLineSeparator>>
              include "gui/commonParts/button"
            <</isLineSeparator>>
          <</buttons>>
          <<#addNewLine>>
            chapterSeparator {
              pos:t='(pw/<<columnsCount>>)*<<columnIndex>>-50%w, 50%ph-50%h'
              position:t='absolute'
              class:t='notFull'
              inactive:t='yes'
            }
            _newcolumn {size:t='1'}
          <</addNewLine>>
        <</columns>>
      }
    }
    Button_text {
      id:t='<<tmId>>_btn'
      <<#tmText>>
        text:t = '<<tmText>>'
        class:t='topmenu'
      <</tmText>>
      <<#tmImage>>
        img{ background-image:t='<<tmImage>>' }
        class:t='topmenuImage'
      <</tmImage>>
      <<#tmOnClick>>
        on_click:t = '<<tmOnClick>>'
      <</tmOnClick>>
      <<#btnName>>
        btnName:t='<<btnName>>'
        ButtonImg{}
      <</btnName>>
      <<^btnName>>
        talign:t='center'
      <</btnName>>
    }
  }
  <</section>>
}
