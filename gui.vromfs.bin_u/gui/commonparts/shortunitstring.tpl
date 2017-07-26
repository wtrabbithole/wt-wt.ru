<<#unitString>>
  <<^invert>>
  tdiv {
    <<#icon>>
    img {
      background-image:t='<<icon>>'
      shopItemType:t='<<shopItemType>>'
      size:t='@tableIcoSize, @tableIcoSize'
      margin-right:t='1@textPaddingBugWorkaround'
    }
    <</icon>>

    <<#count>>
      textareaNoTab {
        text:t='<<count>>'
        overlayTextColor:t='active'
      }
    <</count>>

    <<#showType>>
      textarea { text:t='<<unitType>>' }
    <</showType>>
    <<^showType>>
      textarea { text:t='<<name>>' }
    <</showType>>

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
  <</invert>>
  <<#invert>>
  tdiv {
    pos:t='pw-w, 0'
    position:t='relative'

    <<#showType>>
      textarea {
        text:t='<<unitType>>'
        margin-right:t='1@textPaddingBugWorkaround'
      }
    <</showType>>
    <<^showType>>
      textarea {
        text:t='<<name>>'
        margin-right:t='1@textPaddingBugWorkaround'
      }
    <</showType>>

    <<#count>>
      textareaNoTab {
        text:t='<<count>>'
        overlayTextColor:t='active'
      }
    <</count>>

    <<#icon>>
      img {
        background-image:t='<<icon>>'
        shopItemType:t='<<shopItemType>>'
        size:t='@tableIcoSize, @tableIcoSize'
        margin-left:t='1@textPaddingBugWorkaround'
      }
    <</icon>>

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
  <</invert>>
<</unitString>>
