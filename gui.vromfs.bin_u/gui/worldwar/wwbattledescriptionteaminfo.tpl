tdiv {
  padding:t='0, 0.005@scrn_tgt'

  <<#invert>>
    pos:t='pw-w'; position:t='relative'
  <</invert>>

  tdiv {
    flow:t='vertical'

    <<#armies>>
    tdiv {
      <<^invert>>
      img {
        size:t='50*@sf/@pf, 26*@sf/@pf'
        margin:t='1@framePadding, 0'
        background-image:t='<<countryIconBig>>'
      }
      <</invert>>
      wwBattleTeamSize {
        top:t='50%(ph-h)'
        position:t='relative'
        activeText { text:t='<<teamSizeText>>' }
      }
      <<#invert>>
      pos:t='pw-w'; position:t='relative'
      img {
        size:t='50*@sf/@pf, 26*@sf/@pf'
        margin:t='1@framePadding, 0'
        background-image:t='<<countryIconBig>>'
      }
      <</invert>>
    }

    tdiv {
      <<#invert>>
      pos:t='pw-w'; position:t='relative'
      <</invert>>
      tdiv {
        pos:t='0, 50%(ph-h)'; position:t='relative'
        flow:t='h-flow'
        flow-align:t='left'
        <<@armyViews>>
      }
    }
    <</armies>>
  }
}
