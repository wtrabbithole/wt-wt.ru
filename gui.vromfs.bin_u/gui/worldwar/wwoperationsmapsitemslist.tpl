<<#items>>
  <<itemTag>><<^itemTag>>mission_item_unlocked<</itemTag>> {
    id:t='<<id>>'
    <<#isSelected>>
    selected:t='yes'
    <</isSelected>>

    <<#isCollapsable>>
    collapse_header:t='yes'
    collapsed:t='no'
    collapsing:t='no'
    <</isCollapsable>>

    <<#itemClass>>
    class:t='<<itemClass>>'
    <</itemClass>>

    img {
      id:t='medal_icon'
      medalIcon:t='yes'
      background-image:t='<<itemIcon>>'
      <<#iconColor>>
        style:t='background-color:<<iconColor>>'
      <</iconColor>>
    }

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
        <<^isActive>>
        overlayTextColor:t='disabled'
        <</isActive>>
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

    div {
      id:t='countries_selection_<<id>>'
      pos:t='pw-w, ph/2-h/2'
      position:t='absolute'

      include "gui/commonParts/checkbox"
    }
  }
<</items>>