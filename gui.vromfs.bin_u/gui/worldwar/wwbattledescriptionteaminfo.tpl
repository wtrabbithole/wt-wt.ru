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
        margin-right:t='15*@sf/@pf'
        pos:t='0, 50%(ph-h)'; position:t='relative'
        background-image:t='<<countryIconBig>>'
      }
      tdiv {
        pos:t='0, 50%(ph-h)'; position:t='relative'
        flow:t='h-flow'
        flow-align:t='left'
        <<@armyViews>>
      }
      <</invert>>
      <<#invert>>
      pos:t='pw-w'; position:t='relative'
      tdiv {
        pos:t='0, 50%(ph-h)'; position:t='relative'
        flow:t='h-flow'
        flow-align:t='left'
        <<@armyViews>>
      }
      img {
        size:t='50*@sf/@pf, 26*@sf/@pf'
        pos:t='0, 50%(ph-h)'; position:t='relative'
        background-image:t='<<countryIconBig>>'
      }
      <</invert>>
    }
    <</armies>>

    wwBattleTeamSize {
      <<#invert>>
      pos:t='pw-w'; position:t='relative'
      <</invert>>
      <<#hasTeamSize>>
      activeText { text:t='#events/players_short'; fontNormal:t='yes' }
      activeText { text:t='<<minPlayers>> - <<maxPlayers>>'; fontNormal:t='yes' }
      <</hasTeamSize>>
      <<^hasTeamSize>>
      activeText { text:t='#worldWar/unavailable_for_team'; fontNormal:t='yes' }
      <</hasTeamSize>>
    }
  }
}
