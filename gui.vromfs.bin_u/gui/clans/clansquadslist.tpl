  <<#squad>>
      expandable {
        display:t='hide'
        selImg {
          flow:t='vertical'
          tdiv {
            size:t='pw, 0.055@scrn_tgt'

            textAreaNoScroll {
              id:t='leader_name'
              width:t='fw'
              max-height:t='ph'
              pare-text:t='yes'
              valign:t='center'
              class:t='active'
              overflow:t='hidden'
              text:t='<<leader_name>>'
            }

            tdiv {
              size:t='0.6pw, ph'
              left:t='pw-w'
              flow:t='vertical'

              text {
                id:t='num_members'
                width:t='pw'
                left:t='pw-w'
                text:t='<<num_members>>'
                text-align:t='right'
                smallFont:t='yes'
              }

              text {
                id:t='presence'
                top:t='ph-h'
                left:t='pw-w'
                position:t='absolute'
                width:t='pw'
                text-align:t='right'
                text:t='<<presence>>'
              }

              text {
                id:t='middle'
                text:t=''
                top:t='ph/2 - h/2'
                position:t='absolute'
                width:t='pw'
                text-align:t='center'
              }
            }
            expandImg {
              id:t='expandImg'
              height:t='0.01@scrn_tgt'
              width:t='2h'
              position:t='absolute'
              pos:t='pw/2 - w/2, ph - h'
            }
          }

          hiddenDiv {
            width:t='pw'
            padding:t='0.08@scrn_tgt, 0, 0.01@scrn_tgt, 0'
            flow:t='vertical'
          }
        }
      }
  <</squad>>