tdiv {
  flow:t='vertical'

  <<#rows>>
  table {
    tr {
      td {
        activeText {
          min-width:t='0.25@scrn_tgt_font'
          parseTags:t='yes'
          text:t='<<name>>'
        }
      }
      td {
        cellType:t='tdRight'
        activeText {
          min-width:t='0.10@scrn_tgt_font'
          hideEmptyText:t='yes'
          parseTags:t='yes'
          text:t='<<info>>'
        }
      }
      td {
        cellType:t='tdRight'
        activeText {
          min-width:t='0.10@scrn_tgt_font'
          hideEmptyText:t='yes'
          parseTags:t='yes'
          text:t='<<time>>'
        }
      }
      td {
        cellType:t='tdRight'
        activeText {
          min-width:t='0.10@scrn_tgt_font'
          hideEmptyText:t='yes'
          parseTags:t='yes'
          text:t='<<value>>'
        }
      }
      td {
        cellType:t='tdRight'
        activeText {
          min-width:t='0.10@scrn_tgt_font'
          hideEmptyText:t='yes'
          parseTags:t='yes'
          text:t='<<reward>>'
        }
      }
    }
  }

  <<#bonuses>>
  tdiv {
    pos:t='0.03@scrn_tgt_font, 0'
    position:t='relative'
    width:t='0.62@scrn_tgt_font'

    include "gui/statistics/rewardSources"
  }
  <</bonuses>>
<</rows>>

<<#tooltipComment>>
  _newline {}

  textareaNoTab {
    max-width:t='0.65@scrn_tgt_font'
    style:t='color:@fadedTextColor'
    tinyFont:t='yes'
    text:t='<<tooltipComment>>'
  }
<</tooltipComment>>
}
