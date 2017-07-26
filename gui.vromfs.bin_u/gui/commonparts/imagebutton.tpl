<<#buttons>>
imgButton {
  id:t='<<id>>';
  class:t='decal_image';
  width:t='<<ratio>>@decalIconHeight';
  min-height:t='1@decalIconHeight';
  min-width:t='1@decalIconHeight';

  <<^tooltipId>>
  <<#tooltipText>>
    tooltip:t='<<tooltipText>>'
  <</tooltipText>>
  <</tooltipId>>

  <<#unlocked>> unlocked:t='yes'; <</unlocked>>
  <<#highlighted>> highlighted:t='yes' <</highlighted>>

  <<#onClick>> on_click:t='<<onClick>>' <</onClick>>
  <<#onDblClick>> on_dbl_click:t='<<onDblClick>>' <</onDblClick>>

  selImg{}

  <<^emptySlot>>
    <<#image>>
    img {
      background-image:t='<<image>>'
      max-height:t='1.0/<<ratio>>pw'
      max-width:t='<<ratio>>pw'
      height:t='ph';
      width:t='pw';
      pos:t='50%pw-50%w, 50%ph-50%h';
      position:t='relative';
      background-repeat:t='aspect-ratio';
    }
    <</image>>

    <<#onDeleteClick>>
      closeBtn {
        pos:t='pw - w + 2*@sf/@pf_outdated, 0'
        tooltip:t='#msgbox/btn_delete'
        on_click:t='<<onDeleteClick>>'
        img {}
      }
    <</onDeleteClick>>

  <</emptySlot>>

  <<^unlocked>>
    <<#statusLock>>
    LockedImg {
       statusLock:t='<<statusLock>>'
      <<#lockCountryImg>> background-image:t='<<lockCountryImg>>' <</lockCountryImg>>
    }
    <</statusLock>>
  <</unlocked>>

  <<#unitLocked>>
    textareaNoTab {
      text-shade:t='yes'
      pos:t='pw-w-4, ph-h';
      position:t='absolute';
      text:t='<<unitLocked>>'
      fontNormal:t='yes'
      overlayTextColor:t='bad'
    }
  <</unitLocked>>

  <<#unlocked>>
  <<#emptySlot>>
    textAreaCentered {
      valign:t='center'
      width:t='pw';
      tinyFont:t='yes'
      text:t='#ui/empty'
    }
  <</emptySlot>>
  <</unlocked>>

  <<#cost>>
    contentCorner {
      pos:t='pw-w-2, ph-h-2';
      position:t='absolute';
      textareaNoTab {
        text:t='<<cost>>'
        tinyFont:t='yes';
        padding:t='3@dp,6@dp,3@dp,3@dp';
      }
    }
  <</cost>>

  <<#showLimit>>
    textareaNoTab {
      textShade:t='yes'
      pos:t='pw-w-2, ph-h-2';
      position:t='absolute';
      text:t='<<leftAmount>>/<<limit>>'
      tinyFont:t='yes';
      padding:t='3@dp,6@dp,3@dp,3@dp';
      <<#isMax>>
        overlayTextColor:t='bad'
      <</isMax>>
    }
  <</showLimit>>

  <<#tooltipId>>
    tooltipObj {
      tooltipId:t='<<tooltipId>>'
      on_tooltip_open:t='onGenericTooltipOpen'
      on_tooltip_close:t='onTooltipObjClose'
      max-width:t='8*@decalIconHeight+10*@sf/@pf_outdated'
      tinyFont:t='yes';
      display:t='hide';
    }
    title:t='$tooltipObj';
  <</tooltipId>>
}
<</buttons>>
