<<#awards>>
div{
  size:t='0.06@shHud, 0.06@shHud'
  margin:t='8*@sf/@pf'

  <<#iconLayers>>
  layeredIconContainer {
    id:t='award_image'
    size:t='ph, ph'
    pos:t='50%pw-50%w, 50%ph-50%h'
    position:t='absolute'
    <<@iconLayers>>
  }
  <</iconLayers>>

  <<#amount>>
  img {
    id:t='award_multiplier'
    background-image:t='#ui/gameuiskin#window_body_shadow'
    pos:t='ph-w, ph-h + 0.2ph'
    position:t='absolute'

    textarea {
      id:t='amount_text'
      style:t='font:medium_text_hud'
      overlayTextColor:t='userlog'
      text:t='<<amount>>'
      removeParagraphIndent:t='yes'
      padding:t='0.2ph'
    }
  }
  <</amount>>
}
<</awards>>
