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
    margin:t='1@gcButtonsInterval, 0'
    css-hier-invalidate:t='yes'
    input-transparent:t='yes'
    on_click:t = 'onGCDropdown'

    hoverSize {
      id:t='<<tmId>>_list_hover'
      <<#forceHoverWidth>>
        width:t='<<forceHoverWidth>>'
      <</forceHoverWidth>>
      <<^forceHoverWidth>>
        width:t='<<columnsCount>> * 0.28@sf'
      <</forceHoverWidth>>
      height:t='0'
      pos:t='<<tmHoverMenuPos>> - 1@topMenuHoverMenuIndent, ph+2@dp'; position:t='absolute'
      overflow:t='hidden'
      tooltip:t='' // Overrides underlying widgets tooltips.

      height-base:t='0'; height-end:t='60'
      size-scale:t='sh'
      _size-timer:t='0'

      topMenuButtons {
        id:t='<<tmId>>_focus'
        pos:t='<<tmHoverMenuPos>> + 1@topMenuHoverMenuIndent, ph-60%sh';
        position:t='absolute';
        padding-top:t='0'
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

        line {}

        <<#columns>>
          <<#buttons>>
            <<#isLineSeparator>>
              topMenuLinePlace {
                inactive:t='yes'
                topMenuLine {}
              }
            <</isLineSeparator>>
            <<#isButton>>
              include "gui/commonParts/button"
            <</isButton>>
            <<#checkbox>>
              include "gui/commonParts/checkbox"
            <</checkbox>>
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
      noMargin:t='yes'
      imgSize:t='big'
      visualStyle:t='<<visualStyle>>'

      <<^btnName>>
      showConsoleImage:t='no'
      <</btnName>>
      <<^tmText>>
        class:t='image'
      <</tmText>>
      <<#tmOnClick>> on_click:t = '<<tmOnClick>>' <</tmOnClick>>

      <<#haveTmDiscount>>
        discount_notification {
          id:t='<<tmDiscountId>>'
          type:t='up'
          display:t='hide'
        }
      <</haveTmDiscount>>

      <<#tmWinkImage>>
        buttonWink {
          pos:t='50%pw-50%w, 50%ph-50%h'; position:t='absolute'
          size:t='pw-2@dp, ph-2@dp'
          padding:t='ph-4, 4, 4, 4'

          behaviour:t='basicTransparency'
          transp-base:t='255'
          transp-end:t='70'
          transp-time:t='6000'
          transp-func:t='sin'
          transp-cycled:t='yes'

          re-type:t='9rect'
          background-image:t='<<tmWinkImage>>'
          background-color:t='@white'
          background-position:t='2'
          background-repeat:t='expand'
          text {
            id:t='<<tmId>>_btn_wink'
            text:t='<<tmText>>'
            input-transparent:t='yes'
            hideText:t='yes'
          }
        }
      <</tmWinkImage>>

      <<#btnName>>
        btnName:t='<<btnName>>'
        ButtonImg{}
      <</btnName>>

      <<#tmImage>>
      img{
        background-image:t='<<tmImage>>'
        <<#tmText>>
        <<^btnName>>isFirstLeft:t='yes'<</btnName>>
        <</tmText>>
      }
      <</tmImage>>

      <<#tmText>>
      btnText {
        id:t='<<tmId>>_txt'
        text:t='<<tmText>>'
      }
      <</tmText>>
    }
  }
  <</section>>
}
