tdiv {
  height:t='ph'
  flow:t='vertical'
  padding:t='1@framePadding'

  <<#isInvert>>
    left:t='pw-w'; position:t='relative'
  <</isInvert>>

  textareaNoTab {
    margin-bottom:t='1@framePadding'
    text:t='#worldwar/operation/participating_clans'
    overlayTextColor:t='active'
  }

  <<#columns>>
  tdiv {
    height:t='ph'
    flow:t='vertical'
    <<#isInvert>>
      left:t='pw-w'; position:t='relative'
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
          left:t='pw-w'; position:t='relative'
        <</isInvert>>
        text:t='<<name>>'
      }
    <</armyGroupNames>>
  }
  <</columns>>
}