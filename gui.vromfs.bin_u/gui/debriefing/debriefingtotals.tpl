<<#showTeaser>>
tdiv{
  pos:t='0, 0'; position='relative'
  flow:t='vertical'
  tooltip:t='<<teaserTooltip>>'

  activeText{
    pos:t='pw-w, 0'; position:t='relative'
    padding-bottom:t='0.004@sf'
    noMargin:t='yes'
    talign:t='right'
    text:t='#debriefing/withPremium'
    style:t='color:@disabledTextColor;'
    tinyFont:t='yes'
  }
  activeText{
    id:t='expTeaser'
    pos:t='pw-w, 0'; position:t='relative'
    noMargin:t='yes'
    talign:t='right'
    text:t='<<expTeaser>>'
    style:t='color:@disabledTextColor;'
  }
  activeText{
    id:t='wpTeaser'
    pos:t='pw-w, 0'; position:t='relative'
    noMargin:t='yes'
    talign:t='right'
    text:t='<<wpTeaser>>'
    style:t='color:@disabledTextColor;'
  }
}
<</showTeaser>>

tdiv{
  pos:t='0.01@sf, 0'; position='relative'
  flow:t='vertical'

  <<#showTeaser>>
  activeText{
    pos:t='pw-w, 0'; position:t='relative'
    padding-bottom:t='0.004@sf'
    noMargin:t='yes'
    talign:t='right'
    text:t='#debriefing/withoutPremium'
    tinyFont:t='yes'
  }
  <</showTeaser>>
  activeText{
    id:t='exp'
    min-width:t='0.1@sf'
    pos:t='pw-w, 0'; position:t='relative'
    padding-right:t='0.03@sf'
    noMargin:t='yes'
    talign:t='right'
    <<^canSuggestPrem>>
    caption:t='yes'
    <</canSuggestPrem>>
    text:t='<<exp>>'

    img{
      height:t='0.03@sf'; width:t='h'
      pos:t='pw-85%w, ph/2-h/2'; position:t='absolute'
      background-image:t='#ui/gameuiskin#convert_rp'
    }
  }
  activeText{
    id:t='wp'
    min-width:t='0.1@sf'
    pos:t='pw-w, 0'; position:t='relative'
    padding-right:t='0.03@sf'
    noMargin:t='yes'
    talign:t='right'
    <<^canSuggestPrem>>
    caption:t='yes'
    <</canSuggestPrem>>
    text:t='<<wp>>'

    tdiv{
      height:t='0.03@sf'; width:t='h'
      pos:t='pw-85%w, ph/2-h/2'; position:t='absolute'
      img{
        size:t='80%ph, 80%ph'
        pos:t='pw/2-w/2, ph/2-h/2'; position:t='absolute'
        background-image:t='#ui/gameuiskin#shop_warpoints'
      }
    }
  }
}
