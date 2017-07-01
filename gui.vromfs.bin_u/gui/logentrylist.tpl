<<#logEntries>>
expandable {
  id:t='<<id>>'

  selImg {
    tdiv {
      size:t='pw, 0.055@scrn_tgt'
      padding-left:t='0.08@scrn_tgt'
      padding-right:t='0.01@scrn_tgt'

      tdiv {
        position:t='absolute'
        pos:t='0.04@scrn_tgt - w/2, ph/2 - h/2'

        cardImg {
          id:t='log_icon'
        }

        cardImg {
          id:t='log_icon2'
          margin-left:t='0.005@scrn_tgt'
          background-image:t=''
        }
      }

      tdiv {
        position:t='absolute'
        pos:t='-1, -2'
        bonus {
          id:t='log_bonus'
        }
      }

      textAreaNoScroll {
        id:t='name'
        width:t='fw'
        max-height:t='ph'
        pare-text:t='yes'
        valign:t='center'
        class:t='active'
        overflow:t='hidden'
        padding-top:t='-0.005@scrn_tgt'
        text:t='<<header>>'
      }

      text {
        id:t='time'
        text:t='<<time>>'
        min-width:t='0.20@scrn_tgt_font'
        valign:t='center'
        text-align:t='right'
        tinyFont:t='yes'
      }

      text {
        id:t='middle'
        text:t=''
        top:t='ph/2 - h/2'
        position:t='absolute'
        width:t='pw'
        text-align:t='center'
      }

      expandImg {
        id:t='expandImg'
        height:t='0.01@scrn_tgt'
        width:t='2h'
        position:t='absolute'
        pos:t='pw/2 - w/2, ph - h'
        background-image:t='#ui/gameuiskin#expand_info'
        background-color:t='@premiumColor'
      }
    }

    hiddenDiv {
      width:t='pw'
      padding:t='0.08@scrn_tgt, 0, 0.01@scrn_tgt, 0'
      flow:t='vertical'

      <<#details>>
      <<>details>>
      <</details>>
    }
  }
}
<</logEntries>>
