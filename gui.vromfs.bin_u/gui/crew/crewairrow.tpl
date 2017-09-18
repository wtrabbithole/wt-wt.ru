<<#rows>>
tr {
  id:t='<<id>>'
  <<#even>> even:t='yes' <</even>>

  title:t='$tooltipObj'
  tooltipObj {
    tooltipId:t='<<rowTooltipId>>'
    on_tooltip_open:t='onGenericTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
    display:t='hide'
  }

  td {
    cellType:t='left';
    padding-left:t='5*@sf/100.0'
    optiontext { text:t='<<unitName>>' }
    cardImg { id:t='name_icon'; display:t='hide'; background-image:t='#ui/gameuiskin#crew_skill_points' }
  }
  td {
    activeText { id:t='curValue'; text:t=' '; valign:t='center' }
    <<#hasProgressBar>>
    crewSpecProgressBar {
      id:t='crew_spec_progress_bar'
      height:t='@referenceProgressHeight'
      width:t='pw - 4*@sf/@pf_outdated'
      pos:t='0, ph-6*@sf/@pf_outdated'
      position:t='absolute'
      min:t='0'
      max:t='1000'
      value:t='0'
    }
    <</hasProgressBar>>
    cardImg { id:t='curValue_icon'; display:t='hide'; background-image:t='#ui/gameuiskin#crew_skill_points' }
  }
  td {
    width:t='0.092@scrn_tgt'

    hoverBgButton {
      id:t='btn_spec1'
      size:t='0.046@scrn_tgt, 0.046@scrn_tgt'
      pos:t='0, 50%ph-50%h'; position:t='relative'
      holderId:t='<<holderId>>'
      foreground-image:t='#ui/gameuiskin#spec_icon1'
      foreground-position:t='3'
      on_click:t='onSpecIncrease1'

      title:t='$tooltipObj'
      tooltipObj {
        tooltipId:t='<<buySpecTooltipId1>>'
        on_tooltip_open:t='onGenericTooltipOpen'
        on_tooltip_close:t='onTooltipObjClose'
        display:t='hide'
      }
    }

    hoverBgButton {
      id:t='btn_spec2'
      size:t='0.046@scrn_tgt, 0.046@scrn_tgt'
      pos:t='0, 50%ph-50%h'; position:t='relative';
      holderId:t='<<holderId>>'
      foreground-image:t='#ui/gameuiskin#spec_icon2'
      foreground-position:t='3'
      on_click:t='onSpecIncrease2'

      title:t='$tooltipObj'
      tooltipObj {
        tooltipId:t='<<buySpecTooltipId2>>'
        on_tooltip_open:t='onGenericTooltipOpen'
        on_tooltip_close:t='onTooltipObjClose'
        display:t='hide'
      }
    }
  }
  td {
    padding-left:t='1*@scrn_tgt/100.0'
    textareaNoTab { id:t='cost'; text:t=' '; min-width:t='10*@scrn_tgt/100.0'; text-align:t='right'; valign:t='center';}
  }
  td {
    id:t='<<holderId>>'
    padding-right:t='5*@sf/100.0'
    min-width:t='0.15@sf'
    max-width:t='0.45@sf'

    Button_text {
      id:t='buttonRowApply';
      on_click:t='onButtonRowApply'
      text:t=' ';
      redDisabled:t='yes'
      pos:t='0, 50%ph-50%h';
      position:t='relative';
      noMargin:t='yes'
      btnName:t=''

      ButtonImg {
        id:t='ButtonImg'
        iconName:t='X'
        showOn:t='selectedAndEnabled'
      }

      title:t='$tooltipObj'
      tooltipObj {
        tooltipId:t='<<buySpecTooltipId>>'
        on_tooltip_open:t='onGenericTooltipOpen'
        on_tooltip_close:t='onTooltipObjClose'
        display:t='hide'
      }
    }

    discount {
      id:t='buy-discount'
      text:t=''
      pos:t='pw-15%w-5*@sf/100.0, 50%ph-60%h'; position:t='absolute'
      rotation:t='-10'
    }
  }
}
<</rows>>
