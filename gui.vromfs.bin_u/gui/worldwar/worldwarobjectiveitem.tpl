<<#objectiveBlock>>
objectiveBlock {
  id:t='<<id>>_objectives'
  flow:t='vertical'
  width:t='pw'
  <<#hide>>
    display:t='hide'
    enable:t='no'
  <</hide>>

  header {
    cardImg {
      margin-left:t='1@headerIndent'
      background-image:t="<<countryIcon>>"
      valign:t='center'
    }
    text {
      text:t='#worldWar/objectivesHeader/<<id>>'
      valign:t='center'
    }
    <<#reqFullMissionObjectsButton>>
    tdiv {
      size:t='fw, ph'

      tdiv {
        pos:t='pw-w, 50%ph-50%h'
        position:t='relative'
        margin-right:t='1@headerIndent'

        Button_text {
          id:t = 'btn_tasks_list'
          showConsoleImage:t='no'
          text:t='#icon/info'
          reduceMinimalWidth:t='yes'
          tooltip:t = '#mainmenu/tasksList'
          _on_click:t = 'onOpenFullMissionObjects'
        }
        <<#hiddenObjectives>>
        textareaNoTab {
          margin-left:t='1@itemPadding'
          valign:t='center'
          text:t='<<?keysPlus>><<hiddenObjectives>> <<?worldWar/objectives/more>>'
        }
        <</hiddenObjectives>>
      }
    }
    <</reqFullMissionObjectsButton>>
  }
  body {
    id:t='<<id>>_objectives_list'
    width:t='pw'
    flow:t='vertical'

    include "gui/worldWar/operationString"
  }
}
<</objectiveBlock>>
