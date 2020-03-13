ComboBox {
  <<#id>>
    id:t='<<id>>'
  <</id>>
  width:t='<<#width>><<width>><</width>><<^width>>pw<</width>>'
  <<#btnName>>
    btnName:t='<<btnName>>'
  <</btnName>>
  <<#isHidden>>
    display:t='hide'
    enable:t='no'
  <</isHidden>>
  <<#funcName>>
    on_select:t='<<funcName>>'
  <</funcName>>

  <<#values>>
    option {
      <<#valueId>>
        id:t='<<valueId>>'
      <</valueId>>
      <<#unseenIcon>>
        unseenIcon {
          <<#unseenIconId>>id:t='<<unseenIconId>>'<</unseenIconId>>
          valign:t='center'
          value:t='<<unseenIcon>>'
          unseenText {}
        }
      <</unseenIcon>>
      optiontext {
        text:t='<<text>>'
      }
    }
  <</values>>
}
