<<#items>>
mission_item_unlocked {
  id:t='<<id>>'
  <<#isSelected>>
  selected:t='yes'
  <</isSelected>>

  <<#isCollapsable>>
  collapse_header:t='yes'
  collapsed:t='no'
  collapsing:t='no'
  <</isCollapsable>>

  <<#isBattle>>
  img {
    id:t='battle_icon'
    size:t='ph,ph'
    background-image:t='#ui/gameuiskin#lb_each_player_session'
  }
  <</isBattle>>

  missionDiv {
    css-hier-invalidate:t='yes'

    <<#itemText>>
    mission_item_text {
      id:t = 'txt_<<id>>'
      text:t = '<<itemText>>'
    }
    <</itemText>>

    <<#teamACountries>>
      <<#country>>
        cardImg {
          background-image:t='<<image>>'
          pos:t='2, 50%ph-50%h'
          position:t='relative'
        }
      <</country>>
    <</teamACountries>>

    <<#teamBCountries>>
      <<#teamACountries>>
        mission_item_text {
          text:t = '#country/VS'
          padding-right:t='1@textPaddingBugWorkaround' //to balance text padding
        }
      <</teamACountries>>

      <<#country>>
        cardImg {
          background-image:t='<<image>>'
          pos:t='2, 50%ph-50%h'
          position:t='relative'
        }
      <</country>>
    <</teamBCountries>>
  }

  <<#isCollapsable>>
  fullSizeCollapseBtn {
    id:t='btn_<<id>>'
    css-hier-invalidate:t='yes'
    square:t='yes'
    activeText{}
  }
  <</isCollapsable>>
}
<</items>>
