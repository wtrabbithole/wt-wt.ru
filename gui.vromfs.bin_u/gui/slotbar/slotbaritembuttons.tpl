<<#itemButtons>>
<<#hasToBattleButton>>
Button_text {
  id:t='slotBtn_battle'
  class:t='battle'
  noMargin:t='yes'
  text:t=''
  css-hier-invalidate:t='yes'
  on_click:t='<<toBattleButtonAction>>'
  navButtonFont:t='yes'
  showConsoleImage:t='no'

  buttonWink {
    _transp-timer:t='0'
  }

  buttonGlance {}

  pattern {
    type:t='bright_texture'
  }

  textarea {
    id:t='slotBtn_battle_text'
    font-bold:t='@fontTiny'
    text:t=''
  }
}
<</hasToBattleButton>>

tdiv {
  height:t='@dIco'
  pos:t='0.002@scrn_tgt, ph-h-0.005@scrn_tgt'
  position:t='absolute'
  input-transparent:t='yes'

<<#specIconBlock>>
specIconBlock {
  <<#specTypeIcon>>
  tooltip:t='<<specTypeTooltip>>'
  shopTrainedImg {
    background-image:t='<<specTypeIcon>>'
  }
  <</specTypeIcon>>
  <<#showWarningIcon>>
  warningIcon {
    tooltip:t='#mainmenu/selectCrew/haveMoreQualified/tooltip'
  }
  <</showWarningIcon>>
}
<</specIconBlock>>

<<#hasRepairIcon>>
repairIcon {
  _transp-timer:t='0'
}
<</hasRepairIcon>>

<<#hasWeaponsStatus>>
<<#isWeaponsStatusZero>>
weaponsStatus:t='zero'
<</isWeaponsStatusZero>>
weaponsIcon {
  _transp-timer:t='0'
}
<</hasWeaponsStatus>>
}

<<#hasRentIcon>>
rentIcon {
  id:t='rent_icon'
  <<#hasRentProgress>>
  progress {
    id:t='rent_progress'
    sector-angle-1:t='<<rentProgress>>'
  }
  <</hasRentProgress>>
  icon {}
}
<</hasRentIcon>>

crewStatus:t='<<crewStatus>>'

<<#hasExtraInfoBlock>>
extraInfoBlock {
  <<#hasCrewInfo>>
  crewInfoBlock {
    icon {
      id:t='crew_spec'
      background-image:t='<<crewSpecIcon>>'
    }
    shopItemText {
      id:t='crew_level'
      text:t='<<crewLevel>>'
      _transp-timer:t='0'
    }
  }
  <</hasCrewInfo>>

  <<#hasSpareCount>>
  spareCount { text:t='<<spareCount>>' }
  <</hasSpareCount>>
}
<</hasExtraInfoBlock>>

<<#bonusId>>
bonus {
  id:t='<<bonusId>>-bonus'
  text:t=''
}
<</bonusId>>

<</itemButtons>>
