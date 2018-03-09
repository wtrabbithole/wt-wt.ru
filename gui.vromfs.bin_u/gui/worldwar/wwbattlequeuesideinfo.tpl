tdiv {
  flow:t='vertical'
  margin-bottom:t='0.03@scrn_tgt'

  <<#armies>>
  img {
    size:t='50*@sf/@pf_outdated, 26*@sf/@pf_outdated'
    margin-bottom:t='0.01@scrn_tgt'
    background-image:t='<<countryIconBig>>'
  }

  tdiv {
    margin-bottom:t='0.01@scrn_tgt'
    activeText { text:t='#events/handicap' }
    activeText { text:t='<<maxPlayers>>' }
  }
  <</armies>>

  table {
    class:t='noPad'
    tr {
      td {
        cellType:t='right'
        optiontext {
          text:t='#worldwar/airfieldStrenght/clans_players'
          tooltip:t='#worldwar/airfieldStrenght/clans_players/tooltip'
          padding-right:t='0.05@scrn_tgt'
        }
      }
      td {
        optiontext {
          id:t='players_in_clans_count'
          text:t='#event_dash'
        }
      }
    }

    tr {
      td {
        cellType:t='right'
        optiontext {
          text:t='#worldwar/airfieldStrenght/other'
          padding-right:t='0.05@scrn_tgt'
        }
      }
      td {
        optiontext {
          id:t='other_players_count'
          text:t='#event_dash'
        }
      }
    }
  }
}
