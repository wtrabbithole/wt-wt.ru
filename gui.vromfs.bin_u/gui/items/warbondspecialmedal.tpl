<<#medal>>
warbondSpecialMedal {
  size:t='1@battleTasksHardMedalWidth, 0.05@sf'
  pos:t='<<#posX>><<posX>><</posX>><<^posX>>0<</posX>>, 50%ph-50%h'
  position:t='relative'

  <<#sector>>
    warbondSpecialMedalImg {
      background-image:t='<<image>>'
      background-position:t='0'
      background-repeat:t='aspect-ratio'
      background-color:t='#80404040'
      size:t='pw, ph'
      pos:t='50%pw-50%w, 50%ph-50%h'
      position:t='absolute'
    }
  <</sector>>

  warbondSpecialMedalImg {
    background-image:t='<<image>>'
    background-position:t='0'
    background-repeat:t='aspect-ratio'
    background-color:t='@white'
    size:t='pw, ph'
    pos:t='50%pw-50%w, 50%ph-50%h'
    position:t='absolute'
    <<#sector>>
      re-type:t='sector'
      sector-angle-1:t='<<sector>>'
      sector-angle-2:t='360'
    <</sector>>
  }
}
<</medal>>