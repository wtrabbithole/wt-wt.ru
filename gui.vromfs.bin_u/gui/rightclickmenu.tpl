root {
  class:t="button"
  behaviour:t="button"
  on_click:t='goBack'
  on_r_click:t='goBack'

  rightClickMenu {
    id:t='rclick_menu_div'
    behaviour:t='wrapNavigator';
    navigatorShortcuts:t='yes';
    childsActivate:t='yes';
    position:t='absolute'
    flow:t='vertical'
    overflow-y:t='auto';
    max-height:t='0.75@rh'

    <<#actions>>

    <<^text>>
    topMenuLine { enable:t='no' }
    <</text>>

    <<#text>>
    Button_text {
      id:t='<<id>>'
      <<^enabled>>inactiveColor:t='yes'<</enabled>>
      text:t='<<textUncolored>>'
      tooltip:t='<<tooltip>>'
      btnName:t='A'
      on_click:t='onMenuButton'

      <<#needTimer>>
      behaviour:t='Timer'
      <</needTimer>>

      textarea {
        id:t='text'
        text:t='<<text>>'
      }
      ButtonImg{}
    }
    <</text>>

    <</actions>>
  }

  dummy {
    on_click:t = 'goBack'
    behaviour:t='accesskey'
    accessKey:t = 'Esc | J:B'
  }
}
