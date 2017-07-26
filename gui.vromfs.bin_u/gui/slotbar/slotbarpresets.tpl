div {
  id:t='slotbar-presetsList'
  height:t = 'ph'
  width:t='pw'
  invertImages:t='yes'
  showSelect='yes'
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

    RadioButtonImg {}
    tabText {
      id:t='tab_text'
      text:t = ''
      min-width:t='1@buttonWidth - 1@activateTabPaddingSum'
      max-width:t='p.p.w / <<itemsCount>>'
      pare-text:t='yes'
    }
  }
  <</presets>>

  Button_text {
    id:t='btn_slotbar_presets'
    max-width:t='pw / <<itemsCount>>'
    style:t='height:ph; min-width:1@buttonWidth;'
    top:t='50%ph-50%h'; position:t='relative'
    class:t='header'
    tooltip:t='#shop/slotbarPresets/tooltip'
    on_click:t='onSlotsChoosePreset'

    cardImg{
      background-image:t='#ui/gameuiskin#slot_change_aircraft'
      margin-left:t='@sIco/4'
    }
    text{
      text:t='#shop/slotbarPresets/button'
      position:t='relative'
      pos:t='0, 50%ph-50%h'
      talign:t='left'
      margin:t='@sIco/8, 0, @sIco/4, 0'
      padding-right:t='-1@textPaddingBugWorkaround'
    }
  }
}
