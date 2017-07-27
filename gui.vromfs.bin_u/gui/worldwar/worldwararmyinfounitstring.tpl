<<#unitString>>
tdiv {
  width:t='pw'
  <<#hasSpaceBetweenUnits>>
  height:t='1@unitStringHeight'
  <</hasSpaceBetweenUnits>>

  <<^reflect>>
    padding-left:t='3@dp'

    <<#isShow>>
      <<#count>>
      textareaNoTab {
        width:t='0.05@scrn_tgt_font'
        pos:t='0, 50%ph-50%h'
        position:t='relative'
        text:t='<<count>>'
      }
      <</count>>

      <<#icon>>
      img {
        size:t='@tableIcoSize, @tableIcoSize'
        pos:t='0, 50%ph-50%h'
        position:t='relative'
        background-image:t='<<icon>>'
        shopItemType:t='<<shopItemType>>'
      }
      <</icon>>

      textareaNoTab {
        width:t='fw'
        pos:t='0, 50%ph-50%h'
        position:t='relative'
        pare-text:t='yes'
        text:t=' <<#showType>><<unitType>><</showType>><<^showType>><<name>><</showType>> '
      }
    <</isShow>>
  <</reflect>>

  <<#hasPresetWeapon>>
  tdiv {
    pos:t='0, 50%ph-50%h'
    position:t='relative'
    tooltip:t='<<?modification/category/secondaryWeapon>><<?ui/colon>>\n<<weapon>>'

    <<#presetCount>>
    textareaNoTab {
      text:t='('
    }
    <</presetCount>>

    <<#hasBomb>>
      img { size:t='0.4@tableIcoSize,@tableIcoSize' top:t='50%ph-50%h' position:t='relative' background-image:t='#ui/gameuiskin#weap_bomb' }
    <</hasBomb>>
    <<#hasRocket>>
      img { size:t='0.6@tableIcoSize,@tableIcoSize' top:t='50%ph-50%h' position:t='relative' background-image:t='#ui/gameuiskin#weap_missile' }
    <</hasRocket>>
    <<#hasTorpedo>>
      img { size:t='0.4@tableIcoSize,@tableIcoSize' top:t='50%ph-50%h' position:t='relative' background-image:t='#ui/gameuiskin#weap_torpedo' }
    <</hasTorpedo>>
    <<#hasAdditionalGuns>>
      img { size:t='0.4@tableIcoSize,@tableIcoSize' top:t='50%ph-50%h' position:t='relative' background-image:t='#ui/gameuiskin#weap_pod' }
    <</hasAdditionalGuns>>

    <<#presetCount>>
    textareaNoTab {
      text:t='<<presetCount>>)'
    }
    <</presetCount>>
  }
  <</hasPresetWeapon>>

  <<#reflect>>
    pos:t='pw-w-3@dp, 0'
    position:t='relative'

    <<#isShow>>
      textareaNoTab {
        width:t='fw'
        pos:t='0, 50%ph-50%h'
        position:t='relative'
        pare-text:t='yes'
        text:t=' <<#showType>><<unitType>><</showType>><<^showType>><<name>><</showType>> '
      }

      <<#icon>>
      img {
        size:t='@tableIcoSize, @tableIcoSize'
        pos:t='0, 50%ph-50%h'
        position:t='relative'
        background-image:t='<<icon>>'
        shopItemType:t='<<shopItemType>>'
      }
      <</icon>>

      <<#count>>
      textareaNoTab {
        width:t='0.05@scrn_tgt_font'
        pos:t='0, 50%ph-50%h'
        position:t='relative'
        text-align:t='right'
        text:t='<<count>>'
      }
      <</count>>
    <</isShow>>
  <</reflect>>

  <<#tooltipId>>
  title:t='$tooltipObj'
  tooltipObj {
    id:t='tooltip_obj'
    tooltipId:t='<<tooltipId>>'
    display:t='hide'
    on_tooltip_open:t='onGenericTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
  }
  <</tooltipId>>
}
<</unitString>>