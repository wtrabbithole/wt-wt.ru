id:t='<<slotId>>'

<<#slotInactive>>
inactive:t='yes'
<</slotInactive>>

<<#isFullSlotbar>>
slotbarCurAir {
  pattern {
    type:t='bright_hor_lines'
  }
}
<</isFullSlotbar>>

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
    <<#premiumPatternType>>
    type:t='premium'
    <</premiumPatternType>>

    <<^premiumPatternType>>
    type:t='bright_texture'
    <</premiumPatternType>>
  }

  focus_border {}

  shopStat:t='<<shopStatus>>'
  unitRarity:t='<<unitRarity>>'

  <<#isBroken>>
  isBroken:t='yes'
  <</isBroken>>

  <<^isBroken>>
  isBroken:t='no'
  <</isBroken>>

  <<#isPkgDev>>
  shopAirImg { foreground-image:t='#ui/gameuiskin#unit_under_construction' }
  <</isPkgDev>>

  shopAirImg {
    foreground-image:t='<<shopAirImg>>'
  }

  <<#isElite>>
  eliteIcon {}
  <</isElite>>

  <<#hasTalismanIcon>>
  talismanIcon {}
  <</hasTalismanIcon>>

  discount_notification {
    id:t='<<discountId>>'
    type:t='box_down'
    place:t='unit'
    text:t=''

    <<#showDiscount>>
    showDiscount:t='yes'
    <</showDiscount>>

    <<^showDiscount>>
    showDiscount:t='no'
    <</showDiscount>>
  }

  topline {
    shopItemText {
      id:t='<<shopItemTextId>>'
      text:t='<<shopItemText>>'
      header:t='yes'
    }
  }

  bottomline {
    tdiv {
      size:t='fw, ph'

      shopItemText {
        text:t='<<progressText>>'
        position:t='absolute'
        pos:t='pw-w, -2/3h'
        tinyFont:t='yes'
        talign:t='right'
      }
      <<@progressBlk>>
    }

    shopItemPrice {
      id:t='bottom_item_price_text'
      text:t='<<priceText>>'
    }

    shopItemText {
      id:t='rank_text'
      text:t='<<unitRankText>>'

      <<#isItemLocked>>
      locked:t='yes'
      <</isItemLocked>>

      <<^isItemLocked>>
      locked:t='no'
      <</isItemLocked>>

      text-align:t='right'
    }

    classIconPlace {
      classIcon {
        text:t='<<unitClassIcon>>'
        shopItemType:t='<<shopItemType>>'
      }
    }
  }

  <<#showInService>>
  shopInServiceImg {
    <<#isMounted>>
    mounted:t='yes'
    <</isMounted>>
    icon {}
  }
  <</showInService>>

  <<@itemButtons>>

  tooltipObj {
    tooltipId:t='<<tooltipId>>'
    on_tooltip_open:t='onGenericTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
    display:t='hide'
  }

  tooltip-float:t='horisontal'
  title:t='$tooltipObj'

  <<@bottomButton>>

  <<#hasHoverMenu>>
  refuseOpenHoverMenu:t='yes'
  <</hasHoverMenu>>

  <<^hasHoverMenu>>
  refuseOpenHoverMenu:t='no'
  <</hasHoverMenu>>

  <<#hasOnHover>>
  on_hover:t='onUnitHover'
  <</hasOnHover>>
}
