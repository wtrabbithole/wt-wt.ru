<<#isPromo>>
tinyFont:t='yes'
<</isPromo>>
<<#taskDescription>>
textareaNoTab {
  id:t='taskDescription'
  padding-top:t='0.01@scrn_tgt'
  width:t='pw'
  <<#isPromo>>
  text-align:t='right'
  <</isPromo>>
  text:t='<<taskDescription>>'
}
<</taskDescription>>

<<#taskConditionsList>>
unlockCondition {
  unlocked:t='<<#unlocked>>yes<</unlocked>><<^unlocked>>no<</unlocked>>'
  unlockImg{}
  textareaNoTab {
    text:t='<<text>>'
  }
}
<</taskConditionsList>>

<<#taskUnlocksList>>
tdiv {
  width:t='pw'
  class:t='header'
  Button_text {
    class:t='image16'
    img { background-image:t='#ui/gameuiskin#help_tooltip' }
    on_click:t='onViewUnlocks'
  }
  textareaNoTab {
    id:t='taskUnlocksListPrefix'
    text:t='<<taskUnlocksListPrefix>>'
    top:t='50%ph-50%h'
    position:t='relative'
    padding-left:t='0.005@scrn_tgt'
  }
}
tdiv {
  id:t='taskUnlocksList'
  width:t='pw'
  flow:t='h-flow'
  padding-left:t='0.02@scrn_tgt'

  <<#taskUnlocks>>
  textareaNoTab {
    text:t='<<text>>'
    overlayTextColor:t='<<overlayTextColor>>'
    title:t='$tooltipObj'
    tooltipObj {
      display:t='hide'
      on_tooltip_open:t='onGenericTooltipOpen'
      on_tooltip_close:t='onTooltipObjClose'
      tooltipId:t='<<tooltipId>>'
    }
  }
  <</taskUnlocks>>
}
<</taskUnlocksList>>

<<#taskSpecialDescription>>
textareaNoTab {
  id:t='task_timer_text'
  behavior:t='Timer'
  padding-top:t='0.03@scrn_tgt'
  width:t='pw'
  <<#isPromo>>
  text-align:t='right'
  <</isPromo>>
  text:t='<<taskSpecialDescription>>'
}
<</taskSpecialDescription>>

<<#doneTasksTable>>
  <<#rows>>
    table {
      width:t='pw'
      baseRow:t='yes'
      padding:t='0.01@scrn_tgt,0'
      total-input-transparent:t='yes'
      <<@rows>>
    }
  <</rows>>

  <<^rows>>
    textAreaCentered {
      pos:t='50%pw-50%w, 50%ph-50%h'
      position:t='absolute'
      text:t='#mainmenu/battleTasks/noHistory'
    }
  <</rows>>
<</doneTasksTable>>
