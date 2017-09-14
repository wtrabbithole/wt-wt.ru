activeText {
  id:t='txt_squad_title'
  text:t='#squad/title'
  pos:t='0, 50%(ph-h)'; position:t='relative'
  margin-right:t='@buttonTextPadding'
  inactive:t='yes'
}

Button_text {
  id:t='btn_squad_ready'
  pos:t='0, 50%(ph-h)'; position:t='relative'
  display:t='hide'
  text:t='#mainmenu/btnReady'
  on_click:t='onSquadReady'
}

Button_text {
  id:t='btn_squadPlus'
  class:t='image'
  tooltip:t='#contacts/invite'
  on_click:t='onSquadPlus'

  squadButtonImg {
    pos:t='50%(pw-w), 50%(ph-h)'; position:t='absolute'
    background-image:t='#ui/gameuiskin#btn_inc'
    tooltip:t='#contacts/invite'
  }
}

animated_wait_icon
{
  id:t='wait_icon'
  pos:t='0, 50%(ph-h)'
  position:t="relative"
  class:t='byParent'
  background-rotation:t = '0'

  wait_icon_cock {}
}

<<#members>>
Button_text {
  id:t='member_<<id>>'
  display:t='hide'
  css-hier-invalidate:t='yes'
  class:t='squadWidgetMember'
  uid:t=''
  isInvite:t='no'
  status:t='offline'
  title:t='$tooltipObj'
  on_click:t='onSquadMemberMenu'
  on_r_click:t='onSquadMemberMenu'

  squadMemberNick {
    id:t='speaking_member_nick_<<id>>'
    pos:t='50%(pw-w), -h-1@blockInterval'; position:t='absolute'

    activeText {
      id:t='speaking_member_nick_text_<<id>>'
      margin:t='1@blockInterval'
      tinyFont:t='yes'
    }
  }

  tdiv {
    height:t='1@cIco'
    width:t='pw'
    pos:t='0, 0.5(ph-h)'; position:t='relative'
    css-hier-invalidate:t='yes'

    memberIcon {
      id:t='member_icon_<<id>>'
      pos:t='0, 2*@sf/@pf_outdated'; position:t='relative'
      bgcolor:t='#FFFFFF'
      background-image:t=''
      border:t='yes'
      border-color:t='@black'
    }

    tdiv {
      id:t='member_state_block_<<id>>'
      height:t='ph'
      margin-left:t='2@dp'
      flow:t='vertical'
      css-hier-invalidate:t='yes'

      tdiv {
        margin-left:t='1@dp'
        css-hier-invalidate:t='yes'

        squadMemberStatus {
          id:t='member_ready_<<id>>'
          margin-top:t='2*@sf/@pf_outdated'
        }

        squadMemberVoipStatus {
          id:t='member_voip_<<id>>'
          margin-left:t='5@sf/@pf'
          isVoipActive:t='no'
        }
      }

      tdiv {
        id:t='member_country_<<id>>'
        pos:t='0, -1@dp'; position:t='relative'
        size:t='@sIco, @sIco'
        bgcolor:t='#FFFFFF'
        background-image:t=''
      }
    }
  }

  animated_wait_icon {
    id:t='member_waiting_<<id>>'
    display:t='hide'
    background-rotation:t='0'
    wait_icon_cock {}
  }

  tooltipObj {
    id:t='member_tooltip_<<id>>'
    uid:t=''
    on_tooltip_open:t='onContactTooltipOpen'
    on_tooltip_close:t='onTooltipObjClose'
    display:t='hide'
  }
}
<</members>>

Button_text {
  id:t='btn_squadInvites'
  class:t='image'
  tooltip:t='#squad/invited_players'
  on_click:t='onSquadInvitesClick'
  type:t='squadInvites'

  tdiv {
    id:t='invite_widget'
    pos:t='50%(pw-w), 0'; position:t='absolute'
  }

  squadButtonImg {
    pos:t='50%(pw-w), 50%(ph-h)'; position:t='absolute'
  }
}

Button_text {
  id:t='btn_squadLeave'
  class:t='image'
  tooltip:t=''
  on_click:t='onSquadLeave'
  type:t='squadLeave'

  squadButtonImg {
    pos:t='50%(pw-w), 50%(ph-h)'; position:t='absolute'
    background-image:t='#ui/gameuiskin#close'
  }
}
