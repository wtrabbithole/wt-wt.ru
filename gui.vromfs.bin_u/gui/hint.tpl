hint {
  id:t='<<id>>'
  behaviour:t='Timer'
  hintStyle:t='<<style>>'

  <<#isOrderPopup>>
  order-popup:t='yes'
  <</isOrderPopup>>

  <<#rows>>
  hintRow {
    <<#isWrapInRowAllowed>>
    width:t='p.p.w'
    flow:t='h-flow'
    <</isWrapInRowAllowed>>
    flow-align:t='<<flowAlign>>'
    <<#slices>>
    <<#shortcut>>
    <<@shortcut>>
    <</shortcut>>
    <<#timer>>
    timeBar {
      id:t='time_bar'
      size:t='0.06@shHud, 0.06@shHud'
      <<#timerOffsetX>>
      pos:t='<<timerOffsetX>>, @hintRowCenterOffsetY - 50%h'
      <</timerOffsetX>>

      <<#hideWhenStopped>>
      hideWhenStopped:t='yes'
      <</hideWhenStopped>>
      inc-factor:t='<<incFactor>>'
      sector-angle-2:t='<<angle>><<^angle>>0<</angle>>'

      textareaNoTab {
        mark:t=''
        id:t='time_text'
        position:t='absolute'
        pos:t='pw/2 - w/2, ph/2 - h/2'
        text:t='<<total>>'
      }

      background-color:t='@white';
      background-image:t='#ui/gameuiskin#circular_progress_1';

      tdiv {
        position:t='absolute'
        size:t='pw, ph'
        background-color:t='#33555555';
        background-image:t='#ui/gameuiskin#circular_progress_1';
      }
    }
    <</timer>>
    <<#image>>
    img {
      size:t='0.06@shHud, 0.06@shHud'
      pos:t='0, @hintRowCenterOffsetY - 50%h'
      position:t='relative'
      background-image:t='<<image>>'
      background-repeat:t='aspect-ratio'
    }
    <</image>>
    <<#text>>
    textareaNoTab {
      text:t='<<text>>'
    }
    <</text>>
    <</slices>>
  }
  <</rows>>
}