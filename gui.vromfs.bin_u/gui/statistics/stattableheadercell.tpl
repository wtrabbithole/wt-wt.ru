<<#cells>>
td {
  id:t='<<id>>';
  width:t='<<width>>';
  tooltip:t='<<tooltip>>';
  <<@customParams>>

  <<#fontIcon>>
  fontIcon32 {
    fonticon { text:t='<<fontIcon>>' }
  }
  <</fontIcon>>
  <<^fontIcon>>
  <<#tooltip>>
  activeText {
    position:t='relative'
    pos:t='pw/2-w/2, ph/2-h/2'
    max-width:t='pw'
    pare-text:t='yes'
    halign:t='center'
    text:t='<<tooltip>>'
  }
  <</tooltip>>
  <</fontIcon>>
}
<</cells>>
