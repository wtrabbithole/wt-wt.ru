<<itemTag>><<^itemTag>>mission_item_unlocked<</itemTag>> {
  id:t='<<id>>'
  <<#isSelected>>
  selected:t='yes'
  <</isSelected>>

  <<#isCollapsable>>
  collapsed:t='no'
  collapsing:t='no'
  <</isCollapsable>>

  <<#itemClass>>
  class:t='<<itemClass>>'
  <</itemClass>>

  <<#itemPrefixText>>
  hasItemPrefixText:t='yes'
  mission_item_text {
    id:t='mission_item_prefix_text_<<id>>'
    pos:t='0, 50%(ph-h)'
    text:t='<<itemPrefixText>>'
  }
  <</itemPrefixText>>

  img {
    id:t='medal_icon'
    medalIcon:t='yes'
    background-image:t='<<itemIcon>>'
    <<#iconColor>>
      style:t='background-color:<<iconColor>>'
    <</iconColor>>
    <<#isLastPlayedIcon>>
      isLastPlayedIcon:t='yes'
    <</isLastPlayedIcon>>
  }

  <<#checkBoxActionName>>
  CheckBox {
    id:t='checkbox_<<id>>'
    pos:t='@missionBoxImageOffsetX - 50%w, 50%ph - 50%h'
    position:t='absolute'
    class:t='empty'
    value:t='<<isChosen>>'
    on_change_value:t='<<checkBoxActionName>>'
    CheckBoxImg{}
  }
  <</checkBoxActionName>>

  <<#hasWaitAnim>>
  animated_wait_icon {
    id:t = 'wait_icon_<<id>>'
    class:t='missionBox'
    background-rotation:t = '0'
    wait_icon_cock {}
  }
  <</hasWaitAnim>>

  missionDiv {
    css-hier-invalidate:t='yes'
    <<#newIconWidgetLayout>>
    div {
      id:t='new_icon_widget_<<id>>'
      css-hier-invalidate:t='yes'
      <<@newIconWidgetLayout>>
    }
    <</newIconWidgetLayout>>

    mission_item_text {
      id:t = 'txt_<<id>>'
      text:t = '<<itemText>>'
    }
  }

  <<#isSpecial>>
  img { medalIcon:t='dlc' }
  <</isSpecial>>

  <<#isCollapsable>>
  fullSizeCollapseBtn {
    id:t='btn_<<id>>'
    css-hier-invalidate:t='yes'
    activeText{}
  }
  <</isCollapsable>>

  <<#discountText>>
  discount {
    id:t='mis-discount'
    text:t='<<discountText>>'
  }
  <</discountText>>
}