<<#items>>
expandable {
  id:t='<<performActionId>>'
  <<#action>> on_click:t='<<action>>' <</action>>
  <<#taskId>> task_id:t='<<taskId>>' <</taskId>>

  <<#taskStatus>>
  battleTaskStatus:t='<<taskStatus>>'
  <</taskStatus>>

  <<#showAsUsualPromoButton>>
    setStandartWidth:t='yes'
  <</showAsUsualPromoButton>>
  <<^showAsUsualPromoButton>>
    setStandartWidth:t='no'
  <</showAsUsualPromoButton>>

  class:t='battletask'
  fullSize:t='yes'
  selImg {
    header {
      <<^isPromo>>
      width:t='pw'
      <</isPromo>>

      <<#isPromo>>
      left:t='pw-w'
      position:t='relative'
        <<#taskStatus>>
          statusImg {}
        <</taskStatus>>
      <</isPromo>>

      <<#newIconWidget>>
      tdiv {
        id:t='new_icon_widget_<<id>>'
        valign:t='center'
        <<@newIconWidget>>
      }
      <</newIconWidget>>

      <<#taskDifficultyImage>>
      cardImg {
        type:t='medium'
        background-image:t='<<taskDifficultyImage>>'
      }
      <</taskDifficultyImage>>

      textareaNoTab {
        text:t='<<title>>'
        top:t='50%ph-50%h'
        position:t='relative'

        <<^showAsUsualPromoButton>>
          overlayTextColor:t='active'
          <<#isLowWidthScreen>>
            smallFont:t='yes'
          <</isLowWidthScreen>>
          <<^isLowWidthScreen>>
            caption:t='yes'
          <</isLowWidthScreen>>
        <</showAsUsualPromoButton>>

        <<#isPromo>>
          margin:t='5@sf/@pf_outdated,0,0,0'
        <</isPromo>>
        <<^isPromo>>
          width:t='fw'
          margin:t='5@sf/@pf_outdated, 0'
        <</isPromo>>
      }

      <<#isPromo>>
      <<#refreshTimer>>
        textareaNoTab {
          id:t='tasks_refresh_timer'
          behavior:t='Timer'
          text:t=''
        }
      <</refreshTimer>>
      <</isPromo>>

      <<#taskRankValue>>
      textareaNoTab {
        text:t='<<taskRankValue>>'
        overlayTextColor:t='active'
        top:t='50%ph-50%h'
        position:t='relative'

        <<#isLowWidthScreen>>
          tinyFont:t='yes'
        <</isLowWidthScreen>>
      }
      <</taskRankValue>>

      <<^isPromo>>
      <<#taskStatus>>
        statusImg {}
      <</taskStatus>>
      <</isPromo>>
    }

    hiddenDiv {
      width:t='pw'
      flow:t='vertical'

      <<#taskImage>>
      img {
        width:t='pw'
        height:t='0.33*w'
        margin-top:t='0.005@scrn_tgt'
        background-image:t='<<taskImage>>'
        border:t='yes';
        border-color:t='@black' //Not a forgotten string, by design.

        <<#taskPlayback>>
        ShadowPlate {
          pos:t='pw-w, ph-h'
          position:t='absolute'
          padding:t='1@framePadding'
          playbackCheckbox {
            id:t='<<id>>_sound'
            on_change_value:t='switchPlaybackMode'
            playback:t='<<taskPlayback>>'
            downloading:t='<<#isPlaybackDownloading>>yes<</isPlaybackDownloading>><<^isPlaybackDownloading>>no<</isPlaybackDownloading>>'
            btnName:t='LB'
            ButtonImg{}
            descImg {
              background-image:t='#ui/gameuiskin#sound_on'
            }
            animated_wait_icon {
              background-rotation:t = '0'
              behavior:t='increment'
              inc-target:t='background-rotation'
              inc-factor:t='120'

              wait_icon_cock {}
            }
            playbackImg{}
          }
        }
        <</taskPlayback>>
      }
      <</taskImage>>

      <<@description>>

      <<#reward>>
      tdiv {
        left:t='pw-w'
        position:t='relative'
        textarea {
          max-width:t='fw'
          removeParagraphIndent:t='yes';
          text:t='<<rewardText>>'
          overlayTextColor:t='active'
        }
        <<@itemMarkUp>>
      }
      <</reward>>

      tdiv {
        width:t='pw'

        //Suppose that at a moment will be shown only one of two below buttons
        //So pos pw-w won't move recieve_reward button outside of window
        <<#canReroll>>
        Button_text {
          id:t = 'btn_reroll'
          taskId:t='<<id>>'
          visualStyle:t='purchase'
          text:t = '#battletask/reroll'
          on_click:t = 'onTaskReroll'
          hideText:t='yes'
          btnName:t='A'
          buttonGlance{}
          buttonWink{}
          ButtonImg {}
          textarea{
            id:t='btn_reroll_text';
            class:t='buttonText';
          }
        }
        <</canReroll>>

        <<#canGetReward>>
        Button_text {
          id:t = 'btn_recieve_reward'
          task_id:t='<<id>>'
          pos:t='pw-w, 0'
          position:t='relative'
          text:t = '#mainmenu/battleTasks/receiveReward'
          on_click:t = 'onGetRewardForTask'
          btnName:t='A'
          visualStyle:t='secondary'
          buttonWink {}
          ButtonImg{}
        }
        <</canGetReward>>
      }
    }

    expandImg {
      id:t='expandImg'
      height:t='1*@scrn_tgt/100.0'
      width:t='2h'
      pos:t='50%pw-50%w, ph-h'; position:t='absolute'
      background-image:t='#ui/gameuiskin#expand_info'
      background-color:t='@premiumColor'
    }

    <<#isPromo>>
    <<#otherTasksText>>
      textareaNoTab {
        text:t='<<otherTasksText>>'
        position:t='relative'
        pos:t='pw-w, 0'
      }
    <</otherTasksText>>
    <</isPromo>>
  }
}

<<#isPromo>>
collapsedContainer {
  <<#taskStatus>>
    battleTaskStatus:t='<<taskStatus>>'
    statusImg {}
  <</taskStatus>>
  <<#collapsedAction>> on_click:t='<<collapsedAction>>Collapsed' <</collapsedAction>>
  shortHeaderText { text:t='<<collapsedText>>' }
  shortHeaderIcon { text:t='<<collapsedIcon>>' }
}
hangarToggleButton {
  id:t='<<id>>_toggle'
  on_click:t='onToggleItem'
  type:t='right'
  directionImg {}
}
<</isPromo>>
<</items>>
