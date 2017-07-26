tdiv {
  width:t='pw-0.06@sf'
  pos:t='50%pw-50%w, 0'
  position:t='relative'
  margin-bottom:t='0.005@scrn_tgt'

  <<#armyCountryImg1>>
    cardImg {
      background-image:t='<<image>>'
      pos:t='0, 50%ph-50%h'
      position:t='relative'
      margin:t='1@framePadding'
    }
  <</armyCountryImg1>>

  textAreaCentered {
    id:t='label_commands'
    text:t='#worldWar/armyStrength'
    hideEmptyText:t='yes'
    fontNormal:t='yes'
    pos:t='0, 50%ph-50%h'
    position:t='relative'
    width:t='fw'
    overlayTextColor:t='active'
  }

  <<#armyCountryImg2>>
    cardImg {
      background-image:t='<<image>>'
      pos:t='0, 50%ph-50%h'
      position:t='relative'
      margin:t='1@framePadding'
    }
  <</armyCountryImg2>>
}

<<#unitString>>
  tdiv {
    padding-top:t='1@wwMapInterlineStrengthPadding'
    pos:t='50%pw-50%w, 0'
    position:t='relative'
    img {
      background-image:t='<<unitIcon>>'
      shopItemType:t='<<shopItemType>>'
      size:t='1@tableIcoSize, 1@tableIcoSize'
      pos:t='0, 50%ph-50%h'
      position:t='relative'
      margin-left:t='3@framePadding'
      margin-right:t='3@dp'
    }
    textareaNoTab {
      text:t='<<side1UnitCount>>'
      width:t='15%p.p.w'
      pos:t='0, 50%ph-50%h'
      position:t='relative'
    }
    textAreaCentered {
      text:t='<<unitName>>'
      width:t='50%p.p.w'
      pos:t='0, 50%ph-50%h'
      position:t='relative'
    }
    textareaNoTab {
      text:t='<<side2UnitCount>>'
      width:t='15%p.p.w'
      talign:t='right'
      pos:t='0, 50%ph-50%h'
      position:t='relative'
    }
    img {
      background-image:t='<<unitIcon>>'
      shopItemType:t='<<shopItemType>>'
      size:t='@tableIcoSize, @tableIcoSize'
      pos:t='0, 50%ph-50%h'
      position:t='relative'
      margin-left:t='3@dp'
      margin-right:t='3@framePadding'
    }
  }
<</unitString>>
