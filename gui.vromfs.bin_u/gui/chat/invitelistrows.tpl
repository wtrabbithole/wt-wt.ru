<<#invites>>
expandable {
  inviteUid:t='<<uid>>'
  class:t='simple'

  selImg {
    style:t='flow:horizontal;'

    tdiv {
      width:t='fw'
      flow:t='vertical'

      tdiv {
        ButtonImg {
          size:t='@cIco, @cIco'
          pos:t='0, 50%ph-50%h'
          position:t='relative'
          margin-right:t='0.01@scrn_tgt'
          showOnSelect:t='yes'
          iconName:t='X'
        }

        textareaNoTab {
          id:t='inviterName_<<uid>>'
          inviteUid:t='<<uid>>'
          overlayTextColor:t='userlog'
          text:t='<<inviterName>>'

          behaviour:t='button'
          on_r_click:t='onInviterInfo'
          on_click:t='onInviterInfo'
        }
      }

      tdiv {
        cardImg {
          background-image:t='<<getIcon>>'
        }

        textareaNoTab {
          width:t='fw'
          pos:t='0.01@scrn_tgt, 0'
          position:t='relative'
          overlayTextColor:t='active'
          text:t='<<getInviteText>>'
        }
      }
    }

    tdiv {
      pos:t='0, ph - h + 2' //+2 - is shadow under the buttons
      position:t='relative'
      //padding-right:t='8*@sf/@pf'

      Button_text {
        inviteUid:t='<<uid>>'
        class:t="double"
        tooltip:t = '#invite/accept'
        btnName:t='A'
        showOnSelect:t='yes'
        on_click:t = 'onAccept'
        ButtonImg {}
        img { background-image:t='#ui/gameuiskin#favorite' }
      }

      Button_text {
        inviteUid:t='<<uid>>'
        class:t="double"
        showOnSelect:t='yes'
        noMargin:t='yes'
        tooltip:t = '#invite/reject'
        btnName:t='Y'
        on_click:t = 'onReject'
        ButtonImg {}
        img { background-image:t='#ui/gameuiskin#icon_primary_fail' }
      }
    }
  }
}
<</invites>>
