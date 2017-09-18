<<#updateTime>>
activeText {
  id:t='lb_update_time'
  pos:t='0, 50%ph-50%h'; position:t='relative'
  margin-right:t='1@blockInterval'
  caption:t='no'
  text:t=''
  textHide:t='no'
}
<</updateTime>>
<<#monthCheckbox>>
CheckBox {
  id:t='btn_type'
  pos:t='0, 50%ph-50%h'; position:t='relative'
  text:t='#mainmenu/btnMonthLb'
  margin-right:t='2*@scrn_tgt/100.0'
  on_change_value:t='onChangeType'
  value:t='<<monthCbValue>>'
  CheckBoxImg{}
}
<</monthCheckbox>>