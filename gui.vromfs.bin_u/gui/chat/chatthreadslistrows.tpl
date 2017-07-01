<<#threads>>
expandable {
  id:t='room_<<roomId>>'
  roomId:t='<<roomId>>'
  class:t='simple'
  input-transparent:t='yes'
  <<#isJoined>>
  active:t='yes'
  <</isJoined>>
  <<#noSelect>>
  fullSize:t='yes'
  <</noSelect>>
  <<#addTimer>>
  behavior:t = 'Timer'
  timer_handler_func:t = 'onThreadTimer'
  timer_interval_msec:t='1000'
  <</addTimer>>

  <<^onlyInfo>>
  on_click:t = 'onJoinThread'
  clickable:t='yes'
  <</onlyInfo>>

  selImg {
    id:t='thread_row_sel_img'
    flow:t='vertical'

    tdiv {
      width:t='pw'

      tdiv {
        <<#needShowLang>>
        tdiv {
          margin-right:t='0.02@scrn_tgt'
          <<#getLangsList>>
          cardImg { background-image:t='<<icon>>' }
          <</getLangsList>>
        }
        <</needShowLang>>

        textareaNoTab {
          id:t='ownerName_<<roomId>>'
          pos:t='0, 50%ph-50%h'
          position:t='relative'
          roomId:t='<<roomId>>'
          overlayTextColor:t='minor'
          tinyFont:t='yes'
          text:t='<<getOwnerText>>'

          behaviour:t='button'
          on_r_click:t='onUserInfo'
          on_click:t='onUserInfo'
        }

        <<#canEdit>>
        Button_text {
          roomId:t='<<roomId>>'
          pos:t='0.02@scrn_tgt, 50%ph-50%h'
          position:t='relative'
          class:t='tinyButton'

          text:t = '#chat/editThread'
          on_click:t = 'onEditThread'
        }
        <</canEdit>>
      }

      textareaNoTab {
        id:t='thread_members'
        pos:t='pw-w, 0'
        position:t='absolute'
        tinyFont:t='yes'
        overlayTextColor:t='minor'
        text:t='<<getMembersAmountText>>'
      }
    }

    tdiv {
      width:t='pw'

      textareaNoTab {
        id:t='thread_title'
        width:t='fw'
        max-height:t='0.09@scrn_tgt_font'
        pos:t='0, ph-h'
        position:t='relative'
        padding-right:t='4*@sf/@pf'
        tinyFont:t='yes'
        overlayTextColor:t='active'
        overflow-y:t='auto'
        scrollbarShortcutsOnSelect:t="focus"
        text:t='<<getTitle>>'
      }

      <<^onlyInfo>>
      <<#isGamepadMode>>
      tdiv {
        height:t='@buttonHeight -0.005@scrn_tgt -2'
        pos:t='0, ph-h'
        position:t='relative'

        Button_text {
          id:t='action_btn'
          pos:t='0, ph-h+2' //2 bottom button pixels are shade
          position:t='relative'
          noMargin:t='yes'
          roomId:t='<<roomId>>'

          text:t = '#mainmenu/btnAirAction'
          on_click:t = 'onThreadsActivate'
          btnName:t='A'
          ButtonImg { showOnSelect:t='focus' }
        }
      }
      <</isGamepadMode>>
      <</onlyInfo>>
    }
  }
}
<</threads>>
