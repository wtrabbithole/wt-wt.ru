<<#items>>
imgFrame {
  backlight {
    unlockedObject:t='<<#unlocked>>yes<</unlocked>><<^unlocked>>no<</unlocked>>'
  }

  img {
    size:t='1@profileMedalSize, 1@profileMedalSize'
    <<#imgRatio>>
    max-width:t='<<imgRatio>>h'
    max-height:t='w/<<imgRatio>>'
    <</imgRatio>>
    position:t='relative'
    background-image:t='<<image>>'
    <<^unlocked>>
      style:t='background-color:@lockedDecal;'
    <</unlocked>>
  }

  <<#tooltipId>>
  tooltipObj {
    id:t='tooltip_<<tooltipId>>'
    tooltipId:t='<<tooltipId>>'
    on_tooltip_open:t='onGenericTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
    display:t='hide'
  } title:t='$tooltipObj'
  <</tooltipId>>
}
<</items>>
