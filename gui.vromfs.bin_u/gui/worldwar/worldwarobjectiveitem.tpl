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
      width:t='fw'

      tdiv {
        left:t='pw-w'
        position:t='relative'
        margin-right:t='1@headerIndent'

        Button_text {
          id:t = 'btn_tasks_list'
          class:t='image16'
          valign:t='center'
          text:t='#icon/info'
          tooltip:t = '#mainmenu/tasksList'
          _on_click:t = 'onOpenFullMissionObjects'
          showConsoleImage:t='no'
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
