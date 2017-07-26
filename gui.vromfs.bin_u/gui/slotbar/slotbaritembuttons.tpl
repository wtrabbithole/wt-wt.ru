<<#itemButtons>>
<<#hasToBattleButton>>
Button_text {
  id:t='slotBtn_battle'
  class:t='battle'
  text:t=''
  css-hier-invalidate:t='yes'
  on_click:t='<<toBattleButtonPrefix>>Battle'
  navButtonFont:t='yes'

  buttonWink {
    _transp-timer:t='0'
  }

  buttonGlance {}

  pattern {
    type:t='bright_texture'
  }

  btnText {
    id:t='slotBtn_battle_text'
    text:t=''
  }
}
<</hasToBattleButton>>

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
