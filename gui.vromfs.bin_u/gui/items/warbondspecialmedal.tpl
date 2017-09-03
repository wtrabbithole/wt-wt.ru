<<#medal>>
warbondSpecialMedal {
  width:t='1@battleTasksHardMedalWidth'
  height:t='w'
  pos:t='<<#posX>><<posX>><</posX>><<^posX>>0<</posX>>, 0'
  position:t='relative'

  <<#sector>>
    warbondSpecialMedalImg {
      background-image:t='<<image>>'
      background-position:t='0'
      background-repeat:t='aspect-ratio'
      background-color:t='@inactiveWarbondMedalImgColor'
      size:t='pw, ph'
      pos:t='50%pw-50%w, 50%ph-50%h'
      position:t='absolute'
    }
  <</sector>>

  warbondSpecialMedalImg {
    background-image:t='<<image>>'
    background-position:t='0'
    background-repeat:t='aspect-ratio'
    <<#inactive>>
      background-color:t='@inactiveWarbondMedalImgColor'
    <</inactive>>
    <<^inactive>>
      background-color:t='@warbondMedalImgColor'
    <</inactive>>

    size:t='pw, ph'
    pos:t='50%pw-50%w, 50%ph-50%h'
    position:t='absolute'
    <<#sector>>
      re-type:t='sector'
      sector-angle-1:t='<<sector>>'
      sector-angle-2:t='360'
    <</sector>>
  }
  <<#countText>>
    textareaNoTab {
      pos:t='1@battleTasksHardMedalWidth, 50%ph-50%h'
      position:t='absolute'
      text:t='x<<countText>>'
      caption:t='yes'
    }
  <</countText>>
}
<</medal>>