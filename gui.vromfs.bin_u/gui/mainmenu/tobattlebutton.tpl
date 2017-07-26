textareaNoTab {
  id:t='server_message';
  position:t='absolute';
  pos:t='50%pw-50%w, 2@topBarHeight';
  text:t='';
  overlayTextColor:t='warning'
  max-width:t='0.4sw';
  input-transparent:t='yes'
}

tdiv{
  position:t='absolute';
  pos:t='0, 13*@sf/@pf';
  size:t='pw, 0.057@scrn_tgt_font';
  input-transparent:t='yes';
  display:t='hide';
  tdiv{
    re-type:t='9rect';
    position:t='relative';
    top:t='4*@sf/@pf';
    size:t='pw, ph';
    foreground-image:t='#ui/gameuiskin#button_bright_bg';
    foreground-position:t='16';
    foreground-repeat:t='expand';
    foreground-color:t='#aa000000';
    input-transparent:t='yes';
    if_target_pc:t='yes';
  }
}

tdiv{
  position:t='absolute';
  pos:t='0, 8*@sf/@pf';
  size:t='pw, 0.0565@scrn_tgt_font';
  input-transparent:t='yes';
  display:t='hide';
  tdiv{
    re-type:t='9rect';
    position:t='relative';
    top:t='4*@sf/@pf';
    size:t='pw, ph';
    foreground-image:t='#ui/gameuiskin#button_bright_bg';
    foreground-position:t='16';
    foreground-repeat:t='expand';
    foreground-color:t='#ffffff';
    input-transparent:t='yes';
    if_target_pc:t='yes';
  }
}

Button_text {
  id:t='to_battle_button';
  position:t='absolute';
  pos:t='50%pw-50%w, 3';
  class:t='battle';
  text:t='#mainmenu/toBattle';
  on_click:t='onStart';
  css-hier-invalidate:t='yes';
  is_to_battle_button:t='yes';
  isCancel:t='no';

  <<^enableEnterKey>>
    noEnter:t='yes'
  <</enableEnterKey>>

  style:t='margin-right: 0*@sf/@pf; height: 1@topMenuBattleButtonHeight; min-width: pw - 14*@sf/@pf;'

  buttonWink {
    _transp-timer:t='0';
  }

  buttonGlance {}

  pattern{
    type:t='bright_texture';
  }

  btnText {
    id:t='to_battle_button_text';
    text:t='#mainmenu/toBattle';
    style:t='text-shade-color: #55000000; color: #ffffff; text-shade:smooth:48; text-shade-x:0; text-shade-y:0;';
  }

  btnName:t='X';
  ButtonImg{
    id:t='to_battle_console_image'
    position:t='absolute';
    pos:t='0.5pw-0.5w, ph-0.5h';
  }
}
