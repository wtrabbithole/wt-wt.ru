tdiv {
  id:t='airfield_object'
  width:t='pw'
  flow:t='vertical'

  tdiv {
    id:t='airfields_list'
    pos:t='50%pw-50%w, 0'
    position:t='relative'
    flow:t='h-flow'

    <<#airfields>>
    imageButton {
      id:t='<<id>>'
      type:t='wwAirfield'
      <<#selected>>
        selected:t='yes'
      <</selected>>
      on_click:t='onAirfieldClick'
      size:t='40, 40'
      margin:t='0.01@scrn_tgt'

      textareaNoTab {
        pos:t='75%pw, ph-h+0.004@scrn_tgt'
        position:t='absolute'
        text:t='<<text>>'
        input-transparent:t='yes'
      }
    }
    <</airfields>>
  }

  tdiv {
    id:t='free_formations_block'
    width:t='pw'
    height:t='@mIco+2@framePadding'
    position:t='relative'
    display:t='hide'
    background-color:t='@objectiveHeaderBackground'

    textareaNoTab {
      id:t='empty_formations_text'
      width:t='pw'
      top:t='50%ph-50%h'
      position:t='relative'
      text-align:t='center'
      display:t='hide'
      text:t=''
    }
    textareaNoTab {
      id:t='free_formations_text'
      width:t='0.5pw'
      top:t='50%ph-50%h'
      position:t='relative'
      text-align:t='right'
      display:t='hide'
      text:t='<<?worldwar/state/ready_to_fly>><<?ui/colon>>'
    }
    FormationRadioButtonsList {
      id:t='free_formations'
      behavior:t = 'Timer'
      top:t='50%ph-50%h'
      position:t='relative'
    }
  }

  tdiv {
    id:t='cooldown_formations'
    size:t='pw, 0.35p.p.h'
    position:t='relative'

    tdiv {
      size:t='pw, fh'
      position:t='absolute'
      overflow-y:t='auto'
      scrollbarShortcuts:t='yes'
      padding-left:t='1@framePadding'

      FormationRadioButtonsList {
        id:t='cooldowns_list'
        behavior:t = 'Timer'
        pos:t='0, 0.01@scrn_tgt'
        position:t='relative'
        width:t='pw'
        flow:t='h-flow'
        flow-align:t='left'
      }
    }
  }
}
