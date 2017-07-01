tdiv {
  id:t='battle_head'
  size:t='fw, ph'
  flow:t='vertical'

  div {
    size:t='pw, fh'
    overflow-y:t='auto'
    flow:t='vertical'
    scrollbarShortcuts:t='yes'

    tdiv {
      width:t='pw'
      padding:t='3*@sf/@pf'

      <<#teamBlock>>
      tdiv {
        size:t='50%pw - 2*@sf/@pf, fh'
        flow:t='vertical'

        <<#armies>>
        tdiv {
          width:t='pw'
          height:t='1@mIco'
          <<^invert>>flow-align:t='left'<</invert>>
          <<#invert>>flow-align:t='right'<</invert>>
          margin-top:t='0.005@scrn_tgt'

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
              background-image:t='#ui/gameuiskin#ww_army'
              foreground-image:t='#ui/gameuiskin#ww_select_army'
              pos:t='50%pw-50%w, 50%ph-50%h'
              position:t='absolute'
            }
            armyUnitType {
              text:t='<<getUnitTypeText>>'
              pos:t='50%pw-50%w, 50%ph-50%h'
              position:t='absolute'
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
  }
}
