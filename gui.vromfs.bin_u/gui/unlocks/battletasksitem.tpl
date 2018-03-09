<<#items>>
expandable {
  id:t='<<performActionId>>'
  type:t='battleTask'
  <<^isOnlyInfo>><<#action>> on_click:t='<<action>>' <</action>><</isOnlyInfo>>
  task_id:t='<<id>>'

  <<#taskStatus>>
  battleTaskStatus:t='<<taskStatus>>'
  <</taskStatus>>

  <<#showAsUsualPromoButton>>
    setStandartWidth:t='yes'
  <</showAsUsualPromoButton>>

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
            normalFont:t='yes'
          <</isLowWidthScreen>>
        <</showAsUsualPromoButton>>

        <<^isPromo>>
          width:t='fw'
        <</isPromo>>
      }

      <<#isPromo>>
      <<#refreshTimer>>
        textareaNoTab {
          id:t='tasks_refresh_timer'
          behavior:t='Timer'
          top:t='50%ph-50%h'
          position:t='relative'
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

        <<^showAsUsualPromoButton>>
          overlayTextColor:t='active'
          <<#isLowWidthScreen>>
            normalFont:t='yes'
          <</isLowWidthScreen>>
        <</showAsUsualPromoButton>>
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
      <<#isOnlyInfo>> showHidden:t='yes' <</isOnlyInfo>>

      <<^isOnlyInfo>>
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
            task_id:t='<<id>>'
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
            }
            playbackImg{}
          }
        }
        <</taskPlayback>>
      }
      <</taskImage>>
      <</isOnlyInfo>>

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

      <<^isOnlyInfo>>
      tdiv {
        width:t='pw'

        //Suppose that at a moment will be shown only one of two below buttons
        //So pos pw-w would not move recieve_reward button outside of window
        <<#canReroll>>
        Button_text {
          id:t = 'btn_reroll'
          task_id:t='<<id>>'
          visualStyle:t='purchase'
          text:t = '#battletask/reroll'
          on_click:t = 'onTaskReroll'
          hideText:t='yes'
          btnName:t='X'
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
          btnName:t='X'
          visualStyle:t='secondary'
          buttonWink {}
          ButtonImg{}
        }
        <</canGetReward>>
      }
      <</isOnlyInfo>>
    }

    expandImg {
      id:t='expandImg'
      height:t='0.01@scrn_tgt'
      width:t='2h'
      pos:t='50%pw-50%w, ph-h'; position:t='absolute'
      background-image:t='#ui/gameuiskin#expand_info'
      background-color:t='@premiumColor'
      <<#isOnlyInfo>> hideExpandImg:t='yes' <</isOnlyInfo>>
    }

    <<#isPromo>>
    <<#otherTasksNum>>
      textareaNoTab {
        text:t='<<?mainmenu/battleTasks/OtherTasksCount>> (<<otherTasksNum>>)'
        position:t='relative'
        pos:t='pw-w, 0'
      }
    <</otherTasksNum>>
    <</isPromo>>

    <<#isPromo>>
    <<#warbondLevelPlace>>
      progressBoxPlace {
        id:t='progress_box_place'
        left:t='pw-w - 0.4@warbondShopLevelItemHeight'
        position:t='relative'
        margin:t='0, 0.015@scrn_tgt'
        size:t='75%pw, 1@warbondShopLevelProgressHeight'

        <<@warbondLevelPlace>>
      }
    <</warbondLevelPlace>>

    <<#newItemsAvailable>>
      tdiv {
        width:t='pw'
        flow:t='vertical'
        margin:t='0, 0.01@scrn_tgt'
        tdiv {
          left:t='pw-w'
          position:t='relative'
          <<@warbondsNewIconWidget>>
          textarea {
            text:t='#mainmenu/newItemsAvailable'
            overlayTextColor:t='warning'
          }
        }
      <<^isConsoleMode>>
        Button_text {
          id:t = 'btn_warbond_shop'
          left:t='pw-w'
          position:t='relative'
          text:t = '#mainmenu/btnWarbondsShop'
          on_click:t = 'onWarbondsShop'
          visualStyle:t='secondary'
          buttonWink {}
        }
      <</isConsoleMode>>
      }
    <</newItemsAvailable>>
    <</isPromo>>
  }

  fgLine {}
}

<<#isPromo>>
collapsedContainer {
  <<#collapsedAction>> on_click:t='<<collapsedAction>>Collapsed' <</collapsedAction>>
  shortInfoBlock {
    <<#taskStatus>>
      battleTaskStatus:t='<<taskStatus>>'
      statusImg {}
    <</taskStatus>>
    <<#taskDifficultyImage>>
      cardImg {
        type:t='medium'
        background-image:t='<<taskDifficultyImage>>'
      }
    <</taskDifficultyImage>>
    shortHeaderText { text:t='<<collapsedText>>' }

    <<^needShowProgressBar>>
      <<#needShowProgressValue>>
        shortHeaderText { text:t=' (<<progressValue>>/<<progressMaxValue>>) ' }
      <</needShowProgressValue>>
    <</needShowProgressBar>>

    shortHeaderIcon { text:t='<<collapsedIcon>>' }
  }

  <<#needShowProgressBar>>
  progressDiv {
    left:t='pw-w'
    position:t='relative'
    margin-bottom:t='0.005@sf'
    battleTaskProgress {
      top:t='50%ph-50%h'
      position:t='relative'
      width:t='0.4@arrowButtonWidth'
      value:t='<<progressBarValue>>'
    }
    <<#needShowProgressValue>>
    textarea {
      text:t='( <<progressValue>> / <<progressMaxValue>> )'
      smallFont:t='yes'
      overlayTextColor:t='disabled'
    }
    <</needShowProgressValue>>
  }
  <</needShowProgressBar>>
  <<#getTooltipId>>
    title:t='$tooltipObj'
    tooltipObj {
      tooltipId:t='<<getTooltipId>>'
      display:t='hide'
      on_tooltip_open:t='onGenericTooltipOpen'
      on_tooltip_close:t='onTooltipObjClose'
    }
  <</getTooltipId>>
}
hangarToggleButton {
  id:t='<<id>>_toggle'
  on_click:t='onToggleItem'
  type:t='right'
  directionImg {}
}
<</isPromo>>
<</items>>
