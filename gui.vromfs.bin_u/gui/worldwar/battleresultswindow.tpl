frame {
  size:t='1.3@sf, 1@maxWindowHeight'
  pos:t='50%pw-50%w, 1@minYposWindow'
  position:t='absolute'
  class:t='wnd'

  frame_header {
    activeText {
      id:t='wnd_title'
      position:t='relative'
      pos:t='0, 0'
      text:t='<<getBattleTitle>>'
      caption:t='yes'
    }

    Button_close {
      img {}
    }
  }

  tdiv {
    size:t='pw, fh - 1@navBarBattleButtonHeight'

    include "gui/worldWar/battleResults"
  }

  navBar{
    navLeft{
      <<#hasReplay>>
      Button_text {
        text:t = '#mainmenu/btnViewServerReplay'
        btnName:t='Y'
        tooltip:t='<<getReplayBtnTooltip>>'
        _on_click:t='onViewServerReplay'
        ButtonImg {}
      }
      <</hasReplay>>
      activeText {
        style:t='color:@fadedTextColor'
        text:t='<<getBattleDescText>>'
      }
    }
    navRight{
      Button_text {
        text:t = '#mainmenu/btnClose'
        btnName:t='B'
        _on_click:t='goBack'
        ButtonImg {}
      }
    }
  }
}
