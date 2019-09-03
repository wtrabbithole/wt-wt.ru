tdiv {
  size:t='sw, sh';
  position:t='root';
  pos:t='0, 0';
  behavior:t='button';
  on_click:t='goBack';
  on_r_click:t='goBack';
  flow:t='vertical';
}

frame {
  game_mode_select {
    id:t='game_mode_select';
    width:t='@gameModeSelectWindowWidth';
    max-height:t='p.p.h-0.045@sf - 2@framePadding - 1@bh';
    position:t='relative';
    overflow-y:t='auto';
    flow:t='vertical'
    total-input-transparent:t='yes';
    padding:t='1@framePadding';
    re-type:t='9rect';
    background-color:t='@white';
    background-repeat:t='expand';
    background-image:t='#ui/gameuiskin#block_bg_rounded_gray';
    background-position:t='4, 4, 4, 4';

    <<#categoriesHeaderText>>
    textAreaCentered {
      width:t='pw'
      pos:t='50%pw-50%w, 0'
      position:t='relative'
      text:t='<<categoriesHeaderText>>'
    }
    <</categoriesHeaderText>>

    <<#categories>>
    <<#separator>>
    separator {}
    <</separator>>
    general_game_modes {
      id:t='<<id>>';
      behavior:t='posNavigator';
      navigatorShortcuts:t='active';
      moveX:t='linear';
      moveY:t='closest';
      childsActivate:t='yes';
      on_wrap_up:t='onWrapUp';
      on_wrap_down:t='onWrapDown';
      on_activate:t='<<onActivate>>';
      on_set_focus:t='<<onSetFocus>>';
      <<#onSelectOption>>
      on_select:t='<<onSelect>>'
      <</onSelectOption>>

      <<#blackBackground>>
      re-type:t='9rect';
      background-color:t='@white';
      background-repeat:t='expand';
      background-image:t='#ui/gameuiskin#selectbox_bg';
      background-position:t='5, 5, 5, 5';
      <</blackBackground>>

      <<#modes>>
      <<#separator>>
      separator {
        enable:t='no';
      }
      <</separator>>
      game_mode_block {
        <<#isWide>>
          wide:t='yes';
        <</isWide>>
        <<^isWide>>
          <<#isNarrow>>
            narrow:t='yes';
          <</isNarrow>>
        <</isWide>>
        <<#hasContent>>
        id:t='<<id>>';
        tooltip:t='<<#crossplayTooltip>><<crossplayTooltip>>\n<</crossplayTooltip>><<tooltip>>'
        value:t='<<value>>';

        <<#isFeatured>>
        featured:t='yes';
        <</isFeatured>>

        <<#inactiveColor>>
          inactiveColor:t='yes'
        <</inactiveColor>>

        on_click:t='<<onClick>>'
        <<#onHover>>
          on_hover:t='<<onHover>>'
        <</onHover>>

        <<#isCurrentGameMode>>
          current_mode:t='yes';
        <</isCurrentGameMode>>

        behavior:t='button';
        shortcutActivate:t='J:A | Space';
        background-color:t='@white';
        background-repeat:t='expand';
        background-image:t='#ui/gameuiskin#item';
        background-position:t='3, 4, 3, 5';
        re-type:t='9rect';

        img {
          background-image:t='<<image>>';
          background-repeat:t='repeat-y';
        }

        <<#videoPreview>>
        movie {
          movie-load='<<videoPreview>>'
          movie-autoStart:t='yes'
          movie-loop:t='yes'
        }
        <</videoPreview>>

        glow{}

        title {
          css-hier-invalidate:t='yes';
          tdiv {
            css-hier-invalidate:t='yes';
            flow:t='vertical';

            textarea {
              game_mode_textarea:t='yes';
              text:t='<<#isCrossPlayRequired>><<?icon/cross_play>> <</isCrossPlayRequired>><<text>>';
              <<#crossPlayRestricted>>
                overlayTextColor:t='warning'
              <</crossPlayRestricted>>
            }
            textarea {
              id:t='<<id>>_text_description'
              game_mode_textarea:t='yes';
              text:t='<<textDescription>>';
            }
          }
          <<#newIconWidgetContent>>
          div {
            id:t='<<newIconWidgetId>>'
            pos:t='0, ph-h'; position:t='relative'
            <<@newIconWidgetContent>>
          }
          <</newIconWidgetContent>>
        }

        <<#eventTrophyImage>>
        tdiv {
          height:t='1@mIco'
          padding-left:t='0.0125@scrn_tgt'

          textareaNoTab {
            pos:t='0, 50%(ph-h)'; position:t='relative'
            text:t="#reward/everyDay"
            <<^inactiveColor>>
              <<#isTrophyRecieved>>
                overlayTextColor:t='silver'
              <</isTrophyRecieved>>
              <<^isTrophyRecieved>>
                overlayTextColor:t='active'
              <</isTrophyRecieved>>
            <</inactiveColor>>
          }

          tdiv {
            pos:t='0, 50%(ph-h)'; position:t='relative'
            <<@eventTrophyImage>>

            <<#isTrophyRecieved>>
              img {
                pos:t='50%pw-20%w, 50%ph-50%h'
                position:t='absolute'
                size:t='1@mIco, 1@mIco'
                background-image:t='#ui/gameuiskin#check.svg'
                background-svg-size:t='1@mIco, 1@mIco'
                input-transparent:t='yes'
              }
            <</isTrophyRecieved>>
          }
        }
        <</eventTrophyImage>>

        <<#checkBox>>
        CheckBoxImg {}
        <</checkBox>>

        <<#showEventDescription>>
        Button_text {
          visualStyle:t='header';
          size:t='0.4ph, 0.4ph';
          right:t='0';
          padding-top:t='0';
          on_click:t='onEventDescription';
          tooltip:t='#mainmenu/titleEventDescription';
          value:t='<<eventDescriptionValue>>';
          position:t='absolute';
          display:t='hide';
          show_on_parent_hover:t='yes'
          text {
            text:t='?';
            overflow:t='hidden';
            pare-text:t='yes';
            pos:t='50%pw-50%w, 50%ph-50%h';
            position:t='relative';
          }
        }
        <</showEventDescription>>

        <<#hasCountries>>
        tdiv {
          css-hier-invalidate:t='yes';
          <<#countries>>
          img {
            size:t='@cIco, @cIco';
            background-image:t='<<img>>';
            background-svg-size:t='@cIco, @cIco'
            margin-left:t='0.01@sf';
          }
          <</countries>>
        }
        <</hasCountries>>

        <<#linkIcon>>
        dark_corner {
          link_icon {}
        }
        <</linkIcon>>
        <</hasContent>>
        <<^hasContent>>
        enable:t='no';
        <</hasContent>>
      }
      <</modes>>
    }
    <</categories>>
  }

  tdiv {
    height:t='0.045@sf'
    flow:t='horizontal'

    gameModeChangeButton {
      position:t='relative'
      top:t='ph/2 - h/2 + 0.5@blockInterval'
      on_click:t='onOpenClusterSelect'
      btnName:t='X'
      dropMenuArrow {}
      dropMenuSeparator{}
      ButtonImg{}
      activeText {
        id:t='cluster_select_button'
        height:t='ph'
        padding-left:t='1@blockInterval'
      }
    }

    Button_text {
      id:t='event_description_console_button'
      text:t='#mainmenu/titleEventDescription'
      position:t='relative'
      pos:t='1@blockInterval, 0.5@blockInterval'
      btnName:t='L3'
      on_click:t='onEventDescription'
      display:t='hide'
      enable:t='no'

      ButtonImg {}
    }

    Button_text {
      id:t='wiki_link'
      position:t='absolute'
      pos:t='@gameModeSelectWindowWidth-w-1@blockInterval, 0'
      isLink:t='yes'
      isFeatured:t='yes'
      link:t='#url/wiki_matchmaker'
      on_click:t='onMsgLink'
      visualStyle:t='noFrame'
      display:t='hide'
      enable:t='no'

      btnText{
        text:t='#profile/wiki_matchmaking'
        underline{}
      }
      btnName:t='R3'
      ButtonImg {}
    }
  }

  <<#hasTimer>>
  dummy {
    id:t='game_modes_timer'
    behavior:t='Timer'
    timer_handler_func:t='onTimerUpdate'
    timer_interval_msec:t='1000'
  }
  <</hasTimer>>
}
