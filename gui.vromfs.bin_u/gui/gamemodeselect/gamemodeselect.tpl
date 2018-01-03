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
    width:t='0.759@scrn_tgt';
    max-height:t='p.p.h-0.045@sf - 2@framePadding - 1@bh';
    position:t='relative';
    overflow-y:t='auto';
    flow:t='vertical'
    total-input-transparent:t='yes';
    padding:t='0.01@scrn_tgt';
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
        <<#hasContent>>
        id:t='<<id>>';
        tooltip:t='<<tooltip>>'
        value:t='<<value>>';

        <<#isFeatured>>
        featured:t='yes';
        <</isFeatured>>
        <<^isFeatured>>
        featured:t='no';
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
        <<^isCurrentGameMode>>
        current_mode:t='no';
        <</isCurrentGameMode>>
        behavior:t='button';
        shortcutActivate:t='J:A | Space';
        background-color:t='@white';
        background-repeat:t='expand';
        background-image:t='#ui/gameuiskin#item';
        background-position:t='3, 4, 3, 5';
        re-type:t='9rect';
        <<#isWide>>
        wide:t='yes';
        <</isWide>>
        <<^isWide>>
        wide:t='no';
        <</isWide>>

        img {
          background-image:t='<<image>>';
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
              text:t='<<text>>';
            }
            textarea {
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
            <<#isTrophyRecieved>>
              overlayTextColor:t='silver'
            <</isTrophyRecieved>>
            <<^isTrophyRecieved>>
              overlayTextColor:t='active'
            <</isTrophyRecieved>>
          }

          tdiv {
            pos:t='0, 50%(ph-h)'; position:t='relative'
            <<@eventTrophyImage>>

            <<#isTrophyRecieved>>
              img {
                pos:t='50%pw-20%w, 50%ph-50%h'
                position:t='absolute'
                size:t='1@mIco, 1@mIco'
                background-image:t='#ui/gameuiskin#check'
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

  div {
    id:t='cluster_select_button_container';
    width:t='0.759@scrn_tgt';
    height:t='0.045@sf';
    padding-top:t='0.3@sIco';
    padding:t='0.005@sf';
    cluster_select_button_container:t='yes';
    behavior:t='posNavigator';
    navigatorShortcuts:t='active';
    moveX:t='linear';
    moveY:t='linear';
    childsActivate:t='yes';
    on_wrap_up:t='onWrapUp';
    on_wrap_down:t='onWrapDown';
    on_activate:t='onClusterSelectActivate';
    on_set_focus:t='onGameModeSelectFocus';

    button {
      id:t='cluster_select_button';
      height:t='0.035@sf';
      position:t='relative';
      padding-left:t='1.2@sIco';
      on_click:t='onOpenClusterSelect';
      shortcutActivate:t='J:A | Space';

      img {
        position:t='absolute';
        pos:t='12*@sf/@pf_outdated, ph/2 - h/2';
        size:t='5*@sf/@pf_outdated, ph';
        rotation:t='0';
        background-image:t='#ui/gameuiskin#drop_menu_separator';
        bgcolor:t='#FFFFFF';
        input-transparent:t='yes';
      }

      img {
        position:t='absolute';
        pos:t='0, ph/2 - h/2';
        size:t='11*@sf/@pf_outdated, 8*@sf/@pf_outdated';
        rotation:t='0';
        background-image:t='#ui/gameuiskin#drop_menu_icon';
        bgcolor:t='#FFFFFF';
        input-transparent:t='yes';
      }
    }

    tdiv {
      position:t='absolute'
      pos:t='pw-1.01w, ph-1.1h'

      Button_text {
        id:t='event_description_console_button'
        text:t='#mainmenu/titleEventDescription'
        btnName:t='X'
        on_click:t='onEventDescription'
        display:t='hide'
        enable:t='no'

        ButtonImg {}
      }

      Button_text {
        id:t='activate_console_button'
        text:t='#mainmenu/openGameModeLink'
        btnName:t='X'
        on_click:t='onActivateConsoleButton'
        display:t='hide'
        enable:t='no'

        ButtonImg {}
      }
    }
  }
}
