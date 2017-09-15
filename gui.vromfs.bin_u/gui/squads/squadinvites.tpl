<<#items>>
emptyButton {
  id:t='squad_invite_<<id>>'
  class:t='squadWidgetInvite'
  uid:t='<<id>>'
  title:t='$tooltipObj'
  on_click:t='onMemberClicked'
  on_r_click:t='onMemberClicked'

  img {
    background-image:t='<<pilotIcon>>'
  }

  animated_wait_icon {
    background-rotation:t='0'
  }

  tooltipObj {
    uid:t='<<id>>'
    on_tooltip_open:t='onContactTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
    display:t='hide'
  }
}
<</items>>