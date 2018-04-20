<<#header>>
_newline{ size:t='0' }
textareaNoTab {
  <<#timerId>>
  id:t='<<timerId>>'
  behavior:t='Timer'
  <</timerId>>

  <<^widthByParentParent>>
  width:t='pw'
  <</widthByParentParent>>
  <<#widthByParentParent>>
  max-width:t='p.p.w'
  <</widthByParentParent>>

  margin-bottom:t='1@itemPadding'
  font-bold:t='@fontMedium'
  text:t='<<header>>'
}
<</header>>
<<#list>>
_newline{ size:t='0' }
tdiv {
  width:t='pw'
  max-width:t='p.p.w'
  total-input-transparent:t='yes'
  <<#tooltip>>
  tooltip:t='<<tooltip>>'
  <</tooltip>>

  <<#title>>
  <<#icon>>
  img {
    size:t='1@dIco, 1@dIco'
    pos:t='0, ph/2-h/2'
    position:t='relative'
    background-image:t='<<icon>>'
  }
  <</icon>>
  <<#icon2>>
  img {
    size:t='1@dIco, 1@dIco'
    pos:t='0, ph/2-h/2'
    position:t='relative'
    background-image:t='<<icon2>>'
  }
  <</icon2>>

  textareaNoTab {
    <<^widthByParentParent>>
    width:t='pw -1@dIco -1@itemPadding <<#icon2>>-1@dIco<</icon2>> <<#buttonsCount>>-1.5@sIco*<<buttonsCount>><</buttonsCount>>'
    <</widthByParentParent>>
    max-width:t='p.p.p.w -1@dIco -1@itemPadding <<#icon2>>-1@dIco<</icon2>> <<#buttonsCount>>-1.5@sIco*<<buttonsCount>><</buttonsCount>>'
    pos:t='1@itemPadding, ph/2-h/2'; position:t='relative'
    font-bold:t='@fontSmall'
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
    <<^widthByParentParent>>
    width:t='pw <<#classIco>>-1@dIco<</classIco>> -1@itemPadding <<#buttonsCount>>-1.5@sIco*<<buttonsCount>><</buttonsCount>>'
    <</widthByParentParent>>
    max-width:t='p.p.p.w <<#classIco>>-1@dIco<</classIco>> -1@itemPadding <<#buttonsCount>>-1.5@sIco*<<buttonsCount>><</buttonsCount>>'
    padding:t='-1@slot_interval, -1@slot_vert_pad'
    pos:t='1@itemPadding, ph/2-h/2'; position:t='relative'
    tdiv {
      class:t='rankUpList'
      <<@unitPlate>>
    }
  }
  <</unitPlate>>

  <<#buttons>>
  hoverButton {
    pos:t='0, ph/2-h/2'; position:t='relative'
    tooltip:t = '<<tooltip>>'
    on_click:t='onDescAction'
    no_text:t='yes'
    actionData:t='<<actionData>>'
    icon { background-image:t='<<icon>>' }
  }
  <</buttons>>

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

<<#commentText>>
_newline{ size:t='0' }
textareaNoTab {
  <<^widthByParentParent>>
  width:t='pw'
  <</widthByParentParent>>
  <<#widthByParentParent>>
  max-width:t='p.p.w'
  <</widthByParentParent>>
  <<#title>>
  pos:t='0, -4@sf/@pf'; position:t='relative'
  padding-left:t='1@dIco <<#icon2>>+1@dIco<</icon2>> +1@itemPadding'
  <</title>>
  <<#unitPlate>>
  pos:t='0, 2@sf/@pf'; position:t='relative'
  padding-left:t='<<#classIco>>1@dIco +<</classIco>> 1@itemPadding'
  <</unitPlate>>
  text:t='<<commentText>>'
  tinyFont:t='yes'
}
<</commentText>>
<</list>>
