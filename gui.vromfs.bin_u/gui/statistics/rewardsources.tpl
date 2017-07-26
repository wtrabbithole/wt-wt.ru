<<#multiplier>>
activeText {
  style:t='color:@commonTextColor'
  tinyFont:t='yes'
  parseTags:t='yes'
  text:t='<<multiplier>>'
}
activeText {
  style:t='color:@fadedTextColor'
  tinyFont:t='yes'
  text:t='#ui/multiply'
}
activeText {
  style:t='color:@commonTextColor'
  tinyFont:t='yes'
  text:t='('
}
<</multiplier>>
<<#noBonus>>
activeText {
  style:t='color:@commonTextColor'
  tinyFont:t='yes'
  parseTags:t='yes'
  text:t='<<noBonus>>'
}
<</noBonus>>
<<#premAcc>>
activeText {
  style:t='color:@fadedTextColor'
  tinyFont:t='yes'
  text:t='+'
}
tdiv {
  size:t='0.75@sIco, @sIco'
  pos:t='0, -2@sf/@pf'; position:t='relative'
  img {
    size:t='@sIco, @sIco'; pos:t='pw/2-w/2, 0'; position:t='relative'
    background-image:t='#ui/gameuiskin#item_type_premium'
  }
}
activeText {
  style:t='color:@chapterUnlockedColor'
  tinyFont:t='yes'
  parseTags:t='yes'
  text:t='<<premAcc>>'
}
<</premAcc>>
<<#premMod>>
activeText {
  style:t='color:@fadedTextColor'
  tinyFont:t='yes'
  text:t='+'
}
tdiv {
  size:t='0.95@sIco, @sIco'
  pos:t='0, -2@sf/@pf'; position:t='relative'
  img {
    size:t='@sIco, @sIco'; pos:t='pw/2-w/2, 0'; position:t='relative'
    background-image:t='#ui/gameuiskin#item_type_talisman'
  }
}
activeText {
  style:t='color:@chapterUnlockedColor'
  tinyFont:t='yes'
  parseTags:t='yes'
  text:t='<<premMod>>'
}
<</premMod>>
<<#booster>>
activeText {
  style:t='color:@fadedTextColor'
  tinyFont:t='yes'
  text:t='+'
}
tdiv {
  size:t='0.75@sIco, @sIco'
  pos:t='0, -2@sf/@pf'; position:t='relative'
  img {
    size:t='@sIco, @sIco'; pos:t='pw/2-w/2, 0'; position:t='relative'
    background-image:t='#ui/gameuiskin#item_type_boosters'
  }
}
activeText {
  style:t='color:@linkTextColor'
  tinyFont:t='yes'
  parseTags:t='yes'
  text:t='<<booster>>'
}
<</booster>>
<<#multiplier>>
activeText {
  style:t='color:@commonTextColor'
  tinyFont:t='yes'
  text:t=')'
}
<</multiplier>>
