tdiv {
  flow:t='vertical'

  tdiv {
    img {
      size:t='100, 100'
      background-image:t='#ui/images/avatars/<<icon>>'
    }
    tdiv {
      flow:t='vertical'
      margin-left:t='0.01@scrn_tgt'
      textareaNoTab {
        text:t='<<name>>'
        max-width:t='70*@scrn_tgt/100.0'
      }
      tdiv {
        max-width:t='@sIco + 100*@scrn_tgt/100.0'
        img {
          id:t='statusImg'
          background-image:t='<<presenceIcon>>'
          pos:t='0, ph/2 - h/2'; position:t='relative'
          size:t='@sIco, @sIco'
        }
        textareaNoTab {
          margin-left:t='0.01@scrn_tgt'
          id:t='contact-presenceText'
          text:t='<<presenceText>>'
          max-width:t='70*@scrn_tgt/100.0'
        }
      }
      textareaNoTab {
        text:t='<<?stats/missions_wins>><<?ui/colon>><<wins>>'
        max-width:t='70*@scrn_tgt/100.0'
      }
      tdiv {
        textareaNoTab {
          text:t='<<?mainmenu/rank>><<?ui/colon>><<rank>>'
          max-width:t='70*@scrn_tgt/100.0'
        }
      }
    }
  }

  tdiv {
    id:t='contact-aircrafts'
    flow:t='vertical'

    <<#unitList>>
    airRow {
    <<#header>>
      text {
        text:t='<<header>>';
        overlayTextColor:t='userlog'
      }

      text {
        text:t='#ui/colon';
        overlayTextColor:t='userlog'
      }
    <</header>>

    <<#unit>>
      cardImg {
        background-image:t='<<countryIcon>>'
      }
      text {
        text:t='(<<rank>>)'
      }
      activeText {
        text:t='#<<unit>>_shop'
      }
    <</unit>>

    <<#noUnit>>
      cardImg {
        background-image:t='<<countryIcon>>'
      }
      activeText {
        text:t='-'
      }
    <</noUnit>>
    }
    <</unitList>>
  }
}
