<<#playerListItem>>
contactItem {
  id:t='<<blockID>>';

  contactStatusImg {
    id:t='statusImg';
    background-image:t=''
    background-color:t='@transparent'
    pos:t='pw - w, ph/2 - h/2'; position:t='absolute'
  }

  img {
    id:t='pilotIconImg'
    position:t='relative'
    pos:t='0, ph/2 - h/2'
    size:t='@cIco, @cIco'
    background-image:t='#ui/opaque#<<pilotIcon>>_ico'
  }

  tdiv {
    flow:t='vertical'
    position:t='relative'
    top:t='ph/2 - h/2'

    text {
      id:t='contactName'
      input-transparent:t='yes'
      playerName:t='yes'
    }
    textareaNoTab {
      id:t='contactPresence'
      input-transparent:t='yes'
      contact_presence:t='yes'
      playerPresence:t='yes'
      padding-left:t='6'
    }
  }

  on_r_click:t = 'onPlayerRClick';
  title:t='$tooltipObj';

  tdiv {
    id:t='contact_buttons_holder';
    position:t='absolute';
    pos:t='pw - w - @sIco, 0.5ph-0.5h';
    display:t='hide';
    contact_buttons_holder:t='yes';
    contact_buttons_contact_uid:t='<<contactUID>>';

    Button_text {
      id:t='btn_friendAdd';
      tooltip:t='#contacts/friendlist/add';
      on_click:t='onFriendAdd';
      class:t='image16';
      input-transparent:t='yes';
      img {
        background-image:t='#ui/gameuiskin#btn_friend_add';
      }
    }

    Button_text {
      id:t='btn_friendRemove';
      tooltip:t='#contacts/friendlist/remove';
      on_click:t='onFriendRemove';
      class:t='image16';
      input-transparent:t='yes';
      img {
        background-image:t='#ui/gameuiskin#btn_friend_remove';
      }
    }

    Button_text {
      id:t='btn_blacklistAdd';
      tooltip:t='#contacts/blacklist/add';
      on_click:t='onBlacklistAdd';
      class:t='image16';
      input-transparent:t='yes';
      img {
        background-image:t='#ui/gameuiskin#btn_blacklist_add';
      }
    }

    Button_text {
      id:t='btn_blacklistRemove';
      tooltip:t='#contacts/blacklist/remove';
      on_click:t='onBlacklistRemove';
      class:t='image16';
      input-transparent:t='yes';
      img {
        background-image:t='#ui/gameuiskin#btn_blacklist_remove';
      }
    }

    Button_text {
      id:t='btn_message';
      tooltip:t='#contacts/message';
      on_click:t='onPlayerMsg';
      class:t='image16';
      input-transparent:t='yes';
      enable:t='no';
      img {
        background-image:t='#ui/gameuiskin#btn_send_private_message';
      }
    }

    Button_text {
      id:t='btn_squadInvite';
      tooltip:t='#contacts/invite';
      on_click:t='onSquadInvite';
      class:t='image16';
      input-transparent:t='yes';
      enable:t='no';
      img {
        background-image:t='#ui/gameuiskin#btn_invite';
      }
    }

    Button_text {
      id:t='btn_usercard';
      tooltip:t='#mainmenu/btnUserCard';
      on_click:t='onUsercard';
      class:t='image16';
      input-transparent:t='yes';
      enable:t='no';
      img {
        background-image:t='#ui/gameuiskin#btn_usercard';
      }
    }

    /*Button_text {
      id:t='btn_steamFriends';
      tooltip:t='#mainmenu/btnSteamFriendsAdd';
      on_click:t='onSteamFriendsAdd';
      class:t='image16';
      input-transparent:t='yes';
      img {
        background-image:t='#ui/gameuiskin#btn_steam_friends_add';
      }
    }

    Button_text {
      id:t='btn_facebookFriends';
      tooltip:t='#mainmenu/btnFacebookFriendsAdd';
      on_click:t='onFacebookFriendsAdd';
      class:t='image16';
      input-transparent:t='yes';
      img {
        background-image:t='#ui/gameuiskin#btn_facebook_friends_add';
      }
    }*/
  }

  tooltipObj {
    id:t='tooltip';
    uid:t='';
    on_tooltip_open:t='onContactTooltipOpen';
    on_tooltip_close:t='onTooltipObjClose';
    display:t='hide';
  }
}
<</playerListItem>>

<<#playerButton>>
buttonPlayer {
  tooltip:t='<<tooltip>>';
  on_click:t='<<callback>>';
  btnText {
    text:t='<<name>>';
  }
  img {
    background-image:t='<<icon>>';
  }
}
<</playerButton>>

<<#searchAdvice>>
textarea {
  id:t='<<searchAdviceID>>';
  text:t='#contacts/search_advice';
  display:t='hide';
  width:t='pw';
  removeParagraphIndent:t='yes';
}
<</searchAdvice>>
