<<#connectingElements>>
  <<#shopArrows>>
    shopArrow {
      type:t='<<arrowType>>'
      size:t='<<arrowSize>>'
      pos:t='<<arrowPos>>'
      enable:t='no'
      <<#isDisabled>>isDisabled:t='yes'<</isDisabled>>
    }
  <</shopArrows>>
  <<#conectionsInRow>>
    textareaNoTab {
      width:t='<<conectionWidth>>'
      position:t='absolute'
      pos:t='<<conectionPos>>'
      text:t='+'
      bigBoldFont:t='yes'
      text-align:t='center'
      enable:t='no'
    }
  <</conectionsInRow>>
<</connectingElements>>
<<#separators>>
  <<#separatorPos>>
  craftTreeSeparator {
    pos:t='<<separatorPos>>'
    size:t='<<separatorSize>>'
  }
  <</separatorPos>>
<</separators>>

include "gui/items/craftTreeItemBlock"

