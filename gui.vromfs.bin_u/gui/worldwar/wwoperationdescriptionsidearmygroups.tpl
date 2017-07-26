tdiv {
  height:t='ph'

  <<#isInvert>>
    pos:t='pw-w, 0'; position:t='relative'
  <</isInvert>>

  <<#columns>>
  tdiv {
    height:t='ph'
    flow:t='vertical'

    <<#isInvert>>
      margin-right:t='@wwWindowListBackgroundPadding'
    <</isInvert>>

    <<^isInvert>>
      margin-left:t='@wwWindowListBackgroundPadding'
    <</isInvert>>

    <<#armyGroupNames>>
      textareaNoTab {
        <<^isSingleColumn>>
          height:t='@leaderboardTrHeight'
        <</isSingleColumn>>
        <<#isSingleColumn>>
          height:t='fh'
          max-height:t='1.3@leaderboardTrHeight'
        <</isSingleColumn>>

        <<#isInvert>>
          pos:t='pw-w, 0'; position:t='relative'
        <</isInvert>>

        text:t='<<name>>'
      }
    <</armyGroupNames>>
  }
  <</columns>>
}