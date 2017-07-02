div {
  size:t='sw, sh'
  pos:t='0, 0'
  position:t='root'

  behavior:t='button'
  behavior:t='accesskey'
  accessKey:t='Esc | J:B'

  on_click:t='close'
  on_r_click:t='close'
}

popup_menu {
  id:t='main_frame'
  cluster_select:t='yes'
  menu_align:t='<<align>>'
  pos:t='<<position>>'
  position:t='root'

  MultiSelect {
    id:t='multi_select'
    flow:t='vertical'

    navigatorShortcuts:t='full'
    on_select:t='onChangeValue'
    _on_cancel_edit:t='close'

    value:t='<<value>>'
    snd_switch_on:t="<<#sndSwitchOn>><<sndSwitchOn>><</sndSwitchOn>><<^sndSwitchOn>>choose<</sndSwitchOn>>"
    snd_switch_off:t="<<#sndSwitchOff>><<sndSwitchOff>><</sndSwitchOff>><<^sndSwitchOff>>choose<</sndSwitchOff>>"

    <<#list>>
    multiOption {
      <<^show>>
      enable:t='no'
      display:t='hide'
      <</show>>

      CheckBoxImg {}
      cardImg {
        background-image:t='<<icon>>'
        <<#color>>
        style:t='background-color:<<color>>;'
        <</color>>
        <<#size>>
        type:t='<<size>>'
        <</size>>
      }
      multiOptionText { text:t='<<text>>' }
    }
    <</list>>
  }
  popup_menu_arrow{}
}