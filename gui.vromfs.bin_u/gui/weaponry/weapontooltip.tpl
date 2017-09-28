tdiv {
  flow:t='vertical'
  textareaNoTab {
    text:t='<<name>>'
  }
  tooltipDesc {
    text:t='<<reqText>>'
  }
  tooltipDesc {
    text:t='<<desc>>'
  }
  table {
    allAlignLeft:t="yes"
    class:t='noPad'
    smallFont:t='yes'
    <<#bulletActions>>
    tr {
      td {
        padding-right:t='0.005@sf'
        modIcon{
          size:t='@modIcoSize, @modIcoSize'
          ignoreStatus:t='yes'
          wallpaper{
            size:t='pw, ph'
            pos:t='50%pw-50%w, 50%ph-50%h'
            position:t='absolute'
            pattern{type:t='bright_texture';}
          }
          tdiv{
            size:t='pw-6*@sf/@pf_outdated,ph-6*@sf/@pf_outdated'
            pos:t='50%pw-50%w, 50%ph-50%h'
            position:t='absolute'
            <<@visual>>
          }
        }
      }
      td { text { text:t='<<text>>'; valign:t='center' } }
    }
    <</bulletActions>>
  }
  tooltipDesc {
    text:t='<<addDesc>>'
  }

  <<#bulletParams>>
    textareaNoTab {
      pos:t='0, 0.015@sf'
      position:t='relative'
      text:t='<<header>>'
    }
    table {
      //pos:t='0, 0.01@sf'
      //position:t='relative'
      allAlignLeft:t="yes"
      class:t='noPad'
      smallFont:t='yes'

      <<#props>>
      tr {
        td { textareaNoTab { text:t='<<text>>' } }
        <<#value>>
        td { textareaNoTab { text:t='<<value>>'; padding-left:t='@blockInterval' } }
        <</value>>
        <<#values>>
        td { textareaNoTab { text:t='<<value>>'; padding-left:t='@blockInterval' } }
        <</values>>
      }
      <</props>>
    }
  <</bulletParams>>

  <<#bulletsDesc>>
  tooltipDesc {
    pos:t='0, 0.015@sf'
    position:t='relative'
    text:t='<<bulletsDesc>>'
  }
  <</bulletsDesc>>

  <<#warningText>>
  tdiv {
    pos:t='0, 5'
    position:t='relative'
    warning_icon {
      size:t='@cIco, @cIco'
      pos:t='0, ph/2-h/2'
      position:t='relative'
      background-image:t='#ui/gameuiskin#new_icon'
      background-color:t='@white'
    }
    textareaNoTab {
      pos:t='2@sf/@pf_outdated, ph/2-h/2'
      position:t='relative'
      smallFont:t='yes'
      overlayTextColor:t='warning'
      text:t='<<warningText>>'
    }
  }
  <</warningText>>

  <<#amountText>>
  textareaNoTab {
    pos:t='pw-w, 5'
    position:t='relative'
    smallFont:t='yes'
    text:t='<<amountText>>'
  }
  <</amountText>>

  <<#delayed>>
  animated_wait_icon
  {
    id:t='loading'
    pos:t="50%pw-50%w,0";
    position:t='relative';
    background-rotation:t = '0'
  }
  <</delayed>>
  <<#expText>>
  textareaNoTab {
    smallFont:t='yes'
    pos:t='pw-w, 5'
    position:t='relative'
    text:t='<<expText>>'
  }
  <</expText>>
  <<#showPrice>>
  tdiv{
    id:t='discount';
    smallFont:t='yes'
    pos:t='pw-w, 5'
    position:t='relative'
    textareaNoTab{
      text:t='<<?ugm/price>><<#noDiscountPrice>><<?ugm/withDiscount>><</noDiscountPrice>><<?ui/colon>>'
    }
    tdiv{
      textareaNoTab{
        text:t='<<noDiscountPrice>>'
        margin-right:t='3'
        tdiv{
          pos:t='50%pw-50%w, 50%ph-50%h';
          position:t='absolute';
          size:t='pw, 1';
          background-color:t='@oldPrice';
        }
      }
      textareaNoTab{
        text:t='<<currentPrice>>'
      }
    }
  }
  <</showPrice>>
}

dummy {
  id:t = 'weapons_timer';
  behavior:t = 'Timer';
  timer_handler_func:t = 'onUpdateWeaponTooltip';
}
