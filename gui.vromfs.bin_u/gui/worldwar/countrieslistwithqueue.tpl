<<#countries>>
tdiv {
  margin:t='0.005@scrn_tgt_font, 0'
  flow:t='vertical'

  img {
    pos:t='pw/2-w/2, 0'
    position:t='relative'
    id:t='<<countryName>>'
    size:t='@cIco, @cIco'
    background-image:t='<<countryIcon>>'
  }

  <<#amount>>
  textareaNoTab {
    pos:t='pw/2-w/2, 0'
    position:t='relative'
    text:t='<<amount>>'
    overlayTextColor:t='<<#isJoined>>userlog<</isJoined>><<^isJoined>>active<</isJoined>>'
  }
  <</amount>>
}
<</countries>>
