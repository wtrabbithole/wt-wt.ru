frame {
  size:t='0.8@scrn_tgt_font, 1@maxWindowHeight'
  pos:t='50%pw-50%w, 1@minYposWindow + 0.1*(sh - 1@minYposWindow - h)';
  position:t='absolute';
  class:t='wnd';
  flow:t='h-flow'

  frame_header {
    HorizontalListBox {
      id:t='tasks_sheet_list'
      class:t='header'
      height:t='ph'
      activeAccesskeys:t='RS'
      on_select:t = 'onChangeTab'
      <<@tabs>>
    }

    Button_close { img {} }
  }

  tdiv {
    size:t='pw, ph - 1@frameFooterHeight'
    flow:t='vertical'
    CheckBox {
      id:t='show_all_tasks'
      pos:t='0, 0';
      position:t='relative'
      text:t='#mainmenu/battleTasks/showAllTasks'
      on_change_value:t='onShowAllTasks'
      btnName:t='Y'
      value:t='no'
      display:t = 'hide'
      enable:t='no'

      CheckBoxImg{}
      ButtonImg{}
    }

    tdiv {
      id:t='tasks_list_frame'
      size:t='pw,fh'
      flow:t='vertical'

      listbox {
        id:t='tasks_list'
        size:t='pw, fh'
        overflow-y:t='auto';
        flow:t='vertical'
        scrollBox-dontResendShortcut:t="yes"

        on_select:t='onSelectTask'

        behaviour:t='wrapNavigator'
        navigatorShortcuts:t='yes'
        childsActivate:t='yes'
        on_wrap_up:t='onWrapUp'
        on_wrap_down:t='onWrapDown'
        selImgType:t='gamepadFocused'
      }

      RadioButtonList {
        id:t='battle_tasks_modes_radiobuttons'
        left:t='50%pw-50%w'
        position:t='relative'

        navigatorShortcuts:t='yes'
        on_select:t = 'onChangeShowMode'
        on_wrap_up:t='onWrapUp'
        on_wrap_down:t='onWrapDown'

        <<#radiobuttons>>
          RadioButton {
            text:t='<<radiobuttonName>>';
            <<#selected>>
              selected:t='yes'
            <</selected>>
            RadioButtonImg{}
          }
        <</radiobuttons>>
      }
    }

    tdiv {
      id:t='tasks_history_frame'
      size:t='pw,ph'
      overflow-y:t='auto'
    }
  }

  navBar {
    navLeft {
      Button_text {
        id:t = 'btn_requirements_list'
        text:t = '#unlocks/requirements'
        _on_click:t = 'onViewUnlocks'
        btnName:t='Y'
        ButtonImg {}
      }

      textareaNoTab {
        id:t='warbonds_balance'
        pos:t='0, 50%ph-50%h'
        position:t='relative'
        margin-right:t='0.02@scrn_tgt'
        hideEmptyText:t='yes'
        text:t=''

        behaviour:t='Timer'
      }
    }
    navRight {
      Button_text {
        id:t = 'btn_warbonds_shop'
        text:t = '#mainmenu/btnWarbondsShop'
        _on_click:t = 'onWarbondsShop'
        btnName:t='X'
        ButtonImg {}
      }

      Button_text {
        id:t = 'btn_activate'
        text:t = '#item/activate'
        _on_click:t = 'onActivate'
        btnName:t='A'
        ButtonImg {}
      }

      Button_text {
        id:t = 'btn_cancel'
        text:t = '#mainmenu/btnCancel'
        _on_click:t = 'onCancel'
        btnName:t='A'
        ButtonImg {}
      }
    }
  }
}
