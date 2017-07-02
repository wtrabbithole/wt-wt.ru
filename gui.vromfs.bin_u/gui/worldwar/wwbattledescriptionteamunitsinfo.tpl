tdiv {
  width:t='pw'
  margin-top:t='0.02@scrn_tgt'

  <<#haveUnitsList>>
  tdiv {
    flow:t='vertical'

    <<#invert>>
      pos:t='pw-w-1.5@wwWindowListBackgroundPadding, 0'; position:t='relative'
    <</invert>>
    <<^invert>>
      pos:t='1.5@wwWindowListBackgroundPadding, 0'; position:t='relative'
    <</invert>>
    <<@unitsList>>
  }
  <</haveUnitsList>>
}
