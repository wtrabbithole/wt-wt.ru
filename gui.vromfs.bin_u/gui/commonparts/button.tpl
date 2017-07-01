<<#isHyperlink>>
  button {
    talign:t='left'
    on_click:t='onMsgLink'

    <<#acccessKeyName>>
      height:t="1@buttonHeight"
      btnName:t=<<acccessKeyName>>
      showConsoleImg:t='yes'
      ButtonImg {}
    <</acccessKeyName>>

    underline{}
<</isHyperlink>>

<<^isHyperlink>>
  Button_text {
  <<#funcName>>
    <<#delayed>>_<</delayed>>on_click:t='<<funcName>>'
  <</funcName>>
<</isHyperlink>>

  id:t='<<id>>'
  text:t='<<text>>'
  <<#isHidden>>
    display:t='hide'
    enable:t='no'
  <</isHidden>>
  <<#isEmptyButton>>
    enable:t='no'
    inactive:t='yes'
  <</isEmptyButton>>

  <<#visualStyle>>
    visualStyle:t='<<visualStyle>>'
  <</visualStyle>>

  <<^isToBattle>>
    <<#class>>
      class:t='<<class>>'
    <</class>>
  <</isToBattle>>
  <<^isToBattle>>
    <<#buttonClass>>
      class:t='<<buttonClass>>'
    <</buttonClass>>
  <</isToBattle>>

  <<#isToBattle>>
    class:t='battle'
    css-hier-invalidate:t='yes'
    <<^titleButtonFont>>
      navButtonFont:t='yes'
    <</titleButtonFont>>
    <<#titleButtonFont>>
      style:t='height:1@battleButtonHeight;'
    <</titleButtonFont>>
    buttonWink { _transp-timer:t='0' }
    buttonGlance {}
    btnText {
      id:t='<<id>>_text'
      text:t='<<text>>'
    }
  <</isToBattle>>

  <<#shortcut>>
    btnName:t='<<shortcut>>'
    ButtonImg {}
  <</shortcut>>

  <<#style>>
    style:t='<<style>>'
  <</style>>

  <<#link>>
    link:t='<<link>>'
    <<#isLink>>
      isLink:t='yes'
      <<#isFeatured>>
        isFeatured:t='yes'
        hideText:t='yes'
      <</isFeatured>>

      btnText {
        id:t='<<id>>_text'
        position:t='relative';
        pos:t='50%pw-50%w, 50%ph-50%h';
        <<^isFeatured>>
          hideText:t='yes'
        <</isFeatured>>

        text:t='<<text>>'
        font:t='@small'
        css-hier-invalidate:t='yes'
        underline{}
      }
    <</isLink>>
  <</link>>

  <<#type>>
    type:t='<<type>>'
  <</type>>
}
