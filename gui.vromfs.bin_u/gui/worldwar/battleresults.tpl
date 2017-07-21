tdiv {
  id:t='battle_results'
  size:t='pw, ph'
  flow:t='vertical'

  tdiv {
    width:t='pw'
    padding:t='1@debrPad'
    background-color:t='@shadeBackgroundColor4'

    tdiv {
      size:t='pw, 26*@sf/@pf'
      pos:t='0, 1@debrPad'
      position:t='absolute'

      textareaNoTab {
        pos:t='pw/2-w/2, ph/2-h/2'
        position:t='absolute'
        text:t='<<getBattleResultText>>'
        fontNormal:t='yes'
      }

      <<#isBattleResultsIgnored>>
      textareaNoTab {
        max-width:t='pw-120@sf/@pf'
        pos:t='pw/2-w/2, ph'
        position:t='absolute'
        text-align:t='center'
        text:t='#worldwar/operation_complete_battle_results_ignored'
        overlayTextColor:t='userlog'
      }
      <</isBattleResultsIgnored>>
    }

    <<#teamBlock>>
    tdiv {
      size:t='50%pw'
      flow:t='vertical'

      img{
        position:t='relative'
        iconType:t='small_country'
        <<^invert>>pos:t='0, 0'<</invert>>
        <<#invert>>pos:t='pw-w, 0'<</invert>>
        background-image:t='<<countryIcon>>'
      }

      <<#armies>>
      tdiv {
        size:t='pw, 1@mIco'
        margin-top:t='0.005@scrn_tgt'
        <<^invert>>flow-align:t='left'<</invert>>
        <<#invert>>flow-align:t='right'<</invert>>

        <<#armyView>>
        <<#invert>>
        textareaNoTab {
          valign:t='center'
          caption:t='yes'
          text:t='<<getTextAfterIcon>>'
        }
        <</invert>>
        armyIcon {
          team:t='<<getTeamColor>>'
          <<#isBelongsToMyClan>>
          isBelongsToMyClan:t='yes'
          <</isBelongsToMyClan>>

          background {
            pos:t='50%pw-50%w, 50%ph-50%h'
            position:t='absolute'
            background-image:t='#ui/gameuiskin#ww_army'
            foreground-image:t='#ui/gameuiskin#ww_select_army'
          }
          armyUnitType {
            pos:t='50%pw-50%w, 50%ph-50%h'
            position:t='absolute'
            text:t='<<getUnitTypeCustomText>>'
          }
        }
        <<^invert>>
        textareaNoTab {
          valign:t='center'
          caption:t='yes'
          text:t='<<getTextAfterIcon>>'
        }
        <</invert>>
        <</armyView>>
      }

      tdiv {
        width:t='pw'
        <<^invert>>flow-align:t='left'<</invert>>
        <<#invert>>flow-align:t='right'<</invert>>

        textareaNoTab {
          veryTinyFont:t='yes'
          text:t='<<armyStateText>>'
        }
      }
      <</armies>>
    }
    <</teamBlock>>
  }

  tdiv {
    size:t='pw, fh'
    pos:t='0, 1@debrPad'
    position:t='relative'
    overflow-y:t='auto'

    <<#teamBlock>>
    <<#statistics>>
    tdiv {
      width:t='(pw -1@debrPad)/2'
      min-height:t='ph'
      <<^invert>>pos:t='0, 0'<</invert>>
      <<#invert>>pos:t='1@debrPad, 0'<</invert>>
      position:t='relative'
      padding:t='1@debrPad'
      background-color:t='@shadeBackgroundColor4'
      flow:t='vertical'

      tdiv {
        width:t='pw'
        padding:t='1@debrPad, 0, 0, 0'

        textareaNoTab {
          width:t='0.3pw+@tableIcoSize'
          text:t=''
        }
        textareaNoTab {
          width:t='0.2pw'
          text-align:t='center'
          text:t='#debriefing/ww_engaged'
        }
        textareaNoTab {
          width:t='0.2pw'
          text-align:t='center'
          text:t='#debriefing/ww_casualties'
        }
        textareaNoTab {
          width:t='0.2pw'
          text-align:t='center'
          text:t='#debriefing/ww_left'
        }
      }

      tdiv {
        size:t='pw, @tableIcoSize'
      }

      <<#unitTypes>>
      tdiv {
        width:t='pw'
        padding:t='1@debrPad, 0, 0, 0'

        textareaNoTab {
          width:t='0.3pw + @tableIcoSize'
          pos:t='0, ph/2-h/2'
          position:t='relative'
          pare-text:t='yes'
          text:t='<<name>>'
        }

        <<#row>>
          textareaNoTab {
            width:t='0.2pw'
            pos:t='0, ph/2-h/2'
            position:t='relative'
            text-align:t='center'
            text:t='<<col>>'
            <<#tooltip>>
            tooltip:t='<<tooltip>>'
            <</tooltip>>
          }
        <</row>>
      }
      <</unitTypes>>

      tdiv {
        size:t='pw, @tableIcoSize'
      }

      <<#units>>
      tdiv {
        width:t='pw'
        padding:t='1@debrPad, 0, 0, 0'

        tdiv {
          width:t='0.3pw + @tableIcoSize'
          pos:t='0, ph/2-h/2'
          position:t='relative'

          include "gui/worldWar/worldWarArmyInfoUnitString"
        }

        <<#row>>
          textareaNoTab {
            width:t='0.2pw'
            pos:t='0, ph/2-h/2'
            position:t='relative'
            text-align:t='center'
            text:t='<<col>>'
            <<#tooltip>>
            tooltip:t='<<tooltip>>'
            <</tooltip>>
          }
        <</row>>
      }
      <</units>>
    }
    <</statistics>>
    <</teamBlock>>
  }
}
