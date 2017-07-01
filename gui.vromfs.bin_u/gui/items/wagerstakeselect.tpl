div {
  size:t='sw, sh'
  position:t='root'
  pos:t='0, 0'
  behavior:t='button'
  on_click:t='goBack'
  on_r_click:t='goBack'
  input-transparent:t='yes'
  accessKey:t='Esc | J:B'
}

popup_menu {
  id:t='stake_select'
  cluster_select:t='yes'
  menu_align:t='<<align>>'
  pos:t='<<position>>'
  position:t='root'
  total-input-transparent:t='yes'
  width:t='0.325*@scrn_tgt'
  height:t='0.185*@scrn_tgt'
  flow:t='vertical'

  Button_close {
    pos:t='pw-w, 0'
    position:t='absolute'
    img {}
  }

  activeText {
    text:t='#items/wager/stake/header'
    padding-top:t='1*@scrn_tgt/100.0'
    padding-bottom:t='2*@scrn_tgt/100.0'
    left:t='50%pw-50%w'
    position:t='relative'
  }

  tdiv {
    left:t='50%pw-50%w-0.5*3.5*@scrn_tgt/100.0'
    position:t='relative'

    tdiv{
      id:t='btnDec_place'
      width:t='3*@scrn_tgt/100.0'
    }

    Button_text {
      id:t='buttonDec'
      text:t='-'
      square:t='yes'
      on_click:t='onButtonDec'
      //on_click_repeat:t='onButtonDecRepeat'
      pos:t='0, 50%ph-50%h'
      position:t='absolute'
      tooltip:t='#items/wager/stake/decStake'
    }

    invisSlider {
      id:t='skillSlider'
      size:t='20*@scrn_tgt/100.0, 2*@scrn_tgt/100.0'
      pos:t='0, 50%ph-50%h'
      position:t='relative'
      value:t='0'
      min:t='0'
      max:t='100'
      on_change_value:t='onSkillChanged'

      expProgress {
        id:t='newSkillProgress'
        width:t='pw - @sliderThumbWidth'
        pos:t='50%pw-50%w, 50%ph-50%h'
        position:t="absolute"
        type:t='new'
        value:t='70'
      }

      sliderButton{
        type:t='various'
        img{
          showWhenSelected:t='yes'
        }
      }
    }

    Button_text {
      id:t='buttonInc'
      text:t='+'
      square:t='yes'
      on_click:t='onButtonInc'
      //on_click_repeat:t='onButtonIncRepeat'
      position:t='absolute'
      //position:t='relative'
      pos:t='24*@scrn_tgt/100.0, 50%ph-50%h'
      tooltip:t='#items/wager/stake/incStake'
    }
  }

  textarea {
    id:t='stake_select_stake'
    talign:t='right'
    text:t=''
    left:t='50%pw-50%w'
    position:t='relative'
    padding-top:t='0.5*@scrn_tgt/100.0'
  }

  Button_text {
    text:t='#items/wager/stake/button'
    position:t='relative'
    left:t='50%pw-50%w'
    on_click:t='onMainButton'
    btnName:t='A'
    ButtonImg{}
  }

  <<#hasPopupMenuArrow>>
  popoup_menu_arrow{}
  <</hasPopupMenuArrow>>
}
