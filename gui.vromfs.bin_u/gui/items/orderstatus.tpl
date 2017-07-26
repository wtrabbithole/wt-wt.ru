// Same template for active and finished orders.

dummy {
  id:t='order_timer'
  behavior:t='Timer'
  timer_handler_func:t='onOrderTimerUpdate'
  timer_interval_msec:t='1000'
}

// Used in spectator mode.
<<#addScalableFrame>>
frame {
  id:t='order_status_frame'

  <<#orderStatusFrameSize>>
  size:t='<<orderStatusFrameSize>>'
  <</orderStatusFrameSize>>
  <<^orderStatusFrameSize>>
  size:t='0.7@itemInfoWidth, 0.7@itemInfoWidth'
  <</orderStatusFrameSize>>

  min-width:t='0.5@itemInfoWidth'
  min-height:t='0.5@itemInfoWidth'
  flow:t='vertical'
  overflow-y:t='auto'
  class:t='scaleable'
  position:t='relative'

  <<#orderStatusFramePos>>
  pos:t='<<orderStatusFramePos>>'
  <</orderStatusFramePos>>

  moveElem {
    check-off-screen:t='yes'
  }
<</addScalableFrame>>

textareaNoTab {
  id:t='status_text'
  width:t='pw - 10/720*@scrn_tgt'
  color:t='@red'
  text:t=''
  overlayTextColor:t='bad'
  total-input-transparent:t='yes'
  input-transparent:t='yes'
  padding-left:t='10/720*@scrn_tgt'
  padding-top:t='10/720*@scrn_tgt'
  tinyFont:t='yes'
  order-status-text-shade:t='yes'
}

table {
  id:t='status_table'
  margin-top:t='0.005*@scrn_tgt'
  margin-right:t='0.01*@scrn_tgt'
  width:t='pw - 10/720*@scrn_tgt'
  total-input-transparent:t='yes'
  input-transparent:t='yes'
  class:t='smallFont'

  <<#rows>>
  tr {
    height:t='0.6@baseTrHeight'
    id:t='order_score_row_<<rowIndex>>'
    td {
      img {
        id:t='order_score_pilot_icon'
        top:t='0.5ph - 0.7h'
        position:t='relative'
        size:t='16*@scrn_tgt/720, 16*@scrn_tgt/720'
        background-image:t='#ui/gameuiskin#player_in_queue'
      }
      textarea {
        id:t='order_score_player_name_text'
        removeParagraphIndent:t='yes'
        halign:t='left'
        text:t='Player Name'
        tinyFont:t='yes'
        order-status-text-shade:t='yes'
      }
    }
    td {
      textarea {
        id:t='order_score_value_text'
        removeParagraphIndent:t='yes'
        halign:t='center'
        text:t='0000'
        tinyFont:t='yes'
        order-status-text-shade:t='yes'
      }
    }
  }
  <</rows>>
}

textareaNoTab {
  id:t='status_text_bottom'
  width:t='pw - 10/720*@scrn_tgt'
  color:t='@red'
  text:t=''
  overlayTextColor:t='bad'
  total-input-transparent:t='yes'
  input-transparent:t='yes'
  tinyFont:t='yes'
  order-status-text-shade:t='yes'
}

<<#addScalableFrame>>
} // Closes frame block.
<</addScalableFrame>>
