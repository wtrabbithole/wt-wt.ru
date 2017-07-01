<<#checkbox>>
CheckBox {
  id:t='<<id>>'
  pos:t='0, 0'
  position:t='relative'
  value:t='<<#value>>yes<</value>><<^value>>no<</value>>'
  text:t='<<text>>'
  tooltip:t='<<tooltip>>'
  <<#onChangeValue>>
    on_change_value:t='<<onChangeValue>>'
  <</onChangeValue>>

  <<#useImage>>
    class:t='with_image'
  <</useImage>>

  <<#hide>>
    display:t='hide'
    enable:t='no'
  <</hide>>

  <<#useImage>>
    infoImg { background-image:t='<<useImage>>' }
  <</useImage>>

  CheckBoxImg {}
}
<</checkbox>>
