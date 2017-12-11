<<#rows>>
tr {
  id:t='<<id>>'
  <<#even>> even:t='yes' <</even>>

  //tooltip:t='<<tooltip>>'
  title:t='$tooltipObj'
  tooltipObj {
    id:t='tooltip'
    on_tooltip_open:t='onSkillRowTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
    display:t='hide'
    skillName:t='<<skillName>>'
    memberName:t='<<memberName>>'
  }

  td {
    cellType:t='left';
    padding-left:t='5*@scrn_tgt/100.0'
    optiontext { text:t='<<name>>' }
  }
  td {
    id:t='<<rowIdx>>'
    cellType:t='right';
    padding-right:t='3.5*@scrn_tgt/100.0'

    hoverBgButton {
      id:t='btn_spec1'
      size:t='ph, ph'
      pos:t='0, 50%ph-50%h'; position:t='relative'
      holderId:t='<<rowIdx>>'
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
      size:t='ph, ph'
      pos:t='0, 50%ph-50%h'; position:t='relative';
      holderId:t='<<rowIdx>>'
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

    tdiv{
      id:t='btnDec_place'
      size:t='1@sliderButtonSquareHeight+@buttonMargin, ph'
      pos:t='0.01@scrn_tgt, 0'; position:t='relative';

      Button_text {
        id:t='buttonDec'
        square:t='yes'
        holderId:t='<<rowIdx>>'
        text:t='-'
        tooltip:t='#crew/skillDecrease'
        on_click:t='onButtonDec'
        on_click_repeat:t = 'onButtonDecRepeat'
      }
    }

    invisSlider {
      id:t='skillSlider'
      size:t='<<maxSkillCrewLevel>> * (0.185@scrn_tgt \ (<<maxSkillCrewLevel>> * @skillProgressWidthMul)) * @skillProgressWidthMul, 2*@scrn_tgt/100.0'
      pos:t='0, 50%ph-50%h'; position:t='relative'
      min:t='0'
      max:t='<<progressMax>>'
      value:t='0'
      snap-to-values:t='yes'
      clicks-by-points:t='yes'
      on_change_value:t='onSkillChanged'

      skillProgressBg {
        height:t='(pw / <<maxSkillCrewLevel>>) * 1@skillProgressHeightMul + 1@skillProgressBgIncSize'
        width:t='pw + 1@skillProgressBgIncSize + 1'
      }

      skillProgress {
        id:t='availableSkillProgress'
        height:t='(w / <<maxSkillCrewLevel>>) * 1@skillProgressHeightMul'
        width:t='pw'
        pos:t='50%pw-50%w, 50%ph-50%h';
        position:t="absolute"
        type:t='available'
        max:t='<<progressMax>>'
      }

      skillProgress {
        id:t='glowSkillProgress'
        height:t='w / <<maxSkillCrewLevel>>'
        width:t='pw'
        pos:t='50%pw-50%w, 50%ph-50%h';
        position:t="absolute"
        type:t='glow'
        max:t='<<progressMax>>'
      }

      skillProgress {
        id:t='newSkillProgress'
        height:t='(w / <<maxSkillCrewLevel>>) * 1@skillProgressHeightMul'
        width:t='pw'
        pos:t='50%pw-50%w, 50%ph-50%h';
        position:t="absolute"
        type:t='new'
        max:t='<<progressMax>>'
      }

      skillProgress {
        id:t='shadeSkillProgress'
        height:t='w / <<maxSkillCrewLevel>>'
        width:t='pw'
        pos:t='50%pw-50%w, 50%ph-50%h';
        position:t="absolute"
        type:t='shade'
        max:t='<<maxValue>>'
      }

      skillProgress {
        id:t='skillProgress'
        height:t='(w / <<maxSkillCrewLevel>>) * 1@skillProgressHeightMul'
        width:t='pw'
        pos:t='50%pw-50%w, 50%ph-50%h';
        position:t="absolute"
        type:t='old'
        max:t='<<maxValue>>'
      }

      sliderButton{}
    }

    activeText { id:t='curValue'; min-width:t='4*@scrn_tgt/100.0'; talign:t='right'; valign:t='center' }
    activeText {
      id:t='addValue'
      <<^havePageBonuses>> display:t='hide' <</havePageBonuses>>
      min-width:t='4*@scrn_tgt/100.0'
      overlayTextColor:t='good'
      valign:t='center'
    }

    Button_text {
      id:t='buttonInc';
      text:t='+';
      square:t='yes';
      on_click:t='onButtonInc';
      on_click_repeat:t = 'onButtonIncRepeat'
      tooltip:t='#crew/skillIncrease'
    }
  }
  td {
    padding-right:t='5*@scrn_tgt/100.0'
    min-width:t='15*@scrn_tgt/100.0';
    textareaNoTab { id:t='incCost'; commonTextColor:t='yes'; valign:t='center'; tooltip:t='#crew/incCost/tooltip' }
  }
}
<</rows>>
