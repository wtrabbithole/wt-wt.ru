tdiv {
  size:t='1@wwMapPanelInfoWidth, ph'
  flow:t='vertical'

  ownerPanel {
    size:t='pw, 1@ownerPanelHeight'
    margin:t='0, 1@framePadding'

    cardImg {
      pos:t='1@armyGroupTablePadding, 50%ph-50%h'
      position:t='relative'
      background-image:t='<<getCountryIcon>>'
    }

    armyIcon {
      pos:t='1@armyGroupTablePadding, 50%ph-50%h'
      position:t='relative'
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
        text:t='<<getUnitTypeCustomText>>'
        pos:t='50%pw-50%w, 50%ph-50%h'
        position:t='absolute'
      }
      <<#showArmyGroupText>>
      armyGroupText {
        text:t='<<getArmyGroupIdx>>'
        pos:t='50%pw-50%w, 50%ph-50%h'
        position:t='absolute'
      }
      <</showArmyGroupText>>
    }
    activeText {
      text:t='#worldwar/<<getMapObjectName>>'
      pos:t='3@sf/@pf, 50%ph-50%h'
      position:t='relative'
    }

    clanTag {
      pos:t='1@armyGroupTablePadding, 50%ph-50%h'
      position:t='relative'
      hideEmptyText:t='yes'
      text:t='<<clanTag>>'
    }
  }

  statusPanel {
    size:t='pw, 1@statusPanelHeight'
    background-color:t='@objectiveHeaderBackground'

    <<#isFormation>>
      block {
        activeText {
          id:t='army_count'
          tooltip:t='<<getUnitsIconTooltip>>'
          text:t='<<getUnitsCountTextIcon>>'
        }
      }
      block {
        activeText {
          id:t='army_morale'
          tooltip:t='<<getMoraleIconTooltip>>'
          text:t='<<getMoralText>>'
          blockSeparator{}
        }
      }
    <</isFormation>>
    <<^isFormation>>
      block {
        activeText {
          id:t='army_status_time'
          tooltip:t='<<getActionStatusIconTooltip>>'
          text:t='<<getActionStatusTimeText>>'
        }
      }
      block {
        activeText {
          id:t='army_count'
          tooltip:t='<<getUnitsIconTooltip>>'
          text:t='<<getUnitsCountTextIcon>>'
          blockSeparator{}
        }
      }
      <<#isArtillery>>
        block {
          activeText {
            id:t='army_ammo'
            tooltip:t='<<getAmmoTooltip>>'
            text:t='<<getAmmoText>>'
            blockSeparator{}
          }
        }
        block {
          activeText {
            id:t='army_ammo_refill_time'
            tooltip:t='<<getAmmoRefillTimeTooltip>>'
            text:t='<<getAmmoRefillTime>>'
            blockSeparator{}
          }
        }
      <</isArtillery>>
      <<^isArtillery>>
        block {
          activeText {
            id:t='army_morale'
            tooltip:t='<<getMoraleIconTooltip>>'
            text:t='<<getMoralText>>'
            blockSeparator{}
          }
        }
        block {
          activeText {
            id:t='army_return_time'
            tooltip:t='<<getArmyReturnTimeTooltip>>'
            text:t='<<getAirFuelLastTime>>'
            blockSeparator{}
          }
        }
      <</isArtillery>>
    <</isFormation>>
  }

  armyAlertPanel {
    size:t='pw, 0.03@scrn_tgt_font'
    margin-top:t='1'
    isAlert:t='no'
    <<^getArmyInfoText>>
      display:t='hide'
    <</getArmyInfoText>>
    textarea {
      id:t='army_info_text'
      pos:t='0, 50%ph-50%h';
      position:t='relative'
      text-align:t='center'
      width:t='pw'
      tinyFont:t='yes'
      overlayTextColor:t='silver'
      text:t='<<getArmyInfoText>>'
    }
  }

  armyAlertPanel {
    size:t='pw, 0.03@scrn_tgt_font'
    margin-top:t='1'
    isAlert:t='<<isAlert>>'
    <<^getArmyAlertText>>
      display:t='hide'
    <</getArmyAlertText>>
    textarea {
      id:t='army_alert_text'
      pos:t='0, 50%ph-50%h';
      position:t='relative'
      text-align:t='center'
      width:t='pw'
      tinyFont:t='yes'
      overlayTextColor:t='silver'
      text:t='<<getArmyAlertText>>'
    }
  }

  armyGroup {
    id:t='<<name>>'
    width:t='pw'

    <<@unitsList>>
  }
}
