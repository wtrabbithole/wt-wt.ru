textareaNoTab {
  id:t='no_active_battles_full_text'
  width:t='pw'
  margin-top:t='0.01@scrn_tgt'
  text-align:t='center'
  text:t='#worldwar/operation/noActiveBattlesFullText'
}

tdiv {
  id:t='battle_desc'
  size:t='pw, ph'
  pos:t='0, 0'; position:t='relative'
  flow:t='vertical'

  tdiv {
    size:t='pw, ph'
    left:t='50%pw-50%w'
    position:t='absolute'
    overflow:t='hidden'

    img {
      size:t='pw, 50%w'
      max-height:t='ph'

      background-image:t='#ui/images/worldwar_window_bg_image.jpg?P1'
      background-position:t='6,6'

      wwBattleBackgroundShadow { type:t='left'   }
      wwBattleBackgroundShadow { type:t='right'  }
      wwBattleBackgroundShadow { type:t='top'    }
      wwBattleBackgroundShadow { type:t='bottom'; top:t='ph-h' }
    }
  }

  div {
    size:t='pw, ph'
    padding:t='1@framePadding'
    flow:t='vertical'

    div {
      size:t='pw, 0.14@scrn_tgt'
      position:t='absolute'
      margin-top:t='0.01@scrn_tgt+0.03@wwBattleInfoScreenIncHeight'
      flow:t='vertical'

      textareaNoTab {
        width:t='pw'
        text:t='<<#getBattleName>><<getBattleName>> <</getBattleName>><<getMissionName>>'
        text-align:t='center'
        mediumFont:t='yes'
      }

      activeText {
        id:t='battle_status_text'
        left:t='50%pw-50%w'
        position:t='relative'
        margin-top:t='1@framePadding'
        text:t='<<getBattleStatusWithCanJoinText>>'
      }

      textareaNoTab {
        position:t='relative'
        width:t='pw'
        padding:t='10%pw, 0'
        text:t='<<getBattleStatusDescText>>'
        text-align:t='center'
      }
    }

    tdiv {
      size:t='pw, 75%ph'
      top:t='ph-h'
      position:t='relative'
      flow:t='vertical'

      tdiv {
        width:t='pw'
        margin-bottom:t='0.15@wwBattleInfoScreenIncHeight'

        tdiv {
          id:t='team_header_info_0'
          width:t='50%pw'
        }

        tdiv {
          id:t='team_header_info_1'
          width:t='50%pw'
        }
      }

      tdiv {
        size:t='pw, fh'

        tdiv {
          size:t='pw, ph'
          position:t='absolute'

          wwWindowListBackground {
            size:t='25%pw, ph'
            type:t='left'
          }
          wwWindowListBackground {
            size:t='25%pw, ph'
            left:t='pw-2w'
            position:t='relative'
            type:t='right'
          }
        }

        tdiv {
          size:t='pw, ph'
          overflow-y:t='auto'
          scrollbarShortcuts:t='yes'

          tdiv {
            id:t='team_unit_info_0'
            width:t='35%pw'
          }
          tdiv {
            id:t='team_unit_info_1'
            width:t='35%pw'
            left:t='pw-2w'
            position:t='relative'
          }
        }
      }
    }

    <<#isStarted>>
    tdiv {
      width:t='25%pw'
      pos:t='50%pw-50%w, ph-h-0.02@scrn_tgt-0.15@wwBattleInfoScreenIncHeight'
      position:t='absolute'
      flow:t='vertical'

      ShadowPlate {
        size:t='pw, w'
        max-width:t='1@wwBattleInfoMapMaxSize'
        pos:t='50%pw-50%w, 0'; position:t='relative'
        padding:t='1@wwBattleMapShadowPadding, 0, 1@wwBattleMapShadowPadding, 1.5@wwBattleMapShadowPadding'
        tacticalMap {
          id:t='tactical_map_single'
          size:t='pw, ph'
          display:t='hide'
        }
      }

      textareaNoTab {
        id:t='battle_time_text'
        pos:t='50%pw-50%w, 0'; position:t='relative'
        text:t=''
      }
    }
    <</isStarted>>
  }
}
