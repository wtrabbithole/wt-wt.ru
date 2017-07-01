<<#header>>
textareaNoTab {
  id:t='item_desc'

  <<^widthByParentParent>>
  width:t='pw'
  <</widthByParentParent>>
  <<#widthByParentParent>>
  max-width:t='p.p.w'
  <</widthByParentParent>>

  margin-bottom:t='1@itemPadding'
  font-bold:t='@normal'
  text:t='<<header>>'
}
<</header>>
<<#list>>
_newline{}
tdiv {
  width:t='pw'
  max-width:t='p.p.w'
  margin-bottom:t='1@itemPadding'
  <<#tooltip>>
  tooltip:t='<<tooltip>>'
  <</tooltip>>

  <<#title>>
  <<#icon>>
  img {
    size:t='1@dIco, 1@dIco'
    pos:t='0, 0.012@scrn_tgt_font - h/2'; position:t='absolute'
    position:t='relative'
    background-image:t='<<icon>>'
  }
  <</icon>>
  <<#icon2>>
  img {
    size:t='1@dIco, 1@dIco'
    pos:t='0, 0.012@scrn_tgt_font - h/2'; position:t='absolute'
    position:t='relative'
    background-image:t='<<icon2>>'
  }
  <</icon2>>

  textareaNoTab {
    <<^widthByParentParent>>
    width:t='pw -1@dIco -1@itemPadding <<#icon2>>-1@dIco<</icon2>>'
    <</widthByParentParent>>
    max-width:t='p.p.p.w -1@dIco -1@itemPadding <<#icon2>>-1@dIco<</icon2>>'
    pos:t='1@itemPadding, ph/2-h/2'; position:t='relative'
    font-bold:t='@tiny'
    text:t='<<title>>'
  }
  <</title>>

  <<#unitPlate>>
  <<#classIco>>
  img {
    size:t='1@tableIcoSize, 1@tableIcoSize'
    pos:t='0.5@dIco-0.5@tableIcoSize, 50%ph-50%h'; position:t='relative'
    background-image:t='<<classIco>>'
    shopItemType:t='<<shopItemType>>'
  }
  <</classIco>>

  tdiv {
    max-width:t='pw -1@dIco -1@itemPadding'
    padding:t='-1@slot_interval, -1@slot_vert_pad'
    pos:t='1@itemPadding, ph/2-h/2'; position:t='relative'
    tdiv {
      class:t='rankUpList'
      <<@unitPlate>>
    }
  }

  <<#unitInfoText>>
  _newline{}
  textareaNoTab {
    <<^widthByParentParent>>
    width:t='pw -1@dIco -1@itemPadding'
    <</widthByParentParent>>
    max-width:t='p.p.p.w -1@dIco -1@itemPadding'
    pos:t='<<#classIco>>1@dIco+<</classIco>> 1@itemPadding, 0'; position:t='relative'
    text:t='<<unitInfoText>>'
    tinyFont:t='yes'
    margin-bottom:t='20'
  }
  <</unitInfoText>>
  <</unitPlate>>

  <<#tooltipId>>
  tooltipObj {
    id:t='tooltip_<<tooltipId>>'
    on_tooltip_open:t='onGenericTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
    display:t='hide'
  }
  title:t='$tooltipObj'
  <</tooltipId>>
}
<</list>>
