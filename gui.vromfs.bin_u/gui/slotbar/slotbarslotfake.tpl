id:t='<<slotId>>'

<<#slotInactive>>
inactive:t='yes'
<</slotInactive>>

shopItem {
  id:t='<<shopItemId>>'
  behavior:t='Timer'
  timer_interval_msec:t='1000'
  unit_name:t='<<unitName>>'

  bgPlate {}

  itemWinkBlock {
    buttonWink {
      _transp-timer:t='0'
    }
  }

  hoverHighlight {}

  pattern {
    type:t='bright_texture'
  }

  shopStat:t='<<shopStatus>>'

  shopAirImg {
    foreground-image:t='<<shopAirImg>>'
  }

  topline {
    shopItemText {
      id:t='<<shopItemTextId>>'
      text:t='<<shopItemText>>'
      header:t='yes'
      <<#needMultiLineName>>isMultiLine:t='yes'<</needMultiLineName>>

      <<#isItemDisabled>>
      disabled:t='yes'
      <</isItemDisabled>>
      <<^isItemDisabled>>
      disabled:t='no'
      <</isItemDisabled>>
    }
  }

  bottomline {
    shopItemText {
      id:t='rank_text'
      text:t='<<unitRankText>>'
      header:t='yes'
    }
  }
}
