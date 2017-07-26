tdiv {
  id:t='battle_desc'
  size:t='fw, ph'
  flow:t='vertical'

  div {
    size:t='pw, fh'
    overflow-y:t='auto'
    flow:t='vertical'
    scrollbarShortcuts:t='yes'

    frameBlock {
      size:t='fw, ph'
      flow:t='vertical'

      tdiv {
        size:t='pw, fh'
        overflow-y:t='auto'
        flow:t='vertical'
        scrollbarShortcuts:t='yes'
        separatorInCenter:t='yes'

        tdiv {
          width:t='pw'
          padding:t='3*@sf/@pf'

          <<#teamBlock>>
          tdiv {
            size:t='50%pw - 2*@sf/@pf, fh'
            flow:t='vertical'

            tdiv{
              width:t="pw"
              padding:t='10*@sf/@pf, 0, 0, 0'

              cardImg{
                type:t='medium'
                background-image:t="<<countryIcon>>"
              }
            }

            <<#statistics>>
            tdiv {
              width:t="pw"
              padding:t='10*@sf/@pf, 0, 0, 0'

              textareaNoTab {
                width:t='0.3pw+@tableIcoSize'
                text:t=''
              }
              textareaNoTab {
                width:t='0.2pw'
                text-align:t="center"
                text:t='#debriefing/ww_engaged'
              }
              textareaNoTab {
                width:t='0.2pw'
                text-align:t="center"
                text:t='#debriefing/ww_casualties'
              }
              textareaNoTab {
                width:t='0.2pw'
                text-align:t="center"
                text:t='#debriefing/ww_left'
              }
            }

            <<#unitTypes>>
            tdiv {
              width:t="pw"
              padding:t='10*@sf/@pf, 0, 0, 0'

              textareaNoTab {
                pos:t='0, ph-h'
                position:t='relative'
                width:t='0.3pw + @tableIcoSize'
                pare-text:t='yes'
                text:t='<<name>>'
              }

              <<#row>>
                textareaNoTab {
                  width:t='0.2pw'
                  text-align:t="center"
                  text:t='<<col>>'
                }
              <</row>>
            }
            <</unitTypes>>

            tdiv {
              width:t="pw"
              height:t="@tableIcoSize"
            }

            <<#units>>
            tdiv {
              width:t="pw"
              padding:t='10*@sf/@pf, 0, 0, 0'

              tdiv {
                width:t='0.3pw + @tableIcoSize'
                position:t='relative'

                include "gui/worldWar/worldWarArmyInfoUnitString"
              }

              <<#row>>
                textareaNoTab {
                  width:t='0.2pw'
                  text-align:t="center"
                  text:t='<<col>>'
                }
              <</row>>
            }
            <</units>>
            <</statistics>>
          }
          <</teamBlock>>
        }
        chapterSeparator {
          class:t='inTheMiddle'
        }
      }
    }
  }
}
