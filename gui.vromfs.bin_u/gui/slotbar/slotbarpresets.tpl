gcButtonsHolder {
  id:t='slotbar-presetsList'
  width:t='pw'
  showSelect='yes'
  <<#isSmallFont>>smallFont:t='yes'<</isSmallFont>>
  css-hier-invalidate:t='yes'

  behavior:t='ActivateSelect'
  navigatorShortcuts:t='SpaceA'
  on_select:t='onPresetChange'
  on_wrap_up:t='onWrapUp'
  on_wrap_down:t='onWrapDown'
  on_wrap_left:t='onBottomGCPanelLeft'
  on_wrap_right:t='onBottomGCPanelRight'

  <<#presets>>
  activateTab {
    enable:t='no'
    display:t='hide'
    css-hier-invalidate:t='yes'

    tabText {
      id:t='tab_text'
      text:t = ''
      min-width:t='@minPresetNameTextWidth'
      max-width:t='@maxPresetNameTextWidth'
      pare-text:t='yes'
    }
  }
  <</presets>>

  Button_text {
    id:t='btn_slotbar_presets'
    style:t='min-width:1@minPresetNameItemWidth;'
    tooltip:t='#shop/slotbarPresets/tooltip'
    on_click:t='onSlotsChoosePreset'

    img {
      isFirstLeft:t='yes'
      background-image:t='#ui/gameuiskin#slot_change_aircraft'
    }

    btnText {
      pos:t='@blockInterval, 50%ph-50%h'
      position:t='relative'
      text-align:t='left'
      text:t='#shop/slotbarPresets/button'
    }
  }
}
