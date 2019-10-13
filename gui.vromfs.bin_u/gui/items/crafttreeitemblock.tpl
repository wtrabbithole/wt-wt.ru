<<#itemBlock>>
  itemBlock {
  <<#hasComponent>>hasComponent:t='yes'<</hasComponent>>
  <<#isDisabled>>isDisabled:t='yes'<</isDisabled>>
    id:t='<<itemId>>'
    <<#blockPos>>
      pos:t='<<blockPos>>'
      position:t='absolute'
    <</blockPos>>
    <<#isFullSize>>isFullSize:t='yes'<</isFullSize>>
    include "gui/items/item"
    tdiv {
      margin-left:t='1@blockInterval'
      <<#component>><<@component>><</component>>
    }
  }
<</itemBlock>>